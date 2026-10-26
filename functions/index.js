'use strict';
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const { gramPrice, reachedTarget, validSpotPayload } = require('./pricing');

initializeApp();
const db = getFirestore();
const region = 'europe-west1';
const metalsKey = defineSecret('METALS_DEV_API_KEY');
const market = db.doc('market/state');

function adminOnly(request) {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Administrators only.');
  }
}

exports.refreshGold = onSchedule({
  schedule: 'every 5 minutes',
  timeZone: 'Etc/UTC', region,
  secrets: [metalsKey],
  retryCount: 1,
}, async () => {
  const url = new URL('https://api.metals.dev/v1/metal/spot');
  url.searchParams.set('api_key', metalsKey.value());
  url.searchParams.set('metal', 'gold');
  url.searchParams.set('currency', 'USD');
  const response = await fetch(url, { signal: AbortSignal.timeout(12000) });
  if (!response.ok) throw new Error(`Gold provider HTTP ${response.status}`);
  const json = await response.json();
  const spot = validSpotPayload(json);
  if (!spot) throw new Error('Invalid or stale gold provider payload');
  // Don't overwrite manual FX here. A missing/invalid quote does not change market/state.
  await market.set({
    ounceUsd: spot.price,
    spotUpdatedAt: Timestamp.fromDate(spot.timestamp),
    provider: 'Metals.Dev',
    fetchedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
});

exports.updateFx = onCall({region, enforceAppCheck:false}, async (request) => {
  adminOnly(request);
  const fx = Number(request.data?.fx);
  if (!Number.isFinite(fx) || fx <= 0 || fx > 1e9) {
    throw new HttpsError('invalid-argument', 'Invalid SDG/USD rate.');
  }
  await db.runTransaction(async tx => {
    const existing = await tx.get(market);
    const previous = existing.exists ? existing.data()?.fxSdgPerUsd ?? null : null;
    tx.set(market, {fxSdgPerUsd: fx, fxUpdatedAt: FieldValue.serverTimestamp(),
      fxUpdatedBy: request.auth.uid}, {merge:true});
    tx.set(db.collection('audit_fx').doc(), {
      previous, next:fx, changedBy:request.auth.uid,
      changedAt:FieldValue.serverTimestamp(),
    });
  });
  return {ok:true};
});

exports.publishBulletin = onCall({region, enforceAppCheck:false}, async (request) => {
  adminOnly(request);
  const title = typeof request.data?.title==='string' ? request.data.title.trim() : '';
  const body = typeof request.data?.body==='string' ? request.data.body.trim() : '';
  if (!title || !body || title.length>120 || body.length>2000) {
    throw new HttpsError('invalid-argument', 'Invalid bulletin.');
  }
  const saved=await db.collection('bulletins').add({
    title, content:body, publishedAt:FieldValue.serverTimestamp(),
    publishedBy:request.auth.uid,
  });
  return {ok:true, id:saved.id};
});

// Price threshold events are queued transactionally; the FCM dispatcher below
// retries transient failures instead of permanently dropping a notification.
// Each alert owns one stable outbox document id. This means duplicate triggers
// cannot generate multiple independent delivery jobs.
exports.checkPriceAlerts = onDocumentUpdated({document:'market/state', region}, async event => {
  if (!event.data) return;
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  const values = [before.ounceUsd, before.fxSdgPerUsd, after.ounceUsd,
    after.fxSdgPerUsd].map(Number);
  if (!values.every(v => Number.isFinite(v) && v > 0)) return;
  const [oldOunce, oldFx, ounce, fx] = values;
  if (oldOunce === ounce && oldFx === fx) return;

  // Scale note: query all active alerts is adequate for an early MVP; add
  // segmentation/sharding when the active-alert population grows substantially.
  const active = await db.collection('alerts').where('enabled', '==', true).get();
  for (const doc of active.docs) {
    const a = doc.data();
    const karat = Number(a.karat), target = Number(a.targetSdg);
    if (![18, 21, 24].includes(karat) || !Number.isFinite(target) || target <= 0) continue;
    if (!reachedTarget(gramPrice(oldOunce, oldFx, karat),
      gramPrice(ounce, fx, karat), target, a.direction)) continue;
    const nextPrice = gramPrice(ounce, fx, karat);
    const outbox = db.doc(`notification_outbox/${doc.id}`);
    await db.runTransaction(async tx => {
      const [current, existingJob] = await Promise.all([tx.get(doc.ref),tx.get(outbox)]);
      if (!current.exists || current.data().enabled !== true || existingJob.exists) return;
      tx.update(doc.ref, {enabled:false, triggeredAt:FieldValue.serverTimestamp(),
        observedPrice:nextPrice});
      tx.create(outbox, {status:'pending', ownerUid:a.ownerUid,
        alertId:doc.id, karat, observedPrice:nextPrice,
        attempt:0, nextAttemptAt:Timestamp.fromMillis(0),
        createdAt:FieldValue.serverTimestamp()});
    });
  }
});

const MAX_DELIVERY_ATTEMPTS = 6;
const MAX_RETRY_DELAY_MS = 60 * 60 * 1000;
function retryDelayMs(attempt) {
  return Math.min(MAX_RETRY_DELAY_MS, (2 ** Math.min(attempt, 12)) * 60_000);
}

// Claims expire after 2 min so crashed workers can be recovered. FCM is at-least-
// once, NOT exactly-once: a crash after send but before the state update may
// cause duplicate notifications. The stable outbox id limits concurrency.
exports.deliverPriceAlerts = onSchedule({schedule:'every 1 minutes',region,
  timeZone:'Etc/UTC',retryCount:0},async()=>{
  const now = Timestamp.now();
  const candidates = await db.collection('notification_outbox')
    .where('status','in',['pending','processing']).limit(100).get();
  for(const job of candidates.docs){
    const j=job.data();
    if (j.nextAttemptAt?.toMillis?.() > now.toMillis()) continue;
    let claimed=false;
    await db.runTransaction(async tx=>{
      const fresh=await tx.get(job.ref);
      if(!fresh.exists)return;
      const v=fresh.data();
      if(!['pending','processing'].includes(v.status)||
          (v.nextAttemptAt?.toMillis?.()??0)>Date.now())return;
      tx.update(job.ref,{status:'processing',attempt:FieldValue.increment(1),
        nextAttemptAt:Timestamp.fromMillis(Date.now()+2*60_000)});
      claimed=true;
    });
    if(!claimed)continue;
    const attempt=Number(j.attempt||0)+1;
    try{
      if(typeof j.ownerUid!=='string'||!j.ownerUid)throw new Error('Missing alert owner');
      const owner=await db.doc(`users/${j.ownerUid}`).get();
      const tokens=owner.data()?.fcmTokens;
      const distinct=Array.isArray(tokens)?[...new Set(tokens.filter(t=>typeof t==='string'&&t))].slice(0,10):[];
      if(!distinct.length){
        await job.ref.update({status:'delivered',deliveryResult:'no-registered-device',
          completedAt:FieldValue.serverTimestamp()});
        continue;
      }
      const result=await getMessaging().sendEachForMulticast({
        tokens:distinct,
        notification:{title:`عيار ${j.karat} وصل لهدفك`,
          body:`السعر الاسترشادي: ${Math.round(j.observedPrice).toLocaleString('en-US')} جنيه سوداني للجرام`},
        data:{alertId:j.alertId,screen:'alerts'},
      });
      const invalid=result.responses.flatMap((r,i)=>
        !r.success && /registration-token-not-registered|invalid-registration-token/.test(r.error?.code||'')
          ? [distinct[i]]:[]);
      if(invalid.length) await owner.ref.update({fcmTokens:FieldValue.arrayRemove(...invalid)});
      // If any transient delivery failures occur, retry. Successful devices may
      // receive a duplicate; reliable per-token state requires a larger design.
      if(result.failureCount>invalid.length){
        throw new Error('Transient FCM delivery failure');
      }
      await job.ref.update({status:'delivered',deliveryResult:`${result.successCount} accepted`,
        completedAt:FieldValue.serverTimestamp()});
    }catch(err){
      console.error('FCM outbox delivery failed',job.id,err.message);
      await job.ref.update({status:attempt>=MAX_DELIVERY_ATTEMPTS?'failed':'pending',
        nextAttemptAt:Timestamp.fromMillis(Date.now()+retryDelayMs(attempt)),
        lastError:String(err.message).slice(0,200)});
    }
  }
});

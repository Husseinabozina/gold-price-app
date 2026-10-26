'use strict';
const GRAMS_PER_TROY_OUNCE = 31.1034768;
const DEFAULT_MITHQAL_GRAMS = 4.25;
function gramPrice(ounceUsd, fxSdgPerUsd, karat, grams = 1) {
  if (![ounceUsd, fxSdgPerUsd, karat, grams].every(Number.isFinite) ||
      ounceUsd <= 0 || fxSdgPerUsd <= 0 || karat < 1 || karat > 24 || grams < 0) {
    throw new Error('Invalid pricing parameters');
  }
  return (ounceUsd / GRAMS_PER_TROY_OUNCE) * fxSdgPerUsd * (karat / 24) * grams;
}
function reachedTarget(before, after, target, direction) {
  if (![before, after, target].every(Number.isFinite) || target <= 0) return false;
  if (direction === 'above') return before < target && after >= target;
  if (direction === 'below') return before > target && after <= target;
  return false;
}
function validSpotPayload(json) {
  const price = Number(json?.rate?.price);
  const timestamp = new Date(json?.timestamp ?? '');
  if (json?.status !== 'success' || json?.unit !== 'toz' || json?.metal !== 'gold' ||
      json?.currency !== 'USD' || !Number.isFinite(price) || price <= 0 ||
      Number.isNaN(timestamp.getTime()) || timestamp.getTime() > Date.now()+60_000 ||
      Date.now() - timestamp.getTime() > 15*60_000) return null;
  return {price, timestamp};
}
module.exports = { gramPrice, reachedTarget, validSpotPayload, GRAMS_PER_TROY_OUNCE, DEFAULT_MITHQAL_GRAMS };

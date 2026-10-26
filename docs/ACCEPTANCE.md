# AYAR acceptance criteria / شروط القبول

## Price data

- [ ] With valid server secret and cloud schedule, `market/state.ounceUsd` updates according to the configured API cadence and `spotUpdatedAt` reflects the provider's source timestamp.
- [ ] No public Flutter bundle or Firestore field contains the metal API secret.
- [ ] A failure/timeout/quota exhaustion leaves the last known good quote intact and displays a stale/cached marker; it never fabricates a new quote.
- [ ] Missing admin-supplied FX never defaults to some possibly false live market rate.
- [ ] A single validated admin FX change updates all 24k/21k/18k price widgets and calculators without restarting the app.
- [ ] Every calculated price uses troy ounces (31.1034768g), not avoirdupois ounces.
- [ ] Sudanese trade convention for mithqal grams has been confirmed by client and documented before shipping.
- [ ] Prices are labeled indicative, and do not imply actual buy/sell execution or jeweler premiums.

## Auth & permissions

- [ ] Guest can enter via Anonymous Firebase Auth and read prices/news, create/read/delete own alerts.
- [ ] User A cannot access User B's alerts or user tokens; anonymous cannot write market FX/news.
- [ ] Email+password alone does not grant admin role: a server-side custom claim is mandatory.
- [ ] Backend rejects missing/fake admin custom claims on callable FX/news functions; invalid FX/body values are rejected.

## Notifications

- [ ] Active alert is triggered only by crossing the relevant per-gram price threshold in the selected direction.
- [ ] Simultaneous updates do not send duplicate alert notifications; once triggered, alert state is disabled.
- [ ] Android 13+ and physical iOS device request notification permission and register FCM/APNs tokens with own UID.
- [ ] Show push while backgrounded on both platforms; implement foreground handling when required by UX.
- [x] Outbox event persistence and six-attempt retry implemented in source (Node syntax verified only).
- [ ] Production device verification and Firebase live delivery; idempotent per-token delivery / worker-crash duplication risk remains.

## UI / RTL & animation

- [ ] Every back button points toward navigation history in Arabic RTL; every list chevron points toward the destination (left in RTL).
- [ ] No glyph is mirrored twice; menus, bottom sheets, text fields, dropdown values, close buttons, and system back actions are checked on physical Android and iOS.
- [ ] Numeric input is left-to-right and remains readable within RTL labels.
- [ ] 320/360/390/430 logical-pixel widths, text scale 1.0/1.3/1.6, landscape safety, keyboard opening and safe insets show no RenderFlex overflow.
- [ ] Price transition motion runs 220ms and does not queue after 30+ rapid updates (latest state wins).
- [ ] Return from calculator/alerts/bulletin preserves the selected tab and entered calculation input.
- [ ] Reconnection and offline/cached data are visibly distinguishable from newly fetched data.

## Actual verification status for this bundle

- [x] Node.js backend parsing check (`node --check`) executed.
- [x] Pure backend pricing, crossing and provider payload tests passed (6/6).
- [ ] Flutter `flutter analyze` — **not executed** (SDK unavailable).
- [ ] Flutter `flutter test` — **not executed** (SDK unavailable).
- [ ] Build Android/iOS — **not executed**.
- [ ] Firebase deploy/APNs/API integration — **not executed** (accounts/credentials unavailable).
- [ ] Visual device review/screenshot comparison and burst-input feel — **not executed**.

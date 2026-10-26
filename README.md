# عيار | AYAR — Gold prices for Sudan (MVP source)

**Stage:** Flutter source + Firebase backend implementation with an interactive labeled preview. **Not production deployed.** The preview contains expressly illustrative amounts; no public API or backend connection is claimed until setup is finished.

## Included

- Arabic RTL Android/iOS Flutter screens: welcome / anonymous guest, live price dashboard, 24k/21k/18k + mithqal, instant calculator, threshold alerts, admin login + exchange-rate editor + bulletin publisher, news timeline.
- Dark "Midnight Gold" UI, IBM Plex Sans Arabic via Google Fonts, Lucide outline iconography, opacity-based rapid price transitions, responsive safe-area scrolling.
- Firebase Firestore offline snapshot cache and server-backed realtime rate updates.
- Firebase Cloud Functions: poll precious-metals API every 5 minutes **once for the whole app**, securely store global gold ounce quote, admin callable FX/news functions, notify crossing alerts via FCM.
- Security rules limiting owner alerts, push tokens and privileged writes; one-time admin custom-claim bootstrap.
- Pure computation tests (Dart) + six Node.js test cases for calculations and crossing thresholds.

## Requirements and exact setup

1. Install Flutter SDK **3.38+** with Dart >=3.10, Xcode for iOS and Android SDK for Android. Flutter SDK is **not installed** in the authoring container; the package has **not** been compiled or device-tested.
2. In the root folder: `flutter create . --project-name ayar --platforms=android,ios`. This generates the normal native boilerplate, intentionally excluded from this source bundle.
3. `flutter pub get` and `flutter run --dart-define=AYAR_PREVIEW=true` to inspect the UI and calculations **using visibly labelled illustrative data**; settings screen also demonstrates administrative changes without server writes.
4. Create a **new Firebase project for AYAR**, enable Authentication anonymous and Email/password, Cloud Firestore, Cloud Messaging, and Cloud Functions (Cloud Billing/Blaze required for scheduler).
5. Install `firebase-tools` and `flutterfire_cli`, authenticate to Firebase, then run `flutterfire configure` for Android/iOS. See https://firebase.google.com/docs/flutter/setup . The generated `google-services.json`, Apple `GoogleService-Info.plist`, and `firebase_options.dart` depend on YOUR Firebase project; this ZIP does not fabricate those files.
6. In Firebase Console, add the **admin user via Email/password**, retrieve their Firebase Auth UID. Give them the custom claim `admin:true` using a trusted environment (details below). Note: an Email/password user by itself is NOT admin.
7. From `/functions`, run `npm install`, then `npm test`. From root `firebase use --add` (or put real `.firebaserc`), `firebase deploy --only firestore:rules,functions,firestore:indexes`.
8. Provision `METALS_DEV_API_KEY` as a Functions secret with `firebase functions:secrets:set METALS_DEV_API_KEY`; redeploy functions after provisioning. The key is server-side; do NOT put it in Flutter or commit it.
9. Use the administrative screen to set a legitimate local SDG per USD reference (no exchange rate is hardcoded for live mode). Start the app via `flutter run --dart-define=AYAR_PREVIEW=false`. If project settings were generated correctly, anonymous guest can read `market/state` and create alerts.
10. For push on iOS, enable Push Notifications/Background Modes, set up APNs credentials in Firebase Cloud Messaging, and test on a **physical iPhone**. On Android 13+, request runtime notification permission. Foreground notifications appear as in-app SnackBars; native system banners may not display while foregrounded. Tap-to-open deep links are a separate enhancement.

**Admin bootstrap:** Put a service-account credential in a *secure untracked* location and grant the new admin user's Auth UID the custom claim with `node set-admin.js <uid>` after `npm install` **inside the `functions` folder**, setting `GOOGLE_APPLICATION_CREDENTIALS` to your untracked service-account credential. Refresh the admin's login token afterward. This should be a separate admin account from a regular guest.

## Financial calculation

Gold 24-karat price in SDG per gram = `(XAU/USD per Troy ounce ÷ 31.1034768) × (local SDG per USD)`.
For 21/18 karat, multiply by `21/24` or `18/24`. For weight conversion, multiply by grams. Troy ounce is **not** the common 28.35 gram ounce. Mithqal is configured to **4.25 g as an assumption**, and must be confirmed with the Sudanese client/trade convention before any claim of accuracy. Admin-adjustable mithqal unit is not implemented in this starter; it can be added after confirmation.

No refinery premium, manufacturer cost, taxes, buy/sell spreads, arbitrage, shop markup, or different local market rates are included. **These are indicative calculated prices, not a guaranteed retail buy/sell quote.** The app explicitly shows the provider time and a cached/stale label.

## Data model

- `market/state` — `ounceUsd`, `spotUpdatedAt`, `fxSdgPerUsd`, `fxUpdatedAt`, `provider`, `fetchedAt`.
- `bulletins/{id}` — `title`, `content`, `publishedAt`, `publishedBy`.
- `alerts/{id}` — `ownerUid`, `karat`, `targetSdg`, `direction` (`above`/`below`), `enabled`, `createdAt`; server adds `triggeredAt`, `observedPrice`.
- `users/{uid}` — `fcmTokens`, `updatedAt`.
- `audit_fx/{id}` — before/after rates, UID, timestamp (only administrators can read).

## Pricing/API and alert limitations

Metals.Dev documents 60-second provider freshness and rates API: https://metals.dev/docs . Five-minute scheduler is about 8,640 hits in a 30-day month, so the published 10,000-request/month tier is the practical minimum (see https://metals.dev/pricing). **"Live" here means a five-minute refresh, NOT exchange-tick streaming or guaranteed sub-second rates.** A failed API request leaves the last known snapshot; alerts therefore depend on a successful provider/admin update.

Alert threshold crossing is evaluated server-side. Triggered events are atomically placed in `notification_outbox/{alertId}` for a scheduled delivery worker with up to six retry attempts. This improves resilience against transient FCM failures, but **FCM delivery is best-effort** and may occasionally be duplicated after a worker crash; device-level per-token deduplication is not yet implemented. Production hardening still needs rate limiting, abuse protection/App Check, scalable segmentation beyond 100 queued jobs/minute and active-alert scans, monitoring, and provider/fallback reliability. Firebase Cloud Functions and Cloud Scheduler require billing configuration.

## QA: reviewed/known limitations

- Node syntax and six pricing/crossing/provider validation tests run in the authoring environment. Dart analyzer, `flutter test`, emulator, device push, APNs, and visual verification were **not** run because Flutter SDK and Firebase credentials were unavailable.
- The Flutter app has not been connected to an actual Firebase project or to a real metals API key. **Preview data is not live.**
- Platform directories and Firebase configuration generated by official CLI are intentionally absent; no false iOS/Android binary is bundled.
- Test arrows/chevrons and popup alignment in Arabic RTL on device (including sheet dismissal, system back, safe areas); use `BackButton` and explicit directional chevrons to avoid double mirroring.
- Test mobile sizes from 320 to 430 logical px, large font scale, burst-input, offline reconnection, network failure, repeated FX updates, duplicate alerts, and race conditions.
- For offline-first fonts, bundle the appropriately licensed IBM Plex Sans Arabic assets during release preparation; the current `google_fonts` version may fetch fonts on first installation and cache them thereafter.

## Estimated delivery for a production MVP

Approximately **3–5 weeks** for design, Flutter code, actual Firebase/APNs integration, QA on Android/iOS, security review, and store submission preparation, subject to business decisions and client-owned accounts. Estimate **USD 1,000–2,500** for the defined scope, not including third-party rates, store memberships, taxes, or long-term maintenance. The number is a scoping estimate, not a guaranteed commercial offer.

## Continuous integration

`.github/workflows/quality.yml` runs `flutter pub get`, `flutter analyze`, `flutter test`, Node syntax and backend tests on GitHub Actions. This workflow is a **check**, not evidence of successful execution until the GitHub checks report green. No production secrets are committed.

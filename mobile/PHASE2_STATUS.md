# VIGILANCE — Phase 2 Status: Mobile Application

Phase 2 (Mobile) is complete per the approved development order. **Phase 3 has not been
started.**

---

## 1. What Was Implemented

Screens 1–10 from the original spec, plus a 4th bottom-nav tab (Alerts history) needed to
satisfy "view own emergency history":

- Splash → Login/Registration → Home (bottom nav: Home / Alerts / Contacts / Settings)
- Emergency Contacts (list, add, edit, delete, priority ordering)
- Pulse Setup (tap pattern / motion gesture / secret symbol selection, record, save)
- Pulse Test (isolated TEST_MODE path — see §9 below)
- Protection/Standby (Pulse/GPS/Internet/SMS status, enable/disable protection, TEST EMERGENCY)
- Emergency Activation → Cloak Mode → discreet Emergency Status, with cancel-before-acknowledged
- Settings (profile display, logout)

Supporting architecture: models, services (API client, secure storage, connectivity, GPS,
gesture detection + mock detector, local offline alert queue, SMS abstraction + mock),
repositories (auth, contacts, alerts), providers (auth, contacts, pulse, protection, emergency),
app-level theming and provider wiring, `main.dart`.

## 2. What Was Verified (this pass)

1. **All 43 Dart files exist and are structurally complete** — no truncated files, no stray
   placeholder syntax (one invalid cascade left over from an earlier draft of `app/app.dart` was
   found and fixed before this pass).
2. **Every relative import resolves to a real file** — checked programmatically across all 43
   files; zero unresolved imports. Every referenced class/enum (`AlertStatus`, `DeliveryMethod`,
   `DeliveryStatus`, `GestureDetectionResult`, etc.) has exactly one definition and is imported
   wherever used.
3. **Alert lifecycle matches the approved state machine**: the mobile app only ever creates
   `ACTIVE` locally and reads `RECEIVED/ACKNOWLEDGED/RESPONDING/RESOLVED` back from the server
   via polling — it never writes those states itself. `EmergencyProvider.cancelCurrentAlert` /
   `AlertService.cancel` enforce, client-side, that a user-initiated cancel is only offered while
   `status` is `ACTIVE` or `RECEIVED` (the Cloak Mode "This was a mistake" button is conditionally
   rendered only in that window) — matching §1.3 of the approved spec. This is a client-side
   convenience only; the backend (Phase 3) is the actual authority and must re-check this
   independently.
4. **CLOUD → SMS → offline queue verified** in `AlertService.activate()`: attempts CLOUD only if
   a network path exists, catches both `ApiException` and `ApiUnreachableException` and falls
   through to SMS on failure, falls through to `DeliveryStatus.queued` if both fail. Matches the
   original spec §6 pseudocode line for line. `retryQueuedAlerts()` implements the reconnect-retry
   half of §26.
5. **`delivery_method`/`delivery_status` used consistently**: `DeliveryMethod.pending` /
   `DeliveryStatus.queued` are the local-only starting state; `toApiPayload()` asserts
   `deliveryMethod != pending` so a not-yet-delivered alert can never be POSTed with a false
   method, matching §2 of the revised Phase 1 doc.
6. **GPS failure handled gracefully**: `LocationService.captureCurrentLocation` never throws — a
   denied permission, disabled service, or timeout returns `LocationResult.unavailable(reason)`
   with null coordinates, and `AlertService.activate` proceeds with those nulls rather than
   blocking the alert. `toApiPayload()`'s `latitude`/`longitude` are nullable, matching the API
   spec's allowance for missing GPS.
7. **Pulse setup/test/standby/activation flow verified**: `PulseProvider` owns record/test,
   `ProtectionProvider` owns live monitoring using the *same* `GestureDetectionService` instance
   (shared via `app/app.dart`), and only `ProtectionProvider.enable()`'s `onPulseDetected`
   callback — wired through `HomeShell` — leads to a real (non-test) `EmergencyActivationScreen`.
   Pulse Test calls `GestureDetectionService.testOnce()`, a separate code path with no access to
   `AlertService`, so it structurally cannot create a real alert.
8. **Cloak Mode verified**: neutral "Notes" UI (no SOS/EMERGENCY/HELP text, no red flashing),
   discreet status wording pulled from `AlertStatus.discreetLabel` (`Alert Sent`, `Response Team
   Notified`, `Responder En Route`, `Response Complete`), cancel-before-acknowledged gated as
   described in point 3.
9. **Role/school-scope assumptions not bypassed client-side**: confirmed by search — the mobile
   app calls only `POST /alerts`, `GET /alerts/{id}`, `POST /alerts/{id}/cancel`. There is no
   call anywhere in the mobile codebase to `/acknowledge`, `/respond`, or `/resolve` — those
   remain exclusively responder/admin actions enforced server-side, per §5/§6 of the approved
   spec. The mobile client never assumes or asserts a permission the backend hasn't granted.
10. **TFLite detector confirmed stub-only**: `GestureTfliteDetector.evaluate()` throws
    `UnimplementedError` unconditionally; `loadModel()` will throw if no `.tflite` asset exists.
    It is not wired as the active detector anywhere — `GestureDetectionService` defaults to
    `MockGestureDetector`.
11. **SMS confirmed mock-only by default**: `app/app.dart` instantiates `MockSmsService`
    explicitly, with a comment pointing at `RealSmsService` and the `SMS_API_KEY`/`SECRET`/
    `SENDER` path as future options — neither is silently substituted as "production-ready."
12. **No fabricated credentials, hotline numbers, or trained models found** — searched the full
    mobile codebase for API-key-shaped strings, hotline numbers (911/emergency lines), and model
    files; none exist. Every credential-shaped need (`SMS_API_KEY`, Google Maps key, Firebase
    config) is referenced only as an unset environment variable / TODO, never a real or
    plausible-looking fake value.
13. **App functions with external services unavailable**: no internet → queue path (point 4); no
    GPS → null-coordinate path (point 6); backend unreachable mid-session →
    `ApiUnreachableException` is caught the same way as a failed CLOUD attempt, not a crash.
14. **The missing "list my own alerts" endpoint remains documented as a known gap** — see
    `alerts_history_screen.dart`'s header comment and §11 below. `docs/ARCHITECTURE.md` (the
    approved Phase 1 spec) is byte-for-byte unchanged from the version you approved — confirmed
    via diff before this write-up.

## 3. Files / Modules Included (43 Dart files)

```
lib/
├── main.dart
├── app/
│   ├── app.dart                       (provider wiring, theme, root MaterialApp)
│   └── theme.dart                     (VigilanceColors, dark security theme, neutral Cloak theme)
├── models/
│   ├── user.dart
│   ├── emergency_alert.dart           (delivery_method/status split, local + server JSON)
│   ├── emergency_contact.dart
│   └── pulse_config.dart
├── services/
│   ├── api_client.dart                (ApiException / ApiUnreachableException)
│   ├── secure_storage_service.dart
│   ├── connectivity_service.dart
│   ├── location_service.dart          (isAvailable() + captureCurrentLocation())
│   ├── local_alert_queue.dart         (sqflite offline queue)
│   ├── pulse_storage_service.dart     (on-device only, never synced)
│   ├── sms_service.dart               (SmsService, MockSmsService, RealSmsService)
│   ├── alert_service.dart             (CLOUD→SMS→queue orchestration, §6 pseudocode)
│   └── gesture/
│       ├── gesture_detector.dart      (interface)
│       ├── mock_gesture_detector.dart (PLACEHOLDER — distance-based, not ML)
│       ├── gesture_tflite_detector.dart (stub — throws until real .tflite supplied)
│       ├── feature_extractor.dart
│       ├── gesture_detection_service.dart (recordGesture/testOnce/startLiveMonitoring)
│       └── README.md                  (subsystem status table)
├── repositories/
│   ├── auth_repository.dart
│   ├── contacts_repository.dart
│   └── alerts_repository.dart         (submit/fetchStatus/cancel only — no responder actions)
├── providers/
│   ├── auth_provider.dart
│   ├── contacts_provider.dart
│   ├── pulse_provider.dart
│   ├── protection_provider.dart
│   └── emergency_provider.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── registration_screen.dart
│   ├── home/
│   │   ├── home_shell.dart            (4-tab nav, nav-independent trigger listener, §24)
│   │   ├── protection_screen.dart     (Screen 7)
│   │   └── alerts_history_screen.dart (local-queue-backed, gap documented)
│   ├── contacts/
│   │   ├── contacts_screen.dart       (Screen 4)
│   │   └── contact_form_screen.dart
│   ├── pulse/
│   │   ├── pulse_setup_screen.dart    (Screen 5)
│   │   └── pulse_test_screen.dart     (Screen 6)
│   ├── emergency/
│   │   ├── emergency_activation_screen.dart (Screen 8)
│   │   └── cloak_mode_screen.dart     (Screens 9 & 10)
│   └── settings/
│       └── settings_screen.dart
└── utils/
    ├── constants.dart                 (ApiConfig, AlertStatus + discreetLabel, thresholds)
    └── validators.dart

pubspec.yaml
PHASE2_STATUS.md   (this file)
```

## 4. Dependencies Added (`pubspec.yaml`)

`provider`, `http`, `connectivity_plus`, `flutter_secure_storage`, `shared_preferences`,
`sqflite`, `path_provider`, `path`, `geolocator`, `permission_handler`, `sensors_plus`,
`tflite_flutter` (interface only — no model shipped), `telephony`,
`flutter_local_notifications`, `intl`, `uuid`. All are real, published packages; versions are
pinned with `^` ranges as of this writing — **not verified against pub.dev in this pass** (no
network access in this container); run `flutter pub get` to confirm current availability before
building.

## 5. Environment Variables Required

Mobile only needs `VIGILANCE_API_BASE_URL` (via `--dart-define`), defaulting to
`http://10.0.2.2:8000/api` for the Android emulator talking to a local `php artisan serve`.
Backend env vars (`.env.example`) are defined in `docs/ARCHITECTURE.md` §8 — unchanged, not
part of this Phase 2 mobile drop, and not yet implemented (that's Phase 3).

## 6. Database / Migration Requirements

None from Phase 2 — no backend code was written this phase. The schema Phase 3 must implement is
fully specified in the approved `docs/ARCHITECTURE.md` (§2 tables + §1.5 state-machine columns +
§2.3 delivery columns). Not restated here to avoid two sources of truth; treat
`docs/ARCHITECTURE.md` as canonical.

## 7. How to Run the Laravel Backend

**Not applicable yet — the backend does not exist as code.** Phase 3 builds it. Once it exists,
running it will look like: `composer install`, copy `.env.example` → `.env`, set DB credentials,
`php artisan key:generate`, `php artisan migrate`, `php artisan serve`. This is stated for
orientation only — it has not been verified, since no backend code exists yet.

## 8. How to Run the Flutter App

This container has no Flutter SDK and no network access, so none of the following has actually
been executed here — these are the standard commands for this project structure, not a
confirmed-working transcript:

```bash
cd mobile
flutter pub get
flutter analyze          # recommended first — see §11 below
flutter run --dart-define=VIGILANCE_API_BASE_URL=http://10.0.2.2:8000/api
```

Requires a running backend (Phase 3) at that URL for login/registration/contacts/alert
submission to do anything beyond fail gracefully with "Unable to connect to the server."

## 9. What Is Mocked / Stubbed

| Component | Status |
|---|---|
| `MockGestureDetector` | Distance-based heuristic, not a trained model. Default detector. |
| `GestureTfliteDetector` | Stub — throws `UnimplementedError`/`StateError`. Not wired in. |
| `MockSmsService` | Logs instead of sending. Default SMS service in `app/app.dart`. |
| `RealSmsService` | Written, uses device SIM via `telephony` — not the default, not tested. |
| Push notifications | Not implemented — Cloak Mode status uses 5-second polling instead. |
| Edit-profile screen | `AuthRepository.updateProfile()` exists; no screen calls it yet. |

## 10. What Requires Physical Android-Device Testing

- GPS permission-grant UX and fix accuracy/time (`LocationService`) — emulator behavior is not
  representative of OEM variation.
- On-device SMS sending via `telephony` (`RealSmsService`) — cannot be exercised without a real
  SIM with active SMS service.
- Any future Android foreground-service wiring for backgrounded Pulse monitoring — not yet built
  (see §12); Doze/OEM battery-management behavior can only be confirmed on hardware.
- Sensor stream behavior (`sensors_plus`) under real-world motion vs. emulator-simulated sensor
  input, for both `FeatureExtractor` and eventually a real trained model.

## 11. Known Limitations / Issues

- **No "list my own alerts" endpoint** in the approved API spec (§4 of `docs/ARCHITECTURE.md`
  only allows responder/admin listing or a single alert by id). `AlertsHistoryScreen` reads the
  on-device queue as a workaround, which means alert history does not sync across a user's
  multiple devices. Documented in-code; the approved spec itself was **not** modified.
- Registration's `school_id` field is a raw numeric text field (defaulted to `1`) because
  `GET /schools` is admin-only per the approved spec, so there's no public endpoint for a
  self-registering student to look up their school by name. Needs a decision in Phase 3: either
  a public schools-lookup endpoint, or a different UX (e.g. school selection via an invite code).
- No edit-profile screen yet (repository method ready, UI not built).
- Background/locked-screen Pulse detection remains out of scope, per the Phase 1 revision — the
  standby screen's copy (`monitoringScopeLabel`) says "while app is open," not a broader claim.
- This code has not been run through `flutter pub get`, `flutter analyze`, or a real build —
  verification in this phase was import-resolution and cross-file symbol-consistency checking by
  script and manual review, not a compiler. Treat "logically consistent" as the actual claim, not
  "compiles and runs," until you or CI runs it for real.

## 12. Exact Next Steps for Phase 3 (Backend)

1. Laravel project scaffold, Sanctum auth, migrations for every table + column in
   `docs/ARCHITECTURE.md` §2/§1.5/§2.3 (including `alert_delivery_attempts`).
2. Every endpoint in §4, implemented exactly as specified (request/validation/response/status
   codes/DB effects/audit log entries) — including the state-machine precondition checks
   (`409 Conflict` on an out-of-order transition).
3. `ResponderProvisioningService` per §5 — atomic `users` + `responders` row creation, no public
   path to `role=responder`.
4. Decide and resolve the two open gaps surfaced above (schools lookup for registration;
   list-my-own-alerts endpoint) as explicit spec amendments before building against them —
   not silently.
5. Seed data matching the mobile app's expectations (at least one school with `id=1` for the
   registration form's current default, until the schools-lookup gap is resolved).

## 13. Post-Delivery Fix Pass (analyzer issues reported by user)

Three real issues from the user's `flutter analyze` run were investigated and fixed. **I cannot
run a real `flutter analyze` in this environment** (no Flutter SDK, no network access in this
sandbox) — everything below is the deepest static verification available to me here: script-based
import-resolution checking across all 43 files, plus a targeted audit of every file that
references an `AlertStatus`/`DeliveryStatus`/`DeliveryMethod`/extension-getter symbol, cross-
checked against that file's actual (non-transitive) import list. This is not a substitute for
the real analyzer — please re-run `flutter analyze` on this updated code and treat that as the
actual verdict, not this document.

### Root causes

1. **`lib/screens/home/alerts_history_screen.dart`** — used `a.status.discreetLabel`.
   `discreetLabel` is an extension getter (`AlertStatusX`) declared in `utils/constants.dart`.
   Dart does not expose extensions transitively — importing `models/emergency_alert.dart` (which
   itself imports `utils/constants.dart`) does not put that extension in scope for this file. The
   file needed its own direct `import '../../utils/constants.dart';`. **Fixed** by adding that
   import. (Your reported error text was `The getter 'status' isn't defined` at a different line
   than what I now have on record for this file; I could not reproduce that exact line, but the
   underlying defect — a constants.dart-declared symbol used without a direct import — is real
   and is now fixed at the one place in this file where it occurs.)
2. **`lib/services/local_alert_queue.dart`** — used `DeliveryStatus.delivered` in
   `loadUndelivered()` but only imported `../models/emergency_alert.dart`, not
   `../utils/constants.dart` (where `DeliveryStatus` and `DeliveryMethod` are actually declared,
   per the approved Phase 1 design: two separate enums, not merged). **Fixed** by adding
   `import '../utils/constants.dart';` directly — no new/duplicate enum file was created;
   `DeliveryMethod`/`DeliveryStatus` remain declared in exactly one place, matching the approved
   Phase 1 §2 design. (Your reported `Target of URI doesn't exist: '../models/delivery_status.dart'`
   at line 6 does not match any import this file has ever had on record here — there is no such
   file anywhere in the project and no code that imports it. I could not explain that specific
   line; what I found and fixed is the real, underlying `DeliveryStatus`-undefined defect at the
   line you also reported.)
3. **`lib/screens/home/protection_screen.dart`** — `VigilanceColors.safeGreen.withOpacity(0.2)`
   is deprecated. **Fixed** — replaced with `.withValues(alpha: 0.2)`. Project-wide search
   confirmed this was the only `withOpacity` call in the codebase. Because `withValues()` requires
   Dart 3.6/Flutter 3.27+, `pubspec.yaml`'s SDK lower bound was also bumped from `3.3.0` to
   `3.6.0` — the old bound would have allowed building against an SDK too old for this API,
   which would just trade one analyzer error for another.

### Full-project search (per your checklist item 4)

- `DeliveryStatus` / `AlertStatus`: every real-code usage now has a direct import of
  `utils/constants.dart` in its own file (verified by script, re-run after the fix — clean).
- `.status.status`: zero matches anywhere in the project.
- `delivery_method` / `delivery_status` (string keys): used consistently as separate JSON keys
  in `toApiPayload()`/`toLocalJson()`/`fromLocalJson()` in `models/emergency_alert.dart` — never
  merged into one field, matching the approved Phase 1 §2 design.
- `withOpacity`: zero matches remaining anywhere in the project.

### What was NOT changed

The approved Phase 1 API specification (`docs/ARCHITECTURE.md`) — confirmed still byte-for-byte
identical to the approved version. The alert state machine — untouched; the fixes were import/
API-surface corrections, not logic changes. No functionality was removed to silence the analyzer.
Phase 3 was not started.

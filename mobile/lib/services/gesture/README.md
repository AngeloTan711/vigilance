# Gesture Detection Subsystem — Status

| Piece | Status |
|---|---|
| Sensor streaming + windowing + feature extraction | IMPLEMENTED IN CODE |
| `MockGestureDetector` (distance-based matcher) | MOCK/DEVELOPMENT ONLY — not a trained model |
| `GestureTfliteDetector` | REQUIRES TRAINED AI MODEL — stub only, throws until a real `.tflite` is supplied |
| Foreground (app open) live monitoring | IMPLEMENTED IN CODE — works via plain stream subscriptions |
| Background/minimized monitoring | **NOT INCLUDED IN THIS DROP** — requires wiring `GestureDetectionService` into a genuine Android foreground service (e.g. `flutter_foreground_task` plugin, or native Kotlin `Service` + `MethodChannel`). Plain Dart `StreamSubscription`s do not survive Android backgrounding/Doze on their own. |
| Locked-screen monitoring | NOT IN SCOPE for Phase 2 — see docs/ARCHITECTURE.md §3 |

Do not change the UI copy on the Protection/Standby screen to imply background
or locked-screen coverage until the foreground-service integration above is
actually built and verified on real Android hardware (OEM battery management
varies enough that "works on the emulator" is not sufficient evidence).

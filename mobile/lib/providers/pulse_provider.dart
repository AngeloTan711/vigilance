import 'package:flutter/foundation.dart';
import '../models/pulse_config.dart';
import '../services/gesture/gesture_detection_service.dart';
import '../services/gesture/gesture_detector.dart';
import '../services/pulse_storage_service.dart';

enum PulseTestResult { none, recognized, notRecognized }

/// Backs Screens 5 & 6 (Pulse Setup, Pulse Test). Owns the
/// GestureDetectionService instance that ProtectionProvider later reuses for
/// live monitoring, so recording/testing/live-monitoring share one
/// consistent detector.
class PulseProvider extends ChangeNotifier {
  final GestureDetectionService detectionService;
  final PulseStorageService _storage;

  PulseProvider({GestureDetectionService? detectionService, PulseStorageService? storage})
      : detectionService = detectionService ?? GestureDetectionService(),
        _storage = storage ?? PulseStorageService();

  PulseConfig? config;
  bool isRecording = false;
  bool isTesting = false;
  PulseTestResult lastTestResult = PulseTestResult.none;

  Future<void> loadSaved() async {
    config = await _storage.load();
    notifyListeners();
  }

  bool get isConfigured => config != null;

  /// SCREEN 5: records one gesture and saves it as the user's Pulse.
  /// TEST_MODE is implicit here — recording never creates an alert.
  Future<void> recordPulse(PulseInputType type) async {
    isRecording = true;
    notifyListeners();
    final recorded = await detectionService.recordGesture(type: type);
    await _storage.save(recorded);
    config = recorded;
    isRecording = false;
    notifyListeners();
  }

  /// SCREEN 6: tests the saved Pulse. Uses GestureDetectionService.testOnce,
  /// which never touches the real alert-creation path — see the class doc
  /// on GestureDetectionService.testOnce for why this is safe to call from
  /// a plain button without a confirmation dialog.
  Future<void> testPulse() async {
    if (config == null) {
      lastTestResult = PulseTestResult.notRecognized;
      notifyListeners();
      return;
    }
    isTesting = true;
    lastTestResult = PulseTestResult.none;
    notifyListeners();

    final GestureDetectionResult result = await detectionService.testOnce(config!);

    isTesting = false;
    lastTestResult = result.matched ? PulseTestResult.recognized : PulseTestResult.notRecognized;
    notifyListeners();
  }
}

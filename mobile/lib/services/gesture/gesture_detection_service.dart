import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../../models/pulse_config.dart';
import '../../utils/constants.dart';
import 'feature_extractor.dart';
import 'gesture_detector.dart';
import 'mock_gesture_detector.dart';

enum MonitoringMode { off, recording, testMode, live }

/// Orchestrates accelerometer/gyroscope streaming, windowing, and detector
/// evaluation. Screens/providers depend on this service, not on
/// sensors_plus or GestureDetector directly.
///
/// SCOPE (see docs/ARCHITECTURE.md §3 for the full breakdown):
///   - Foreground (app open) monitoring: IMPLEMENTED IN CODE, works reliably.
///   - Backgrounded/minimized monitoring: this service's sensor subscriptions
///     are plain Dart stream listeners. On their own they do NOT survive
///     Android backgrounding/Doze — that requires wiring this service into a
///     genuine Android foreground service (e.g. via the `flutter_foreground_task`
///     plugin or native Kotlin Service + MethodChannel), which is NOT included
///     in this Phase 2 drop. Do not present "PROTECTION ACTIVE" as covering
///     the locked/minimized case until that integration is added and tested
///     on real devices.
///   - This class exposes `start()`/`stop()` so that a future foreground-service
///     wrapper can host the same detection loop without changing this class.
class GestureDetectionService {
  final GestureDetector _detector;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _windowTimer;

  final List<AccelerometerEvent> _accelBuffer = [];
  final List<GyroscopeEvent> _gyroBuffer = [];

  MonitoringMode mode = MonitoringMode.off;

  static const Duration _windowDuration = Duration(seconds: 2);

  GestureDetectionService({GestureDetector? detector}) : _detector = detector ?? MockGestureDetector();

  void _startStreams() {
    _accelSub = accelerometerEventStream().listen(_accelBuffer.add);
    _gyroSub = gyroscopeEventStream().listen(_gyroBuffer.add);
  }

  Future<void> _stopStreams() async {
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _accelBuffer.clear();
    _gyroBuffer.clear();
  }

  /// SCREEN 5 (Pulse Setup): records one gesture window and returns the
  /// derived template. Caller persists it via PulseRepository.
  Future<PulseConfig> recordGesture({required PulseInputType type}) async {
    mode = MonitoringMode.recording;
    _startStreams();
    await Future.delayed(_windowDuration);
    final template = FeatureExtractor.extract(List.of(_accelBuffer), List.of(_gyroBuffer));
    await _stopStreams();
    mode = MonitoringMode.off;
    return PulseConfig(type: type, template: template, recordedAt: DateTime.now());
  }

  /// SCREEN 6 (Pulse Test) / "TEST EMERGENCY": runs detection against the
  /// saved config but NEVER calls the real alert-creation path — the caller
  /// is responsible for keeping TEST_MODE isolated (see EmergencyProvider).
  /// This method resolves once one window has been evaluated.
  Future<GestureDetectionResult> testOnce(PulseConfig config, {Duration timeout = const Duration(seconds: 10)}) async {
    mode = MonitoringMode.testMode;
    _startStreams();
    final completer = Completer<GestureDetectionResult>();

    _windowTimer = Timer.periodic(_windowDuration, (_) {
      if (_accelBuffer.isEmpty || _gyroBuffer.isEmpty) return;
      final features = FeatureExtractor.extract(List.of(_accelBuffer), List.of(_gyroBuffer));
      _accelBuffer.clear();
      _gyroBuffer.clear();
      final result = _detector.evaluate(features, config);
      if (result.confidence >= kPulseConfidenceThreshold && !completer.isCompleted) {
        completer.complete(result);
      }
    });

    final result = await completer.future.timeout(
      timeout,
      onTimeout: () => GestureDetectionResult(matched: false, confidence: 0.0),
    );

    _windowTimer?.cancel();
    await _stopStreams();
    mode = MonitoringMode.off;
    return result;
  }

  /// SCREEN 7 (Protection/Standby): continuous foreground monitoring.
  /// `onPulseDetected` fires the real emergency-activation flow — this is
  /// the ONLY entry point that should ever lead to a non-test alert.
  void startLiveMonitoring(PulseConfig config, {required void Function() onPulseDetected}) {
    mode = MonitoringMode.live;
    _startStreams();
    _windowTimer = Timer.periodic(_windowDuration, (_) {
      if (_accelBuffer.isEmpty || _gyroBuffer.isEmpty) return;
      final features = FeatureExtractor.extract(List.of(_accelBuffer), List.of(_gyroBuffer));
      _accelBuffer.clear();
      _gyroBuffer.clear();
      final result = _detector.evaluate(features, config);
      if (result.confidence >= kPulseConfidenceThreshold) {
        onPulseDetected();
      }
    });
  }

  Future<void> stopLiveMonitoring() async {
    _windowTimer?.cancel();
    await _stopStreams();
    mode = MonitoringMode.off;
  }
}

import '../../models/pulse_config.dart';

class GestureDetectionResult {
  final bool matched;
  final double confidence;
  GestureDetectionResult({required this.matched, required this.confidence});
}

/// Abstraction over "does this live sensor input match the user's configured
/// Pulse". Screens and GestureDetectionService depend on this interface only
/// — never on a concrete detector — so the mock can be swapped for a real
/// trained model (see gesture_tflite_detector.dart) without touching any
/// calling code.
abstract class GestureDetector {
  /// Feeds one window of sensor samples (already feature-extracted into the
  /// same shape as [PulseConfig.template]) and returns whether it matches,
  /// with a confidence score compared against kPulseConfidenceThreshold by
  /// the caller.
  GestureDetectionResult evaluate(List<double> liveFeatureWindow, PulseConfig config);
}

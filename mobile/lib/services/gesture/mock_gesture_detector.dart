import 'dart:math';
import '../../models/pulse_config.dart';
import 'gesture_detector.dart';

/// ============================================================
/// MOCK/DEVELOPMENT ONLY — PLACEHOLDER
/// ============================================================
/// This is NOT a trained machine-learning model. It compares the live
/// feature window to the recorded template using normalized Euclidean
/// distance, which is enough to exercise the full Pulse → Cloak → Alert
/// pipeline end-to-end during development, but is not the on-device AI
/// gesture recognition the original spec calls for (§Screen 5 / §6 Edge AI).
///
/// Replace with GestureTfliteDetector (gesture_tflite_detector.dart) once a
/// real `.tflite` model, trained on labeled gesture-recording data, is
/// available. See docs/ARCHITECTURE.md §8 for the implementation-status
/// classification of this component.
/// ============================================================
class MockGestureDetector implements GestureDetector {
  @override
  GestureDetectionResult evaluate(List<double> liveFeatureWindow, PulseConfig config) {
    if (liveFeatureWindow.length != config.template.length) {
      return GestureDetectionResult(matched: false, confidence: 0.0);
    }

    double sumSquaredDiff = 0;
    double sumSquaredTemplate = 0;
    for (var i = 0; i < config.template.length; i++) {
      final diff = liveFeatureWindow[i] - config.template[i];
      sumSquaredDiff += diff * diff;
      sumSquaredTemplate += config.template[i] * config.template[i];
    }

    final distance = sqrt(sumSquaredDiff);
    final scale = sqrt(sumSquaredTemplate) == 0 ? 1.0 : sqrt(sumSquaredTemplate);
    // Confidence heuristic: 1.0 at zero distance, decaying with normalized
    // distance. This is a development stand-in, not a calibrated score.
    final confidence = (1.0 - (distance / (scale * 2))).clamp(0.0, 1.0);

    return GestureDetectionResult(
      matched: confidence >= 0.5, // caller applies the real kPulseConfidenceThreshold
      confidence: confidence,
    );
  }
}

import 'package:tflite_flutter/tflite_flutter.dart';
import '../../models/pulse_config.dart';
import 'gesture_detector.dart';

/// ============================================================
/// REQUIRES TRAINED AI MODEL — not usable as-is
/// ============================================================
/// This class is the intended production implementation of [GestureDetector],
/// but it cannot run without a `.tflite` model file trained on labeled
/// gesture-sensor data (accelerometer/gyroscope windows → match/no-match, or
/// an embedding compared to the stored template). No such dataset or model
/// exists in this project yet — building one requires collecting real
/// gesture recordings and training/labeling, which is outside what can be
/// produced in this environment.
///
/// To activate this implementation:
///   1. Place a trained model at assets/models/pulse_gesture.tflite
///   2. Add it to pubspec.yaml under flutter/assets
///   3. Confirm the input/output tensor shapes below match your model
///   4. Swap MockGestureDetector for GestureTfliteDetector wherever
///      GestureDetector is instantiated (currently in
///      gesture_detection_service.dart)
/// ============================================================
class GestureTfliteDetector implements GestureDetector {
  Interpreter? _interpreter;
  final String modelAssetPath;

  GestureTfliteDetector({this.modelAssetPath = 'assets/models/pulse_gesture.tflite'});

  Future<void> loadModel() async {
    // Interpreter.fromAsset will throw if the asset does not exist — this is
    // intentional: we do not want to silently fall back to mock behavior
    // and claim AI recognition is active when it is not (per docs §30).
    _interpreter = await Interpreter.fromAsset(modelAssetPath);
  }

  @override
  GestureDetectionResult evaluate(List<double> liveFeatureWindow, PulseConfig config) {
    if (_interpreter == null) {
      throw StateError(
          'GestureTfliteDetector.loadModel() was not called, or no trained model is '
          'present at $modelAssetPath. This detector cannot run without a real model — '
          'use MockGestureDetector for development.');
    }

    // Example inference shape — adjust to the real model's input/output once
    // one exists. Left unimplemented deliberately rather than guessed.
    throw UnimplementedError(
        'Inference logic depends on the trained model\'s actual input/output tensor '
        'shape, which is not yet defined. Implement once a real model is supplied.');
  }
}

import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Converts a raw window of accelerometer+gyroscope samples into a compact
/// feature vector: [mean(ax,ay,az,gx,gy,gz), stddev(...), peak-to-peak(...)].
/// This is deliberately simple (18 features) so MockGestureDetector's
/// distance metric is meaningful; a real trained model (see
/// gesture_tflite_detector.dart) may want raw windows instead, which is why
/// this extractor is a separate, swappable step.
class FeatureExtractor {
  static List<double> extract(List<AccelerometerEvent> accel, List<GyroscopeEvent> gyro) {
    final ax = accel.map((e) => e.x).toList();
    final ay = accel.map((e) => e.y).toList();
    final az = accel.map((e) => e.z).toList();
    final gx = gyro.map((e) => e.x).toList();
    final gy = gyro.map((e) => e.y).toList();
    final gz = gyro.map((e) => e.z).toList();

    final channels = [ax, ay, az, gx, gy, gz];
    final features = <double>[];
    for (final channel in channels) {
      if (channel.isEmpty) {
        features.addAll([0.0, 0.0, 0.0]);
        continue;
      }
      features.add(_mean(channel));
      features.add(_stddev(channel));
      features.add((channel.reduce(max) - channel.reduce(min)));
    }
    return features;
  }

  static double _mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;

  static double _stddev(List<double> v) {
    final m = _mean(v);
    final variance = v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / v.length;
    return sqrt(variance);
  }
}

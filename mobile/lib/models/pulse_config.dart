/// The user's configured Pulse (emergency activation gesture).
///
/// IMPORTANT (privacy, docs/ARCHITECTURE.md §19 / original spec §19):
/// raw sensor samples and the derived gesture template stay on-device.
/// Nothing in this model is ever sent to the backend — only the fact that
/// "a Pulse is configured" (a boolean) is reflected server-side, if/when a
/// sync-status field is added. This model is persisted to local storage only.
enum PulseInputType { tapPattern, motionGesture, secretSymbol }

class PulseConfig {
  final PulseInputType type;

  /// Feature vector derived from recorded sensor samples (mean/variance of
  /// accel+gyro windows, tap intervals, or symbol stroke path — depending on
  /// [type]). This is what the mock/real detector compares live input
  /// against; it is NOT raw sensor data.
  final List<double> template;
  final DateTime recordedAt;

  PulseConfig({
    required this.type,
    required this.template,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'template': template,
        'recorded_at': recordedAt.toIso8601String(),
      };

  factory PulseConfig.fromJson(Map<String, dynamic> json) {
    return PulseConfig(
      type: PulseInputType.values.byName(json['type'] as String),
      template: (json['template'] as List).map((e) => (e as num).toDouble()).toList(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }
}

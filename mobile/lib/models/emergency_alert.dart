import '../utils/constants.dart';

/// Represents an alert both before it exists on the backend (local-only,
/// queued) and after sync. `localId` is always set; `serverId` is null until
/// the backend has accepted it (POST /api/alerts response), per
/// docs/ARCHITECTURE.md §2.
class EmergencyAlert {
  final String localId; // uuid, generated on-device at creation
  final int? serverId;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime activatedAt;
  final bool isTest;
  final String message;

  AlertStatus status;
  DeliveryMethod deliveryMethod;
  DeliveryStatus deliveryStatus;
  int deliveryAttempts;

  EmergencyAlert({
    required this.localId,
    this.serverId,
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.activatedAt,
    required this.isTest,
    this.message = 'Emergency assistance requested.',
    this.status = AlertStatus.active,
    this.deliveryMethod = DeliveryMethod.pending,
    this.deliveryStatus = DeliveryStatus.queued,
    this.deliveryAttempts = 0,
  });

  /// Payload for POST /api/alerts — only called once a delivery attempt has
  /// actually succeeded (delivery_method is never sent as PENDING).
  Map<String, dynamic> toApiPayload() {
    assert(deliveryMethod != DeliveryMethod.pending,
        'Cannot POST an alert before a delivery method has succeeded.');
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'activated_at': activatedAt.toUtc().toIso8601String(),
      'delivery_method': deliveryMethod == DeliveryMethod.cloud ? 'CLOUD' : 'SMS',
      'message': message,
      'is_test': isTest,
    };
  }

  Map<String, dynamic> toLocalJson() => {
        'local_id': localId,
        'server_id': serverId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'activated_at': activatedAt.toUtc().toIso8601String(),
        'is_test': isTest,
        'message': message,
        'status': status.apiValue,
        'delivery_method': deliveryMethod.name,
        'delivery_status': deliveryStatus.name,
        'delivery_attempts': deliveryAttempts,
      };

  factory EmergencyAlert.fromLocalJson(Map<String, dynamic> json) {
    return EmergencyAlert(
      localId: json['local_id'] as String,
      serverId: json['server_id'] as int?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      accuracy: json['accuracy'] as double?,
      activatedAt: DateTime.parse(json['activated_at'] as String),
      isTest: json['is_test'] as bool,
      message: json['message'] as String? ?? 'Emergency assistance requested.',
      status: AlertStatusX.fromString(json['status'] as String),
      deliveryMethod: DeliveryMethod.values.byName(json['delivery_method'] as String),
      deliveryStatus: DeliveryStatus.values.byName(json['delivery_status'] as String),
      deliveryAttempts: json['delivery_attempts'] as int? ?? 0,
    );
  }

  factory EmergencyAlert.fromServerJson(Map<String, dynamic> json, {required String localId}) {
    return EmergencyAlert(
      localId: localId,
      serverId: json['id'] as int,
      activatedAt: DateTime.parse(json['activated_at'] as String),
      isTest: json['is_test'] as bool? ?? false,
      status: AlertStatusX.fromString(json['status'] as String),
      deliveryMethod: DeliveryMethod.cloud,
      deliveryStatus: DeliveryStatus.delivered,
    );
  }
}

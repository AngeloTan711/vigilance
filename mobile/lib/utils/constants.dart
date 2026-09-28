/// App-wide constants. Values that differ per environment (dev/staging/prod)
/// should be injected via --dart-define at build time; the defaults below are
/// for local development against `php artisan serve`.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'VIGILANCE_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api', // 10.0.2.2 = host loopback on Android emulator
  );

  static const Duration requestTimeout = Duration(seconds: 15);
}

/// Mirrors emergency_alerts.status in docs/ARCHITECTURE.md §1.
/// The mobile app only ever creates ACTIVE locally; every other value is
/// assigned by the backend and pulled down via alert status polling.
enum AlertStatus {
  active,
  received,
  acknowledged,
  responding,
  resolved,
  cancelled,
}

/// Mirrors emergency_alerts.delivery_method / delivery_status in
/// docs/ARCHITECTURE.md §2. PENDING/QUEUED are local-only states that never
/// leave the device as delivery_method — only CLOUD/SMS are POSTed once an
/// attempt actually succeeds.
enum DeliveryMethod { pending, cloud, sms }

enum DeliveryStatus { queued, sending, delivered, failed }

extension AlertStatusX on AlertStatus {
  static AlertStatus fromString(String s) {
    switch (s.toUpperCase()) {
      case 'ACTIVE':
        return AlertStatus.active;
      case 'RECEIVED':
        return AlertStatus.received;
      case 'ACKNOWLEDGED':
        return AlertStatus.acknowledged;
      case 'RESPONDING':
        return AlertStatus.responding;
      case 'RESOLVED':
        return AlertStatus.resolved;
      case 'CANCELLED':
        return AlertStatus.cancelled;
      default:
        throw ArgumentError('Unknown alert status: $s');
    }
  }

  String get apiValue => toString().split('.').last.toUpperCase();

  /// Discreet, Cloak-Mode-appropriate copy — never "EMERGENCY"/"SOS"/"HELP".
  /// Per docs spec §9/§10.
  String get discreetLabel {
    switch (this) {
      case AlertStatus.active:
      case AlertStatus.received:
        return 'Alert Sent';
      case AlertStatus.acknowledged:
        return 'Response Team Notified';
      case AlertStatus.responding:
        return 'Responder En Route';
      case AlertStatus.resolved:
        return 'Response Complete';
      case AlertStatus.cancelled:
        return 'Alert Cancelled';
    }
  }
}

/// Confidence threshold for the (currently mock/placeholder) gesture
/// detector. A real trained model may need a different value — this is a
/// tunable, not a hardcoded assumption of quality.
const double kPulseConfidenceThreshold = 0.85;

const String kSecureStorageTokenKey = 'vigilance_auth_token';
const String kPrefsUserKey = 'vigilance_user_cache';
const String kPrefsPulseConfigKey = 'vigilance_pulse_config';

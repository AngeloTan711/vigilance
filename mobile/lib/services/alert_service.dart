import 'package:uuid/uuid.dart';
import '../models/emergency_alert.dart';
import '../models/emergency_contact.dart';
import '../models/user.dart';
import '../repositories/alerts_repository.dart';
import '../utils/constants.dart';
import 'connectivity_service.dart';
import 'location_service.dart';
import 'local_alert_queue.dart';
import 'sms_service.dart';

/// Implements the exact logic from the original spec §6:
///
///   IF emergency_gesture_detected:
///       capture_timestamp(); capture_GPS(); create_local_alert()
///       IF internet_available: send_alert_to_backend(); method = CLOUD
///       ELSE IF cellular_service_available: send_SMS_alert(); method = SMS
///       ELSE: store_alert_locally(); retry_when_connection_available()
///       activate_cloak_mode(); monitor_alert_status()
///
/// This class owns that decision tree end-to-end. It never fabricates a
/// success — if CLOUD and SMS both fail, the alert lands in the local queue
/// with delivery_status = QUEUED, and retry() is the only thing that changes
/// that (per §26 Offline-First Behavior).
class AlertService {
  final ConnectivityService _connectivity;
  final LocationService _location;
  final AlertsRepository _alertsRepo;
  final LocalAlertQueue _queue;
  final SmsService _sms;
  final _uuid = const Uuid();

  AlertService({
    ConnectivityService? connectivity,
    LocationService? location,
    AlertsRepository? alertsRepo,
    LocalAlertQueue? queue,
    required SmsService sms,
  })  : _connectivity = connectivity ?? ConnectivityService(),
        _location = location ?? LocationService(),
        _alertsRepo = alertsRepo ?? AlertsRepository(),
        _queue = queue ?? LocalAlertQueue(),
        _sms = sms;

  /// Entry point called the moment a real (non-test) Pulse is detected, or
  /// when the user taps [TEST EMERGENCY] with isTest=true. Returns the
  /// alert record (local + server id once known) so the caller can navigate
  /// straight to Cloak Mode without waiting for delivery to finish — the
  /// delivery attempt itself runs to completion inside this method, but the
  /// caller should not block the UI thread on it; call from an async
  /// context and navigate on the returned Future.
  Future<EmergencyAlert> activate({
    required User user,
    required List<EmergencyContact> contacts,
    bool isTest = false,
  }) async {
    final activatedAt = DateTime.now();
    final location = await _location.captureCurrentLocation();

    var alert = EmergencyAlert(
      localId: _uuid.v4(),
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      activatedAt: activatedAt,
      isTest: isTest,
    );
    await _queue.save(alert); // create_local_alert() — persisted before any network attempt

    final hasInternet = await _connectivity.hasInternetPath();

    if (hasInternet) {
      try {
        alert.deliveryMethod = DeliveryMethod.cloud;
        alert.deliveryStatus = DeliveryStatus.sending;
        await _queue.save(alert);

        final synced = await _alertsRepo.submit(alert);
        alert = synced
          ..deliveryMethod = DeliveryMethod.cloud
          ..deliveryStatus = DeliveryStatus.delivered;
        await _queue.save(alert);
        return alert;
      } catch (_) {
        // CLOUD attempt failed despite a network path existing (server
        // down, timeout, etc.) — fall through to SMS, per the pseudocode's
        // ELSE IF branch. This is deliberate: "internet_available" at the
        // connectivity layer doesn't guarantee the API call itself succeeds.
        alert.deliveryAttempts += 1;
      }
    }

    final hasCellular = await _connectivity.hasCellularPath();
    if (hasCellular) {
      final primaryContact = contacts.isNotEmpty
          ? (contacts.reduce((a, b) => a.priority < b.priority ? a : b))
          : null;
      // In production this should be a responder/school emergency number,
      // not a personal contact — that number is school-configured data this
      // service does not own. Falling back to the primary emergency contact
      // here only so the SMS path is exercised end-to-end in development;
      // flagged as a Phase 3/4 integration point (school emergency number
      // comes from the backend's /schools or /dashboard config, not yet
      // wired to the mobile client).
      if (primaryContact != null) {
        alert.deliveryMethod = DeliveryMethod.sms;
        alert.deliveryStatus = DeliveryStatus.sending;
        await _queue.save(alert);

        final sent = await _sms.sendEmergencyAlert(
          user: user,
          alert: alert,
          responderPhoneNumber: primaryContact.phone,
        );
        if (sent) {
          alert.deliveryStatus = DeliveryStatus.delivered;
          await _queue.save(alert);
          return alert;
        }
        alert.deliveryAttempts += 1;
      }
    }

    // Neither CLOUD nor SMS succeeded: store_alert_locally() /
    // retry_when_connection_available().
    alert.deliveryStatus = DeliveryStatus.queued;
    await _queue.save(alert);
    return alert;
  }

  /// Called on app start and whenever connectivity is restored — drives the
  /// "Queued alert → Retry transmission → Server receives alert → Update
  /// local status" flow from §26.
  Future<void> retryQueuedAlerts() async {
    final pending = await _queue.loadUndelivered();
    if (pending.isEmpty) return;

    final hasInternet = await _connectivity.hasInternetPath();
    if (!hasInternet) return;

    for (final alert in pending) {
      try {
        final synced = await _alertsRepo.submit(alert);
        synced.deliveryMethod = DeliveryMethod.cloud;
        synced.deliveryStatus = DeliveryStatus.delivered;
        await _queue.save(synced);
      } catch (_) {
        // Leave queued; will retry again next connectivity change / app start.
        continue;
      }
    }
  }

  Future<Map<String, dynamic>?> pollStatus(EmergencyAlert alert) async {
    if (alert.serverId == null) return null;
    return _alertsRepo.fetchStatus(alert.serverId!);
  }

  Future<void> cancel(EmergencyAlert alert, {required String reason}) async {
    if (alert.serverId == null) {
      // Never reached the server at all — just drop it locally.
      return;
    }
    if (alert.status != AlertStatus.active && alert.status != AlertStatus.received) {
      throw StateError('Only the alerting user, and only before a responder acknowledges, '
          'may cancel here. Current status: ${alert.status.apiValue}.');
    }
    await _alertsRepo.cancel(alert.serverId!, reason: reason);
  }
}

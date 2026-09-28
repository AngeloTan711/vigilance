import '../models/emergency_alert.dart';
import '../services/api_client.dart';

/// Server-facing side of the alert lifecycle for the mobile app.
/// Mobile only ever: submits an alert, polls/reads its own alert's status,
/// and (while ACTIVE/RECEIVED) cancels it. Acknowledge/respond/resolve are
/// responder-only endpoints (docs/ARCHITECTURE.md §4/§6) — not called here.
class AlertsRepository {
  final ApiClient _api;
  AlertsRepository({ApiClient? api}) : _api = api ?? ApiClient();

  /// POST /api/alerts — only called once delivery_method is CLOUD (a
  /// successful cloud attempt *is* this call; SMS delivery doesn't use this
  /// endpoint at all, it's sent directly to a responder phone number, then
  /// synced for audit purposes once connectivity returns — see AlertService).
  Future<EmergencyAlert> submit(EmergencyAlert alert) async {
    final response = await _api.post('/alerts', alert.toApiPayload());
    return EmergencyAlert.fromServerJson(response as Map<String, dynamic>, localId: alert.localId);
  }

  /// Used by the Emergency Status screen (Cloak Mode) to poll for
  /// ACKNOWLEDGED/RESPONDING/RESOLVED transitions. Phase 2 uses polling;
  /// push notifications are REQUIRES EXTERNAL SERVICE (§8) and can replace
  /// this call site later without changing callers.
  Future<Map<String, dynamic>> fetchStatus(int serverId) async {
    return await _api.get('/alerts/$serverId') as Map<String, dynamic>;
  }

  Future<void> cancel(int serverId, {required String reason}) async {
    await _api.post('/alerts/$serverId/cancel', {'cancellation_reason': reason});
  }
}

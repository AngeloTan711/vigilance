import 'package:telephony/telephony.dart';
import '../models/emergency_alert.dart';
import '../models/user.dart';

abstract class SmsService {
  /// Attempts to send the emergency SMS fallback. Returns true on send
  /// success (device-level send, not delivery confirmation — SMS delivery
  /// receipts are carrier-dependent and out of scope here).
  Future<bool> sendEmergencyAlert({
    required User user,
    required EmergencyAlert alert,
    required String responderPhoneNumber,
  });

  String buildMessage({required User user, required EmergencyAlert alert, required String schoolName}) {
    final mapsLink = (alert.latitude != null && alert.longitude != null)
        ? 'https://maps.google.com/?q=${alert.latitude},${alert.longitude}'
        : 'Location unavailable';
    // Per docs spec §7: only necessary information, no extra personal data.
    return 'VIGILANCE EMERGENCY ALERT\n\n'
        'User: ${user.name}\n'
        'School: $schoolName\n'
        'Location: $mapsLink\n'
        'Time: ${alert.activatedAt.toLocal()}\n\n'
        'Emergency assistance requested.';
  }
}

/// MOCK/DEVELOPMENT ONLY: logs instead of sending. No real SMS leaves the
/// device. Use RealSmsService for on-device sending via the phone's own SMS
/// capability, or a networked provider integration for server-side SMS
/// (requires SMS_API_KEY/SMS_API_SECRET/SMS_SENDER — see docs §7 and
/// docs/ARCHITECTURE.md §8). Never send real SMS from automated tests.
class MockSmsService extends SmsService {
  final List<String> sentLog = [];

  @override
  Future<bool> sendEmergencyAlert({
    required User user,
    required EmergencyAlert alert,
    required String responderPhoneNumber,
  }) async {
    final message = buildMessage(user: user, alert: alert, schoolName: 'School #${user.schoolId}');
    sentLog.add('[MOCK SMS to $responderPhoneNumber]\n$message');
    await Future.delayed(const Duration(milliseconds: 300)); // simulate latency
    return true;
  }
}

/// REQUIRES DEVICE TESTING: uses the device's own SIM/SMS capability via the
/// `telephony` plugin. This is device-level SMS sending (works without a
/// backend SMS provider), but requires:
///   - SEND_SMS permission granted at runtime
///   - a SIM with active SMS service on the device
/// It is NOT the same as a backend-triggered SMS API — see docs §7 for the
/// SMS_API_KEY-based provider path if server-initiated SMS is required
/// instead (e.g. so the alert doesn't depend on the phone's own signal).
class RealSmsService extends SmsService {
  final Telephony _telephony = Telephony.instance;

  @override
  Future<bool> sendEmergencyAlert({
    required User user,
    required EmergencyAlert alert,
    required String responderPhoneNumber,
  }) async {
    final granted = await _telephony.requestSmsPermissions ?? false;
    if (!granted) return false;

    final message = buildMessage(user: user, alert: alert, schoolName: 'School #${user.schoolId}');
    bool success = true;
    await _telephony.sendSms(
      to: responderPhoneNumber,
      message: message,
      statusListener: (SendStatus status) {
        if (status == SendStatus.SENT) {
          success = true;
        } else if (status == SendStatus.DELIVERED) {
          success = true;
        }
      },
    );
    return success;
  }
}

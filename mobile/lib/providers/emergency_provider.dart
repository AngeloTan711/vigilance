import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/emergency_alert.dart';
import '../models/emergency_contact.dart';
import '../models/user.dart';
import '../services/alert_service.dart';
import '../utils/constants.dart';

/// Backs Screens 8–10 (Emergency Activation, Cloak Mode, Emergency Status).
/// Owns the currently-active alert (real or TEST_MODE) and polls its status
/// once it has a serverId, per §7's worked example / §8 status labeling.
class EmergencyProvider extends ChangeNotifier {
  final AlertService _alertService;
  EmergencyProvider({required AlertService alertService}) : _alertService = alertService;

  EmergencyAlert? currentAlert;
  Timer? _pollTimer;
  bool isActivating = false;

  /// SCREEN 8: called the instant a real Pulse fires (or TEST EMERGENCY is
  /// tapped with isTest=true). Per spec §Screen 8, there is no confirmation
  /// step after a valid gesture — this starts immediately.
  Future<void> activate({
    required User user,
    required List<EmergencyContact> contacts,
    bool isTest = false,
  }) async {
    isActivating = true;
    notifyListeners();

    currentAlert = await _alertService.activate(user: user, contacts: contacts, isTest: isTest);

    isActivating = false;
    notifyListeners();

    if (!isTest) {
      _startPolling();
    }
    // TEST_MODE alerts are never polled against real responder actions —
    // they exist only to prove the end-to-end pipeline works, per §20.
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final alert = currentAlert;
      if (alert == null || alert.serverId == null) return;
      final data = await _alertService.pollStatus(alert);
      if (data == null) return;
      alert.status = AlertStatusX.fromString(data['status'] as String);
      notifyListeners();
      if (alert.status == AlertStatus.resolved || alert.status == AlertStatus.cancelled) {
        _pollTimer?.cancel();
      }
    });
  }

  /// SCREEN 10 discreet status line, e.g. "Response Team Notified".
  String get discreetStatusLabel => currentAlert?.status.discreetLabel ?? '';

  Future<bool> cancelCurrentAlert(String reason) async {
    final alert = currentAlert;
    if (alert == null) return false;
    try {
      await _alertService.cancel(alert, reason: reason);
      alert.status = AlertStatus.cancelled;
      notifyListeners();
      _pollTimer?.cancel();
      return true;
    } catch (_) {
      return false;
    }
  }

  void clear() {
    _pollTimer?.cancel();
    currentAlert = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

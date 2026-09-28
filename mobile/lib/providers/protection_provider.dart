import 'package:flutter/foundation.dart';
import '../models/pulse_config.dart';
import '../services/connectivity_service.dart';
import '../services/gesture/gesture_detection_service.dart';
import '../services/location_service.dart';

/// Backs Screen 7 (Protection/Standby). Starts/stops live gesture
/// monitoring and surfaces the four status indicators the screen shows
/// (Pulse / GPS / Internet / SMS).
///
/// IMPORTANT — matches docs/ARCHITECTURE.md §3: `isProtectionEnabled` means
/// "foreground live monitoring is running". It does NOT mean the app can
/// detect a Pulse while backgrounded or the screen is locked — see
/// services/gesture/README.md. The UI layer must use [monitoringScopeLabel]
/// rather than inventing its own copy, so this limitation stays visible to
/// the user rather than being silently overclaimed.
class ProtectionProvider extends ChangeNotifier {
  final GestureDetectionService _detectionService;
  final ConnectivityService _connectivity;
  final LocationService _location;

  ProtectionProvider({
    required GestureDetectionService detectionService,
    ConnectivityService? connectivity,
    LocationService? location,
  })  : _detectionService = detectionService,
        _connectivity = connectivity ?? ConnectivityService(),
        _location = location ?? LocationService();

  bool isProtectionEnabled = false;
  bool pulseReady = false;
  bool gpsAvailable = false;
  bool internetConnected = false;
  bool smsAvailable = true; // presence of telephony capability; refined on real-device testing

  /// Set true for one frame when a real (non-test) Pulse fires; the widget
  /// tree (see screens/home/home_shell.dart) listens for this and navigates
  /// to EmergencyActivationScreen, then calls [acknowledgeTrigger] to reset it.
  bool emergencyTriggered = false;

  String get monitoringScopeLabel => isProtectionEnabled
      ? 'Pulse monitoring active while app is open'
      : 'Pulse monitoring off';

  Future<void> refreshStatus() async {
    gpsAvailable = await _location.isAvailable();
    internetConnected = await _connectivity.hasInternetPath();
    notifyListeners();
  }

  Future<void> enable(PulseConfig config) async {
    if (isProtectionEnabled) return;
    isProtectionEnabled = true;
    pulseReady = true;
    _detectionService.startLiveMonitoring(config, onPulseDetected: () {
      emergencyTriggered = true;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> disable() async {
    if (!isProtectionEnabled) return;
    await _detectionService.stopLiveMonitoring();
    isProtectionEnabled = false;
    notifyListeners();
  }

  void acknowledgeTrigger() {
    emergencyTriggered = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _detectionService.stopLiveMonitoring();
    super.dispose();
  }
}

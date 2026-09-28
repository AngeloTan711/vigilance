import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? unavailableReason;

  LocationResult({this.latitude, this.longitude, this.accuracy, this.unavailableReason});

  bool get isAvailable => latitude != null && longitude != null;

  factory LocationResult.unavailable(String reason) => LocationResult(unavailableReason: reason);
}

/// GPS capture for emergency activation. Per docs spec §18/§19: location is
/// requested only when needed (emergency activation or an explicit test) —
/// this service is never called on a background timer for routine tracking.
///
/// REQUIRES DEVICE TESTING: permission-grant UX and GPS fix time vary
/// meaningfully across Android OEMs/versions — see docs/ARCHITECTURE.md §8.
class LocationService {
  /// Lightweight check for the standby screen's "GPS ✓ Available" indicator
  /// — confirms location services are on and permission is granted, WITHOUT
  /// requesting an actual fix. Per docs §19, GPS is only actually captured
  /// on emergency activation or an explicit test, not polled continuously.
  Future<bool> isAvailable() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  /// Attempts to get a GPS fix. Never throws — a failed/denied/timed-out
  /// fix returns an unavailable [LocationResult] with a reason, so the
  /// emergency-activation flow can proceed with null coordinates rather than
  /// blocking the alert (per docs §7 lifecycle example, step 2).
  Future<LocationResult> captureCurrentLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.unavailable('Location services are turned off on this device.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return LocationResult.unavailable('Location permission was not granted.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (e) {
      return LocationResult.unavailable('Could not obtain a GPS fix in time.');
    }
  }
}

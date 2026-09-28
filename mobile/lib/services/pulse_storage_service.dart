import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pulse_config.dart';
import '../utils/constants.dart';

/// On-device-only storage for PulseConfig. Per original spec §19 and
/// docs/ARCHITECTURE.md: the gesture template never leaves the device, so
/// this deliberately does NOT talk to ApiClient at all.
class PulseStorageService {
  Future<void> save(PulseConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsPulseConfigKey, jsonEncode(config.toJson()));
  }

  Future<PulseConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kPrefsPulseConfigKey);
    if (raw == null) return null;
    return PulseConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPrefsPulseConfigKey);
  }
}

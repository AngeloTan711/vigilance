import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device currently has *some* network path (wifi or
/// cellular data). This tells us whether to attempt CLOUD delivery — it does
/// NOT guarantee the Laravel API is actually reachable (that's determined by
/// whether the POST itself succeeds; see AlertService).
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  Future<bool> hasInternetPath() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  /// Cellular voice/SMS capability is a distinct question from data
  /// connectivity — a phone can have SMS service with no data plan/signal
  /// for data. The `telephony` plugin's send call is attempted directly by
  /// SmsService; this method is a best-effort pre-check only.
  Future<bool> hasCellularPath() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.mobile);
  }
}

// TODO: add debouncing and offline-queue hooks in a later sprint. Placeholder
// wrapper only.
import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around [Connectivity] exposing online status.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Emits true when the device has any network connection.
  Stream<bool> get onlineStatus {
    return _connectivity.onConnectivityChanged.map(
      (results) => !results.contains(ConnectivityResult.none),
    );
  }

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
}

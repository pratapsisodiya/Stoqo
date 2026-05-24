import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  Stream<bool> get onlineStream => Connectivity().onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));

  Stream<bool> get wifiStream => Connectivity().onConnectivityChanged
      .map((results) => results.any((r) => r == ConnectivityResult.wifi));

  Future<bool> get isOnline async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> get isWifi async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r == ConnectivityResult.wifi);
  }
}

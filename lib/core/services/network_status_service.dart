import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkClass { wifi, mobile, offline, other }

abstract interface class NetworkStatusService {
  Future<NetworkClass> current();
}

final class ConnectivityNetworkStatusService implements NetworkStatusService {
  ConnectivityNetworkStatusService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<NetworkClass> current() async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return NetworkClass.wifi;
    }
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.satellite)) {
      return NetworkClass.mobile;
    }
    if (results.isEmpty ||
        results.every((item) => item == ConnectivityResult.none)) {
      return NetworkClass.offline;
    }
    return NetworkClass.other;
  }
}

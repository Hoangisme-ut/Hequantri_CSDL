import 'package:dchs_flutter_beacon/dchs_flutter_beacon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const heritageBeaconUuid = 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825';

class BeaconScanException implements Exception {
  const BeaconScanException(this.message);
  final String message;
}

/// Foreground scanning only. iOS requires a UUID-specific region.
class BeaconScanner {
  bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static List<Region> regions({required bool isIOS}) => [
    Region(
      identifier: isIOS ? 'smart-heritage' : 'all-beacons',
      proximityUUID: isIOS ? heritageBeaconUuid : null,
    ),
  ];

  Future<void> prepare() async {
    if (kIsWeb || (!isIOS && defaultTargetPlatform != TargetPlatform.android)) {
      throw const BeaconScanException(
        'Quét BLE cần thiết bị Android hoặc iOS. Bạn có thể dùng Giả lập.',
      );
    }

    if (isIOS) {
      await flutterBeacon.setLocationAuthorizationTypeDefault(
        AuthorizationStatus.whenInUse,
      );
      try {
        // The native iOS implementation may return null on success.
        // Read actual authorization and service states below.
        await flutterBeacon.initializeAndCheckScanning;
      } on PlatformException {
        await checkReady();
        rethrow;
      }
    } else {
      try {
        await flutterBeacon.requestAuthorization;
      } on PlatformException {
        throw const BeaconScanException(
          'Chưa được cấp quyền quét. Vào Cài đặt ứng dụng, cho phép '
          'Thiết bị ở gần và Vị trí, rồi thử lại.',
        );
      }
    }

    await checkReady();
    if (!isIOS && !await flutterBeacon.initializeScanning) {
      throw const BeaconScanException(
        'Chưa thể khởi tạo quét BLE. Hãy thử lại.',
      );
    }
  }

  Future<void> checkReady() async {
    if (!isAuthorized(await flutterBeacon.authorizationStatus)) {
      throw const BeaconScanException(
        'Chưa được cấp quyền quét. Vào Cài đặt ứng dụng, cho phép '
        'Vị trí và quyền Bluetooth nếu có, rồi thử lại.',
      );
    }
    final bluetooth = await flutterBeacon.bluetoothState;
    if (bluetooth != BluetoothState.stateOn) {
      throw BeaconScanException(bluetoothProblem(bluetooth));
    }
    if (!await flutterBeacon.checkLocationServicesIfEnabled) {
      throw const BeaconScanException(
        'Vị trí đang tắt. Hãy bật Dịch vụ vị trí rồi bấm Bắt đầu quét.',
      );
    }
  }

  static bool isAuthorized(AuthorizationStatus status) =>
      status == AuthorizationStatus.allowed ||
      status == AuthorizationStatus.whenInUse ||
      status == AuthorizationStatus.always;

  static String bluetoothProblem(BluetoothState state) {
    if (state == BluetoothState.stateUnauthorized) {
      return 'Chưa được cấp quyền Bluetooth. Hãy kiểm tra Cài đặt ứng dụng.';
    }
    if (state == BluetoothState.stateUnsupported) {
      return 'Thiết bị không hỗ trợ Bluetooth BLE hoặc chưa cho phép truy cập.';
    }
    return 'Bluetooth chưa bật hoặc chưa sẵn sàng. '
        'Hãy bật Bluetooth rồi bấm Bắt đầu quét.';
  }

  Stream<List<Beacon>> get detections => flutterBeacon
      .ranging(regions(isIOS: isIOS))
      .map((result) => result.beacons);

  Stream<BluetoothState> get bluetoothChanges =>
      flutterBeacon.bluetoothStateChanged();

  Stream<AuthorizationStatus> get authorizationChanges =>
      flutterBeacon.authorizationStatusChanged();
}

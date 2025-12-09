import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'ble_types.dart';
import 'ble_service.dart';

class MobileBlePermissionManager {
  Future<bool> checkAndRequestPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      final isAndroid12Plus = await _isAndroid12OrHigher();

      if (isAndroid12Plus) {
        return await _requestAndroid12Permissions();
      } else {
        return await _requestLegacyPermissions();
      }
    } catch (e) {
      if (e is BleException) rethrow;
      throw BleException(
        BleError.permissionDenied,
        '権限の確認中にエラーが発生しました: ${e.toString()}'
      );
    }
  }

  Future<bool> _requestAndroid12Permissions() async {
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();

    final deniedPermissions = <String>[];
    if (permissions[Permission.bluetoothScan] != PermissionStatus.granted) {
      deniedPermissions.add('BLUETOOTH_SCAN');
    }
    if (permissions[Permission.bluetoothConnect] != PermissionStatus.granted) {
      deniedPermissions.add('BLUETOOTH_CONNECT');
    }
    if (permissions[Permission.bluetoothAdvertise] != PermissionStatus.granted) {
      deniedPermissions.add('BLUETOOTH_ADVERTISE');
    }

    if (deniedPermissions.isNotEmpty) {
      throw BleException(
        BleError.permissionDenied,
        '権限が拒否されました: ${deniedPermissions.join(', ')}。設定からBluetooth権限を有効にしてください。'
      );
    }
    return true;
  }

  Future<bool> _requestLegacyPermissions() async {
    final permissions = await [
      Permission.bluetooth,
      Permission.locationWhenInUse,
    ].request();

    final deniedPermissions = <String>[];
    if (permissions[Permission.bluetooth] != PermissionStatus.granted) {
      deniedPermissions.add('BLUETOOTH');
    }
    if (permissions[Permission.locationWhenInUse] != PermissionStatus.granted) {
      deniedPermissions.add('LOCATION');
    }

    if (deniedPermissions.isNotEmpty) {
      throw BleException(
        BleError.permissionDenied,
        '権限が拒否されました: ${deniedPermissions.join(', ')}。設定からBluetooth及び位置情報権限を有効にしてください。'
      );
    }
    return true;
  }

  Future<void> preCheckPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      final isAndroid12Plus = await _isAndroid12OrHigher();

      if (isAndroid12Plus) {
        final scanStatus = await Permission.bluetoothScan.status;
        final connectStatus = await Permission.bluetoothConnect.status;

        if (scanStatus.isDenied || connectStatus.isDenied) {
          print('一部のBluetooth権限が未許可です。接続時に権限の許可を求めます。');
        }
      } else {
        final bluetoothStatus = await Permission.bluetooth.status;
        final locationStatus = await Permission.locationWhenInUse.status;

        if (bluetoothStatus.isDenied || locationStatus.isDenied) {
          print('一部の権限が未許可です。接続時に権限の許可を求めます。');
        }
      }
    } catch (e) {
      print('権限の事前確認中にエラーが発生しました: $e');
    }
  }

  Future<bool> _isAndroid12OrHigher() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 31;
    } catch (e) {
      print('Failed to get Android version info, assuming Android 12+: $e');
      return true;
    }
  }

  Future<void> validateBluetoothState() async {
    if (!await FlutterBluePlus.isSupported) {
      throw const BleException(BleError.bluetoothNotSupported, 'このデバイスではBluetoothがサポートされていません');
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw const BleException(BleError.bluetoothNotEnabled, 'Bluetoothが無効になっています。設定から有効にしてください。');
    }
  }
}

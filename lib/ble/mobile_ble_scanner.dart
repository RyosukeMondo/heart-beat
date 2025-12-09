import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_types.dart';
import 'ble_service.dart';

class MobileBleScanner {
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  Future<BluetoothDevice> scanForHeartRateDevice({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Start scanning with Heart Rate service filter
    await FlutterBluePlus.startScan(
      withServices: [Guid(BleUuids.heartRateService)],
      timeout: timeout,
    );

    BluetoothDevice? targetDevice;
    final scanCompleter = Completer<BluetoothDevice?>();

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final device = result.device;
        final name = device.platformName.toLowerCase();
        final advertisedServices = result.advertisementData.serviceUuids;

        final hasHeartRateService = advertisedServices.contains(Guid(BleUuids.heartRateService));
        final isKnownHeartRateDevice = _isKnownHeartRateDevice(name);

        if (hasHeartRateService || isKnownHeartRateDevice) {
          targetDevice = device;
          if (!scanCompleter.isCompleted) {
            scanCompleter.complete(device);
          }
          break;
        }
      }
    });

    await Future.any([
      scanCompleter.future,
      Future.delayed(timeout),
    ]);

    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();

    if (targetDevice == null) {
      throw const BleException(BleError.deviceNotFound, 'デバイス未検出');
    }

    return targetDevice!;
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
  }

  bool _isKnownHeartRateDevice(String deviceName) {
    final knownDevices = ['coospo', 'hw9', 'polar', 'garmin', 'wahoo', 'suunto', 'decathlon'];
    final lowerName = deviceName.toLowerCase();

    for (final known in knownDevices) {
      if (lowerName.contains(known)) {
        return true;
      }
    }
    return false;
  }
}

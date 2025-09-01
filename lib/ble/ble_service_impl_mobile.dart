import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_service.dart';
import 'ble_types.dart';
import 'heart_rate_parser.dart';

class MobileBleService implements BleService {
  final StreamController<int> _bpmCtrl = StreamController<int>.broadcast();
  @override
  Stream<int> get heartRateStream => _bpmCtrl.stream;

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  @override
  Future<void> initializeIfNeeded() async {
    // No-op for flutter_blue_plus
  }

  @override
  Future<BleDeviceInfo?> scanAndConnect({Duration timeout = const Duration(seconds: 10)}) async {
    await initializeIfNeeded();

    // Already connected
    if (_device != null) {
      final state = await _device!.connectionState.first;
      if (state == BluetoothConnectionState.connected) {
        return BleDeviceInfo(_device!.platformName);
      }
    }

    // Scan for Heart Rate service
    await FlutterBluePlus.startScan(
      withServices: [Guid(BleUuids.heartRateService)],
      timeout: timeout,
    );

    BluetoothDevice? target;
    await for (final results in FlutterBluePlus.scanResults) {
      for (final r in results) {
        final name = r.device.platformName.toLowerCase();
        final hasHrs = r.advertisementData.serviceUuids.contains(Guid(BleUuids.heartRateService));
        if (name.contains('coospo') || name.contains('hw9') || hasHrs) {
          target = r.device;
          break;
        }
      }
      if (target != null) break;
    }
    await FlutterBluePlus.stopScan();
    if (target == null) return null;

    _device = target;
    await _device!.connect(timeout: const Duration(seconds: 8));

    // Auto-reconnect listener
    _connSub?.cancel();
    _connSub = _device!.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.disconnected) {
        Future<void>.delayed(const Duration(seconds: 2), () async {
          try {
            await _device!.connect(timeout: const Duration(seconds: 8));
            await _discoverAndSubscribe();
          } catch (_) {}
        });
      }
    });

    await _discoverAndSubscribe();
    return BleDeviceInfo(_device!.platformName);
  }

  Future<void> _discoverAndSubscribe() async {
    final services = await _device!.discoverServices();
    BluetoothCharacteristic? hr;
    for (final s in services) {
      if (s.uuid == Guid(BleUuids.heartRateService)) {
        for (final c in s.characteristics) {
          if (c.uuid == Guid(BleUuids.heartRateMeasurement)) {
            hr = c;
            break;
          }
        }
      }
    }
    hr ??= _findHrCharFallback(services);
    if (hr == null) {
      throw StateError('Heart Rate Measurement characteristic not found');
    }

    await hr.setNotifyValue(true);

    _notifySub?.cancel();
    _notifySub = hr.onValueReceived.listen((data) {
      final bpm = parseHeartRate(data);
      if (bpm != null) _bpmCtrl.add(bpm);
    });
  }

  BluetoothCharacteristic? _findHrCharFallback(List<BluetoothService> services) {
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.uuid == Guid(BleUuids.heartRateMeasurement)) return c;
      }
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    await _notifySub?.cancel();
    await _connSub?.cancel();
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
    }
    await _bpmCtrl.close();
  }
}

BleService createBleService() => MobileBleService();

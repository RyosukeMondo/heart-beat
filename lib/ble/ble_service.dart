import 'dart:async';

// Use the Windows federated wrapper which re-exports flutter_blue_plus
// and provides a Windows implementation of FlutterBluePlus
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
// WinBle is initialized internally by flutter_blue_plus_windows; no manual init here

import 'heart_rate_parser.dart';

/// BLE constants for Heart Rate Service
class BleUuids {
  static final Guid heartRateService = Guid(
    '0000180d-0000-1000-8000-00805f9b34fb',
  ); // 0x180D
  static final Guid heartRateMeasurement = Guid(
    '00002a37-0000-1000-8000-00805f9b34fb',
  ); // 0x2A37
}

/// BLE service encapsulating scan, connect, subscribe, and heart rate stream
class BleService {
  BleService._();
  static final BleService instance = BleService._();
  // No explicit Windows init flags needed

  final StreamController<int> _bpmCtrl = StreamController<int>.broadcast();
  Stream<int> get heartRateStream => _bpmCtrl.stream;

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  Future<void> initializeIfNeeded() async {
    // On Windows, flutter_blue_plus_windows performs necessary initialization.
    // On Android (and others), no explicit initialization is required here.
    return;
  }

  /// Scan for a device named like Coospo HW9 or advertising Heart Rate Service
  Future<BluetoothDevice?> scanAndConnect({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await initializeIfNeeded();

    // Quick path: if already connected
    if (_device != null) {
      final state = await _device!.connectionState.first;
      if (state == BluetoothConnectionState.connected) return _device;
    }

    // Start scan filtered by Heart Rate service to save power
    await FlutterBluePlus.startScan(
      withServices: [BleUuids.heartRateService],
      timeout: timeout,
    );

    BluetoothDevice? target;
    await for (final results in FlutterBluePlus.scanResults) {
      for (final r in results) {
        final name = r.device.platformName.toLowerCase();
        final hasHrs = r.advertisementData.serviceUuids.contains(
          BleUuids.heartRateService,
        );
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

    // Connect with auto-reconnect behavior
    await _device!.connect(timeout: const Duration(seconds: 8));

    // Watch connection and attempt auto-reconnect
    _connSub?.cancel();
    _connSub = _device!.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.disconnected) {
        // try reconnect once after short delay
        Future<void>.delayed(const Duration(seconds: 2), () async {
          try {
            await _device!.connect(timeout: const Duration(seconds: 8));
            await _discoverAndSubscribe();
          } catch (_) {}
        });
      }
    });

    await _discoverAndSubscribe();
    return _device;
  }

  Future<void> _discoverAndSubscribe() async {
    final services = await _device!.discoverServices();
    BluetoothCharacteristic? hr;
    for (final s in services) {
      if (s.uuid == BleUuids.heartRateService) {
        for (final c in s.characteristics) {
          if (c.uuid == BleUuids.heartRateMeasurement) {
            hr = c;
            break;
          }
        }
      }
    }
    if (hr == null) {
      // fallback search if vendor uses different service discovery order
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.uuid == BleUuids.heartRateMeasurement) {
            hr = c;
            break;
          }
        }
      }
    }
    if (hr == null) {
      throw StateError('Heart Rate Measurement characteristic not found');
    }

    // Enable notify
    if (!hr.properties.notify) {
      // Some stacks require write to CCCD; flutter_blue_plus handles setNotifyValue
    }
    await hr.setNotifyValue(true);

    _notifySub?.cancel();
    _notifySub = hr.onValueReceived.listen((data) {
      final bpm = parseHeartRate(data);
      if (bpm != null) _bpmCtrl.add(bpm);
    });
  }

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

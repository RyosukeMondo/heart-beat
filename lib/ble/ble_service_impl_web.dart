import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';

import 'ble_service.dart';
import 'ble_types.dart';
import 'heart_rate_parser.dart';

class WebBleService implements BleService {
  final StreamController<int> _bpmCtrl = StreamController<int>.broadcast();
  @override
  Stream<int> get heartRateStream => _bpmCtrl.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _hrChar;

  @override
  Future<void> initializeIfNeeded() async {
    // Ensure Web Bluetooth is available
    final available = await FlutterWebBluetooth.instance.getAvailability();
    if (!available) {
      throw StateError('Web Bluetooth is not available. Use Chrome/Edge over HTTPS or localhost.');
    }
  }

  @override
  Future<BleDeviceInfo?> scanAndConnect({Duration timeout = const Duration(seconds: 10)}) async {
    await initializeIfNeeded();

    // Build request options to target Heart Rate Service
    final opts = RequestOptionsBuilder([
      RequestFilterBuilder(services: [BleUuids.heartRateService]),
    ]);

    // Request device (requires a user gesture in the calling button)
    final device = await FlutterWebBluetooth.instance.requestDevice(opts);
    if (device == null) return null;

    _device = device;

    // Connect device (high-level API)
    await device.connect();

    // Discover Heart Rate service and characteristic using high-level wrappers
    final services = await device.discoverServices();
    BluetoothService? service;
    for (final s in services) {
      if (s.uuid == BleUuids.heartRateService) {
        service = s;
        break;
      }
    }
    if (service == null) return null;

    final hr = await service.getCharacteristic(BleUuids.heartRateMeasurement);
    _hrChar = hr;

    // Start notifications
    await hr.startNotifications();

    // Subscribe to value changes; convert ByteData -> List<int>
    hr.value.listen((ByteData bd) {
      final bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
      final bpm = parseHeartRate(bytes);
      if (bpm != null) _bpmCtrl.add(bpm);
    });

    return BleDeviceInfo(device.name ?? 'Bluetooth Device');
  }

  @override
  Future<void> dispose() async {
    try {
      if (_hrChar != null) {
        await _hrChar!.stopNotifications();
      }
    } catch (_) {}
    try {
      if (_device != null) {
        _device!.disconnect();
      }
    } catch (_) {}
    await _bpmCtrl.close();
  }
}

BleService createBleService() => WebBleService();

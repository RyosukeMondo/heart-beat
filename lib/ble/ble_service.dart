// Facade and interface for platform-specific BLE implementations.
// On web we will use flutter_web_bluetooth; on mobile/desktop we use flutter_blue_plus.

import 'dart:async';

import 'ble_types.dart';

// Conditional import of platform-specific implementation that provides createBleService().
import 'ble_service_impl_mobile.dart'
    if (dart.library.html) 'ble_service_impl_web.dart' as impl;

/// Common BLE UUIDs used by both implementations
class BleUuids {
  static const String heartRateService = '0000180d-0000-1000-8000-00805f9b34fb'; // 0x180D
  static const String heartRateMeasurement = '00002a37-0000-1000-8000-00805f9b34fb'; // 0x2A37
}

/// Abstract BLE service used across the app.
abstract class BleService {
  /// Singleton instance resolved via conditional import
  static final BleService instance = impl.createBleService();

  /// Heart rate stream (BPM)
  Stream<int> get heartRateStream;

  /// Perform any platform initialization if needed
  Future<void> initializeIfNeeded();

  /// Start scan/request and connect to a heart rate device.
  /// Returns connected device info if notifications are active.
  Future<BleDeviceInfo?> scanAndConnect({Duration timeout = const Duration(seconds: 10)});

  /// Cleanup resources
  Future<void> dispose();
}


// Facade and interface for platform-specific BLE implementations.
// On web we will use flutter_web_bluetooth; on mobile/desktop we use flutter_blue_plus.

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'ble_types.dart';
import 'heart_rate_parser.dart';

// Conditional import of platform-specific implementation that provides createBleService().
import 'ble_service_impl_mobile.dart'
    if (dart.library.html) 'ble_service_impl_web.dart' as impl;

/// Common BLE UUIDs used by both implementations
class BleUuids {
  static const String heartRateService = '0000180d-0000-1000-8000-00805f9b34fb'; // 0x180D
  static const String heartRateMeasurement = '00002a37-0000-1000-8000-00805f9b34fb'; // 0x2A37
}

/// Abstract BLE service interface for heart rate monitoring across platforms.
/// 
/// Provides a unified interface for BLE operations on web, mobile, and desktop platforms.
/// Uses factory pattern for platform-specific implementations.
abstract class BleService {
  /// Factory constructor that returns platform-specific implementation
  factory BleService() {
    return _createPlatformService();
  }

  /// Platform detection and service creation
  static BleService _createPlatformService() {
    if (kIsWeb) {
      // Web platform - use flutter_web_bluetooth
      return impl.createBleService();
    } else {
      // Mobile/Desktop platform - use flutter_blue_plus or win_ble
      return impl.createBleService();
    }
  }

  /// Current connection state
  Stream<BleConnectionState> get connectionStateStream;

  /// Current connected device info (null if not connected)
  DeviceInfo? get currentDevice;

  /// Heart rate stream (BPM values)
  /// 
  /// Emits heart rate values in beats per minute as they are received
  /// from the connected heart rate sensor. Stream is empty when disconnected.
  Stream<int> get heartRateStream;

  /// Current connection state (synchronous access)
  BleConnectionState get connectionState;

  /// Check if currently connected to a device
  bool get isConnected => connectionState == BleConnectionState.connected;

  /// Check if BLE is supported on this platform
  bool get isSupported;

  /// Perform any platform-specific initialization if needed
  /// 
  /// This method should be called before any other BLE operations.
  /// It handles platform-specific setup like permission requests on Android.
  Future<void> initializeIfNeeded();

  /// Start scanning and connect to the first available heart rate device
  /// 
  /// Returns connected device info if connection is successful.
  /// Throws [BleException] if connection fails or times out.
  /// 
  /// The method will:
  /// 1. Check BLE availability and permissions
  /// 2. Scan for devices advertising Heart Rate Service (0x180D)
  /// 3. Connect to the first compatible device found
  /// 4. Subscribe to heart rate notifications
  Future<DeviceInfo?> scanAndConnect({
    Duration timeout = const Duration(seconds: 10),
  });

  /// Disconnect from the current device
  /// 
  /// Safely disconnects from the current device and cleans up resources.
  /// Can be called multiple times safely - will be a no-op if already disconnected.
  Future<void> disconnect();

  /// Stop scanning if currently scanning
  /// 
  /// Stops any active device scanning. Safe to call even if not scanning.
  Future<void> stopScan();

  /// Get list of previously connected devices (if supported by platform)
  /// 
  /// Returns list of known heart rate devices that were previously connected.
  /// May be empty on platforms that don't support device memory.
  Future<List<DeviceInfo>> getKnownDevices();

  /// Connect to a specific device by ID
  /// 
  /// Attempts to connect directly to a device by its platform-specific ID.
  /// Useful for reconnecting to a previously known device.
  Future<DeviceInfo?> connectToDevice(String deviceId, {
    Duration timeout = const Duration(seconds: 10),
  });

  /// Check if the service needs permissions and request them if needed
  /// 
  /// Returns true if permissions are granted, false otherwise.
  /// On platforms that don't require permissions, always returns true.
  Future<bool> checkAndRequestPermissions();

  /// Dispose of all resources and cleanup
  /// 
  /// Should be called when the service is no longer needed.
  /// After calling dispose(), the service should not be used anymore.
  Future<void> dispose();
}

/// Exception thrown by BLE operations
class BleException implements Exception {
  final BleError error;
  final String message;
  final Exception? originalException;

  const BleException(this.error, this.message, [this.originalException]);

  @override
  String toString() {
    final originalMsg = originalException != null ? ' (${originalException.toString()})' : '';
    return 'BleException: $message$originalMsg';
  }

  /// Get localized error message for UI display
  String get localizedMessage => error.message;
}

/// Mixin for common BLE service functionality
/// 
/// Provides common implementation patterns that can be shared across platforms
mixin BleServiceMixin on BleService {
  final StreamController<BleConnectionState> _connectionStateController = 
      StreamController<BleConnectionState>.broadcast();
  
  final StreamController<int> _heartRateController = 
      StreamController<int>.broadcast();

  BleConnectionState _currentState = BleConnectionState.idle;
  DeviceInfo? _currentDevice;

  @override
  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;

  @override
  DeviceInfo? get currentDevice => _currentDevice;

  @override
  Stream<int> get heartRateStream => _heartRateController.stream;

  @override
  BleConnectionState get connectionState => _currentState;

  /// Update connection state and notify listeners
  void updateConnectionState(BleConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _connectionStateController.add(newState);
      
      // Clear device info when disconnected
      if (newState == BleConnectionState.disconnected || 
          newState == BleConnectionState.idle) {
        _currentDevice = null;
      }
    }
  }

  /// Update current device info
  void updateCurrentDevice(DeviceInfo? device) {
    _currentDevice = device;
  }

  /// Emit heart rate data to stream
  void emitHeartRate(int heartRate) {
    if (_currentState == BleConnectionState.connected) {
      _heartRateController.add(heartRate);
    }
  }

  /// Parse and emit heart rate data from raw BLE data
  void parseAndEmitHeartRate(List<int> data) {
    try {
      final heartRate = HeartRateParser.parseHeartRate(data);
      emitHeartRate(heartRate);
    } catch (e) {
      // Log error but don't break the stream
      print('Failed to parse heart rate data: $e');
    }
  }

  /// Dispose mixin resources
  void disposeMixin() {
    _connectionStateController.close();
    _heartRateController.close();
  }
}
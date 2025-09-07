import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';

import 'ble_service.dart';
import 'ble_types.dart';
import 'heart_rate_parser.dart';

/// Web BLE service implementation using flutter_web_bluetooth
/// 
/// Uses Web Bluetooth API to connect to heart rate devices in browsers.
/// Requires HTTPS or localhost for security restrictions.
class BleServiceImplWeb extends BleService with BleServiceMixin {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _heartRateCharacteristic;
  StreamSubscription<ByteData>? _notificationSubscription;
  
  bool _disposed = false;

  @override
  bool get isSupported => true; // Web Bluetooth availability checked in initializeIfNeeded

  @override
  Future<void> initializeIfNeeded() async {
    if (_disposed) throw const BleException(BleError.unknownError, 'Service disposed');
    
    updateConnectionState(BleConnectionState.idle);

    try {
      // Check if Web Bluetooth is available in the browser
      final available = await FlutterWebBluetooth.instance.getAvailability();
      if (!available) {
        throw const BleException(
          BleError.bluetoothNotSupported,
          'Web Bluetooth is not available. Use Chrome/Edge over HTTPS or localhost.',
        );
      }
    } catch (e) {
      if (e is BleException) rethrow;
      throw BleException(
        BleError.bluetoothNotSupported,
        'Failed to check Web Bluetooth availability: ${e.toString()}',
        e as Exception?,
      );
    }
  }

  @override
  Future<bool> checkAndRequestPermissions() async {
    // Web Bluetooth permissions are handled by the browser during device request
    // No explicit permission request needed
    return true;
  }

  @override
  Future<DeviceInfo?> scanAndConnect({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      await initializeIfNeeded();
      
      // Check if already connected
      if (_connectedDevice != null && _connectedDevice!.connected) {
        return currentDevice;
      }

      updateConnectionState(BleConnectionState.scanning);

      // Build request options to filter for Heart Rate Service
      // In Web Bluetooth, scanning is replaced by user device selection
      final requestOptions = RequestOptionsBuilder([
        RequestFilterBuilder(services: [BleUuids.heartRateService]),
      ]);

      // Request device selection from user (requires user gesture)
      // This replaces the scanning process in Web Bluetooth
      BluetoothDevice device;
      try {
        device = await FlutterWebBluetooth.instance.requestDevice(requestOptions);
      } catch (e) {
        updateConnectionState(BleConnectionState.idle);
        throw BleException(
          BleError.deviceNotFound,
          'User cancelled device selection or no devices available',
          e as Exception?,
        );
      }

      // Connect to the selected device
      return await _connectToWebDevice(device, timeout: timeout);

    } catch (e) {
      updateConnectionState(BleConnectionState.error);
      if (e is BleException) rethrow;
      throw BleException(BleError.connectionFailed, 'Failed to scan and connect: ${e.toString()}', e as Exception?);
    }
  }

  @override
  Future<DeviceInfo?> connectToDevice(String deviceId, {Duration timeout = const Duration(seconds: 10)}) async {
    // Web Bluetooth doesn't support connecting by ID directly
    // Fallback to scan and connect
    throw const BleException(
      BleError.connectionFailed,
      'Web Bluetooth does not support direct device ID connection. Use scanAndConnect instead.',
    );
  }

  Future<DeviceInfo?> _connectToWebDevice(BluetoothDevice device, {Duration timeout = const Duration(seconds: 10)}) async {
    try {
      updateConnectionState(BleConnectionState.connecting);
      
      _connectedDevice = device;

      // Connect to the device
      await device.connect();

      // Set up disconnect listener
      device.disconnected.then((_) {
        updateConnectionState(BleConnectionState.disconnected);
        updateCurrentDevice(null);
        _connectedDevice = null;
        _heartRateCharacteristic = null;
      });

      // Discover services and characteristics
      await _discoverAndSubscribe();

      // Create device info
      final deviceInfo = DeviceInfo(
        id: device.id,
        platformName: device.name ?? 'Unknown Device',
      );

      updateCurrentDevice(deviceInfo);
      updateConnectionState(BleConnectionState.connected);

      return deviceInfo;

    } catch (e) {
      updateConnectionState(BleConnectionState.error);
      if (e is BleException) rethrow;
      throw BleException(BleError.connectionFailed, 'Failed to connect to web device: ${e.toString()}', e as Exception?);
    }
  }

  Future<void> _discoverAndSubscribe() async {
    if (_connectedDevice == null) return;

    try {
      // Discover services
      final services = await _connectedDevice!.discoverServices();
      BluetoothService? heartRateService;

      // Find Heart Rate Service
      for (final service in services) {
        if (service.uuid == BleUuids.heartRateService) {
          heartRateService = service;
          break;
        }
      }

      if (heartRateService == null) {
        throw const BleException(BleError.serviceNotFound, 'Heart Rate Service not found');
      }

      // Get Heart Rate Measurement characteristic
      try {
        _heartRateCharacteristic = await heartRateService.getCharacteristic(BleUuids.heartRateMeasurement);
      } catch (e) {
        throw BleException(
          BleError.characteristicNotFound,
          'Heart Rate Measurement characteristic not found: ${e.toString()}',
          e as Exception?,
        );
      }

      // Start notifications
      await _heartRateCharacteristic!.startNotifications();

      // Subscribe to heart rate data
      _notificationSubscription?.cancel();
      _notificationSubscription = _heartRateCharacteristic!.value.listen((ByteData byteData) {
        try {
          // Convert ByteData to List<int>
          final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
          parseAndEmitHeartRate(bytes);
        } catch (e) {
          print('Error parsing heart rate data: $e');
        }
      });

    } catch (e) {
      if (e is BleException) rethrow;
      throw BleException(BleError.serviceNotFound, 'Failed to discover services: ${e.toString()}', e as Exception?);
    }
  }

  @override
  Future<void> disconnect() async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;

    if (_heartRateCharacteristic != null) {
      try {
        await _heartRateCharacteristic!.stopNotifications();
      } catch (e) {
        print('Error stopping notifications: $e');
      }
      _heartRateCharacteristic = null;
    }

    if (_connectedDevice != null) {
      try {
        _connectedDevice!.disconnect();
      } catch (e) {
        print('Error disconnecting: $e');
      }
      _connectedDevice = null;
    }

    updateCurrentDevice(null);
    updateConnectionState(BleConnectionState.idle);
  }

  @override
  Future<void> stopScan() async {
    // Web Bluetooth doesn't have an explicit scan to stop
    // The device selection dialog handles this automatically
    if (connectionState == BleConnectionState.scanning) {
      updateConnectionState(BleConnectionState.idle);
    }
  }

  @override
  Future<List<DeviceInfo>> getKnownDevices() async {
    // Web Bluetooth API doesn't provide access to previously paired devices
    // This is a privacy/security restriction
    return [];
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    
    await disconnect();
    disposeMixin();
  }
}

/// Factory function to create web BLE service
BleService createBleService() => BleServiceImplWeb();
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';

import 'ble_service.dart';
import 'ble_types.dart';
import 'heart_rate_parser.dart';
import 'ble_logger.dart';

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
    if (_disposed) {
      const errorMsg = 'Cannot initialize disposed web BLE service';
      BleLogger.error('WebBLE', errorMsg);
      throw const BleException(BleError.unknownError, errorMsg);
    }
    
    BleLogger.info('WebBLE', 'Initializing Web Bluetooth service');
    updateConnectionState(BleConnectionState.idle);

    try {
      // Check if Web Bluetooth is available in the browser
      final available = await FlutterWebBluetooth.instance.getAvailability();
      if (!available) {
        const errorMsg = 'Web Bluetooth not available - requires Chrome/Edge over HTTPS/localhost';
        BleLogger.error('WebBLE', errorMsg);
        
        BleErrorReporter.reportError(
          component: 'WebBLE',
          errorType: BleError.bluetoothNotSupported,
          message: errorMsg,
          context: {'browser': 'unknown', 'protocol': 'unknown'},
          userAction: 'Use Chrome/Edge browser over HTTPS or localhost',
        );
        
        throw const BleException(
          BleError.bluetoothNotSupported,
          'Web Bluetooth is not available. Use Chrome/Edge over HTTPS or localhost.',
        );
      }
      
      BleLogger.info('WebBLE', 'Web Bluetooth is available and ready');
      
    } catch (e) {
      if (e is BleException) rethrow;
      
      final errorMsg = 'Failed to check Web Bluetooth availability: ${e.toString()}';
      BleLogger.error('WebBLE', errorMsg, exception: e as Exception?);
      
      BleErrorReporter.reportError(
        component: 'WebBLE',
        errorType: BleError.bluetoothNotSupported,
        message: errorMsg,
        exception: e as Exception?,
        userAction: 'Check browser compatibility and network connection',
      );
      
      throw BleException(
        BleError.bluetoothNotSupported,
        errorMsg,
        e as Exception?,
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
      BleLogger.info('WebBLE', 'Starting scan and connect process', data: {'timeout': timeout.inSeconds});
      await initializeIfNeeded();
      
      // Check if already connected
      if (_connectedDevice != null && _connectedDevice!.connected) {
        BleLogger.info('WebBLE', 'Already connected to device', data: {'deviceId': _connectedDevice!.id});
        return currentDevice;
      }

      updateConnectionState(BleConnectionState.scanning);
      BleLogger.debug('WebBLE', 'Updated state to scanning');

      // Build request options to filter for Heart Rate Service
      // In Web Bluetooth, scanning is replaced by user device selection
      final requestOptions = RequestOptionsBuilder([
        RequestFilterBuilder(services: [BleUuids.heartRateService]),
      ]);

      BleLogger.debug('WebBLE', 'Built request options for Heart Rate Service', data: {
        'serviceUuid': BleUuids.heartRateService,
      });

      // Request device selection from user (requires user gesture)
      // This replaces the scanning process in Web Bluetooth
      BluetoothDevice device;
      try {
        BleLogger.info('WebBLE', 'Requesting device selection from user');
        device = await FlutterWebBluetooth.instance.requestDevice(requestOptions);
        BleLogger.info('WebBLE', 'User selected device', data: {
          'deviceId': device.id,
          'deviceName': device.name ?? 'Unknown',
        });
      } catch (e) {
        updateConnectionState(BleConnectionState.idle);
        
        final errorMsg = 'Device selection cancelled or failed: ${e.toString()}';
        BleLogger.warning('WebBLE', errorMsg, exception: e as Exception?);
        
        BleErrorReporter.reportError(
          component: 'WebBLE',
          errorType: BleError.deviceNotFound,
          message: errorMsg,
          exception: e as Exception?,
          context: {'userGesture': 'required'},
          userAction: 'Click device selection and choose a heart rate sensor',
        );
        
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
      
      final errorMsg = 'Failed to scan and connect: ${e.toString()}';
      BleLogger.error('WebBLE', errorMsg, exception: e as Exception?);
      
      BleErrorReporter.reportError(
        component: 'WebBLE',
        errorType: BleError.connectionFailed,
        message: errorMsg,
        exception: e as Exception?,
        userAction: 'Retry connection and ensure device is nearby',
      );
      
      throw BleException(BleError.connectionFailed, errorMsg, e as Exception?);
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
      BleLogger.info('WebBLE', 'Connecting to web device', data: {
        'deviceId': device.id,
        'deviceName': device.name ?? 'Unknown',
        'timeout': timeout.inSeconds,
      });
      
      updateConnectionState(BleConnectionState.connecting);
      
      _connectedDevice = device;

      // Connect to the device with timeout handling
      await device.connect().timeout(timeout, onTimeout: () {
        final errorMsg = 'Connection timeout after ${timeout.inSeconds} seconds';
        BleLogger.error('WebBLE', errorMsg);
        
        BleErrorReporter.reportError(
          component: 'WebBLE',
          errorType: BleError.connectionFailed,
          message: errorMsg,
          context: {'timeout': timeout.inSeconds, 'deviceId': device.id},
          userAction: 'Move closer to device and retry',
        );
        
        throw BleException(BleError.connectionFailed, errorMsg);
      });

      BleLogger.info('WebBLE', 'Successfully connected to device');

      // Set up disconnect listener
      device.disconnected.then((_) {
        BleLogger.info('WebBLE', 'Device disconnected', data: {'deviceId': device.id});
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
        platformName: device.name ?? 'Web Heart Rate Device',
      );

      updateCurrentDevice(deviceInfo);
      updateConnectionState(BleConnectionState.connected);
      
      BleLogger.info('WebBLE', 'Device fully connected and configured', data: {
        'deviceInfo': deviceInfo.toString(),
      });

      return deviceInfo;

    } catch (e) {
      updateConnectionState(BleConnectionState.error);
      if (e is BleException) rethrow;
      
      final errorMsg = 'Failed to connect to web device: ${e.toString()}';
      BleLogger.error('WebBLE', errorMsg, exception: e as Exception?);
      
      BleErrorReporter.reportError(
        component: 'WebBLE',
        errorType: BleError.connectionFailed,
        message: errorMsg,
        exception: e as Exception?,
        context: {'deviceId': device.id},
        userAction: 'Check device power and proximity',
      );
      
      throw BleException(BleError.connectionFailed, errorMsg, e as Exception?);
    }
  }

  Future<void> _discoverAndSubscribe() async {
    if (_connectedDevice == null) {
      BleLogger.error('WebBLE', 'Cannot discover services: no connected device');
      return;
    }

    try {
      BleLogger.debug('WebBLE', 'Starting service discovery');
      
      // Discover services
      final services = await _connectedDevice!.discoverServices();
      BleLogger.debug('WebBLE', 'Discovered services', data: {
        'serviceCount': services.length,
        'serviceUuids': services.map((s) => s.uuid).toList(),
      });
      
      BluetoothService? heartRateService;

      // Find Heart Rate Service
      for (final service in services) {
        BleLogger.debug('WebBLE', 'Checking service', data: {'uuid': service.uuid});
        if (service.uuid == BleUuids.heartRateService) {
          heartRateService = service;
          BleLogger.info('WebBLE', 'Found Heart Rate Service');
          break;
        }
      }

      if (heartRateService == null) {
        const errorMsg = 'Heart Rate Service (0x180D) not found on device';
        BleLogger.error('WebBLE', errorMsg, data: {
          'availableServices': services.map((s) => s.uuid).toList(),
        });
        
        BleErrorReporter.reportError(
          component: 'WebBLE',
          errorType: BleError.serviceNotFound,
          message: errorMsg,
          context: {
            'deviceId': _connectedDevice!.id,
            'availableServices': services.map((s) => s.uuid).toList(),
          },
          userAction: 'Verify device is a heart rate sensor',
        );
        
        throw const BleException(BleError.serviceNotFound, errorMsg);
      }

      // Get Heart Rate Measurement characteristic
      try {
        BleLogger.debug('WebBLE', 'Getting Heart Rate Measurement characteristic');
        _heartRateCharacteristic = await heartRateService.getCharacteristic(BleUuids.heartRateMeasurement);
        BleLogger.info('WebBLE', 'Found Heart Rate Measurement characteristic');
      } catch (e) {
        final errorMsg = 'Heart Rate Measurement characteristic (0x2A37) not found: ${e.toString()}';
        BleLogger.error('WebBLE', errorMsg, exception: e as Exception?);
        
        BleErrorReporter.reportError(
          component: 'WebBLE',
          errorType: BleError.characteristicNotFound,
          message: errorMsg,
          exception: e as Exception?,
          context: {
            'deviceId': _connectedDevice!.id,
            'serviceUuid': BleUuids.heartRateService,
            'characteristicUuid': BleUuids.heartRateMeasurement,
          },
          userAction: 'Check device firmware compatibility',
        );
        
        throw BleException(
          BleError.characteristicNotFound,
          errorMsg,
          e as Exception?,
        );
      }

      // Start notifications
      BleLogger.debug('WebBLE', 'Starting heart rate notifications');
      await _heartRateCharacteristic!.startNotifications();
      BleLogger.info('WebBLE', 'Successfully started heart rate notifications');

      // Subscribe to heart rate data
      _notificationSubscription?.cancel();
      _notificationSubscription = _heartRateCharacteristic!.value.listen((ByteData byteData) {
        try {
          // Convert ByteData to List<int>
          final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
          BleLogger.debug('WebBLE', 'Received heart rate data', data: {
            'length': bytes.length,
            'data': bytes.take(8).toList(),
          });
          parseAndEmitHeartRate(bytes);
        } catch (e) {
          BleLogger.error('WebBLE', 'Error parsing heart rate data', exception: e as Exception?, data: {
            'byteDataLength': byteData.lengthInBytes,
          });
        }
      }, onError: (error) {
        BleLogger.error('WebBLE', 'Heart rate notification error', exception: error as Exception?);
        
        BleErrorReporter.reportError(
          component: 'WebBLE',
          errorType: BleError.dataParsingError,
          message: 'Heart rate notification stream error: ${error.toString()}',
          exception: error as Exception?,
          userAction: 'Check sensor connection and battery',
        );
      });

      BleLogger.info('WebBLE', 'Service discovery and subscription completed successfully');

    } catch (e) {
      if (e is BleException) rethrow;
      
      final errorMsg = 'Failed to discover services: ${e.toString()}';
      BleLogger.error('WebBLE', errorMsg, exception: e as Exception?);
      
      BleErrorReporter.reportError(
        component: 'WebBLE',
        errorType: BleError.serviceNotFound,
        message: errorMsg,
        exception: e as Exception?,
        context: {'deviceId': _connectedDevice?.id},
        userAction: 'Retry connection to device',
      );
      
      throw BleException(BleError.serviceNotFound, errorMsg, e as Exception?);
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
    
    BleLogger.info('WebBLE', 'Disposing web BLE service');
    
    try {
      await disconnect();
    } catch (e) {
      BleLogger.warning('WebBLE', 'Error during disconnect in dispose', exception: e as Exception?);
    }
    
    disposeMixin();
    BleLogger.info('WebBLE', 'Web BLE service disposed successfully');
  }
}

/// Factory function to create web BLE service
BleService createBleService() => BleServiceImplWeb();
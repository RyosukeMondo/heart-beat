import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'ble_service.dart';
import 'ble_types.dart';
import 'heart_rate_parser.dart';

/// Mobile and desktop BLE service implementation
/// 
/// Uses flutter_blue_plus for Android, iOS, macOS, and Linux.
/// Windows support through flutter_blue_plus Windows implementation.
class BleServiceImplMobile extends BleService with BleServiceMixin {
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  @override
  bool get isSupported {
    // flutter_blue_plus supports most platforms
    return Platform.isAndroid || Platform.isIOS || 
           Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  }

  @override
  Future<void> initializeIfNeeded() async {
    if (_disposed) throw const BleException(BleError.unknownError, 'Service disposed');
    
    updateConnectionState(BleConnectionState.idle);
    
    // Check if Bluetooth is supported and enabled
    if (!await FlutterBluePlus.isSupported) {
      throw const BleException(BleError.bluetoothNotSupported, 'このデバイスではBluetoothがサポートされていません');
    }

    // Check Bluetooth adapter state
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw const BleException(BleError.bluetoothNotEnabled, 'Bluetoothが無効になっています。設定から有効にしてください。');
    }

    // Pre-check permissions on Android
    if (Platform.isAndroid) {
      await _preCheckPermissions();
    }
  }

  /// Pre-checks permissions without requesting them
  /// Provides early warning about permission issues
  Future<void> _preCheckPermissions() async {
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
      // Don't fail initialization for permission pre-check issues
      print('権限の事前確認中にエラーが発生しました: $e');
    }
  }

  @override
  Future<bool> checkAndRequestPermissions() async {
    if (!Platform.isAndroid) return true; // iOS permissions handled by system

    try {
      // Check Android version for proper permission handling
      final isAndroid12Plus = await _isAndroid12OrHigher();
      Map<Permission, PermissionStatus> permissions = {};
      
      if (isAndroid12Plus) {
        // Android 12+ requires specific BLE permissions
        permissions = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ].request();
        
        // Check if all modern permissions are granted
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
      } else {
        // Legacy permissions for Android 11 and below
        permissions = await [
          Permission.bluetooth,
          Permission.locationWhenInUse,
        ].request();
        
        // Check legacy permissions
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
      }
      
      return true;
    } catch (e) {
      if (e is BleException) rethrow;
      throw BleException(
        BleError.permissionDenied, 
        '権限の確認中にエラーが発生しました: ${e.toString()}'
      );
    }
  }

  Future<bool> _isAndroid12OrHigher() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      // Android 12 is API level 31
      return androidInfo.version.sdkInt >= 31;
    } catch (e) {
      // If device info fails, assume modern Android for safety
      // This ensures we request the more restrictive permissions
      print('Failed to get Android version info, assuming Android 12+: $e');
      return true;
    }
  }

  @override
  Future<DeviceInfo?> scanAndConnect({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      await initializeIfNeeded();
      await checkAndRequestPermissions();

      // Check if already connected
      if (_connectedDevice != null) {
        final state = await _connectedDevice!.connectionState.first;
        if (state == BluetoothConnectionState.connected) {
          return currentDevice;
        }
      }

      updateConnectionState(BleConnectionState.scanning);

      // Start scanning with Heart Rate service filter
      await FlutterBluePlus.startScan(
        withServices: [Guid(BleUuids.heartRateService)],
        timeout: timeout,
      );

      BluetoothDevice? targetDevice;
      final scanCompleter = Completer<BluetoothDevice?>();

      // Listen for scan results
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final device = result.device;
          final name = device.platformName.toLowerCase();
          final advertisedServices = result.advertisementData.serviceUuids;
          
          // Check if device advertises Heart Rate service or is a known heart rate device
          final hasHeartRateService = advertisedServices.contains(Guid(BleUuids.heartRateService));
          final isKnownHeartRateDevice = _isKnownHeartRateDevice(name);
          
          if (hasHeartRateService || isKnownHeartRateDevice) {
            targetDevice = device;
            scanCompleter.complete(device);
            break;
          }
        }
      });

      // Wait for scan to complete or timeout
      await Future.any([
        scanCompleter.future,
        Future.delayed(timeout),
      ]);

      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();

      if (targetDevice == null) {
        updateConnectionState(BleConnectionState.idle);
        throw const BleException(BleError.deviceNotFound, 'デバイス未検出');
      }

      // Connect to the device
      return await connectToDevice(targetDevice.remoteId.str, timeout: timeout);

    } catch (e) {
      updateConnectionState(BleConnectionState.error);
      if (e is BleException) rethrow;
      throw BleException(BleError.connectionFailed, 'Failed to scan and connect: ${e.toString()}', e as Exception?);
    }
  }

  @override
  Future<DeviceInfo?> connectToDevice(String deviceId, {Duration timeout = const Duration(seconds: 10)}) async {
    try {
      updateConnectionState(BleConnectionState.connecting);

      // Find device by ID
      BluetoothDevice? device;
      final connectedDevices = FlutterBluePlus.connectedDevices;
      
      for (final connectedDevice in connectedDevices) {
        if (connectedDevice.remoteId.str == deviceId) {
          device = connectedDevice;
          break;
        }
      }

      if (device == null) {
        // Device not found in connected devices, try to create from ID
        device = BluetoothDevice.fromId(deviceId);
      }

      _connectedDevice = device;

      // Connect to device
      await device.connect(timeout: timeout, autoConnect: false);

      // Set up connection state monitoring
      await _setupConnectionMonitoring();

      // Discover services and subscribe to heart rate notifications
      await _discoverAndSubscribe();

      // Create device info
      final deviceInfo = DeviceInfo(
        id: device.remoteId.str,
        platformName: device.platformName,
      );

      updateCurrentDevice(deviceInfo);
      updateConnectionState(BleConnectionState.connected);
      _reconnectAttempts = 0; // Reset reconnect attempts on successful connection

      return deviceInfo;

    } catch (e) {
      updateConnectionState(BleConnectionState.error);
      if (e is BleException) rethrow;
      throw BleException(BleError.connectionFailed, 'Failed to connect to device: ${e.toString()}', e as Exception?);
    }
  }

  Future<void> _setupConnectionMonitoring() async {
    if (_connectedDevice == null) return;

    // Listen for connection state changes
    _connectionSubscription?.cancel();
    _connectionSubscription = _connectedDevice!.connectionState.listen((state) {
      switch (state) {
        case BluetoothConnectionState.connected:
          updateConnectionState(BleConnectionState.connected);
          break;
        case BluetoothConnectionState.disconnected:
          updateConnectionState(BleConnectionState.disconnected);
          _handleDisconnection();
          break;
      }
    });
  }

  Future<void> _discoverAndSubscribe() async {
    if (_connectedDevice == null) return;

    try {
      final services = await _connectedDevice!.discoverServices();
      BluetoothCharacteristic? heartRateCharacteristic;

      // Find Heart Rate Measurement characteristic
      for (final service in services) {
        if (service.uuid == Guid(BleUuids.heartRateService)) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid == Guid(BleUuids.heartRateMeasurement)) {
              heartRateCharacteristic = characteristic;
              break;
            }
          }
        }
      }

      // Fallback: search in all services
      heartRateCharacteristic ??= _findHeartRateCharacteristic(services);

      if (heartRateCharacteristic == null) {
        throw const BleException(BleError.characteristicNotFound, 'Heart Rate Measurement characteristic not found');
      }

      // Enable notifications
      await heartRateCharacteristic.setNotifyValue(true);

      // Subscribe to heart rate data
      _notificationSubscription?.cancel();
      _notificationSubscription = heartRateCharacteristic.onValueReceived.listen((data) {
        try {
          parseAndEmitHeartRate(data);
        } catch (e) {
          print('Error parsing heart rate data: $e');
        }
      });

    } catch (e) {
      if (e is BleException) rethrow;
      throw BleException(BleError.serviceNotFound, 'Failed to discover services: ${e.toString()}', e as Exception?);
    }
  }

  BluetoothCharacteristic? _findHeartRateCharacteristic(List<BluetoothService> services) {
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == Guid(BleUuids.heartRateMeasurement)) {
          return characteristic;
        }
      }
    }
    return null;
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

  void _handleDisconnection() {
    updateCurrentDevice(null);
    
    // Implement exponential backoff for reconnection
    if (_reconnectAttempts < _maxReconnectAttempts && !_disposed && _connectedDevice != null) {
      final delay = Duration(seconds: 2 << _reconnectAttempts); // Exponential backoff
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () async {
        try {
          _reconnectAttempts++;
          await _connectedDevice!.connect(timeout: const Duration(seconds: 8));
          await _discoverAndSubscribe();
        } catch (e) {
          print('Reconnection attempt $_reconnectAttempts failed: $e');
        }
      });
    }
  }

  @override
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    
    await _notificationSubscription?.cancel();
    await _connectionSubscription?.cancel();
    
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
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
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    
    if (connectionState == BleConnectionState.scanning) {
      updateConnectionState(BleConnectionState.idle);
    }
  }

  @override
  Future<List<DeviceInfo>> getKnownDevices() async {
    final connectedDevices = FlutterBluePlus.connectedDevices;
    final deviceInfoList = <DeviceInfo>[];
    
    for (final device in connectedDevices) {
      final services = await device.discoverServices();
      final hasHeartRateService = services.any((s) => s.uuid == Guid(BleUuids.heartRateService));
      
      if (hasHeartRateService) {
        deviceInfoList.add(DeviceInfo(
          id: device.remoteId.str,
          platformName: device.platformName,
        ));
      }
    }
    
    return deviceInfoList;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    
    await disconnect();
    await _scanSubscription?.cancel();
    disposeMixin();
  }
}

/// Factory function to create mobile BLE service
BleService createBleService() => BleServiceImplMobile();
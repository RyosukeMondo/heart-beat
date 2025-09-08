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
  Timer? _connectionHealthTimer;
  Timer? _retryTimer;
  bool _disposed = false;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  int _consecutiveErrors = 0;
  DateTime? _lastSuccessfulConnection;
  DateTime? _lastErrorTime;
  
  // Error recovery configuration
  static const int _maxReconnectAttempts = 8;
  static const int _maxConsecutiveErrors = 10;
  static const Duration _baseReconnectDelay = Duration(seconds: 2);
  static const Duration _maxReconnectDelay = Duration(minutes: 5);
  static const Duration _connectionHealthInterval = Duration(seconds: 10);
  static const Duration _staleConnectionThreshold = Duration(seconds: 30);

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
      
      // Reset all error recovery state on successful connection
      _reconnectAttempts = 0;
      _consecutiveErrors = 0;
      _lastSuccessfulConnection = DateTime.now();
      _isReconnecting = false;
      
      // Start health monitoring for the new connection
      _startConnectionHealthMonitoring();

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
    _stopConnectionHealthMonitoring();
    
    if (!_disposed && _connectedDevice != null && !_isReconnecting) {
      _scheduleReconnection();
    }
  }

  /// Schedule reconnection with exponential backoff and jitter
  void _scheduleReconnection() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('最大再接続試行回数に達しました。手動で再接続してください。');
      updateConnectionState(BleConnectionState.error);
      return;
    }

    // Calculate delay with exponential backoff and jitter
    final baseDelay = _baseReconnectDelay.inSeconds * (1 << _reconnectAttempts);
    final maxDelay = _maxReconnectDelay.inSeconds;
    final delaySeconds = baseDelay.clamp(2, maxDelay);
    
    // Add jitter (±25%) to prevent thundering herd
    final jitter = (delaySeconds * 0.25 * (2 * (DateTime.now().millisecond / 1000.0) - 1)).round();
    final finalDelay = Duration(seconds: (delaySeconds + jitter).clamp(1, maxDelay));

    print('再接続を${finalDelay.inSeconds}秒後にスケジュール (試行 ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(finalDelay, () => _attemptReconnection());
  }

  /// Attempt reconnection with comprehensive error handling
  Future<void> _attemptReconnection() async {
    if (_disposed || _isReconnecting) return;

    _isReconnecting = true;
    _reconnectAttempts++;
    
    try {
      print('再接続を試行中... (${_reconnectAttempts}/$_maxReconnectAttempts)');
      updateConnectionState(BleConnectionState.connecting);

      // Check if device is still available before attempting connection
      if (!await _isDeviceStillAvailable()) {
        throw const BleException(BleError.deviceNotFound, 'デバイスが利用できません');
      }

      // Attempt connection with shorter timeout for retry
      await _connectedDevice!.connect(
        timeout: const Duration(seconds: 8),
        autoConnect: false,
      );

      // Re-setup connection monitoring and services
      await _setupConnectionMonitoring();
      await _discoverAndSubscribe();

      // Success - reset error counters
      _reconnectAttempts = 0;
      _consecutiveErrors = 0;
      _lastSuccessfulConnection = DateTime.now();
      _startConnectionHealthMonitoring();
      
      print('再接続に成功しました');
      updateConnectionState(BleConnectionState.connected);
      
    } catch (e) {
      _consecutiveErrors++;
      _lastErrorTime = DateTime.now();
      
      print('再接続に失敗しました (${_reconnectAttempts}/$_maxReconnectAttempts): $e');
      
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        print('連続エラー上限に達しました。サービスを停止します。');
        updateConnectionState(BleConnectionState.error);
        _isReconnecting = false;
        return;
      }

      // Schedule next retry if under limit
      if (_reconnectAttempts < _maxReconnectAttempts) {
        updateConnectionState(BleConnectionState.disconnected);
        _scheduleReconnection();
      } else {
        updateConnectionState(BleConnectionState.error);
      }
    } finally {
      _isReconnecting = false;
    }
  }

  /// Check if device is still available/discoverable
  Future<bool> _isDeviceStillAvailable() async {
    if (_connectedDevice == null) return false;

    try {
      // Quick scan to check if device is advertising
      await FlutterBluePlus.startScan(
        withServices: [Guid(BleUuids.heartRateService)],
        timeout: const Duration(seconds: 3),
      );

      bool deviceFound = false;
      final scanCompleter = Completer<bool>();

      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          if (result.device.remoteId.str == _connectedDevice!.remoteId.str) {
            deviceFound = true;
            scanCompleter.complete(true);
            break;
          }
        }
      });

      // Wait for device or timeout
      await Future.any([
        scanCompleter.future,
        Future.delayed(const Duration(seconds: 3), () => scanCompleter.complete(false)),
      ]);

      await subscription.cancel();
      await FlutterBluePlus.stopScan();

      return deviceFound;
    } catch (e) {
      print('デバイス可用性チェック中にエラー: $e');
      return false; // Assume unavailable on error
    }
  }

  /// Start connection health monitoring
  void _startConnectionHealthMonitoring() {
    _stopConnectionHealthMonitoring();

    _connectionHealthTimer = Timer.periodic(_connectionHealthInterval, (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }

      _checkConnectionHealth();
    });
  }

  /// Stop connection health monitoring
  void _stopConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
  }

  /// Check connection health and trigger recovery if needed
  void _checkConnectionHealth() async {
    if (_connectedDevice == null || connectionState != BleConnectionState.connected) {
      return;
    }

    try {
      // Check if we're still receiving data
      final now = DateTime.now();
      final performanceMetrics = getPerformanceMetrics();
      final lastDataReceived = performanceMetrics['lastDataReceived'] as String?;
      
      if (lastDataReceived != null) {
        final lastData = DateTime.parse(lastDataReceived);
        final timeSinceData = now.difference(lastData);
        
        if (timeSinceData > _staleConnectionThreshold) {
          print('接続が停止している可能性があります (${timeSinceData.inSeconds}秒間データなし)');
          _handleStaleConnection();
          return;
        }
      }

      // Check physical connection state
      final connectionState = await _connectedDevice!.connectionState.first;
      if (connectionState != BluetoothConnectionState.connected) {
        print('デバイスが物理的に切断されました');
        _handleDisconnection();
      }

    } catch (e) {
      print('接続ヘルスチェック中にエラー: $e');
      _consecutiveErrors++;
      
      if (_consecutiveErrors >= 3) {
        _handleStaleConnection();
      }
    }
  }

  /// Handle stale connection by forcing reconnection
  void _handleStaleConnection() {
    print('停止した接続を検出しました。強制再接続を開始します。');
    _forceReconnection();
  }

  /// Force reconnection by disconnecting and reconnecting
  Future<void> _forceReconnection() async {
    if (_disposed || _isReconnecting) return;

    try {
      // Force disconnect
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      
      updateConnectionState(BleConnectionState.disconnected);
      
      // Wait a moment then trigger reconnection
      await Future.delayed(const Duration(seconds: 1));
      _handleDisconnection();
      
    } catch (e) {
      print('強制再接続中にエラー: $e');
      updateConnectionState(BleConnectionState.error);
    }
  }

  /// Get connection reliability metrics
  Map<String, dynamic> getConnectionMetrics() {
    final now = DateTime.now();
    return {
      'reconnectAttempts': _reconnectAttempts,
      'consecutiveErrors': _consecutiveErrors,
      'lastSuccessfulConnection': _lastSuccessfulConnection?.toIso8601String(),
      'lastErrorTime': _lastErrorTime?.toIso8601String(),
      'isReconnecting': _isReconnecting,
      'connectionUptime': _lastSuccessfulConnection != null 
          ? now.difference(_lastSuccessfulConnection!).inSeconds
          : null,
      'errorRate': _calculateErrorRate(),
    };
  }

  /// Calculate error rate for monitoring
  double _calculateErrorRate() {
    if (_lastSuccessfulConnection == null) return 1.0;
    
    final totalTime = DateTime.now().difference(_lastSuccessfulConnection!).inMinutes;
    if (totalTime == 0) return 0.0;
    
    return (_consecutiveErrors / totalTime).clamp(0.0, 1.0);
  }

  /// Reset error recovery state (for manual recovery)
  void resetErrorRecovery() {
    _reconnectAttempts = 0;
    _consecutiveErrors = 0;
    _reconnectTimer?.cancel();
    _isReconnecting = false;
    print('エラー回復状態がリセットされました');
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
    
    // Cancel all timers first
    _reconnectTimer?.cancel();
    _connectionHealthTimer?.cancel();
    _retryTimer?.cancel();
    
    // Stop connection monitoring
    _stopConnectionHealthMonitoring();
    
    // Disconnect and cleanup
    await disconnect();
    await _scanSubscription?.cancel();
    
    // Reset state
    _isReconnecting = false;
    _reconnectAttempts = 0;
    _consecutiveErrors = 0;
    _lastSuccessfulConnection = null;
    _lastErrorTime = null;
    
    disposeMixin();
    print('Mobile BLE service disposed with error recovery cleanup');
  }
}

/// Factory function to create mobile BLE service
BleService createBleService() => BleServiceImplMobile();
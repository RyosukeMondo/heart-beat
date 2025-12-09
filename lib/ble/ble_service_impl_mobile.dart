import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_service.dart';
import 'ble_types.dart';
import 'heart_rate_parser.dart';
import 'mobile_ble_permission_manager.dart';
import 'mobile_ble_scanner.dart';

/// Mobile and desktop BLE service implementation
/// 
/// Uses flutter_blue_plus for Android, iOS, macOS, and Linux.
/// Windows support through flutter_blue_plus Windows implementation.
class BleServiceImplMobile extends BleService with BleServiceMixin {
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final _permissionManager = MobileBlePermissionManager();
  final _scanner = MobileBleScanner();
  
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
    return Platform.isAndroid || Platform.isIOS || 
           Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  }

  BleServiceImplMobile() : super.protected();

  @override
  Future<void> initializeIfNeeded() async {
    if (_disposed) throw const BleException(BleError.unknownError, 'Service disposed');
    updateConnectionState(BleConnectionState.idle);
    await _permissionManager.validateBluetoothState();
    await _permissionManager.preCheckPermissions();
  }

  @override
  Future<bool> checkAndRequestPermissions() async {
    return _permissionManager.checkAndRequestPermissions();
  }

  @override
  Future<DeviceInfo?> scanAndConnect({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      await initializeIfNeeded();
      await checkAndRequestPermissions();

      if (_connectedDevice != null) {
        final state = await _connectedDevice!.connectionState.first;
        if (state == BluetoothConnectionState.connected) {
          return currentDevice;
        }
      }

      updateConnectionState(BleConnectionState.scanning);

      final targetDevice = await _scanner.scanForHeartRateDevice(timeout: timeout);

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

      BluetoothDevice? device;
      final connectedDevices = FlutterBluePlus.connectedDevices;
      
      for (final connectedDevice in connectedDevices) {
        if (connectedDevice.remoteId.str == deviceId) {
          device = connectedDevice;
          break;
        }
      }

      device ??= BluetoothDevice.fromId(deviceId);
      _connectedDevice = device;

      await device.connect(timeout: timeout, autoConnect: false);
      await _setupConnectionMonitoring();
      await _discoverAndSubscribe();

      final deviceInfo = DeviceInfo(
        id: device.remoteId.str,
        platformName: device.platformName,
      );

      updateCurrentDevice(deviceInfo);
      updateConnectionState(BleConnectionState.connected);
      
      _reconnectAttempts = 0;
      _consecutiveErrors = 0;
      _lastSuccessfulConnection = DateTime.now();
      _isReconnecting = false;
      
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
        default:
          break;
      }
    });
  }

  Future<void> _discoverAndSubscribe() async {
    if (_connectedDevice == null) return;

    try {
      final services = await _connectedDevice!.discoverServices();
      BluetoothCharacteristic? heartRateCharacteristic;

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

      heartRateCharacteristic ??= _findHeartRateCharacteristic(services);

      if (heartRateCharacteristic == null) {
        throw const BleException(BleError.characteristicNotFound, 'Heart Rate Measurement characteristic not found');
      }

      await heartRateCharacteristic.setNotifyValue(true);

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

  void _handleDisconnection() {
    updateCurrentDevice(null);
    _stopConnectionHealthMonitoring();
    
    if (!_disposed && _connectedDevice != null && !_isReconnecting) {
      _scheduleReconnection();
    }
  }

  void _scheduleReconnection() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('最大再接続試行回数に達しました。手動で再接続してください。');
      updateConnectionState(BleConnectionState.error);
      return;
    }

    final baseDelay = _baseReconnectDelay.inSeconds * (1 << _reconnectAttempts);
    final maxDelay = _maxReconnectDelay.inSeconds;
    final delaySeconds = baseDelay.clamp(2, maxDelay);
    
    final jitter = (delaySeconds * 0.25 * (2 * (DateTime.now().millisecond / 1000.0) - 1)).round();
    final finalDelay = Duration(seconds: (delaySeconds + jitter).clamp(1, maxDelay));

    print('再接続を${finalDelay.inSeconds}秒後にスケジュール (試行 ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(finalDelay, () => _attemptReconnection());
  }

  Future<void> _attemptReconnection() async {
    if (_disposed || _isReconnecting) return;

    _isReconnecting = true;
    _reconnectAttempts++;
    
    try {
      print('再接続を試行中... (${_reconnectAttempts}/$_maxReconnectAttempts)');
      updateConnectionState(BleConnectionState.connecting);

      if (!await _isDeviceStillAvailable()) {
        throw const BleException(BleError.deviceNotFound, 'デバイスが利用できません');
      }

      await _connectedDevice!.connect(
        timeout: const Duration(seconds: 8),
        autoConnect: false,
      );

      await _setupConnectionMonitoring();
      await _discoverAndSubscribe();

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

  Future<bool> _isDeviceStillAvailable() async {
    if (_connectedDevice == null) return false;

    try {
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
            if (!scanCompleter.isCompleted) scanCompleter.complete(true);
            break;
          }
        }
      });

      await Future.any([
        scanCompleter.future,
        Future.delayed(const Duration(seconds: 3), () {
           if (!scanCompleter.isCompleted) scanCompleter.complete(false);
        }),
      ]);

      await subscription.cancel();
      await FlutterBluePlus.stopScan();

      return deviceFound;
    } catch (e) {
      print('デバイス可用性チェック中にエラー: $e');
      return false;
    }
  }

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

  void _stopConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
  }

  void _checkConnectionHealth() async {
    if (_connectedDevice == null || connectionState != BleConnectionState.connected) {
      return;
    }

    try {
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

  void _handleStaleConnection() {
    print('停止した接続を検出しました。強制再接続を開始します。');
    _forceReconnection();
  }

  Future<void> _forceReconnection() async {
    if (_disposed || _isReconnecting) return;

    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      
      updateConnectionState(BleConnectionState.disconnected);
      
      await Future.delayed(const Duration(seconds: 1));
      _handleDisconnection();
      
    } catch (e) {
      print('強制再接続中にエラー: $e');
      updateConnectionState(BleConnectionState.error);
    }
  }

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

  double _calculateErrorRate() {
    if (_lastSuccessfulConnection == null) return 1.0;
    
    final totalTime = DateTime.now().difference(_lastSuccessfulConnection!).inMinutes;
    if (totalTime == 0) return 0.0;
    
    return (_consecutiveErrors / totalTime).clamp(0.0, 1.0);
  }

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
    await _scanner.stopScan();
    
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
    
    _reconnectTimer?.cancel();
    _connectionHealthTimer?.cancel();
    _retryTimer?.cancel();
    
    _stopConnectionHealthMonitoring();
    
    await disconnect();
    await _scanner.stopScan();
    
    _isReconnecting = false;
    _reconnectAttempts = 0;
    _consecutiveErrors = 0;
    _lastSuccessfulConnection = null;
    _lastErrorTime = null;
    
    disposeMixin();
    print('Mobile BLE service disposed with error recovery cleanup');
  }
}

BleService createBleService() => BleServiceImplMobile();

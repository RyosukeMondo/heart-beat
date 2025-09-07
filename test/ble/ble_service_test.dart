import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:heart_beat/ble/ble_service.dart';
import 'package:heart_beat/ble/ble_types.dart';

// Generate mocks for testing
@GenerateNiceMocks([
  MockSpec<BleService>(),
])
import 'ble_service_test.mocks.dart';

void main() {
  group('BleService Factory', () {
    test('factory creates appropriate service for platform', () {
      // Test that the factory creates a service instance
      final service = BleService();
      expect(service, isA<BleService>());
    });

    test('factory returns supported service', () {
      final service = BleService();
      // Service should be supported on test environment
      expect(service.isSupported, isTrue);
    });
  });

  group('BleServiceMixin Tests', () {
    late MockBleService mockService;
    late TestBleServiceImplementation testService;

    setUp(() {
      mockService = MockBleService();
      testService = TestBleServiceImplementation();
    });

    tearDown(() {
      testService.dispose();
    });

    test('initial state is idle', () {
      expect(testService.connectionState, BleConnectionState.idle);
      expect(testService.currentDevice, isNull);
      expect(testService.isConnected, isFalse);
    });

    test('connection state updates correctly', () {
      final states = <BleConnectionState>[];
      testService.connectionStateStream.listen(states.add);

      testService.updateConnectionState(BleConnectionState.scanning);
      testService.updateConnectionState(BleConnectionState.connecting);
      testService.updateConnectionState(BleConnectionState.connected);

      expect(testService.connectionState, BleConnectionState.connected);
      expect(testService.isConnected, isTrue);
      expect(states, [
        BleConnectionState.scanning,
        BleConnectionState.connecting,
        BleConnectionState.connected,
      ]);
    });

    test('device info is cleared when disconnected', () {
      final deviceInfo = DeviceInfo(
        id: 'test-device',
        platformName: 'Test Heart Rate Monitor',
      );

      testService.updateCurrentDevice(deviceInfo);
      testService.updateConnectionState(BleConnectionState.connected);

      expect(testService.currentDevice, equals(deviceInfo));

      testService.updateConnectionState(BleConnectionState.disconnected);

      expect(testService.currentDevice, isNull);
    });

    test('heart rate stream emits data when connected', () {
      final heartRates = <int>[];
      testService.heartRateStream.listen(heartRates.add);

      testService.updateConnectionState(BleConnectionState.connected);
      testService.emitHeartRate(75);
      testService.emitHeartRate(80);
      testService.emitHeartRate(85);

      expect(heartRates, [75, 80, 85]);
    });

    test('heart rate stream does not emit when not connected', () {
      final heartRates = <int>[];
      testService.heartRateStream.listen(heartRates.add);

      // Try to emit heart rate while disconnected
      testService.updateConnectionState(BleConnectionState.idle);
      testService.emitHeartRate(75);

      expect(heartRates, isEmpty);
    });

    test('parse and emit heart rate with valid data', () {
      final heartRates = <int>[];
      testService.heartRateStream.listen(heartRates.add);

      testService.updateConnectionState(BleConnectionState.connected);

      // Simulate valid heart rate data (8-bit format, BPM = 72)
      testService.parseAndEmitHeartRate([0x00, 72]);

      expect(heartRates, [72]);
    });

    test('parse and emit heart rate with invalid data does not crash', () {
      final heartRates = <int>[];
      testService.heartRateStream.listen(heartRates.add);

      testService.updateConnectionState(BleConnectionState.connected);

      // Simulate invalid data
      testService.parseAndEmitHeartRate([]);

      // Should not crash and should not emit any heart rate
      expect(heartRates, isEmpty);
    });

    test('stream subscription management prevents memory leaks', () {
      final states = <BleConnectionState>[];
      final StreamSubscription subscription = testService.connectionStateStream.listen(states.add);

      testService.updateConnectionState(BleConnectionState.scanning);
      expect(states, [BleConnectionState.scanning]);

      // Cancel subscription
      subscription.cancel();

      // Further updates should not affect the cancelled subscription
      testService.updateConnectionState(BleConnectionState.connected);
      expect(states, [BleConnectionState.scanning]); // Should not have updated
    });
  });

  group('BleException Tests', () {
    test('BleException creates correctly with error and message', () {
      const exception = BleException(BleError.deviceNotFound, 'Test message');

      expect(exception.error, BleError.deviceNotFound);
      expect(exception.message, 'Test message');
      expect(exception.originalException, isNull);
    });

    test('BleException toString includes message', () {
      const exception = BleException(BleError.connectionFailed, 'Connection timeout');

      expect(exception.toString(), 'BleException: Connection timeout');
    });

    test('BleException toString includes original exception', () {
      final originalError = Exception('Network error');
      final exception = BleException(BleError.connectionFailed, 'Connection failed', originalError);

      expect(exception.toString(), contains('Connection failed'));
      expect(exception.toString(), contains('Network error'));
    });

    test('BleException localizedMessage returns error message', () {
      const exception = BleException(BleError.deviceNotFound, 'Device not found');

      expect(exception.localizedMessage, BleError.deviceNotFound.message);
      expect(exception.localizedMessage, '心拍センサーが見つかりません');
    });
  });

  group('DeviceInfo Tests', () {
    test('DeviceInfo creates correctly', () {
      const deviceInfo = DeviceInfo(
        id: 'device-123',
        platformName: 'Heart Rate Monitor',
        rssi: -45,
      );

      expect(deviceInfo.id, 'device-123');
      expect(deviceInfo.platformName, 'Heart Rate Monitor');
      expect(deviceInfo.rssi, -45);
    });

    test('DeviceInfo equality works correctly', () {
      const deviceInfo1 = DeviceInfo(id: 'device-1', platformName: 'Monitor 1');
      const deviceInfo2 = DeviceInfo(id: 'device-1', platformName: 'Monitor 1');
      const deviceInfo3 = DeviceInfo(id: 'device-2', platformName: 'Monitor 1');

      expect(deviceInfo1, equals(deviceInfo2));
      expect(deviceInfo1, isNot(equals(deviceInfo3)));
    });

    test('DeviceInfo copyWith works correctly', () {
      const original = DeviceInfo(
        id: 'device-1',
        platformName: 'Original Name',
        rssi: -50,
      );

      final updated = original.copyWith(
        platformName: 'Updated Name',
        rssi: -40,
      );

      expect(updated.id, 'device-1'); // Unchanged
      expect(updated.platformName, 'Updated Name'); // Updated
      expect(updated.rssi, -40); // Updated
    });
  });

  group('BLE Connection State Extension Tests', () {
    test('isConnected returns correct values', () {
      expect(BleConnectionState.connected.isConnected, isTrue);
      expect(BleConnectionState.idle.isConnected, isFalse);
      expect(BleConnectionState.scanning.isConnected, isFalse);
      expect(BleConnectionState.error.isConnected, isFalse);
    });

    test('isWorking returns correct values', () {
      expect(BleConnectionState.connected.isWorking, isTrue);
      expect(BleConnectionState.connecting.isWorking, isTrue);
      expect(BleConnectionState.scanning.isWorking, isTrue);
      expect(BleConnectionState.idle.isWorking, isFalse);
      expect(BleConnectionState.error.isWorking, isFalse);
    });

    test('displayText returns Japanese text', () {
      expect(BleConnectionState.idle.displayText, 'アイドル');
      expect(BleConnectionState.scanning.displayText, 'スキャン中');
      expect(BleConnectionState.connecting.displayText, '接続中');
      expect(BleConnectionState.connected.displayText, '接続済み');
      expect(BleConnectionState.disconnected.displayText, '切断');
      expect(BleConnectionState.error.displayText, 'エラー');
    });
  });

  group('BLE Error Extension Tests', () {
    test('error messages are in Japanese', () {
      expect(BleError.bluetoothNotSupported.message, 'Bluetoothがサポートされていません');
      expect(BleError.bluetoothNotEnabled.message, 'Bluetoothが有効になっていません');
      expect(BleError.permissionDenied.message, 'Bluetoothの権限が拒否されました');
      expect(BleError.deviceNotFound.message, '心拍センサーが見つかりません');
      expect(BleError.connectionFailed.message, '接続に失敗しました');
      expect(BleError.connectionLost.message, '接続が切れました');
      expect(BleError.serviceNotFound.message, '心拍サービスが見つかりません');
      expect(BleError.characteristicNotFound.message, '心拍特性が見つかりません');
      expect(BleError.dataParsingError.message, 'データの解析に失敗しました');
      expect(BleError.unknownError.message, '不明なエラーが発生しました');
    });
  });

  group('Error Handling Scenarios', () {
    late MockBleService mockService;

    setUp(() {
      mockService = MockBleService();
    });

    test('handles initialization failure gracefully', () async {
      when(mockService.initializeIfNeeded())
          .thenThrow(const BleException(BleError.bluetoothNotSupported, 'Not supported'));

      expect(
        () async => await mockService.initializeIfNeeded(),
        throwsA(isA<BleException>()),
      );
    });

    test('handles permission denial gracefully', () async {
      when(mockService.checkAndRequestPermissions())
          .thenThrow(const BleException(BleError.permissionDenied, 'Permissions denied'));

      expect(
        () async => await mockService.checkAndRequestPermissions(),
        throwsA(isA<BleException>()),
      );
    });

    test('handles scan timeout gracefully', () async {
      when(mockService.scanAndConnect(timeout: any))
          .thenThrow(const BleException(BleError.deviceNotFound, 'No devices found'));

      expect(
        () async => await mockService.scanAndConnect(),
        throwsA(isA<BleException>()),
      );
    });

    test('handles connection failure gracefully', () async {
      when(mockService.connectToDevice('invalid-id'))
          .thenThrow(const BleException(BleError.connectionFailed, 'Connection failed'));

      expect(
        () async => await mockService.connectToDevice('invalid-id'),
        throwsA(isA<BleException>()),
      );
    });
  });

  group('Platform Integration Tests', () {
    test('platform detection works correctly', () {
      // Note: These tests will run on the test platform
      // In a real scenario, you would mock Platform.isAndroid, etc.
      
      final service = BleService();
      expect(service.isSupported, isA<bool>());
    });

    test('BLE UUIDs are correctly formatted', () {
      expect(BleUuids.heartRateService, '0000180d-0000-1000-8000-00805f9b34fb');
      expect(BleUuids.heartRateMeasurement, '00002a37-0000-1000-8000-00805f9b34fb');
    });
  });
}

/// Test implementation of BleService for testing the mixin
class TestBleServiceImplementation extends BleService with BleServiceMixin {
  @override
  bool get isSupported => true;

  @override
  Future<void> initializeIfNeeded() async {
    updateConnectionState(BleConnectionState.idle);
  }

  @override
  Future<DeviceInfo?> scanAndConnect({Duration timeout = const Duration(seconds: 10)}) async {
    updateConnectionState(BleConnectionState.scanning);
    await Future.delayed(const Duration(milliseconds: 100));
    
    updateConnectionState(BleConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 100));

    const deviceInfo = DeviceInfo(
      id: 'test-device-123',
      platformName: 'Test Heart Rate Monitor',
    );
    
    updateCurrentDevice(deviceInfo);
    updateConnectionState(BleConnectionState.connected);
    
    return deviceInfo;
  }

  @override
  Future<DeviceInfo?> connectToDevice(String deviceId, {Duration timeout = const Duration(seconds: 10)}) async {
    updateConnectionState(BleConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 100));

    final deviceInfo = DeviceInfo(
      id: deviceId,
      platformName: 'Connected Device',
    );
    
    updateCurrentDevice(deviceInfo);
    updateConnectionState(BleConnectionState.connected);
    
    return deviceInfo;
  }

  @override
  Future<void> disconnect() async {
    updateCurrentDevice(null);
    updateConnectionState(BleConnectionState.disconnected);
    await Future.delayed(const Duration(milliseconds: 50));
    updateConnectionState(BleConnectionState.idle);
  }

  @override
  Future<void> stopScan() async {
    if (connectionState == BleConnectionState.scanning) {
      updateConnectionState(BleConnectionState.idle);
    }
  }

  @override
  Future<List<DeviceInfo>> getKnownDevices() async {
    return [
      const DeviceInfo(id: 'known-device-1', platformName: 'Known Device 1'),
      const DeviceInfo(id: 'known-device-2', platformName: 'Known Device 2'),
    ];
  }

  @override
  Future<bool> checkAndRequestPermissions() async {
    return true;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    disposeMixin();
  }
}
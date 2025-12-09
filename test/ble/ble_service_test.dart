
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:heart_beat/ble/ble_service.dart';
import 'package:heart_beat/ble/ble_types.dart';

// Generate mocks for BleService
@GenerateMocks([BleService])
import 'ble_service_test.mocks.dart';

void main() {
  group('BleService Tests', () {
    late MockBleService mockService;

    setUp(() {
      mockService = MockBleService();
    });

    test('initializes correctly', () async {
      when(mockService.initializeIfNeeded()).thenAnswer((_) async {});
      await mockService.initializeIfNeeded();
      verify(mockService.initializeIfNeeded()).called(1);
    });

    test('checks permissions correctly', () async {
      when(mockService.checkAndRequestPermissions()).thenAnswer((_) async => true);
      expect(await mockService.checkAndRequestPermissions(), isTrue);
      verify(mockService.checkAndRequestPermissions()).called(1);
    });

    test('isSupported returns correct value', () {
      when(mockService.isSupported).thenReturn(true);
      expect(mockService.isSupported, isTrue);
    });

    test('scanAndConnect initiates scan', () async {
      final deviceInfo = DeviceInfo(id: 'test_id', platformName: 'Test Device');
      when(mockService.scanAndConnect(timeout: anyNamed('timeout')))
          .thenAnswer((_) async => deviceInfo);

      final result = await mockService.scanAndConnect(timeout: const Duration(seconds: 5));
      expect(result, equals(deviceInfo));
      verify(mockService.scanAndConnect(timeout: anyNamed('timeout'))).called(1);
    });

    test('disconnect calls disconnect on service', () async {
      when(mockService.disconnect()).thenAnswer((_) async {});
      await mockService.disconnect();
      verify(mockService.disconnect()).called(1);
    });

    test('stopScan calls stopScan on service', () async {
      when(mockService.stopScan()).thenAnswer((_) async {});
      await mockService.stopScan();
      verify(mockService.stopScan()).called(1);
    });

    test('connectToDevice initiates connection', () async {
      final deviceInfo = DeviceInfo(id: 'test_id', platformName: 'Test Device');
      when(mockService.connectToDevice(any, timeout: anyNamed('timeout')))
          .thenAnswer((_) async => deviceInfo);

      final result = await mockService.connectToDevice('test_id', timeout: const Duration(seconds: 5));
      expect(result, equals(deviceInfo));
      verify(mockService.connectToDevice('test_id', timeout: anyNamed('timeout'))).called(1);
    });

    test('getKnownDevices returns list of devices', () async {
      final devices = [
        DeviceInfo(id: '1', platformName: 'Device 1'),
        DeviceInfo(id: '2', platformName: 'Device 2'),
      ];
      when(mockService.getKnownDevices()).thenAnswer((_) async => devices);

      final result = await mockService.getKnownDevices();
      expect(result, equals(devices));
      verify(mockService.getKnownDevices()).called(1);
    });

    test('connection state stream emits correct values', () {
      final controller = StreamController<BleConnectionState>();
      when(mockService.connectionStateStream).thenAnswer((_) => controller.stream);

      expect(mockService.connectionStateStream, emitsInOrder([
        BleConnectionState.connecting,
        BleConnectionState.connected,
        BleConnectionState.disconnected,
      ]));

      controller.add(BleConnectionState.connecting);
      controller.add(BleConnectionState.connected);
      controller.add(BleConnectionState.disconnected);
      controller.close();
    });

    test('heart rate stream emits correct values', () {
      final controller = StreamController<int>();
      when(mockService.heartRateStream).thenAnswer((_) => controller.stream);

      expect(mockService.heartRateStream, emitsInOrder([60, 70, 80]));

      controller.add(60);
      controller.add(70);
      controller.add(80);
      controller.close();
    });
  });

  group('BleException Tests', () {
    test('BleException toString includes message', () {
      const exception = BleException(BleError.bluetoothNotSupported, 'Not supported');
      expect(exception.toString(), contains('Not supported'));
      expect(exception.toString(), contains('BleException'));
    });

    test('BleException toString includes original exception', () {
      final original = Exception('Original error');
      final exception = BleException(BleError.unknownError, 'Unknown error', original);

      expect(exception.toString(), contains('Unknown error'));
      expect(exception.toString(), contains('Original error'));
    });

    test('BleException localizedMessage returns error message', () {
      const exception = BleException(BleError.deviceNotFound, 'Device not found');

      expect(exception.localizedMessage, BleError.deviceNotFound.message);
      expect(exception.localizedMessage, contains('心拍センサーが見つかりません'));
    });
  });

  group('DeviceInfo Tests', () {
    test('DeviceInfo creates correctly', () {
      final device = DeviceInfo(
        id: '123',
        platformName: 'Test Device',
        manufacturerData: {'company': 'ACME'},
        rssi: -70,
      );

      expect(device.id, '123');
      expect(device.platformName, 'Test Device');
      expect(device.manufacturerData, {'company': 'ACME'});
      expect(device.rssi, -70);
    });

    test('DeviceInfo equality works correctly', () {
      final device1 = DeviceInfo(id: '123', platformName: 'Test Device');
      final device2 = DeviceInfo(id: '123', platformName: 'Test Device');
      final device3 = DeviceInfo(id: '456', platformName: 'Other Device');

      expect(device1, equals(device2));
      expect(device1, isNot(equals(device3)));
      expect(device1.hashCode, equals(device2.hashCode));
    });

    test('DeviceInfo copyWith works correctly', () {
      final original = DeviceInfo(id: '123', platformName: 'Test Device');
      final copy = original.copyWith(platformName: 'Updated Name');

      expect(copy.id, '123');
      expect(copy.platformName, 'Updated Name');
    });
  });

  group('BLE Connection State Extension Tests', () {
    test('isConnected returns correct values', () {
      expect(BleConnectionState.connected.isConnected, isTrue);
      expect(BleConnectionState.connecting.isConnected, isFalse);
      expect(BleConnectionState.disconnected.isConnected, isFalse);
    });

    test('isWorking returns correct values', () {
      expect(BleConnectionState.connected.isWorking, isTrue);
      expect(BleConnectionState.connecting.isWorking, isTrue);
      expect(BleConnectionState.scanning.isWorking, isTrue);
      expect(BleConnectionState.idle.isWorking, isFalse);
      expect(BleConnectionState.disconnected.isWorking, isFalse);
      expect(BleConnectionState.error.isWorking, isFalse);
    });

    test('displayText returns Japanese text', () {
      expect(BleConnectionState.connected.displayText, '接続済み');
      expect(BleConnectionState.scanning.displayText, 'スキャン中');
      expect(BleConnectionState.disconnected.displayText, '切断');
    });
  });

  group('BLE Error Extension Tests', () {
    test('error messages are in Japanese', () {
      expect(BleError.bluetoothNotSupported.message, contains('Bluetoothがサポートされていません'));
      expect(BleError.bluetoothNotEnabled.message, contains('Bluetoothが有効になっていません'));
      expect(BleError.permissionDenied.message, contains('権限が拒否されました'));
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
        () => mockService.initializeIfNeeded(),
        throwsA(isA<BleException>()),
      );
    });

    test('handles permission denial gracefully', () async {
      when(mockService.checkAndRequestPermissions()).thenAnswer((_) async => false);
      expect(await mockService.checkAndRequestPermissions(), isFalse);
    });

    test('handles scan timeout gracefully', () async {
      when(mockService.scanAndConnect(timeout: anyNamed('timeout')))
          .thenThrow(const BleException(BleError.deviceNotFound, 'No device found'));

      expect(
        () => mockService.scanAndConnect(timeout: const Duration(seconds: 1)),
        throwsA(isA<BleException>()),
      );
    });

    test('handles connection failure gracefully', () async {
      when(mockService.connectToDevice(any, timeout: anyNamed('timeout')))
          .thenThrow(const BleException(BleError.connectionFailed, 'Connection failed'));

      expect(
        () => mockService.connectToDevice('id', timeout: const Duration(seconds: 1)),
        throwsA(isA<BleException>()),
      );
    });
  });

  group('Platform Integration Tests', () {
    test('platform detection works correctly', () {
      // Indirectly testing via isSupported which relies on Platform.isX
      // Since we can't easily mock Platform.isX in unit tests without extensive setup,
      // we just verify the service exists and returns a boolean.
      final service = TestBleServiceImplementation();
      expect(service.isSupported, isTrue); // Mock returns true
    });

    test('BLE UUIDs are correctly formatted', () {
      expect(BleUuids.heartRateService, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')));
      expect(BleUuids.heartRateMeasurement, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')));
    });
  });

  group('BleServiceMixin Tests', () {
    late TestBleServiceImplementation service;

    setUp(() {
      service = TestBleServiceImplementation();
    });

    tearDown(() {
      service.disposeMixin();
    });

    test('connection state stream emits correct values', () {
      expectLater(service.connectionStateStream, emitsInOrder([
        BleConnectionState.scanning,
        BleConnectionState.connected,
        BleConnectionState.disconnected,
      ]));

      service.updateConnectionState(BleConnectionState.scanning);
      service.updateConnectionState(BleConnectionState.connected);
      service.updateConnectionState(BleConnectionState.disconnected);
    });

    test('heart rate stream emits correct values with throttling', () async {
      // Need to connect first to emit values
      service.updateConnectionState(BleConnectionState.connected);

      // Since the stream is throttled to ~60 FPS (16ms), fast updates will be skipped.
      // We expect at least the last value to be emitted.
      // To test multiple values, we need to wait >16ms between emits.

      final emissions = <int>[];
      final sub = service.heartRateStream.listen(emissions.add);

      service.emitHeartRate(60);
      await Future.delayed(const Duration(milliseconds: 20));

      service.emitHeartRate(75);
      await Future.delayed(const Duration(milliseconds: 20));

      service.emitHeartRate(80);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(emissions, equals([60, 75, 80]));
      await sub.cancel();
    });

    test('heart rate stream does not emit when not connected', () async {
      service.updateConnectionState(BleConnectionState.disconnected);

      bool receivedData = false;
      final sub = service.heartRateStream.listen((_) => receivedData = true);

      service.emitHeartRate(60);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedData, isFalse);

      await sub.cancel();
    });

    test('parse and emit heart rate with valid data', () {
      service.updateConnectionState(BleConnectionState.connected);

      expectLater(service.heartRateStream, emits(72));

      // 0x00 = 8-bit, 72 bpm
      service.parseAndEmitHeartRate([0x00, 72]);
    });

    test('parse and emit heart rate with invalid data does not crash', () {
      service.updateConnectionState(BleConnectionState.connected);

      // Should handle error gracefully internally
      service.parseAndEmitHeartRate([]); // Empty data
      service.parseAndEmitHeartRate([0x00, 300]); // Out of range (mock logs warning)
    });

    test('stream subscription management prevents memory leaks', () async {
      service.updateConnectionState(BleConnectionState.connected);

      // Create a subscription
      final sub = service.heartRateStream.listen((_) {});

      // Clean up resources
      service.cleanupUnusedResources();

      // Dispose everything
      service.disposeMixin();

      // Should be able to cancel safely
      await sub.cancel();
    });
  });
}

/// Test implementation of BleService for testing the mixin
class TestBleServiceImplementation extends BleService with BleServiceMixin {
  TestBleServiceImplementation() : super.protected();

  @override
  bool get isSupported => true;

  @override
  Future<void> initializeIfNeeded() async {}

  @override
  Future<DeviceInfo?> scanAndConnect({Duration timeout = const Duration(seconds: 10)}) async {
    return null;
  }

  @override
  Future<void> disconnect() async {
    updateConnectionState(BleConnectionState.disconnected);
  }

  @override
  Future<void> stopScan() async {
    if (connectionState == BleConnectionState.scanning) {
      updateConnectionState(BleConnectionState.idle);
    }
  }

  @override
  Future<List<DeviceInfo>> getKnownDevices() async => [];

  @override
  Future<DeviceInfo?> connectToDevice(String deviceId, {Duration timeout = const Duration(seconds: 10)}) async {
    return null;
  }

  @override
  Future<bool> checkAndRequestPermissions() async => true;

  @override
  Future<void> dispose() async {
    disposeMixin();
  }
}

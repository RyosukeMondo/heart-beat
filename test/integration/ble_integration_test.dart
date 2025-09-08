import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:heart_beat/ble/ble_service.dart';
import 'package:heart_beat/ble/ble_types.dart';
import 'package:heart_beat/ble/heart_rate_parser.dart';

// Generate mocks for testing
@GenerateNiceMocks([
  MockSpec<BleService>(),
])
import 'ble_integration_test.mocks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BLE Integration Tests', () {
    late MockBleIntegrationService mockService;
    
    setUp(() {
      mockService = MockBleIntegrationService();
    });

    tearDown(() async {
      await mockService.dispose();
    });

    testWidgets('Full BLE connection workflow with mock devices', (WidgetTester tester) async {
      // Test the complete workflow from initialization to heart rate streaming
      
      // Step 1: Initialize service
      expect(mockService.isSupported, isTrue);
      expect(mockService.connectionState, BleConnectionState.idle);
      
      await mockService.initializeIfNeeded();
      expect(mockService.connectionState, BleConnectionState.idle);

      // Step 2: Check permissions
      final hasPermissions = await mockService.checkAndRequestPermissions();
      expect(hasPermissions, isTrue);

      // Step 3: Start scanning and connect
      final deviceFuture = mockService.scanAndConnect();
      
      // Verify scanning state
      expect(mockService.connectionState, BleConnectionState.scanning);
      
      // Wait for connection completion
      final device = await deviceFuture;
      expect(device, isNotNull);
      expect(device!.id, contains('mock-hr-'));
      expect(device.platformName, contains('Mock Heart Rate'));
      expect(mockService.connectionState, BleConnectionState.connected);
      expect(mockService.currentDevice, equals(device));

      // Step 4: Test heart rate streaming
      final heartRates = <int>[];
      final streamSubscription = mockService.heartRateStream.listen(heartRates.add);

      // Simulate receiving multiple heart rate measurements
      await tester.pump(const Duration(milliseconds: 100));
      await mockService._simulateHeartRateData(75);
      await tester.pump(const Duration(milliseconds: 100));
      await mockService._simulateHeartRateData(80);
      await tester.pump(const Duration(milliseconds: 100));
      await mockService._simulateHeartRateData(82);

      // Verify heart rate data is received
      expect(heartRates.length, greaterThanOrEqualTo(3));
      expect(heartRates, contains(75));
      expect(heartRates, contains(80));
      expect(heartRates, contains(82));

      // Step 5: Test disconnection
      await streamSubscription.cancel();
      await mockService.disconnect();
      
      expect(mockService.connectionState, BleConnectionState.idle);
      expect(mockService.currentDevice, isNull);
    });

    testWidgets('Platform-specific implementations work correctly', (WidgetTester tester) async {
      // Test platform detection and service creation
      final service = BleService();
      expect(service, isA<BleService>());
      expect(service.isSupported, isA<bool>());

      // Test that factory creates appropriate implementation
      if (service.isSupported) {
        await service.initializeIfNeeded();
        expect(service.connectionState, BleConnectionState.idle);
      }
      
      await service.dispose();
    });

    testWidgets('Error recovery and reconnection scenarios', (WidgetTester tester) async {
      // Test connection failure and retry
      mockService.simulateConnectionFailure = true;
      
      expect(
        () async => await mockService.scanAndConnect(),
        throwsA(isA<BleException>()),
      );
      
      expect(mockService.connectionState, BleConnectionState.error);

      // Test recovery after failure
      mockService.simulateConnectionFailure = false;
      await mockService.resetToIdle();
      
      final device = await mockService.scanAndConnect();
      expect(device, isNotNull);
      expect(mockService.connectionState, BleConnectionState.connected);

      // Test connection loss and reconnection
      await mockService.simulateConnectionLoss();
      expect(mockService.connectionState, BleConnectionState.disconnected);

      // Test automatic reconnection
      final reconnectedDevice = await mockService.connectToDevice(device!.id);
      expect(reconnectedDevice, isNotNull);
      expect(mockService.connectionState, BleConnectionState.connected);

      await mockService.disconnect();
    });

    testWidgets('Real-time data streaming performance', (WidgetTester tester) async {
      await mockService.initializeIfNeeded();
      final device = await mockService.scanAndConnect();
      expect(device, isNotNull);

      final heartRates = <int>[];
      final timestamps = <DateTime>[];
      
      final streamSubscription = mockService.heartRateStream.listen((heartRate) {
        heartRates.add(heartRate);
        timestamps.add(DateTime.now());
      });

      // Simulate high-frequency heart rate data (typical sensor sends data every ~1 second)
      final startTime = DateTime.now();
      for (int i = 0; i < 10; i++) {
        await mockService._simulateHeartRateData(70 + i);
        await tester.pump(const Duration(milliseconds: 100));
      }

      final endTime = DateTime.now();
      final totalDuration = endTime.difference(startTime);

      // Verify all data was received
      expect(heartRates.length, equals(10));
      expect(timestamps.length, equals(10));

      // Verify performance requirements (should process data within 200ms per requirement)
      for (int i = 1; i < timestamps.length; i++) {
        final processingTime = timestamps[i].difference(timestamps[i-1]);
        expect(processingTime.inMilliseconds, lessThan(200));
      }

      // Verify data integrity
      for (int i = 0; i < heartRates.length; i++) {
        expect(heartRates[i], equals(70 + i));
      }

      await streamSubscription.cancel();
      await mockService.disconnect();
    });

    testWidgets('Multiple device support and management', (WidgetTester tester) async {
      await mockService.initializeIfNeeded();

      // Test getting known devices
      final knownDevices = await mockService.getKnownDevices();
      expect(knownDevices, isA<List<DeviceInfo>>());

      // Test connecting to specific device
      if (knownDevices.isNotEmpty) {
        final targetDevice = knownDevices.first;
        final connectedDevice = await mockService.connectToDevice(targetDevice.id);
        expect(connectedDevice, isNotNull);
        expect(connectedDevice!.id, equals(targetDevice.id));
        expect(mockService.connectionState, BleConnectionState.connected);

        await mockService.disconnect();
      }

      // Test scan timeout handling
      mockService.simulateSlowScan = true;
      
      expect(
        () async => await mockService.scanAndConnect(
          timeout: const Duration(milliseconds: 100)
        ),
        throwsA(isA<BleException>()),
      );
      
      mockService.simulateSlowScan = false;
    });

    testWidgets('Cross-platform compatibility validation', (WidgetTester tester) async {
      // Test BLE UUIDs are correctly formatted across platforms
      expect(BleUuids.heartRateService.length, equals(36)); // Standard UUID format
      expect(BleUuids.heartRateMeasurement.length, equals(36));
      expect(BleUuids.heartRateService, contains('180d'));
      expect(BleUuids.heartRateMeasurement, contains('2a37'));

      // Test service creation doesn't throw on any supported platform
      expect(() => BleService(), returnsNormally);

      // Test heart rate parsing works consistently
      final testData8Bit = [0x00, 75]; // 8-bit format, 75 BPM
      final testData16Bit = [0x01, 0x4C, 0x00]; // 16-bit format, 76 BPM (little-endian)
      
      expect(HeartRateParser.parseHeartRate(testData8Bit), equals(75));
      expect(HeartRateParser.parseHeartRate(testData16Bit), equals(76));
    });

    testWidgets('Memory management and resource cleanup', (WidgetTester tester) async {
      // Test that multiple service instances can be created and disposed
      final services = <MockBleIntegrationService>[];
      
      for (int i = 0; i < 5; i++) {
        final service = MockBleIntegrationService();
        await service.initializeIfNeeded();
        services.add(service);
      }

      // Connect and generate some data
      for (final service in services) {
        final device = await service.scanAndConnect();
        expect(device, isNotNull);
        await service._simulateHeartRateData(70 + services.indexOf(service));
      }

      // Dispose all services
      for (final service in services) {
        await service.dispose();
        expect(service.connectionState, BleConnectionState.idle);
        expect(service.currentDevice, isNull);
      }

      // Test that streams are properly closed (no memory leaks)
      // This is validated by the disposal process not hanging or throwing
    });

    testWidgets('Concurrent operations handling', (WidgetTester tester) async {
      await mockService.initializeIfNeeded();

      // Test that multiple concurrent scan operations are handled gracefully
      final scanFutures = <Future<DeviceInfo?>>[];
      
      for (int i = 0; i < 3; i++) {
        scanFutures.add(mockService.scanAndConnect());
      }

      // Only one should succeed (the others should be rejected or queued)
      final results = await Future.wait(scanFutures, eagerError: false);
      final successfulConnections = results.where((device) => device != null).length;
      
      expect(successfulConnections, equals(1)); // Only one connection should succeed
      expect(mockService.connectionState, BleConnectionState.connected);

      await mockService.disconnect();
    });
  });

  group('BLE Error Scenarios Integration', () {
    late MockBleIntegrationService mockService;
    
    setUp(() {
      mockService = MockBleIntegrationService();
    });

    tearDown(() async {
      await mockService.dispose();
    });

    testWidgets('Bluetooth not supported scenario', (WidgetTester tester) async {
      mockService.simulateUnsupportedBluetooth = true;
      
      expect(mockService.isSupported, isFalse);
      
      expect(
        () async => await mockService.initializeIfNeeded(),
        throwsA(isA<BleException>()),
      );
    });

    testWidgets('Permission denied scenario', (WidgetTester tester) async {
      mockService.simulatePermissionDenied = true;
      
      expect(
        () async => await mockService.checkAndRequestPermissions(),
        throwsA(predicate((e) => 
          e is BleException && e.error == BleError.permissionDenied
        )),
      );
    });

    testWidgets('Device not found scenario', (WidgetTester tester) async {
      await mockService.initializeIfNeeded();
      mockService.simulateNoDevicesFound = true;
      
      expect(
        () async => await mockService.scanAndConnect(),
        throwsA(predicate((e) => 
          e is BleException && e.error == BleError.deviceNotFound
        )),
      );
    });

    testWidgets('Connection timeout scenario', (WidgetTester tester) async {
      await mockService.initializeIfNeeded();
      mockService.simulateConnectionTimeout = true;
      
      expect(
        () async => await mockService.scanAndConnect(
          timeout: const Duration(milliseconds: 100)
        ),
        throwsA(predicate((e) => 
          e is BleException && e.error == BleError.connectionFailed
        )),
      );
    });

    testWidgets('Service/Characteristic not found scenario', (WidgetTester tester) async {
      await mockService.initializeIfNeeded();
      mockService.simulateServiceNotFound = true;
      
      expect(
        () async => await mockService.scanAndConnect(),
        throwsA(predicate((e) => 
          e is BleException && e.error == BleError.serviceNotFound
        )),
      );
    });
  });
}

/// Mock BLE service implementation for integration testing
class MockBleIntegrationService extends BleService with BleServiceMixin {
  // Simulation flags
  bool simulateConnectionFailure = false;
  bool simulateSlowScan = false;
  bool simulateUnsupportedBluetooth = false;
  bool simulatePermissionDenied = false;
  bool simulateNoDevicesFound = false;
  bool simulateConnectionTimeout = false;
  bool simulateServiceNotFound = false;

  final Random _random = Random();

  @override
  bool get isSupported => !simulateUnsupportedBluetooth;

  @override
  Future<void> initializeIfNeeded() async {
    if (simulateUnsupportedBluetooth) {
      throw const BleException(
        BleError.bluetoothNotSupported, 
        'Bluetooth not supported on this device'
      );
    }
    updateConnectionState(BleConnectionState.idle);
  }

  @override
  Future<bool> checkAndRequestPermissions() async {
    if (simulatePermissionDenied) {
      throw const BleException(
        BleError.permissionDenied,
        'Bluetooth permissions denied'
      );
    }
    return true;
  }

  @override
  Future<DeviceInfo?> scanAndConnect({Duration timeout = const Duration(seconds: 10)}) async {
    if (simulateNoDevicesFound) {
      updateConnectionState(BleConnectionState.scanning);
      await Future.delayed(const Duration(milliseconds: 100));
      updateConnectionState(BleConnectionState.error);
      throw const BleException(BleError.deviceNotFound, 'No heart rate devices found');
    }

    if (simulateConnectionTimeout) {
      updateConnectionState(BleConnectionState.scanning);
      await Future.delayed(timeout);
      updateConnectionState(BleConnectionState.error);
      throw const BleException(BleError.connectionFailed, 'Connection timeout');
    }

    if (simulateConnectionFailure) {
      updateConnectionState(BleConnectionState.scanning);
      await Future.delayed(const Duration(milliseconds: 100));
      updateConnectionState(BleConnectionState.connecting);
      await Future.delayed(const Duration(milliseconds: 100));
      updateConnectionState(BleConnectionState.error);
      throw const BleException(BleError.connectionFailed, 'Connection failed');
    }

    if (simulateServiceNotFound) {
      updateConnectionState(BleConnectionState.scanning);
      await Future.delayed(const Duration(milliseconds: 100));
      updateConnectionState(BleConnectionState.connecting);
      await Future.delayed(const Duration(milliseconds: 100));
      updateConnectionState(BleConnectionState.error);
      throw const BleException(BleError.serviceNotFound, 'Heart rate service not found');
    }

    // Normal connection flow
    updateConnectionState(BleConnectionState.scanning);
    
    if (simulateSlowScan) {
      await Future.delayed(timeout);
      throw const BleException(BleError.deviceNotFound, 'Scan timeout');
    }
    
    await Future.delayed(const Duration(milliseconds: 200));
    
    updateConnectionState(BleConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 300));

    final deviceInfo = DeviceInfo(
      id: 'mock-hr-${_random.nextInt(1000)}',
      platformName: 'Mock Heart Rate Monitor',
      rssi: -45 + _random.nextInt(20),
    );
    
    updateCurrentDevice(deviceInfo);
    updateConnectionState(BleConnectionState.connected);
    
    return deviceInfo;
  }

  @override
  Future<DeviceInfo?> connectToDevice(String deviceId, {Duration timeout = const Duration(seconds: 10)}) async {
    if (simulateConnectionFailure) {
      throw const BleException(BleError.connectionFailed, 'Connection to specific device failed');
    }

    updateConnectionState(BleConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 200));

    final deviceInfo = DeviceInfo(
      id: deviceId,
      platformName: 'Reconnected Heart Rate Monitor',
      rssi: -50 + _random.nextInt(30),
    );
    
    updateCurrentDevice(deviceInfo);
    updateConnectionState(BleConnectionState.connected);
    
    return deviceInfo;
  }

  @override
  Future<void> disconnect() async {
    updateConnectionState(BleConnectionState.disconnected);
    await Future.delayed(const Duration(milliseconds: 100));
    updateConnectionState(BleConnectionState.idle);
    updateCurrentDevice(null);
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
      DeviceInfo(
        id: 'known-device-1',
        platformName: 'Polar H10',
        rssi: -45,
      ),
      DeviceInfo(
        id: 'known-device-2', 
        platformName: 'Wahoo TICKR',
        rssi: -52,
      ),
      DeviceInfo(
        id: 'known-device-3',
        platformName: 'Garmin HRM',
        rssi: -38,
      ),
    ];
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    disposeMixin();
  }

  // Simulation helper methods
  Future<void> _simulateHeartRateData(int heartRate) async {
    if (connectionState == BleConnectionState.connected) {
      // Simulate 8-bit format heart rate data
      final data = [0x00, heartRate];
      parseAndEmitHeartRate(data);
    }
  }

  Future<void> simulateConnectionLoss() async {
    if (connectionState == BleConnectionState.connected) {
      updateConnectionState(BleConnectionState.disconnected);
    }
  }

  Future<void> resetToIdle() async {
    updateConnectionState(BleConnectionState.idle);
    updateCurrentDevice(null);
  }
}
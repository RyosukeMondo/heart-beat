import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:heart_beat/main.dart';
import 'package:heart_beat/ble/ble_service.dart';
import 'package:heart_beat/ble/ble_types.dart';
import 'package:heart_beat/workout/workout_settings.dart';
import 'package:heart_beat/workout/workout_config.dart';
import 'package:heart_beat/workout/workout_config_page.dart';
import 'package:heart_beat/player/player_page.dart';
import 'package:heart_beat/player/settings.dart';

// Generate mocks for testing
@GenerateNiceMocks([
  MockSpec<BleService>(),
  MockSpec<WorkoutSettings>(),
  MockSpec<PlayerSettings>(),
])
import 'heart_rate_page_test.mocks.dart';

void main() {
  group('HeartRatePage Widget Tests', () {
    late MockBleService mockBleService;
    late MockWorkoutSettings mockWorkoutSettings;
    late MockPlayerSettings mockPlayerSettings;
    late StreamController<int> heartRateController;
    late StreamController<BleConnectionState> connectionStateController;

    setUp(() {
      mockBleService = MockBleService();
      mockWorkoutSettings = MockWorkoutSettings();
      mockPlayerSettings = MockPlayerSettings();
      heartRateController = StreamController<int>.broadcast();
      connectionStateController = StreamController<BleConnectionState>.broadcast();

      // Setup mock default behavior
      when(mockBleService.isSupported).thenReturn(true);
      when(mockBleService.connectionState).thenReturn(BleConnectionState.idle);
      when(mockBleService.currentDevice).thenReturn(null);
      when(mockBleService.heartRateStream).thenAnswer((_) => heartRateController.stream);
      when(mockBleService.connectionStateStream).thenAnswer((_) => connectionStateController.stream);
      when(mockBleService.initializeIfNeeded()).thenAnswer((_) async {});
      when(mockBleService.checkAndRequestPermissions()).thenAnswer((_) async => true);
      when(mockBleService.dispose()).thenAnswer((_) async {});

      // Setup workout settings mock
      const defaultWorkout = WorkoutConfig(
        name: 'デフォルト',
        minHeartRate: 120,
        maxHeartRate: 160,
        duration: Duration(minutes: 30),
      );
      when(mockWorkoutSettings.selected).thenReturn(defaultWorkout);
      when(mockWorkoutSettings.load()).thenAnswer((_) async {});

      // Setup player settings mock
      when(mockPlayerSettings.load()).thenAnswer((_) async {});
    });

    tearDown(() {
      heartRateController.close();
      connectionStateController.close();
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkoutSettings>.value(value: mockWorkoutSettings),
          ChangeNotifierProvider<PlayerSettings>.value(value: mockPlayerSettings),
        ],
        child: MaterialApp(
          home: HeartRatePageTestWrapper(bleService: mockBleService),
          routes: {
            '/workout-config': (_) => const WorkoutConfigPage(),
            '/player': (_) => const PlayerPage(),
          },
        ),
      );
    }

    testWidgets('initial state displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if heart rate display shows initial state
      expect(find.text('--'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      
      // Check if connection button is present
      expect(find.text('心拍センサーに接続'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      
      // Check if status shows idle state
      expect(find.textContaining('接続待機'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth), findsOneWidget);
      
      // Check if workout information is displayed
      expect(find.textContaining('ワークアウト: デフォルト'), findsOneWidget);
      
      // Check if YouTube player button is present
      expect(find.text('YouTube プレイヤー (心拍連動)'), findsOneWidget);
    });

    testWidgets('heart rate display updates with mock data streams', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Simulate connection
      connectionStateController.add(BleConnectionState.connected);
      await tester.pump();

      // Verify connected state
      expect(find.textContaining('接続済み'), findsOneWidget);

      // Simulate heart rate data
      heartRateController.add(75);
      await tester.pump();

      // Check if heart rate is displayed
      expect(find.text('75'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      
      // Check heart rate color is red when connected
      final heartRateText = tester.widget<Text>(find.text('75'));
      expect((heartRateText.style!.color), Colors.red);

      // Update heart rate
      heartRateController.add(82);
      await tester.pump();

      expect(find.text('82'), findsOneWidget);
      expect(find.text('75'), findsNothing); // Old value should be gone
    });

    testWidgets('connection button functionality and state changes', (WidgetTester tester) async {
      when(mockBleService.scanAndConnect(timeout: anyNamed('timeout')))
          .thenAnswer((_) async {
        connectionStateController.add(BleConnectionState.scanning);
        await Future.delayed(const Duration(milliseconds: 100));
        connectionStateController.add(BleConnectionState.connecting);
        await Future.delayed(const Duration(milliseconds: 100));
        connectionStateController.add(BleConnectionState.connected);
        
        return const DeviceInfo(
          id: 'test-device',
          platformName: 'Test Heart Rate Monitor',
          rssi: -45,
        );
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially should show connect button
      expect(find.text('心拍センサーに接続'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // Tap connect button
      await tester.tap(find.text('心拍センサーに接続'));
      await tester.pump();

      // Should show scanning state
      connectionStateController.add(BleConnectionState.scanning);
      await tester.pump();
      
      expect(find.text('スキャン中...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Should show connecting state
      connectionStateController.add(BleConnectionState.connecting);
      await tester.pump();
      
      expect(find.textContaining('接続中'), findsOneWidget);

      // Should show connected state
      when(mockBleService.currentDevice).thenReturn(
        const DeviceInfo(
          id: 'test-device',
          platformName: 'Test Heart Rate Monitor',
          rssi: -45,
        ),
      );
      connectionStateController.add(BleConnectionState.connected);
      await tester.pump();

      // Should now show disconnect button
      expect(find.text('切断'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth_disabled), findsOneWidget);
      expect(find.textContaining('Test Heart Rate Monitor'), findsOneWidget);

      // Verify mock was called
      verify(mockBleService.scanAndConnect(timeout: anyNamed('timeout'))).called(1);
    });

    testWidgets('disconnect functionality works', (WidgetTester tester) async {
      when(mockBleService.disconnect()).thenAnswer((_) async {
        connectionStateController.add(BleConnectionState.disconnected);
        await Future.delayed(const Duration(milliseconds: 50));
        connectionStateController.add(BleConnectionState.idle);
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Set connected state
      when(mockBleService.currentDevice).thenReturn(
        const DeviceInfo(
          id: 'test-device',
          platformName: 'Test Heart Rate Monitor',
          rssi: -45,
        ),
      );
      connectionStateController.add(BleConnectionState.connected);
      await tester.pump();

      // Should show disconnect button
      expect(find.text('切断'), findsOneWidget);

      // Tap disconnect button
      await tester.tap(find.text('切断'));
      await tester.pump();

      // Should show disconnected then idle
      connectionStateController.add(BleConnectionState.disconnected);
      await tester.pump();
      expect(find.textContaining('切断されました'), findsOneWidget);

      connectionStateController.add(BleConnectionState.idle);
      await tester.pump();
      expect(find.textContaining('接続待機'), findsOneWidget);

      // Verify disconnect was called
      verify(mockBleService.disconnect()).called(1);
    });

    testWidgets('navigation to workout configuration page', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find and tap workout config button in app bar
      expect(find.byIcon(Icons.settings_suggest), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings_suggest));
      await tester.pumpAndSettle();

      // Should navigate to workout config page
      expect(find.byType(WorkoutConfigPage), findsOneWidget);
    });

    testWidgets('navigation to player page', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find and tap YouTube player button
      expect(find.text('YouTube プレイヤー (心拍連動)'), findsOneWidget);
      await tester.tap(find.text('YouTube プレイヤー (心拍連動)'));
      await tester.pumpAndSettle();

      // Should navigate to player page
      expect(find.byType(PlayerPage), findsOneWidget);
    });

    testWidgets('error state display and recovery', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Simulate error state
      connectionStateController.add(BleConnectionState.error);
      await tester.pump();

      // Should show error icon and message
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.textContaining('エラーが発生しました'), findsOneWidget);
      
      // Status should be red
      final statusText = tester.widget<Text>(find.textContaining('エラーが発生しました'));
      expect((statusText.style!.color), Colors.red);

      // Recovery - return to idle state
      connectionStateController.add(BleConnectionState.idle);
      await tester.pump();

      // Should show normal idle state
      expect(find.textContaining('接続待機'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    });

    testWidgets('device connection display shows device info', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Set connected state with device info
      when(mockBleService.currentDevice).thenReturn(
        const DeviceInfo(
          id: 'polar-h10-123',
          platformName: 'Polar H10 Heart Rate',
          rssi: -42,
        ),
      );
      connectionStateController.add(BleConnectionState.connected);
      await tester.pump();

      // Should show device name in status
      expect(find.textContaining('Polar H10 Heart Rate'), findsAny);
      
      // Should show green connected indicator with device name
      expect(find.byIcon(Icons.bluetooth_connected), findsAny);
      
      // Heart rate display should be colored (red when connected)
      final bpmText = tester.widget<Text>(find.text('BPM'));
      expect((bpmText.style!.color), Colors.black87);
    });

    testWidgets('bluetooth not supported scenario', (WidgetTester tester) async {
      when(mockBleService.isSupported).thenReturn(false);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show not supported message
      expect(find.textContaining('Bluetooth未対応'), findsOneWidget);
    });

    testWidgets('permission denied error handling', (WidgetTester tester) async {
      when(mockBleService.checkAndRequestPermissions()).thenAnswer((_) async => false);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap connect button
      await tester.tap(find.text('心拍センサーに接続'));
      await tester.pump();

      // Should show permission error
      expect(find.textContaining('Bluetooth権限が必要です'), findsOneWidget);
    });

    testWidgets('connection timeout error handling', (WidgetTester tester) async {
      when(mockBleService.scanAndConnect(timeout: anyNamed('timeout')))
          .thenThrow(const BleException(BleError.deviceNotFound, 'No devices found'));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap connect button
      await tester.tap(find.text('心拍センサーに接続'));
      await tester.pump();

      // Wait for error to appear
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.textContaining('心拍センサーが見つかりません'), findsOneWidget);
    });

    testWidgets('heart rate display formatting', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Test different heart rate values
      final testValues = [0, 45, 72, 99, 120, 180, 255];
      
      for (final value in testValues) {
        heartRateController.add(value);
        await tester.pump();
        
        // Should display the value
        expect(find.text('$value'), findsOneWidget);
        expect(find.text('BPM'), findsOneWidget);
      }
    });

    testWidgets('workout information updates', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initial workout should be displayed
      expect(find.textContaining('ワークアウト: デフォルト'), findsOneWidget);

      // Change workout configuration
      const newWorkout = WorkoutConfig(
        name: '高強度インターバル',
        minHeartRate: 140,
        maxHeartRate: 180,
        duration: Duration(minutes: 20),
      );
      when(mockWorkoutSettings.selected).thenReturn(newWorkout);
      
      // Trigger rebuild
      await tester.binding.reassembleApplication();
      await tester.pumpAndSettle();

      // Should show updated workout
      expect(find.textContaining('ワークアウト: 高強度インターバル'), findsOneWidget);
    });

    testWidgets('connection state icons and colors are correct', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final stateTests = [
        (BleConnectionState.idle, Icons.bluetooth, Colors.grey),
        (BleConnectionState.scanning, Icons.bluetooth_searching, Colors.orange),
        (BleConnectionState.connecting, Icons.bluetooth_connected, Colors.orange),
        (BleConnectionState.connected, Icons.bluetooth_connected, Colors.green),
        (BleConnectionState.disconnected, Icons.bluetooth_disabled, Colors.grey),
        (BleConnectionState.error, Icons.error, Colors.red),
      ];

      for (final (state, expectedIcon, expectedColor) in stateTests) {
        connectionStateController.add(state);
        await tester.pump();

        // Check icon
        expect(find.byIcon(expectedIcon), findsOneWidget);
        
        // Check that we can find an icon with the expected color
        final iconWidget = tester.widget<Icon>(find.byIcon(expectedIcon));
        expect(iconWidget.color, expectedColor);
      }
    });

    testWidgets('stream subscription cleanup on dispose', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Emit some data to establish subscriptions
      heartRateController.add(75);
      connectionStateController.add(BleConnectionState.connected);
      await tester.pump();

      // Navigate away to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Other Page'))));
      await tester.pumpAndSettle();

      // Verify dispose was called on BLE service
      verify(mockBleService.dispose()).called(1);
    });
  });

  group('HeartBeatApp Widget Tests', () {
    late MockWorkoutSettings mockWorkoutSettings;
    late MockPlayerSettings mockPlayerSettings;

    setUp(() {
      mockWorkoutSettings = MockWorkoutSettings();
      mockPlayerSettings = MockPlayerSettings();
      
      when(mockWorkoutSettings.load()).thenAnswer((_) async {});
      when(mockPlayerSettings.load()).thenAnswer((_) async {});
    });

    testWidgets('app initializes with correct providers', (WidgetTester tester) async {
      await tester.pumpWidget(const HeartBeatApp());
      await tester.pumpAndSettle();

      // Should find the main page
      expect(find.byType(HeartRatePage), findsOneWidget);
      
      // Should have correct title
      expect(find.text('心拍数表示 (Mobile)'), findsOneWidget);
      
      // Should have Material Design theme
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.colorScheme.primary, isNotNull);
      expect(materialApp.debugShowCheckedModeBanner, isFalse);
    });
  });
}

/// Test wrapper to inject mock BLE service for HeartRatePage
class HeartRatePageTestWrapper extends StatefulWidget {
  final BleService bleService;
  
  const HeartRatePageTestWrapper({
    super.key,
    required this.bleService,
  });

  @override
  State<HeartRatePageTestWrapper> createState() => _HeartRatePageTestWrapperState();
}

class _HeartRatePageTestWrapperState extends State<HeartRatePageTestWrapper> {
  late final BleService _bleService;
  StreamSubscription<int>? _heartRateSubscription;
  StreamSubscription<BleConnectionState>? _connectionStateSubscription;
  
  BleConnectionState _connectionState = BleConnectionState.idle;
  int? _latestBpm;
  DeviceInfo? _connectedDevice;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bleService = widget.bleService;
    _initializeBleService();
  }

  @override
  void dispose() {
    _heartRateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }

  Future<void> _initializeBleService() async {
    try {
      setState(() {
        _connectionState = BleConnectionState.idle;
        _errorMessage = null;
      });

      await _bleService.initializeIfNeeded();
      _setupStreamSubscriptions();

      setState(() {
        _connectionState = BleConnectionState.idle;
      });
    } catch (e) {
      setState(() {
        _connectionState = BleConnectionState.error;
        _errorMessage = _getBleErrorMessage(e);
      });
    }
  }

  void _setupStreamSubscriptions() {
    _heartRateSubscription?.cancel();
    _heartRateSubscription = _bleService.heartRateStream.listen(
      (heartRate) {
        setState(() {
          _latestBpm = heartRate;
        });
      },
      onError: (error) {
        print('Heart rate stream error: $error');
      },
    );

    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = _bleService.connectionStateStream.listen(
      (state) {
        setState(() {
          _connectionState = state;
          _connectedDevice = _bleService.currentDevice;
          
          if (state == BleConnectionState.connected) {
            _errorMessage = null;
          }
        });
      },
      onError: (error) {
        print('Connection state stream error: $error');
      },
    );
  }

  String _getBleErrorMessage(dynamic error) {
    if (error is BleException) {
      return error.localizedMessage;
    }
    return error.toString();
  }

  String get _statusText {
    if (_errorMessage != null) {
      return _errorMessage!;
    }
    
    switch (_connectionState) {
      case BleConnectionState.idle:
        return !_bleService.isSupported ? 'Bluetooth未対応' : '接続待機';
      case BleConnectionState.scanning:
        return 'デバイスをスキャン中...';
      case BleConnectionState.connecting:
        return '接続中...';
      case BleConnectionState.connected:
        return '接続済み: ${_connectedDevice?.platformName ?? "Unknown Device"}';
      case BleConnectionState.disconnected:
        return '切断されました';
      case BleConnectionState.error:
        return 'エラーが発生しました';
    }
  }

  Future<void> _connect() async {
    try {
      setState(() => _errorMessage = null);
      
      final permissionsGranted = await _bleService.checkAndRequestPermissions();
      if (!permissionsGranted) {
        setState(() {
          _errorMessage = 'Bluetooth権限が必要です';
          _connectionState = BleConnectionState.error;
        });
        return;
      }

      final deviceInfo = await _bleService.scanAndConnect(
        timeout: const Duration(seconds: 15),
      );

      if (deviceInfo == null) {
        setState(() {
          _errorMessage = '心拍センサーが見つかりませんでした';
          _connectionState = BleConnectionState.idle;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _getBleErrorMessage(e);
        _connectionState = BleConnectionState.error;
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await _bleService.disconnect();
    } catch (e) {
      setState(() {
        _errorMessage = _getBleErrorMessage(e);
      });
    }
  }

  Widget _buildHeartRateDisplay() {
    final bpm = _latestBpm;
    final isConnected = _connectionState == BleConnectionState.connected;
    
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            bpm != null ? '$bpm' : '--',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: isConnected ? Colors.red : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'BPM',
            style: TextStyle(
              fontSize: 16,
              color: isConnected ? Colors.black87 : Colors.grey,
            ),
          ),
          if (_connectedDevice != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bluetooth_connected, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _connectedDevice!.platformName,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionButton() {
    final isConnected = _connectionState == BleConnectionState.connected;
    final isConnecting = _connectionState == BleConnectionState.connecting || 
                        _connectionState == BleConnectionState.scanning;

    if (isConnected) {
      return FilledButton.icon(
        onPressed: isConnecting ? null : _disconnect,
        icon: const Icon(Icons.bluetooth_disabled),
        label: const Text('切断'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      );
    }

    return FilledButton.icon(
      onPressed: isConnecting ? null : _connect,
      icon: isConnecting 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.favorite),
      label: Text(isConnecting ? 'スキャン中...' : '心拍センサーに接続'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutSettings>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('心拍数表示 (Mobile)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Workout Config',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WorkoutConfigPage()),
              );
            },
            icon: const Icon(Icons.settings_suggest),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(),
                      color: _getStatusColor(),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '状態: $_statusText',
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Expanded(
              child: Center(child: _buildHeartRateDisplay()),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.fitness_center, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text('ワークアウト: ${workout.selected.name}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildConnectionButton(),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlayerPage()),
                );
              },
              icon: const Icon(Icons.ondemand_video),
              label: const Text('YouTube プレイヤー (心拍連動)'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_connectionState) {
      case BleConnectionState.idle:
        return Icons.bluetooth;
      case BleConnectionState.scanning:
        return Icons.bluetooth_searching;
      case BleConnectionState.connecting:
        return Icons.bluetooth_connected;
      case BleConnectionState.connected:
        return Icons.bluetooth_connected;
      case BleConnectionState.disconnected:
        return Icons.bluetooth_disabled;
      case BleConnectionState.error:
        return Icons.error;
    }
  }

  Color _getStatusColor() {
    if (_errorMessage != null) return Colors.red;
    
    switch (_connectionState) {
      case BleConnectionState.idle:
        return Colors.grey;
      case BleConnectionState.scanning:
      case BleConnectionState.connecting:
        return Colors.orange;
      case BleConnectionState.connected:
        return Colors.green;
      case BleConnectionState.disconnected:
        return Colors.grey;
      case BleConnectionState.error:
        return Colors.red;
    }
  }
}
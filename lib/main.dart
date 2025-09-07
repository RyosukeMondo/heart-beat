import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import 'player/player_page.dart';
import 'player/settings.dart';
import 'workout/workout_settings.dart';
import 'workout/workout_config_page.dart';
import 'ble/ble_service.dart';
import 'ble/ble_types.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HeartBeatApp());
}

class HeartBeatApp extends StatelessWidget {
  const HeartBeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerSettings()..load()),
        ChangeNotifierProvider(create: (_) => WorkoutSettings()..load()),
      ],
      child: MaterialApp(
        title: 'Heart Beat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        ),
        home: const HeartRatePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class HeartRatePage extends StatefulWidget {
  const HeartRatePage({super.key});

  @override
  State<HeartRatePage> createState() => _HeartRatePageState();
}

class _HeartRatePageState extends State<HeartRatePage> {
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
    _bleService = BleService();
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

      // Initialize the BLE service
      await _bleService.initializeIfNeeded();

      // Set up stream subscriptions
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
    // Subscribe to heart rate data stream
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

    // Subscribe to connection state changes
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = _bleService.connectionStateStream.listen(
      (state) {
        setState(() {
          _connectionState = state;
          _connectedDevice = _bleService.currentDevice;
          
          // Clear error message on successful connection
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
      
      // Check and request permissions if needed
      final permissionsGranted = await _bleService.checkAndRequestPermissions();
      if (!permissionsGranted) {
        setState(() {
          _errorMessage = 'Bluetooth権限が必要です';
          _connectionState = BleConnectionState.error;
        });
        return;
      }

      // Start scanning and connecting
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
    final platformName = kIsWeb ? "Web" : Platform.isWindows ? "Windows" : "Mobile";
    
    return Scaffold(
      appBar: AppBar(
        title: Text('心拍数表示 ($platformName)'),
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
            // Status display
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

            // Heart rate display
            Expanded(
              child: Center(child: _buildHeartRateDisplay()),
            ),

            const SizedBox(height: 16),

            // Workout info
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

            // Connection button
            _buildConnectionButton(),

            const SizedBox(height: 8),

            // YouTube player button
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
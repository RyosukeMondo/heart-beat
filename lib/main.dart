import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'player/player_page.dart';
import 'player/settings.dart';
import 'workout/workout_settings.dart';
import 'workout/workout_config_page.dart';

import 'ble/ble_service.dart';

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
  String _status = '準備完了';
  int? _latestBpm;
  Stream<int>? _bpmStream;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _status = '初期化中...');

    // Android runtime permissions
    if (!kIsWeb && !Platform.isWindows) {
      await _ensureBlePermissions();
    }

    // Initialize Windows backend if needed happens in service
    await BleService.instance.initializeIfNeeded();

    setState(() => _status = '接続待機');

    // Prepare Stream
    setState(() {
      _bpmStream = BleService.instance.heartRateStream;
    });
  }

  Future<void> _ensureBlePermissions() async {
    if (Platform.isAndroid) {
      // Android 12+ specific BLE permissions
      final scan = await Permission.bluetoothScan.request();
      final connect = await Permission.bluetoothConnect.request();
      // On some devices, location may still be needed for legacy stacks
      if (await Permission.locationWhenInUse.isDenied) {
        await Permission.locationWhenInUse.request();
      }
      if (scan.isDenied || connect.isDenied) {
        setState(() => _status = '権限が拒否されました');
      }
    }
  }

  Future<void> _connect() async {
    setState(() => _status = 'スキャン中...');
    final info = await BleService.instance.scanAndConnect();
    setState(() => _status = info == null ? 'デバイス未検出' : '接続済み: ${info.platformName}');
  }

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutSettings>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('心拍数表示 (Android / Windows)'),
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
            Text('状態: $_status'),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: _bpmStream == null
                    ? const Text('初期化中...')
                    : StreamBuilder<int>(
                        stream: _bpmStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            _latestBpm = snapshot.data;
                          }
                          final bpm = snapshot.data ?? _latestBpm;
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  bpm != null ? '$bpm' : '--',
                                  style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text('BPM'),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Workout: ${workout.selected.name}'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _connect,
              icon: const Icon(Icons.favorite),
              label: const Text('Coospo HW9 に接続'),
            ),
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
}

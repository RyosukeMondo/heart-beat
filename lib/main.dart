import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' hide Provider, Consumer;

import 'player/player_page.dart';
import 'player/settings.dart';
import 'workout/workout_settings.dart';
import 'workout/workout_config_page.dart';
import 'auth/auth_settings.dart';
import 'auth/login_page.dart';
import 'ble/ble_service.dart';
import 'ble/ble_types.dart';

import 'workout/coaching_controller.dart';
import 'workout/coaching_state.dart';
import 'workout/daily_charge_bar.dart';
import 'workout/zone_meter.dart';
import 'workout/session_summary_sheet.dart';
import 'workout/session_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope( // Riverpod scope
      child: const HeartBeatApp(),
    ),
  );
}

class HeartBeatApp extends StatelessWidget {
  const HeartBeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    // We keep MultiProvider for legacy parts or parts not yet migrated to Riverpod
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerSettings()..load()),
        ChangeNotifierProvider(create: (_) => WorkoutSettings()..load()),
        ChangeNotifierProvider(create: (_) => AuthSettings()),
      ],
      child: MaterialApp(
        title: 'Heart Beat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
        ),
        home: const CoachingPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class CoachingPage extends ConsumerStatefulWidget {
  const CoachingPage({super.key});

  @override
  ConsumerState<CoachingPage> createState() => _CoachingPageState();
}

class _CoachingPageState extends ConsumerState<CoachingPage> {
  // We use the controller via Riverpod
  
  @override
  void initState() {
    super.initState();
    // Start scanning on load? Or wait for user?
    // Spec says: "WHEN launching or starting a session on Android 12+ THEN the app SHALL request BLUETOOTH_SCAN and BLUETOOTH_CONNECT"
    // We should probably init BLE permissions here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBle();
    });
  }

  Future<void> _initBle() async {
    final bleService = ref.read(bleServiceProvider);
    await bleService.initializeIfNeeded();
    final hasPerms = await bleService.checkAndRequestPermissions();
    if (hasPerms) {
       // Auto scan? Or manual?
       // Existing app had manual connect button. Spec implies "connection drops... retry".
       // Let's keep manual connect for now but auto reconnect if dropped.
    }
  }

  @override
  Widget build(BuildContext context) {
     final coachingState = ref.watch(coachingControllerProvider);
     final controller = ref.read(coachingControllerProvider.notifier);
     final bleService = ref.watch(bleServiceProvider);

     // Legacy providers
     final authSettings = context.watch<AuthSettings>();
     final workoutSettings = context.watch<WorkoutSettings>();

     return Scaffold(
       appBar: AppBar(
         title: const Text('Heart Beat Coach'),
         actions: [
            IconButton(
            tooltip: 'Authentication',
            onPressed: () {
              if (authSettings.isAuthenticated) {
                // _showUserMenu(context); // Legacy user menu if needed
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
            icon: Icon(
              authSettings.isAuthenticated
                  ? Icons.person 
                  : Icons.person_outline,
            ),
          ),
          IconButton(
            tooltip: 'Workout Config',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WorkoutConfigPage()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
         ],
       ),
       body: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
           const SizedBox(height: 16),
           const DailyChargeBar(),
           const Spacer(),
           const Center(child: ZoneMeter()),
           const Spacer(),
           _buildControls(context, controller, coachingState, bleService),
           const SizedBox(height: 24),
         ],
       ),
     );
  }

  Widget _buildControls(BuildContext context, CoachingController controller, CoachingState state, BleService bleService) {
    return StreamBuilder<BleConnectionState>(
      stream: bleService.connectionStateStream,
      initialData: BleConnectionState.idle,
      builder: (context, snapshot) {
        final connState = snapshot.data ?? BleConnectionState.idle;

        if (connState == BleConnectionState.connected) {
             if (state.status == SessionStatus.idle) {
               // Not started, show Start button
               return FloatingActionButton.extended(
                 onPressed: () {
                    // Start session with current workout settings
                    final ws = context.read<WorkoutSettings>();
                    final (lower, upper) = ws.targetRange();
                    // Assuming targetMinutes is in settings or profile, but spec says "Daily Charge".
                    // Let's assume 30 mins default or read from somewhere.
                    // WS doesn't seem to have target minutes exposed directly except maybe in configs.
                    // For now hardcode 30 or read from controller default.
                    controller.startSession(30, lower, upper);
                 },
                 label: const Text('START SESSION'),
                 icon: const Icon(Icons.play_arrow),
               );
             } else if (state.status == SessionStatus.paused) {
                // Show Resume / Stop
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.extended(
                      onPressed: () => controller.resumeSession(),
                      label: const Text('RESUME'),
                      icon: const Icon(Icons.play_arrow),
                      backgroundColor: Colors.green,
                    ),
                    const SizedBox(width: 24),
                    FloatingActionButton.extended(
                      onPressed: () => _endSession(context, controller),
                      label: const Text('STOP'),
                      icon: const Icon(Icons.stop),
                      backgroundColor: Colors.red,
                    ),
                  ],
                );
             } else {
                // Running
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     FloatingActionButton.extended(
                      onPressed: () => controller.pauseSession(),
                      label: const Text('PAUSE'),
                      icon: const Icon(Icons.pause),
                      backgroundColor: Colors.orange,
                    ),
                  ],
                );
             }
        } else if (connState == BleConnectionState.scanning || connState == BleConnectionState.connecting) {
           return const Center(child: CircularProgressIndicator());
        } else {
           // Disconnected or Error
           return FloatingActionButton.extended(
             onPressed: () async {
               // Manual connect
               try {
                  await bleService.scanAndConnect();
               } catch (e) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
               }
             },
             label: const Text('CONNECT SENSOR'),
             icon: const Icon(Icons.bluetooth_searching),
           );
        }
      },
    );
  }

  void _endSession(BuildContext context, CoachingController controller) {
    controller.pauseSession();
    final state = controller.state;
    // Show summary
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => SessionSummarySheet(
        session: SessionRecord(
          id: DateTime.now().toIso8601String(),
          start: DateTime.now().subtract(Duration(minutes: state.sessionMinutes)),
          end: DateTime.now(),
          avgBpm: state.avgBpm,
          maxBpm: state.maxBpm,
          minutesInZone: state.sessionMinutes,
          rpe: null, // To be filled
        ),
        onSave: (rpe) async {
          // Create final session record with RPE
          final session = SessionRecord(
            id: DateTime.now().toIso8601String(),
            start: DateTime.now().subtract(Duration(minutes: state.sessionMinutes)),
            end: DateTime.now(),
            avgBpm: state.avgBpm,
            maxBpm: state.maxBpm,
            minutesInZone: state.sessionMinutes,
            rpe: rpe,
          );

          // Save to repo
          final repo = ref.read(sessionRepositoryProvider);
          await repo.saveSession(session);

          if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session Saved!')));
          }

          // Check for weekly progression? (WeeklyAdapter usage would go here or in a background job)
          // For now, just saved.
        }
      ),
    );
  }
}

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' hide Provider, Consumer, ChangeNotifierProvider;
import 'package:provider/provider.dart' as p;

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
import 'coaching_controls.dart';

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
        p.ChangeNotifierProvider(create: (_) => PlayerSettings()..load()),
        p.ChangeNotifierProvider(create: (_) => WorkoutSettings()..load()),
        p.ChangeNotifierProvider(create: (_) => AuthSettings()),
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

     return Scaffold(
       appBar: AppBar(
         title: const Text('Heart Beat Coach'),
         actions: const [
           AuthenticationButton(),
           WorkoutConfigButton(),
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
           CoachingControls(
             controller: controller,
             state: coachingState,
             bleService: bleService,
           ),
           const SizedBox(height: 24),
         ],
       ),
     );
  }
}

class AuthenticationButton extends StatelessWidget {
  const AuthenticationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final authSettings = context.watch<AuthSettings>();
    return IconButton(
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
    );
  }
}

class WorkoutConfigButton extends StatelessWidget {
  const WorkoutConfigButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Workout Config',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WorkoutConfigPage()),
        );
      },
      icon: const Icon(Icons.settings),
    );
  }
}

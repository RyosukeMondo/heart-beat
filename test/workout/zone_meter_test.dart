import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heart_beat/workout/zone_meter.dart';
import 'package:heart_beat/workout/coaching_controller.dart';
import 'package:heart_beat/workout/coaching_state.dart';
import 'package:heart_beat/ble/ble_service.dart';
import 'package:heart_beat/workout/workout_settings.dart';
import 'package:heart_beat/providers.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([BleService, WorkoutSettings])
import 'zone_meter_test.mocks.dart';

void main() {
  late MockBleService mockBleService;
  late MockWorkoutSettings mockWorkoutSettings;

  setUp(() {
    mockBleService = MockBleService();
    mockWorkoutSettings = MockWorkoutSettings();
    
    when(mockBleService.heartRateStream).thenAnswer((_) => const Stream.empty());
    when(mockBleService.connectionStateStream).thenAnswer((_) => const Stream.empty());
    when(mockWorkoutSettings.targetRange()).thenReturn((120, 150));
    when(mockWorkoutSettings.selectedCustomConfig).thenReturn(null);
  });

  Widget createTestWidget(CoachingState state) {
    return ProviderScope(
      overrides: [
        bleServiceProvider.overrideWithValue(mockBleService),
        workoutSettingsProvider.overrideWith((ref) => mockWorkoutSettings),
        coachingControllerProvider.overrideWith((ref) => TestCoachingController(state, mockBleService, mockWorkoutSettings)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ZoneMeter(),
        ),
      ),
    );
  }

  testWidgets('ZoneMeter displays BPM and target correctly', (tester) async {
    final state = CoachingState.initial().copyWith(
      status: SessionStatus.running,
      currentBpm: 135,
      targetLowerBpm: 120,
      targetUpperBpm: 150,
      cue: ZoneCue.keep,
    );

    await tester.pumpWidget(createTestWidget(state));
    await tester.pump(); // Use pump instead of pumpAndSettle for repeating animations

    expect(find.text('135'), findsOneWidget);
    expect(find.textContaining('Target: 120 - 150'), findsOneWidget);
    expect(find.text('KEEP ⟷'), findsOneWidget);
  });

  testWidgets('ZoneMeter shows UP cue when BPM is low', (tester) async {
    final state = CoachingState.initial().copyWith(
      status: SessionStatus.running,
      currentBpm: 110,
      targetLowerBpm: 120,
      targetUpperBpm: 150,
      cue: ZoneCue.up,
    );

    await tester.pumpWidget(createTestWidget(state));
    await tester.pump();

    expect(find.text('UP ↑'), findsOneWidget);
    expect(find.text('心拍数を上げて'), findsOneWidget);
  });

  testWidgets('ZoneMeter shows DOWN cue when BPM is high', (tester) async {
    final state = CoachingState.initial().copyWith(
      status: SessionStatus.running,
      currentBpm: 160,
      targetLowerBpm: 120,
      targetUpperBpm: 150,
      cue: ZoneCue.down,
    );

    await tester.pumpWidget(createTestWidget(state));
    await tester.pump();

    expect(find.text('DOWN ↓'), findsOneWidget);
    expect(find.text('心拍数を下げて'), findsOneWidget);
  });
}

class TestCoachingController extends CoachingController {
  final CoachingState _fixedState;
  TestCoachingController(this._fixedState, BleService ble, WorkoutSettings settings) : super(ble, settings) {
    state = _fixedState;
  }
  
  @override
  void dispose() {
    // No-op for test
  }
}

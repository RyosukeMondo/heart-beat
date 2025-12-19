import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heart_beat/workout/daily_charge_bar.dart';
import 'package:heart_beat/workout/coaching_controller.dart';
import 'package:heart_beat/workout/coaching_state.dart';
import 'package:heart_beat/ble/ble_service.dart';
import 'package:heart_beat/workout/workout_settings.dart';
import 'package:heart_beat/providers.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([BleService, WorkoutSettings])
import 'daily_charge_bar_test.mocks.dart';

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
          body: DailyChargeBar(),
        ),
      ),
    );
  }

  testWidgets('DailyChargeBar displays minutes correctly', (tester) async {
    final state = CoachingState.initial().copyWith(
      dailyMinutes: 15,
      targetMinutes: 30,
    );

    await tester.pumpWidget(createTestWidget(state));
    await tester.pumpAndSettle();

    expect(find.text('15'), findsOneWidget);
    expect(find.textContaining('/ 30 mins'), findsOneWidget);
  });

  testWidgets('DailyChargeBar shows reconnecting state', (tester) async {
    final state = CoachingState.initial().copyWith(
      reconnecting: true,
    );

    await tester.pumpWidget(createTestWidget(state));
    await tester.pump();

    expect(find.text('再接続中...'), findsOneWidget);
  });

  testWidgets('DailyChargeBar shows gap indicator', (tester) async {
    final state = CoachingState.initial().copyWith(
      hasGaps: true,
    );

    await tester.pumpWidget(createTestWidget(state));
    await tester.pump();

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('接続中断によるデータの欠落があります'), findsOneWidget);
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

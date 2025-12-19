import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/workout/session_repository.dart';
import 'package:heart_beat/workout/weekly_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([SessionRepository])
import 'weekly_adapter_test.mocks.dart';

void main() {
  late MockSessionRepository mockRepo;
  late WeeklyAdapter adapter;

  setUp(() {
    mockRepo = MockSessionRepository();
    adapter = WeeklyAdapter(mockRepo);
  });

  test('Increase load when completion high and RPE low', () async {
    final start = DateTime(2023, 1, 1);
    final end = DateTime(2023, 1, 8);

    when(mockRepo.getSessions()).thenAnswer((_) async => [
      SessionRecord(
        id: '1',
        start: start.add(Duration(days: 1)),
        end: start.add(Duration(days: 1, minutes: 30)),
        avgBpm: 130,
        maxBpm: 150,
        minutesInZone: 30,
        rpe: 5
      ),
      SessionRecord(
        id: '2',
        start: start.add(Duration(days: 3)),
        end: start.add(Duration(days: 3, minutes: 30)),
        avgBpm: 130,
        maxBpm: 150,
        minutesInZone: 30,
        rpe: 6
      ),
    ]);

    // Target 60 mins, achieved 60. RPE avg 5.5
    final delta = await adapter.computeNextWeek(60, start, end);

    expect(delta.minutesDelta, 6); // 10% of 60
    expect(delta.intensityDelta, 2);
  });

  test('Hold when RPE is high', () async {
    final start = DateTime(2023, 1, 1);
    final end = DateTime(2023, 1, 8);

    when(mockRepo.getSessions()).thenAnswer((_) async => [
      SessionRecord(
        id: '1',
        start: start.add(Duration(days: 1)),
        end: start.add(Duration(days: 1, minutes: 30)),
        avgBpm: 130,
        maxBpm: 150,
        minutesInZone: 30,
        rpe: 9
      ),
    ]);

    // Target 30 mins, achieved 30. RPE 9.
    final delta = await adapter.computeNextWeek(30, start, end);

    expect(delta.minutesDelta, 0);
    expect(delta.intensityDelta, -2);
  });

  test('Hold when completion is low', () async {
    final start = DateTime(2023, 1, 1);
    final end = DateTime(2023, 1, 8);

    when(mockRepo.getSessions()).thenAnswer((_) async => [
      SessionRecord(
        id: '1',
        start: start.add(Duration(days: 1)),
        end: start.add(Duration(days: 1, minutes: 30)),
        avgBpm: 130,
        maxBpm: 150,
        minutesInZone: 10,
        rpe: 5
      ),
    ]);

    // Target 30 mins, achieved 10. (33%)
    final delta = await adapter.computeNextWeek(30, start, end);

    expect(delta.minutesDelta, 0);
    expect(delta.intensityDelta, 0);
  });
}

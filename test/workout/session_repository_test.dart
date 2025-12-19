import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/workout/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferencesSessionRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = SharedPreferencesSessionRepository();
  });

  test('Saves and retrieves sessions', () async {
    final session = SessionRecord(
      id: 'session-1',
      start: DateTime(2025, 12, 20, 10, 0),
      end: DateTime(2025, 12, 20, 10, 30),
      avgBpm: 135,
      maxBpm: 155,
      minutesInZone: 25,
      rpe: 7,
    );

    await repository.saveSession(session);
    final sessions = await repository.getSessions();

    expect(sessions.length, 1);
    expect(sessions[0].id, 'session-1');
    expect(sessions[0].rpe, 7);
    expect(sessions[0].minutesInZone, 25);
  });

  test('Updates existing session by ID', () async {
    final session = SessionRecord(
      id: 'session-1',
      start: DateTime(2025, 12, 20, 10, 0),
      end: DateTime(2025, 12, 20, 10, 30),
      avgBpm: 135,
      maxBpm: 155,
      minutesInZone: 25,
      rpe: null,
    );

    await repository.saveSession(session);
    
    final updatedSession = session.copyWith(rpe: 8);
    await repository.saveSession(updatedSession);
    
    final sessions = await repository.getSessions();
    expect(sessions.length, 1);
    expect(sessions[0].rpe, 8);
  });

  test('Handles empty sessions', () async {
    final sessions = await repository.getSessions();
    expect(sessions, isEmpty);
  });
}

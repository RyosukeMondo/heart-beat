import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SessionRecord {
  final String id;
  final DateTime start;
  final DateTime end;
  final int avgBpm;
  final int maxBpm;
  final int minutesInZone;
  final int? rpe;

  SessionRecord({
    required this.id,
    required this.start,
    required this.end,
    required this.avgBpm,
    required this.maxBpm,
    required this.minutesInZone,
    this.rpe,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'avgBpm': avgBpm,
      'maxBpm': maxBpm,
      'minutesInZone': minutesInZone,
      'rpe': rpe,
    };
  }

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      id: json['id'],
      start: DateTime.parse(json['start']),
      end: DateTime.parse(json['end']),
      avgBpm: json['avgBpm'],
      maxBpm: json['maxBpm'],
      minutesInZone: json['minutesInZone'],
      rpe: json['rpe'],
    );
  }

  SessionRecord copyWith({int? rpe}) {
    return SessionRecord(
      id: id,
      start: start,
      end: end,
      avgBpm: avgBpm,
      maxBpm: maxBpm,
      minutesInZone: minutesInZone,
      rpe: rpe ?? this.rpe,
    );
  }
}

abstract class SessionRepository {
  Future<void> saveSession(SessionRecord session);
  Future<List<SessionRecord>> getSessions();
}

class SharedPreferencesSessionRepository implements SessionRepository {
  static const String _kSessions = 'heart_beat.sessions';

  @override
  Future<void> saveSession(SessionRecord session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();

    // Check if exists
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }

    final jsonList = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_kSessions, json.encode(jsonList));
  }

  @override
  Future<List<SessionRecord>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kSessions);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((j) => SessionRecord.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SharedPreferencesSessionRepository();
});

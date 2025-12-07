import 'session_repository.dart';

class PlanDelta {
  final int minutesDelta; // e.g. +3, 0, -5
  final int intensityDelta; // e.g. +2 (percent), 0, -2
  final String reasoning;

  PlanDelta({
    required this.minutesDelta,
    required this.intensityDelta,
    required this.reasoning,
  });
}

class WeeklyAdapter {
  final SessionRepository _sessionRepository;

  WeeklyAdapter(this._sessionRepository);

  Future<PlanDelta> computeNextWeek(int targetMinutes, DateTime weekStart, DateTime weekEnd) async {
    final sessions = await _sessionRepository.getSessions();
    final weekSessions = sessions.where((s) =>
      s.start.isAfter(weekStart) && s.end.isBefore(weekEnd)
    ).toList();

    int totalMinutes = 0;
    double totalRpe = 0;
    int rpeCount = 0;

    for (var session in weekSessions) {
      totalMinutes += session.minutesInZone;
      if (session.rpe != null) {
        totalRpe += session.rpe!;
        rpeCount++;
      }
    }

    double avgRpe = rpeCount > 0 ? totalRpe / rpeCount : 0;
    double completionRate = targetMinutes > 0 ? totalMinutes / targetMinutes : 0;

    // Logic:
    // 1. Completion >= 100% AND Avg RPE <= 6 -> Increase 10% mins, +2% intensity
    // 2. Completion < 70% OR Avg RPE >= 8 -> Hold or Reduce
    // 3. Else -> Hold

    if (completionRate >= 1.0 && avgRpe <= 6 && rpeCount > 0) {
       int increase = (targetMinutes * 0.10).round();
       if (increase < 1) increase = 1;
       return PlanDelta(
         minutesDelta: increase,
         intensityDelta: 2,
         reasoning: 'Great job! Increasing target by 10% and intensity slightly.',
       );
    } else if (completionRate < 0.70 || avgRpe >= 8) {
       return PlanDelta(
         minutesDelta: 0,
         intensityDelta: 0,
         reasoning: 'Let\'s hold steady for now. Focus on consistency and recovery.',
       );
    } else {
       return PlanDelta(
         minutesDelta: 0,
         intensityDelta: 0,
         reasoning: 'Good work. Maintaining current targets.',
       );
    }
  }
}

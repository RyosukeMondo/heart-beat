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
    // Filter sessions within the week
    final weekSessions = sessions.where((s) =>
      s.start.isAfter(weekStart.subtract(const Duration(seconds: 1))) && 
      s.end.isBefore(weekEnd.add(const Duration(seconds: 1)))
    ).toList();

    int totalMinutesInZone = 0;
    double totalRpe = 0;
    int rpeCount = 0;

    for (var session in weekSessions) {
      totalMinutesInZone += session.minutesInZone;
      if (session.rpe != null) {
        totalRpe += session.rpe!;
        rpeCount++;
      }
    }

    double avgRpe = rpeCount > 0 ? totalRpe / rpeCount : 0;
    // We compare total minutes in zone against the total weekly target
    // If targetMinutes is daily, we assume 7 days or we take it as weekly target if passed as such.
    // Spec says: "compute completion % of planned minutes".
    double completionRate = targetMinutes > 0 ? totalMinutesInZone / targetMinutes : 0;

    // Requirement 4 Logic:
    // 2. IF completion ≥ target AND avg RPE < “Hard” (<=6/10) 
    //    THEN next week’s daily target SHALL increase by 10% (rounded to nearest minute) 
    //    and intensity band +2% HRR.
    // 3. IF completion < 70% OR avg RPE ≥ 8 
    //    THEN next week SHALL hold or reduce targets (no increase).

    if (completionRate >= 1.0 && avgRpe <= 6 && rpeCount > 0) {
       int increase = (targetMinutes * 0.10).round();
       if (increase < 1) increase = 1;
       
       return PlanDelta(
         minutesDelta: increase,
         intensityDelta: 2,
         reasoning: '目標達成おめでとうございます！次週は時間を10%増やし、強度を少し上げましょう。',
       );
    } else if (completionRate < 0.70) {
       return PlanDelta(
         minutesDelta: 0,
         intensityDelta: 0,
         reasoning: '今週は目標の70%に届きませんでした。次週は現在の目標を維持し、一貫性を重視しましょう。',
       );
    } else if (avgRpe >= 8) {
       return PlanDelta(
         minutesDelta: 0,
         intensityDelta: -2,
         reasoning: '強度がかなり高かったようです。次週は時間を維持しつつ、強度を少し下げて調整しましょう。',
       );
    } else {
       return PlanDelta(
         minutesDelta: 0,
         intensityDelta: 0,
         reasoning: '順調です。次週も現在の目標を継続して、ベースを固めていきましょう。',
       );
    }
  }
}

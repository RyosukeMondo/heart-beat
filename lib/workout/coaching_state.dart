enum ZoneCue { up, keep, down }
enum SessionStatus { idle, running, paused }

class CoachingState {
  final int currentBpm;
  final int dailyMinutes; // Cumulative for the day
  final int sessionMinutes; // Current session only
  final int targetMinutes; // Daily target
  final int targetLowerBpm;
  final int targetUpperBpm;
  final ZoneCue cue;
  final SessionStatus status;
  final bool reconnecting;
  final bool hasGaps;
  final Duration lastSampleAgo;
  final DateTime? sessionStartTime;
  final DateTime? sessionEndTime;

  // Session metrics
  final int maxBpm;
  final int totalBpmSum;
  final int totalSamples;

  const CoachingState({
    required this.currentBpm,
    required this.dailyMinutes,
    required this.sessionMinutes,
    required this.targetMinutes,
    required this.targetLowerBpm,
    required this.targetUpperBpm,
    required this.cue,
    required this.status,
    required this.reconnecting,
    this.hasGaps = false,
    required this.lastSampleAgo,
    this.sessionStartTime,
    this.sessionEndTime,
    required this.maxBpm,
    required this.totalBpmSum,
    required this.totalSamples,
  });

  factory CoachingState.initial() {
    return const CoachingState(
      currentBpm: 0,
      dailyMinutes: 0,
      sessionMinutes: 0,
      targetMinutes: 30,
      targetLowerBpm: 120,
      targetUpperBpm: 150,
      cue: ZoneCue.keep,
      status: SessionStatus.idle,
      reconnecting: false,
      hasGaps: false,
      lastSampleAgo: Duration.zero,
      maxBpm: 0,
      totalBpmSum: 0,
      totalSamples: 0,
    );
  }

  // For backwards compatibility with logic that checked paused
  bool get paused => status == SessionStatus.paused;

  int get avgBpm => totalSamples > 0 ? (totalBpmSum / totalSamples).round() : 0;

  int get achievedMinutes => dailyMinutes;

  CoachingState copyWith({
    int? currentBpm,
    int? dailyMinutes,
    int? sessionMinutes,
    int? targetMinutes,
    int? targetLowerBpm,
    int? targetUpperBpm,
    ZoneCue? cue,
    SessionStatus? status,
    bool? reconnecting,
    bool? hasGaps,
    Duration? lastSampleAgo,
    DateTime? sessionStartTime,
    DateTime? sessionEndTime,
    int? maxBpm,
    int? totalBpmSum,
    int? totalSamples,
  }) {
    return CoachingState(
      currentBpm: currentBpm ?? this.currentBpm,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      targetLowerBpm: targetLowerBpm ?? this.targetLowerBpm,
      targetUpperBpm: targetUpperBpm ?? this.targetUpperBpm,
      cue: cue ?? this.cue,
      status: status ?? this.status,
      reconnecting: reconnecting ?? this.reconnecting,
      hasGaps: hasGaps ?? this.hasGaps,
      lastSampleAgo: lastSampleAgo ?? this.lastSampleAgo,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      sessionEndTime: sessionEndTime ?? this.sessionEndTime,
      maxBpm: maxBpm ?? this.maxBpm,
      totalBpmSum: totalBpmSum ?? this.totalBpmSum,
      totalSamples: totalSamples ?? this.totalSamples,
    );
  }
}

import 'player_data.dart';
import 'game_session.dart';

/// Individual player's score and performance metrics for a completed game
class PlayerScore {
  /// Player identifier
  final String playerId;
  
  /// Player's display username
  final String username;
  
  /// Final score for the game
  final double score;
  
  /// Player's final ranking (1st, 2nd, etc.)
  final int rank;
  
  /// Average heart rate during the game
  final double averageHeartRate;
  
  /// Maximum heart rate reached during the game
  final int maxHeartRate;
  
  /// Minimum heart rate during the game
  final int minHeartRate;
  
  /// Percentage of time spent in target zone
  final double targetZonePercentage;
  
  /// Heart rate variability score
  final double variabilityScore;
  
  /// Game-specific performance metrics
  final Map<String, dynamic> performanceMetrics;
  
  /// Whether the player completed the full game
  final bool didComplete;
  
  /// Reason for elimination (if applicable)
  final String? eliminationReason;

  const PlayerScore({
    required this.playerId,
    required this.username,
    required this.score,
    required this.rank,
    required this.averageHeartRate,
    required this.maxHeartRate,
    required this.minHeartRate,
    required this.targetZonePercentage,
    required this.variabilityScore,
    this.performanceMetrics = const {},
    this.didComplete = true,
    this.eliminationReason,
  });

  /// Create PlayerScore from JSON map
  factory PlayerScore.fromJson(Map<String, dynamic> json) {
    return PlayerScore(
      playerId: json['playerId'] as String,
      username: json['username'] as String,
      score: (json['score'] as num).toDouble(),
      rank: json['rank'] as int,
      averageHeartRate: (json['averageHeartRate'] as num).toDouble(),
      maxHeartRate: json['maxHeartRate'] as int,
      minHeartRate: json['minHeartRate'] as int,
      targetZonePercentage: (json['targetZonePercentage'] as num).toDouble(),
      variabilityScore: (json['variabilityScore'] as num).toDouble(),
      performanceMetrics: Map<String, dynamic>.from(
        json['performanceMetrics'] as Map? ?? {},
      ),
      didComplete: json['didComplete'] as bool? ?? true,
      eliminationReason: json['eliminationReason'] as String?,
    );
  }

  /// Convert PlayerScore to JSON map
  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'username': username,
      'score': score,
      'rank': rank,
      'averageHeartRate': averageHeartRate,
      'maxHeartRate': maxHeartRate,
      'minHeartRate': minHeartRate,
      'targetZonePercentage': targetZonePercentage,
      'variabilityScore': variabilityScore,
      'performanceMetrics': performanceMetrics,
      'didComplete': didComplete,
      'eliminationReason': eliminationReason,
    };
  }

  /// Create a copy with updated values
  PlayerScore copyWith({
    String? playerId,
    String? username,
    double? score,
    int? rank,
    double? averageHeartRate,
    int? maxHeartRate,
    int? minHeartRate,
    double? targetZonePercentage,
    double? variabilityScore,
    Map<String, dynamic>? performanceMetrics,
    bool? didComplete,
    String? eliminationReason,
  }) {
    return PlayerScore(
      playerId: playerId ?? this.playerId,
      username: username ?? this.username,
      score: score ?? this.score,
      rank: rank ?? this.rank,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      minHeartRate: minHeartRate ?? this.minHeartRate,
      targetZonePercentage: targetZonePercentage ?? this.targetZonePercentage,
      variabilityScore: variabilityScore ?? this.variabilityScore,
      performanceMetrics: performanceMetrics ?? this.performanceMetrics,
      didComplete: didComplete ?? this.didComplete,
      eliminationReason: eliminationReason ?? this.eliminationReason,
    );
  }

  /// Get heart rate range during the game
  int get heartRateRange => maxHeartRate - minHeartRate;
  
  /// Check if player won the game
  bool get isWinner => rank == 1;
  
  /// Get performance grade based on score and metrics
  GamePerformanceGrade get performanceGrade {
    // Calculate composite performance score (0-100)
    final normalizedScore = score / 1000; // Assuming max score ~1000
    final zoneBonus = targetZonePercentage;
    final variabilityBonus = (100 - variabilityScore) / 100; // Lower variability is better
    
    final composite = (normalizedScore + zoneBonus + variabilityBonus) / 3 * 100;
    
    if (composite >= 90) return GamePerformanceGrade.excellent;
    if (composite >= 80) return GamePerformanceGrade.good;
    if (composite >= 70) return GamePerformanceGrade.average;
    if (composite >= 60) return GamePerformanceGrade.belowAverage;
    return GamePerformanceGrade.poor;
  }

  /// Get rank suffix for display (1st, 2nd, 3rd, etc.)
  String get rankSuffix {
    switch (rank % 10) {
      case 1:
        return rank % 100 == 11 ? '${rank}th' : '${rank}st';
      case 2:
        return rank % 100 == 12 ? '${rank}th' : '${rank}nd';
      case 3:
        return rank % 100 == 13 ? '${rank}th' : '${rank}rd';
      default:
        return '${rank}th';
    }
  }

  @override
  String toString() {
    return 'PlayerScore(player: $username, score: $score, rank: $rank)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerScore &&
        other.playerId == playerId &&
        other.score == score &&
        other.rank == rank;
  }

  @override
  int get hashCode => Object.hash(playerId, score, rank);
}

/// Complete results for a finished competitive game session
class GameResult {
  /// Session ID this result belongs to
  final String sessionId;
  
  /// Type of game that was played
  final GameType gameType;
  
  /// All player scores sorted by rank
  final List<PlayerScore> scores;
  
  /// The winning player's score
  final PlayerScore winner;
  
  /// Actual duration the game was active
  final Duration gameDuration;
  
  /// When the game was completed
  final DateTime completedAt;
  
  /// Game configuration that was used
  final GameConfig gameConfig;
  
  /// Aggregate game metrics and statistics
  final Map<String, dynamic> gameMetrics;
  
  /// Whether the game was completed normally or ended early
  final bool wasCompleted;
  
  /// Reason for early termination (if applicable)
  final String? terminationReason;

  const GameResult({
    required this.sessionId,
    required this.gameType,
    required this.scores,
    required this.winner,
    required this.gameDuration,
    required this.completedAt,
    required this.gameConfig,
    this.gameMetrics = const {},
    this.wasCompleted = true,
    this.terminationReason,
  });

  /// Create GameResult from JSON map
  factory GameResult.fromJson(Map<String, dynamic> json) {
    final scoresList = (json['scores'] as List)
        .map((s) => PlayerScore.fromJson(s as Map<String, dynamic>))
        .toList();
    
    return GameResult(
      sessionId: json['sessionId'] as String,
      gameType: GameType.values.byName(json['gameType'] as String),
      scores: scoresList,
      winner: PlayerScore.fromJson(json['winner'] as Map<String, dynamic>),
      gameDuration: Duration(milliseconds: json['gameDurationMs'] as int),
      completedAt: DateTime.parse(json['completedAt'] as String),
      gameConfig: GameConfig.fromJson(json['gameConfig'] as Map<String, dynamic>),
      gameMetrics: Map<String, dynamic>.from(json['gameMetrics'] as Map? ?? {}),
      wasCompleted: json['wasCompleted'] as bool? ?? true,
      terminationReason: json['terminationReason'] as String?,
    );
  }

  /// Convert GameResult to JSON map
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'gameType': gameType.name,
      'scores': scores.map((s) => s.toJson()).toList(),
      'winner': winner.toJson(),
      'gameDurationMs': gameDuration.inMilliseconds,
      'completedAt': completedAt.toIso8601String(),
      'gameConfig': gameConfig.toJson(),
      'gameMetrics': gameMetrics,
      'wasCompleted': wasCompleted,
      'terminationReason': terminationReason,
    };
  }

  /// Create a copy with updated values
  GameResult copyWith({
    String? sessionId,
    GameType? gameType,
    List<PlayerScore>? scores,
    PlayerScore? winner,
    Duration? gameDuration,
    DateTime? completedAt,
    GameConfig? gameConfig,
    Map<String, dynamic>? gameMetrics,
    bool? wasCompleted,
    String? terminationReason,
  }) {
    return GameResult(
      sessionId: sessionId ?? this.sessionId,
      gameType: gameType ?? this.gameType,
      scores: scores ?? this.scores,
      winner: winner ?? this.winner,
      gameDuration: gameDuration ?? this.gameDuration,
      completedAt: completedAt ?? this.completedAt,
      gameConfig: gameConfig ?? this.gameConfig,
      gameMetrics: gameMetrics ?? this.gameMetrics,
      wasCompleted: wasCompleted ?? this.wasCompleted,
      terminationReason: terminationReason ?? this.terminationReason,
    );
  }

  /// Get number of players who participated
  int get playerCount => scores.length;
  
  /// Get players who completed the full game
  List<PlayerScore> get completedPlayers => 
      scores.where((s) => s.didComplete).toList();
  
  /// Get players who were eliminated
  List<PlayerScore> get eliminatedPlayers => 
      scores.where((s) => !s.didComplete).toList();
  
  /// Get average score across all players
  double get averageScore {
    if (scores.isEmpty) return 0.0;
    return scores.map((s) => s.score).reduce((a, b) => a + b) / scores.length;
  }
  
  /// Get average heart rate across all players
  double get averageHeartRate {
    if (scores.isEmpty) return 0.0;
    return scores.map((s) => s.averageHeartRate).reduce((a, b) => a + b) / scores.length;
  }
  
  /// Get the score difference between winner and second place
  double get winMargin {
    if (scores.length < 2) return 0.0;
    return scores[0].score - scores[1].score;
  }
  
  /// Check if the game was competitive (close scores)
  bool get wasCompetitive => winMargin <= (averageScore * 0.1); // Within 10%
  
  /// Get formatted duration string
  String get durationText {
    final minutes = gameDuration.inMinutes;
    final seconds = gameDuration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  /// Get leaderboard sorted by rank
  List<PlayerScore> get leaderboard => List.from(scores)
    ..sort((a, b) => a.rank.compareTo(b.rank));

  /// Get player score by ID
  PlayerScore? getPlayerScore(String playerId) {
    try {
      return scores.firstWhere((s) => s.playerId == playerId);
    } catch (e) {
      return null;
    }
  }

  /// Get game summary statistics
  GameSummary get summary {
    return GameSummary(
      gameType: gameType,
      playerCount: playerCount,
      completionRate: completedPlayers.length / playerCount,
      averageScore: averageScore,
      winnerScore: winner.score,
      gameDuration: gameDuration,
      wasCompetitive: wasCompetitive,
    );
  }

  @override
  String toString() {
    return 'GameResult(session: $sessionId, type: $gameType, '
           'players: $playerCount, winner: ${winner.username})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameResult &&
        other.sessionId == sessionId &&
        other.completedAt == completedAt;
  }

  @override
  int get hashCode => Object.hash(sessionId, completedAt);
}

/// Performance grades for player evaluation
enum GamePerformanceGrade {
  excellent(5, 'Excellent', 0xFF4CAF50),
  good(4, 'Good', 0xFF8BC34A),
  average(3, 'Average', 0xFFFFEB3B),
  belowAverage(2, 'Below Average', 0xFFFF9800),
  poor(1, 'Poor', 0xFFF44336);

  const GamePerformanceGrade(this.level, this.displayName, this.colorCode);

  final int level;
  final String displayName;
  final int colorCode;
}

/// Game summary statistics
class GameSummary {
  final GameType gameType;
  final int playerCount;
  final double completionRate;
  final double averageScore;
  final double winnerScore;
  final Duration gameDuration;
  final bool wasCompetitive;

  const GameSummary({
    required this.gameType,
    required this.playerCount,
    required this.completionRate,
    required this.averageScore,
    required this.winnerScore,
    required this.gameDuration,
    required this.wasCompetitive,
  });

  /// Get completion percentage as formatted string
  String get completionPercentage => '${(completionRate * 100).toStringAsFixed(1)}%';
  
  /// Get competitiveness rating
  String get competitivenessRating => wasCompetitive ? 'High' : 'Low';
}

/// Extension methods for GamePerformanceGrade
extension GamePerformanceGradeExtension on GamePerformanceGrade {
  /// Get motivational message for the grade
  String get motivationalMessage {
    switch (this) {
      case GamePerformanceGrade.excellent:
        return 'Outstanding performance! Your cardiovascular control is exceptional.';
      case GamePerformanceGrade.good:
        return 'Great job! You showed excellent heart rate management.';
      case GamePerformanceGrade.average:
        return 'Good effort! Keep training to improve your cardiovascular response.';
      case GamePerformanceGrade.belowAverage:
        return 'Keep practicing! Focus on maintaining steady heart rate patterns.';
      case GamePerformanceGrade.poor:
        return 'Don\'t give up! Every session helps build better heart rate control.';
    }
  }

  /// Get improvement suggestion
  String get improvementSuggestion {
    switch (this) {
      case GamePerformanceGrade.excellent:
        return 'Try increasing difficulty for a greater challenge.';
      case GamePerformanceGrade.good:
        return 'Focus on consistency across longer game sessions.';
      case GamePerformanceGrade.average:
        return 'Work on maintaining target heart rate zones.';
      case GamePerformanceGrade.belowAverage:
        return 'Practice breathing techniques and steady pacing.';
      case GamePerformanceGrade.poor:
        return 'Start with easier difficulty and build up gradually.';
    }
  }
}
import 'player_data.dart';

/// Game types for competitive heart rate challenges
enum GameType {
  /// 瞬発力 (instant response) - cardiovascular reactivity challenges
  instantResponse,
  /// Resilience - heart rate stability under varying conditions  
  resilience,
  /// Endurance - sustained heart rate performance over time
  endurance,
}

/// Current state of a game session
enum GameState {
  /// Session created, waiting for players
  lobby,
  /// Players ready, waiting for host to start
  ready,
  /// Game countdown in progress
  countdown,
  /// Game actively running
  active,
  /// Game paused (e.g., due to connection issues)
  paused,
  /// Game completed, showing results
  completed,
  /// Game cancelled or error occurred
  cancelled,
}

/// Multiplayer gaming session for competitive heart rate challenges
/// 
/// Manages the lifecycle and state of competitive gaming sessions
/// including player management, game configuration, and session coordination.
class GameSession {
  /// Unique session identifier
  final String id;
  
  /// ID of the player who created the session
  final String hostId;
  
  /// List of player IDs currently in the session
  final List<String> playerIds;
  
  /// Type of competitive game
  final GameType gameType;
  
  /// Current state of the session
  final GameState state;
  
  /// When the session was created
  final DateTime createdAt;
  
  /// Game configuration settings
  final GameConfig config;
  
  /// Maximum number of players allowed
  final int maxPlayers;
  
  /// Whether the session is public or private
  final bool isPublic;
  
  /// Optional session name/description
  final String? sessionName;
  
  /// Current round number (for multi-round games)
  final int currentRound;
  
  /// Total number of rounds configured
  final int totalRounds;
  
  /// When the current game started (null if not active)
  final DateTime? gameStartTime;
  
  /// Session join code for private sessions
  final String? joinCode;

  const GameSession({
    required this.id,
    required this.hostId,
    required this.playerIds,
    required this.gameType,
    required this.state,
    required this.createdAt,
    required this.config,
    this.maxPlayers = 8,
    this.isPublic = false,
    this.sessionName,
    this.currentRound = 0,
    this.totalRounds = 1,
    this.gameStartTime,
    this.joinCode,
  });

  /// Create GameSession from JSON map
  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: json['id'] as String,
      hostId: json['hostId'] as String,
      playerIds: List<String>.from(json['playerIds'] as List),
      gameType: GameType.values.byName(json['gameType'] as String),
      state: GameState.values.byName(json['state'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      config: GameConfig.fromJson(json['config'] as Map<String, dynamic>),
      maxPlayers: json['maxPlayers'] as int? ?? 8,
      isPublic: json['isPublic'] as bool? ?? false,
      sessionName: json['sessionName'] as String?,
      currentRound: json['currentRound'] as int? ?? 0,
      totalRounds: json['totalRounds'] as int? ?? 1,
      gameStartTime: json['gameStartTime'] != null 
          ? DateTime.parse(json['gameStartTime'] as String)
          : null,
      joinCode: json['joinCode'] as String?,
    );
  }

  /// Convert GameSession to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostId': hostId,
      'playerIds': playerIds,
      'gameType': gameType.name,
      'state': state.name,
      'createdAt': createdAt.toIso8601String(),
      'config': config.toJson(),
      'maxPlayers': maxPlayers,
      'isPublic': isPublic,
      'sessionName': sessionName,
      'currentRound': currentRound,
      'totalRounds': totalRounds,
      'gameStartTime': gameStartTime?.toIso8601String(),
      'joinCode': joinCode,
    };
  }

  /// Create a copy with updated values
  GameSession copyWith({
    String? id,
    String? hostId,
    List<String>? playerIds,
    GameType? gameType,
    GameState? state,
    DateTime? createdAt,
    GameConfig? config,
    int? maxPlayers,
    bool? isPublic,
    String? sessionName,
    int? currentRound,
    int? totalRounds,
    DateTime? gameStartTime,
    String? joinCode,
  }) {
    return GameSession(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      playerIds: playerIds ?? this.playerIds,
      gameType: gameType ?? this.gameType,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      config: config ?? this.config,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      isPublic: isPublic ?? this.isPublic,
      sessionName: sessionName ?? this.sessionName,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      gameStartTime: gameStartTime ?? this.gameStartTime,
      joinCode: joinCode ?? this.joinCode,
    );
  }

  /// Get number of players currently in session
  int get playerCount => playerIds.length;
  
  /// Check if session is full
  bool get isFull => playerCount >= maxPlayers;
  
  /// Check if session can accept new players
  bool get canJoin => !isFull && state == GameState.lobby;
  
  /// Check if game is currently active
  bool get isGameActive => state == GameState.active;
  
  /// Check if game is finished
  bool get isCompleted => state == GameState.completed || state == GameState.cancelled;
  
  /// Get session duration since creation
  Duration get sessionDuration => DateTime.now().difference(createdAt);
  
  /// Get current game duration (null if not active)
  Duration? get gameDuration {
    if (gameStartTime == null) return null;
    return DateTime.now().difference(gameStartTime!);
  }
  
  /// Check if player is the host
  bool isHost(String playerId) => playerId == hostId;
  
  /// Check if player is in the session
  bool hasPlayer(String playerId) => playerIds.contains(playerId);

  /// Get display name for the session
  String get displayName {
    return sessionName ?? '${gameType.displayName} Game ${id.substring(0, 6)}';
  }

  @override
  String toString() {
    return 'GameSession(id: $id, type: $gameType, state: $state, '
           'players: $playerCount/$maxPlayers)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameSession &&
        other.id == id &&
        other.hostId == hostId &&
        other.gameType == gameType &&
        other.state == state &&
        other.createdAt == createdAt &&
        other.config == config;
  }

  @override
  int get hashCode => Object.hash(id, hostId, gameType, state, createdAt, config);
}

/// Configuration settings for competitive games
class GameConfig {
  /// Game duration in seconds
  final int durationSeconds;
  
  /// Minimum heart rate threshold for participation
  final int minHeartRate;
  
  /// Maximum heart rate threshold for safety
  final int maxHeartRate;
  
  /// Target heart rate zone for optimal performance
  final HeartRateZone targetZone;
  
  /// Difficulty level (1-5)
  final int difficultyLevel;
  
  /// Whether to allow spectators
  final bool allowSpectators;
  
  /// Custom game parameters specific to game type
  final Map<String, dynamic> customParams;
  
  /// Scoring multiplier for this configuration
  final double scoreMultiplier;

  const GameConfig({
    required this.durationSeconds,
    this.minHeartRate = 60,
    this.maxHeartRate = 180,
    this.targetZone = HeartRateZone.aerobic,
    this.difficultyLevel = 3,
    this.allowSpectators = true,
    this.customParams = const {},
    this.scoreMultiplier = 1.0,
  });

  /// Create default configuration for a game type
  factory GameConfig.defaultFor(GameType gameType) {
    switch (gameType) {
      case GameType.instantResponse:
        return const GameConfig(
          durationSeconds: 300, // 5 minutes
          targetZone: HeartRateZone.anaerobic,
          difficultyLevel: 4,
          customParams: {'stimulusCount': 10, 'responseWindow': 15},
        );
      case GameType.resilience:
        return const GameConfig(
          durationSeconds: 600, // 10 minutes
          targetZone: HeartRateZone.aerobic,
          difficultyLevel: 3,
          customParams: {'stabilityThreshold': 10, 'stressPhases': 3},
        );
      case GameType.endurance:
        return const GameConfig(
          durationSeconds: 900, // 15 minutes
          targetZone: HeartRateZone.fatBurn,
          difficultyLevel: 2,
          customParams: {'zoneToleranceSeconds': 30},
        );
    }
  }

  /// Create GameConfig from JSON map
  factory GameConfig.fromJson(Map<String, dynamic> json) {
    return GameConfig(
      durationSeconds: json['durationSeconds'] as int,
      minHeartRate: json['minHeartRate'] as int? ?? 60,
      maxHeartRate: json['maxHeartRate'] as int? ?? 180,
      targetZone: HeartRateZone.values.byName(json['targetZone'] as String? ?? 'aerobic'),
      difficultyLevel: json['difficultyLevel'] as int? ?? 3,
      allowSpectators: json['allowSpectators'] as bool? ?? true,
      customParams: Map<String, dynamic>.from(json['customParams'] as Map? ?? {}),
      scoreMultiplier: (json['scoreMultiplier'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Convert GameConfig to JSON map
  Map<String, dynamic> toJson() {
    return {
      'durationSeconds': durationSeconds,
      'minHeartRate': minHeartRate,
      'maxHeartRate': maxHeartRate,
      'targetZone': targetZone.name,
      'difficultyLevel': difficultyLevel,
      'allowSpectators': allowSpectators,
      'customParams': customParams,
      'scoreMultiplier': scoreMultiplier,
    };
  }

  /// Create a copy with updated values
  GameConfig copyWith({
    int? durationSeconds,
    int? minHeartRate,
    int? maxHeartRate,
    HeartRateZone? targetZone,
    int? difficultyLevel,
    bool? allowSpectators,
    Map<String, dynamic>? customParams,
    double? scoreMultiplier,
  }) {
    return GameConfig(
      durationSeconds: durationSeconds ?? this.durationSeconds,
      minHeartRate: minHeartRate ?? this.minHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      targetZone: targetZone ?? this.targetZone,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
      allowSpectators: allowSpectators ?? this.allowSpectators,
      customParams: customParams ?? this.customParams,
      scoreMultiplier: scoreMultiplier ?? this.scoreMultiplier,
    );
  }

  /// Get formatted duration string
  String get durationText {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (seconds == 0) {
      return '${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }

  /// Get difficulty description
  String get difficultyDescription {
    switch (difficultyLevel) {
      case 1: return 'Very Easy';
      case 2: return 'Easy';
      case 3: return 'Medium';
      case 4: return 'Hard';
      case 5: return 'Very Hard';
      default: return 'Medium';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameConfig &&
        other.durationSeconds == durationSeconds &&
        other.minHeartRate == minHeartRate &&
        other.maxHeartRate == maxHeartRate &&
        other.targetZone == targetZone &&
        other.difficultyLevel == difficultyLevel &&
        other.allowSpectators == allowSpectators &&
        other.scoreMultiplier == scoreMultiplier;
  }

  @override
  int get hashCode => Object.hash(
    durationSeconds, minHeartRate, maxHeartRate, targetZone,
    difficultyLevel, allowSpectators, scoreMultiplier,
  );
}

/// Extension methods for GameType
extension GameTypeExtension on GameType {
  /// Get display name for UI
  String get displayName {
    switch (this) {
      case GameType.instantResponse:
        return 'Instant Response (瞬発力)';
      case GameType.resilience:
        return 'Resilience';
      case GameType.endurance:
        return 'Endurance';
    }
  }

  /// Get description of the game type
  String get description {
    switch (this) {
      case GameType.instantResponse:
        return 'Test cardiovascular reactivity with rapid heart rate response challenges';
      case GameType.resilience:
        return 'Maintain stable heart rate under varying stress conditions';
      case GameType.endurance:
        return 'Sustain target heart rate zones over extended periods';
    }
  }

  /// Get icon code for UI display
  int get iconCode {
    switch (this) {
      case GameType.instantResponse:
        return 0xe9f1; // Icons.flash_on
      case GameType.resilience:
        return 0xe0e2; // Icons.shield
      case GameType.endurance:
        return 0xe52f; // Icons.timer
    }
  }

  /// Get primary color for UI theming
  int get colorCode {
    switch (this) {
      case GameType.instantResponse:
        return 0xFFFF5722; // Deep Orange
      case GameType.resilience:
        return 0xFF3F51B5; // Indigo
      case GameType.endurance:
        return 0xFF4CAF50; // Green
    }
  }
}

/// Extension methods for GameState
extension GameStateExtension on GameState {
  /// Check if players can join the session
  bool get allowsJoining => this == GameState.lobby;
  
  /// Check if the game is in progress
  bool get isInProgress => this == GameState.active || this == GameState.paused;
  
  /// Check if the session has ended
  bool get hasEnded => this == GameState.completed || this == GameState.cancelled;

  /// Get display text for UI
  String get displayText {
    switch (this) {
      case GameState.lobby:
        return 'Waiting for Players';
      case GameState.ready:
        return 'Ready to Start';
      case GameState.countdown:
        return 'Starting...';
      case GameState.active:
        return 'Game Active';
      case GameState.paused:
        return 'Paused';
      case GameState.completed:
        return 'Completed';
      case GameState.cancelled:
        return 'Cancelled';
    }
  }

  /// Get status color for UI display
  int get colorCode {
    switch (this) {
      case GameState.lobby:
        return 0xFF9E9E9E; // Grey
      case GameState.ready:
        return 0xFFFF9800; // Orange
      case GameState.countdown:
        return 0xFFFFEB3B; // Yellow
      case GameState.active:
        return 0xFF4CAF50; // Green
      case GameState.paused:
        return 0xFF2196F3; // Blue
      case GameState.completed:
        return 0xFF8BC34A; // Light Green
      case GameState.cancelled:
        return 0xFFF44336; // Red
    }
  }
}
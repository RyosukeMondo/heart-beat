/// Competitive gaming data models for multiplayer heart rate competitions
/// 
/// Follows the established patterns from lib/ble/ble_types.dart with:
/// - Comprehensive data validation and error handling
/// - JSON serialization for network transmission
/// - Extension methods for enhanced functionality
/// - Immutable classes with copyWith methods

/// Player status during competitive sessions
enum PlayerStatus {
  /// Player is connected and ready to participate
  ready,
  /// Player is actively participating in a game
  playing,
  /// Player is temporarily disconnected but may reconnect
  disconnected,
  /// Player has been eliminated from the current game
  eliminated,
  /// Player has left the session permanently
  left,
}

/// Real-time player data for competitive gaming sessions
/// 
/// Contains all information needed to display and process player state
/// during multiplayer heart rate gaming sessions.
class PlayerData {
  /// Unique player identifier
  final String id;
  
  /// Player's display username
  final String username;
  
  /// Most recent heart rate reading in BPM
  final int currentHeartRate;
  
  /// Timestamp of the last heart rate update
  final DateTime lastUpdate;
  
  /// Current connection status
  final bool isConnected;
  
  /// Player's current status in the session
  final PlayerStatus status;
  
  /// Player's current score in the active game (if any)
  final double currentScore;
  
  /// Network latency in milliseconds for real-time sync
  final int latencyMs;
  
  /// Player's display color for UI differentiation
  final int colorCode;
  
  /// Whether the player is the session host
  final bool isHost;

  const PlayerData({
    required this.id,
    required this.username,
    required this.currentHeartRate,
    required this.lastUpdate,
    required this.isConnected,
    required this.status,
    this.currentScore = 0.0,
    this.latencyMs = 0,
    this.colorCode = 0xFF2196F3, // Default blue
    this.isHost = false,
  });

  /// Create PlayerData from JSON map
  factory PlayerData.fromJson(Map<String, dynamic> json) {
    return PlayerData(
      id: json['id'] as String,
      username: json['username'] as String,
      currentHeartRate: json['currentHeartRate'] as int,
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
      isConnected: json['isConnected'] as bool,
      status: PlayerStatus.values.byName(json['status'] as String),
      currentScore: (json['currentScore'] as num?)?.toDouble() ?? 0.0,
      latencyMs: json['latencyMs'] as int? ?? 0,
      colorCode: json['colorCode'] as int? ?? 0xFF2196F3,
      isHost: json['isHost'] as bool? ?? false,
    );
  }

  /// Convert PlayerData to JSON map for network transmission
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'currentHeartRate': currentHeartRate,
      'lastUpdate': lastUpdate.toIso8601String(),
      'isConnected': isConnected,
      'status': status.name,
      'currentScore': currentScore,
      'latencyMs': latencyMs,
      'colorCode': colorCode,
      'isHost': isHost,
    };
  }

  /// Create a copy with updated values
  PlayerData copyWith({
    String? id,
    String? username,
    int? currentHeartRate,
    DateTime? lastUpdate,
    bool? isConnected,
    PlayerStatus? status,
    double? currentScore,
    int? latencyMs,
    int? colorCode,
    bool? isHost,
  }) {
    return PlayerData(
      id: id ?? this.id,
      username: username ?? this.username,
      currentHeartRate: currentHeartRate ?? this.currentHeartRate,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      isConnected: isConnected ?? this.isConnected,
      status: status ?? this.status,
      currentScore: currentScore ?? this.currentScore,
      latencyMs: latencyMs ?? this.latencyMs,
      colorCode: colorCode ?? this.colorCode,
      isHost: isHost ?? this.isHost,
    );
  }

  /// Validate heart rate data
  bool get hasValidHeartRate => 
      currentHeartRate >= 30 && currentHeartRate <= 250;

  /// Check if data is recent (within last 30 seconds)
  bool get isDataRecent {
    final now = DateTime.now();
    return now.difference(lastUpdate).inSeconds <= 30;
  }

  /// Get heart rate zone based on age (estimated max HR = 220 - age)
  HeartRateZone getHeartRateZone(int age) {
    if (!hasValidHeartRate) return HeartRateZone.invalid;
    
    final maxHR = 220 - age;
    final percentage = currentHeartRate / maxHR;
    
    if (percentage < 0.50) return HeartRateZone.recovery;
    if (percentage < 0.60) return HeartRateZone.fatBurn;
    if (percentage < 0.70) return HeartRateZone.aerobic;
    if (percentage < 0.80) return HeartRateZone.anaerobic;
    if (percentage < 0.90) return HeartRateZone.neuromuscular;
    return HeartRateZone.maximum;
  }

  @override
  String toString() {
    return 'PlayerData(id: $id, username: $username, hr: $currentHeartRate, '
           'status: $status, score: $currentScore)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerData &&
        other.id == id &&
        other.username == username &&
        other.currentHeartRate == currentHeartRate &&
        other.lastUpdate == lastUpdate &&
        other.isConnected == isConnected &&
        other.status == status &&
        other.currentScore == currentScore &&
        other.latencyMs == latencyMs &&
        other.colorCode == colorCode &&
        other.isHost == isHost;
  }

  @override
  int get hashCode => Object.hash(
    id, username, currentHeartRate, lastUpdate, isConnected,
    status, currentScore, latencyMs, colorCode, isHost,
  );
}

/// Heart rate zones for competitive analysis
enum HeartRateZone {
  invalid(0, 'Invalid', 0xFFBDBDBD),
  recovery(1, 'Recovery', 0xFF4CAF50),
  fatBurn(2, 'Fat Burn', 0xFF8BC34A),
  aerobic(3, 'Aerobic', 0xFFFFEB3B),
  anaerobic(4, 'Anaerobic', 0xFFFF9800),
  neuromuscular(5, 'Neuromuscular', 0xFFF44336),
  maximum(6, 'Maximum', 0xFF9C27B0);

  const HeartRateZone(this.level, this.name, this.colorCode);

  final int level;
  final String name;
  final int colorCode;
}

/// Extension methods for PlayerStatus
extension PlayerStatusExtension on PlayerStatus {
  /// Check if player can participate in games
  bool get canPlay => this == PlayerStatus.ready || this == PlayerStatus.playing;
  
  /// Check if player is actively in game
  bool get isActive => this == PlayerStatus.playing;
  
  /// Check if player is eliminated
  bool get isEliminated => this == PlayerStatus.eliminated;
  
  /// Check if player has left permanently
  bool get hasLeft => this == PlayerStatus.left;

  /// Get user-friendly display text
  String get displayText {
    switch (this) {
      case PlayerStatus.ready:
        return 'Ready';
      case PlayerStatus.playing:
        return 'Playing';
      case PlayerStatus.disconnected:
        return 'Disconnected';
      case PlayerStatus.eliminated:
        return 'Eliminated';
      case PlayerStatus.left:
        return 'Left';
    }
  }

  /// Get status color for UI display
  int get colorCode {
    switch (this) {
      case PlayerStatus.ready:
        return 0xFF4CAF50; // Green
      case PlayerStatus.playing:
        return 0xFF2196F3; // Blue
      case PlayerStatus.disconnected:
        return 0xFFFF9800; // Orange
      case PlayerStatus.eliminated:
        return 0xFFF44336; // Red
      case PlayerStatus.left:
        return 0xFF9E9E9E; // Grey
    }
  }

  /// Get status icon for UI display
  int get iconCode {
    switch (this) {
      case PlayerStatus.ready:
        return 0xe86c; // Icons.check_circle
      case PlayerStatus.playing:
        return 0xe40a; // Icons.sports_esports
      case PlayerStatus.disconnected:
        return 0xe1e6; // Icons.wifi_off
      case PlayerStatus.eliminated:
        return 0xe14c; // Icons.cancel
      case PlayerStatus.left:
        return 0xe879; // Icons.exit_to_app
    }
  }
}

/// Extension methods for HeartRateZone
extension HeartRateZoneExtension on HeartRateZone {
  /// Get zone description for competitive context
  String get competitiveDescription {
    switch (this) {
      case HeartRateZone.invalid:
        return 'Invalid reading';
      case HeartRateZone.recovery:
        return 'Recovery zone - very light effort';
      case HeartRateZone.fatBurn:
        return 'Fat burn zone - light effort';
      case HeartRateZone.aerobic:
        return 'Aerobic zone - moderate effort';
      case HeartRateZone.anaerobic:
        return 'Anaerobic zone - hard effort';
      case HeartRateZone.neuromuscular:
        return 'Neuromuscular zone - very hard effort';
      case HeartRateZone.maximum:
        return 'Maximum zone - peak effort';
    }
  }

  /// Get target percentage range for the zone
  String get percentageRange {
    switch (this) {
      case HeartRateZone.invalid:
        return 'N/A';
      case HeartRateZone.recovery:
        return '50-60%';
      case HeartRateZone.fatBurn:
        return '60-70%';
      case HeartRateZone.aerobic:
        return '70-80%';
      case HeartRateZone.anaerobic:
        return '80-90%';
      case HeartRateZone.neuromuscular:
        return '90-95%';
      case HeartRateZone.maximum:
        return '95-100%';
    }
  }

  /// Check if zone is suitable for competitive games
  bool get isSuitableForGaming {
    return this != HeartRateZone.invalid && 
           this != HeartRateZone.maximum; // Maximum zone may be unsafe
  }
}
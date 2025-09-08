class UserProfile {
  final String displayName;
  final String? bio;
  final int? age;
  final String? location;
  final DateTime? joinedDate;
  final int totalGamesPlayed;
  final int totalWins;
  final double winRate;

  const UserProfile({
    required this.displayName,
    this.bio,
    this.age,
    this.location,
    this.joinedDate,
    this.totalGamesPlayed = 0,
    this.totalWins = 0,
    this.winRate = 0.0,
  });

  /// Create UserProfile from JSON map
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      displayName: json['displayName'] as String,
      bio: json['bio'] as String?,
      age: json['age'] as int?,
      location: json['location'] as String?,
      joinedDate: json['joinedDate'] != null 
          ? DateTime.parse(json['joinedDate'] as String)
          : null,
      totalGamesPlayed: json['totalGamesPlayed'] as int? ?? 0,
      totalWins: json['totalWins'] as int? ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert UserProfile to JSON map
  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'bio': bio,
      'age': age,
      'location': location,
      'joinedDate': joinedDate?.toIso8601String(),
      'totalGamesPlayed': totalGamesPlayed,
      'totalWins': totalWins,
      'winRate': winRate,
    };
  }

  /// Create a copy of this profile with updated values
  UserProfile copyWith({
    String? displayName,
    String? bio,
    int? age,
    String? location,
    DateTime? joinedDate,
    int? totalGamesPlayed,
    int? totalWins,
    double? winRate,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      age: age ?? this.age,
      location: location ?? this.location,
      joinedDate: joinedDate ?? this.joinedDate,
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      totalWins: totalWins ?? this.totalWins,
      winRate: winRate ?? this.winRate,
    );
  }

  @override
  String toString() {
    return 'UserProfile(displayName: $displayName, totalGamesPlayed: $totalGamesPlayed, winRate: $winRate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.displayName == displayName &&
        other.bio == bio &&
        other.age == age &&
        other.location == location &&
        other.joinedDate == joinedDate &&
        other.totalGamesPlayed == totalGamesPlayed &&
        other.totalWins == totalWins &&
        other.winRate == winRate;
  }

  @override
  int get hashCode {
    return Object.hash(
      displayName,
      bio,
      age,
      location,
      joinedDate,
      totalGamesPlayed,
      totalWins,
      winRate,
    );
  }
}
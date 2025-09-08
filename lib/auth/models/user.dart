import 'user_profile.dart';

class User {
  final String id;
  final String email;
  final String username;
  final DateTime createdAt;
  final UserProfile profile;

  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.createdAt,
    required this.profile,
  });

  /// Create User from JSON map
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
    );
  }

  /// Convert User to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
      'profile': profile.toJson(),
    };
  }

  /// Create a copy of this user with updated values
  User copyWith({
    String? id,
    String? email,
    String? username,
    DateTime? createdAt,
    UserProfile? profile,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      profile: profile ?? this.profile,
    );
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    
    // Basic email regex pattern
    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    return emailRegExp.hasMatch(email) && email.length <= 254;
  }

  /// Validate username format
  static bool isValidUsername(String username) {
    if (username.isEmpty || username.length < 3 || username.length > 20) {
      return false;
    }
    
    // Username can contain letters, numbers, underscores, and hyphens
    // Must start with a letter or number
    final usernameRegExp = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]*$');
    
    return usernameRegExp.hasMatch(username);
  }

  /// Validate password strength
  static bool isValidPassword(String password) {
    if (password.length < 8) return false;
    
    // Check for at least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    
    // Check for at least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    
    // Check for at least one number
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    
    return true;
  }

  /// Get validation error messages for registration
  static List<String> getValidationErrors({
    required String email,
    required String username,
    required String password,
  }) {
    final errors = <String>[];
    
    if (!isValidEmail(email)) {
      errors.add('Please enter a valid email address');
    }
    
    if (!isValidUsername(username)) {
      if (username.isEmpty) {
        errors.add('Username is required');
      } else if (username.length < 3) {
        errors.add('Username must be at least 3 characters long');
      } else if (username.length > 20) {
        errors.add('Username must not exceed 20 characters');
      } else {
        errors.add('Username can only contain letters, numbers, underscores, and hyphens, and must start with a letter or number');
      }
    }
    
    if (!isValidPassword(password)) {
      if (password.length < 8) {
        errors.add('Password must be at least 8 characters long');
      } else {
        final requirements = <String>[];
        if (!password.contains(RegExp(r'[A-Z]'))) {
          requirements.add('one uppercase letter');
        }
        if (!password.contains(RegExp(r'[a-z]'))) {
          requirements.add('one lowercase letter');
        }
        if (!password.contains(RegExp(r'[0-9]'))) {
          requirements.add('one number');
        }
        if (requirements.isNotEmpty) {
          errors.add('Password must contain ${requirements.join(', ')}');
        }
      }
    }
    
    return errors;
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.username == username &&
        other.createdAt == createdAt &&
        other.profile == profile;
  }

  @override
  int get hashCode {
    return Object.hash(id, email, username, createdAt, profile);
  }
}
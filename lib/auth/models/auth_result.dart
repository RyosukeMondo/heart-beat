import 'user.dart';

enum AuthStatus {
  success,
  invalidCredentials,
  userNotFound,
  emailAlreadyExists,
  usernameAlreadyExists,
  weakPassword,
  invalidEmail,
  networkError,
  serverError,
  unknown,
}

class AuthResult {
  final AuthStatus status;
  final User? user;
  final String? token;
  final String? message;
  final Map<String, dynamic>? metadata;

  const AuthResult({
    required this.status,
    this.user,
    this.token,
    this.message,
    this.metadata,
  });

  /// Create a successful auth result
  factory AuthResult.success({
    required User user,
    String? token,
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    return AuthResult(
      status: AuthStatus.success,
      user: user,
      token: token,
      message: message,
      metadata: metadata,
    );
  }

  /// Create a failed auth result
  factory AuthResult.failure({
    required AuthStatus status,
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    return AuthResult(
      status: status,
      message: message,
      metadata: metadata,
    );
  }

  /// Create AuthResult from JSON map
  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      status: _parseAuthStatus(json['status'] as String?),
      user: json['user'] != null 
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      token: json['token'] as String?,
      message: json['message'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert AuthResult to JSON map
  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'user': user?.toJson(),
      'token': token,
      'message': message,
      'metadata': metadata,
    };
  }

  /// Parse AuthStatus from string
  static AuthStatus _parseAuthStatus(String? statusString) {
    if (statusString == null) return AuthStatus.unknown;
    
    for (final status in AuthStatus.values) {
      if (status.name == statusString) return status;
    }
    return AuthStatus.unknown;
  }

  /// Check if authentication was successful
  bool get isSuccess => status == AuthStatus.success;

  /// Check if authentication failed
  bool get isFailure => !isSuccess;

  /// Get user-friendly error message
  String get errorMessage {
    if (message != null) return message!;
    
    switch (status) {
      case AuthStatus.success:
        return 'Authentication successful';
      case AuthStatus.invalidCredentials:
        return 'Invalid email or password';
      case AuthStatus.userNotFound:
        return 'No account found with this email';
      case AuthStatus.emailAlreadyExists:
        return 'An account with this email already exists';
      case AuthStatus.usernameAlreadyExists:
        return 'This username is already taken';
      case AuthStatus.weakPassword:
        return 'Password does not meet security requirements';
      case AuthStatus.invalidEmail:
        return 'Please enter a valid email address';
      case AuthStatus.networkError:
        return 'Network connection error. Please check your internet connection';
      case AuthStatus.serverError:
        return 'Server error. Please try again later';
      case AuthStatus.unknown:
        return 'An unknown error occurred. Please try again';
    }
  }

  /// Create a copy of this result with updated values
  AuthResult copyWith({
    AuthStatus? status,
    User? user,
    String? token,
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    return AuthResult(
      status: status ?? this.status,
      user: user ?? this.user,
      token: token ?? this.token,
      message: message ?? this.message,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'AuthResult(status: $status, user: ${user?.username}, hasToken: ${token != null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthResult &&
        other.status == status &&
        other.user == user &&
        other.token == token &&
        other.message == message;
  }

  @override
  int get hashCode {
    return Object.hash(status, user, token, message);
  }
}
// Authentication service interface for user management across platforms.
// Uses factory pattern similar to BleService for platform-specific implementations.

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'models/models.dart';

// Conditional import of platform-specific implementation that provides createAuthService().
import 'auth_service_impl_mobile.dart'
    if (dart.library.html) 'auth_service_impl_web.dart' as impl;

/// Abstract authentication service interface for user management across platforms.
/// 
/// Provides a unified interface for user authentication operations on web, mobile, and desktop platforms.
/// Uses factory pattern for platform-specific implementations with different backend integrations.
abstract class AuthService {
  /// Factory constructor that returns platform-specific implementation
  factory AuthService() {
    return _createPlatformService();
  }

  /// Platform detection and service creation
  static AuthService _createPlatformService() {
    if (kIsWeb) {
      // Web platform - use Firebase Auth or similar web-based authentication
      return impl.createAuthService();
    } else {
      // Mobile/Desktop platform - use Firebase Auth, custom backend, or local storage
      return impl.createAuthService();
    }
  }

  /// Current authentication state stream
  /// 
  /// Emits the current user when authentication state changes.
  /// Emits null when the user is logged out or unauthenticated.
  Stream<User?> get userStream;

  /// Current authenticated user (null if not authenticated)
  User? get currentUser;

  /// Check if currently authenticated
  bool get isAuthenticated => currentUser != null;

  /// Current authentication token (null if not authenticated)
  String? get authToken;

  /// Check if authentication service is initialized
  bool get isInitialized;

  /// Initialize the authentication service
  /// 
  /// This method should be called before any other authentication operations.
  /// It handles platform-specific setup like API configuration, token validation, etc.
  Future<void> initialize();

  /// Register a new user account
  /// 
  /// Creates a new user account with the provided credentials and profile information.
  /// Returns [AuthResult] indicating success or failure with appropriate error details.
  /// 
  /// The method will:
  /// 1. Validate input parameters (email format, username availability, password strength)
  /// 2. Create user account on the authentication backend
  /// 3. Initialize user profile with default values
  /// 4. Return authentication result with user data and token
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
    String? displayName,
    Map<String, dynamic>? metadata,
  });

  /// Login with email and password
  /// 
  /// Authenticates user with provided credentials and establishes authenticated session.
  /// Returns [AuthResult] indicating success or failure with appropriate error details.
  /// 
  /// The method will:
  /// 1. Validate credentials against authentication backend
  /// 2. Establish authenticated session with token
  /// 3. Load user profile data
  /// 4. Return authentication result with user data and token
  Future<AuthResult> login({
    required String email,
    required String password,
    bool rememberMe = false,
  });

  /// Login with authentication token
  /// 
  /// Authenticates user using a previously stored authentication token.
  /// Useful for automatic login on app startup with saved credentials.
  Future<AuthResult> loginWithToken(String token);

  /// Logout current user
  /// 
  /// Clears current authentication session and user data.
  /// Safely logs out the user and cleans up resources.
  Future<void> logout();

  /// Refresh authentication token
  /// 
  /// Refreshes the current authentication token to extend session validity.
  /// Returns updated [AuthResult] with new token or failure status.
  Future<AuthResult> refreshToken();

  /// Update user profile information
  /// 
  /// Updates the current user's profile with new information.
  /// Returns [AuthResult] with updated user data or failure status.
  Future<AuthResult> updateProfile({
    String? displayName,
    String? bio,
    int? age,
    String? location,
  });

  /// Change user password
  /// 
  /// Updates the user's password after validating the current password.
  /// Returns [AuthResult] indicating success or failure.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Request password reset
  /// 
  /// Initiates password reset process for the given email address.
  /// Returns [AuthResult] indicating if reset request was sent successfully.
  Future<AuthResult> requestPasswordReset(String email);

  /// Verify email address
  /// 
  /// Sends email verification to the user's registered email address.
  /// Returns [AuthResult] indicating if verification email was sent.
  Future<AuthResult> sendEmailVerification();

  /// Check if email is already registered
  /// 
  /// Validates if an email address is already associated with an account.
  /// Useful for registration form validation.
  Future<bool> isEmailRegistered(String email);

  /// Check if username is available
  /// 
  /// Validates if a username is available for registration.
  /// Useful for registration form validation.
  Future<bool> isUsernameAvailable(String username);

  /// Delete user account
  /// 
  /// Permanently deletes the current user account and all associated data.
  /// Returns [AuthResult] indicating success or failure.
  /// This action cannot be undone.
  Future<AuthResult> deleteAccount();

  /// Get user statistics
  /// 
  /// Returns user's game statistics and profile metrics.
  /// Useful for displaying user achievements and progress.
  Future<Map<String, dynamic>> getUserStats();

  /// Dispose of all resources and cleanup
  /// 
  /// Should be called when the service is no longer needed.
  /// After calling dispose(), the service should not be used anymore.
  Future<void> dispose();
}

/// Exception thrown by authentication operations
class AuthException implements Exception {
  final AuthStatus status;
  final String message;
  final Exception? originalException;
  final Map<String, dynamic>? metadata;

  const AuthException(
    this.status, 
    this.message, 
    [this.originalException, this.metadata]
  );

  /// Create from AuthResult failure
  factory AuthException.fromResult(AuthResult result) {
    return AuthException(
      result.status,
      result.message ?? result.errorMessage,
      null,
      result.metadata,
    );
  }

  @override
  String toString() {
    final originalMsg = originalException != null 
        ? ' (${originalException.toString()})' 
        : '';
    return 'AuthException: $message$originalMsg';
  }

  /// Get localized error message for UI display
  String get localizedMessage {
    switch (status) {
      case AuthStatus.invalidCredentials:
        return 'Invalid email or password. Please check your credentials and try again.';
      case AuthStatus.userNotFound:
        return 'No account found with this email address.';
      case AuthStatus.emailAlreadyExists:
        return 'An account with this email already exists. Please use a different email or try logging in.';
      case AuthStatus.usernameAlreadyExists:
        return 'This username is already taken. Please choose a different username.';
      case AuthStatus.weakPassword:
        return 'Password is too weak. Please use at least 8 characters with uppercase, lowercase, and numbers.';
      case AuthStatus.invalidEmail:
        return 'Please enter a valid email address.';
      case AuthStatus.networkError:
        return 'Network connection error. Please check your internet connection and try again.';
      case AuthStatus.serverError:
        return 'Server error occurred. Please try again later.';
      case AuthStatus.success:
        return 'Operation completed successfully.';
      case AuthStatus.unknown:
        return message.isNotEmpty ? message : 'An unexpected error occurred. Please try again.';
    }
  }

  /// Check if this is a network-related error
  bool get isNetworkError => status == AuthStatus.networkError;

  /// Check if this is a user input validation error
  bool get isValidationError => [
    AuthStatus.invalidCredentials,
    AuthStatus.invalidEmail,
    AuthStatus.weakPassword,
  ].contains(status);

  /// Check if this error is recoverable (user can retry)
  bool get isRecoverable => ![
    AuthStatus.emailAlreadyExists,
    AuthStatus.usernameAlreadyExists,
  ].contains(status);
}

/// Mixin for common authentication service functionality
/// 
/// Provides common implementation patterns that can be shared across platforms
/// including user session management, token handling, and state management.
mixin AuthServiceMixin on AuthService {
  final StreamController<User?> _userController = 
      StreamController<User?>.broadcast();

  User? _currentUser;
  String? _authToken;
  bool _isInitialized = false;
  Timer? _tokenRefreshTimer;
  Timer? _sessionValidationTimer;

  // Token management
  static const Duration _tokenRefreshInterval = Duration(minutes: 50); // Refresh 10 min before expiry
  static const Duration _sessionValidationInterval = Duration(minutes: 5);

  @override
  Stream<User?> get userStream => _userController.stream;

  @override
  User? get currentUser => _currentUser;

  @override
  String? get authToken => _authToken;

  @override
  bool get isInitialized => _isInitialized;

  /// Update current user and notify listeners
  void updateCurrentUser(User? user) {
    if (_currentUser != user) {
      _currentUser = user;
      _userController.add(user);

      // Manage session based on user state
      if (user != null) {
        _startSessionManagement();
      } else {
        _stopSessionManagement();
      }
    }
  }

  /// Update authentication token
  void updateAuthToken(String? token) {
    _authToken = token;
    
    if (token != null) {
      _scheduleTokenRefresh();
    } else {
      _cancelTokenRefresh();
    }
  }

  /// Mark service as initialized
  void markAsInitialized() {
    _isInitialized = true;
  }

  /// Start automatic session management
  void _startSessionManagement() {
    _stopSessionManagement(); // Ensure no duplicates

    // Schedule automatic token refresh
    if (_authToken != null) {
      _scheduleTokenRefresh();
    }

    // Schedule session validation
    _sessionValidationTimer = Timer.periodic(_sessionValidationInterval, (timer) {
      _validateSession();
    });
  }

  /// Stop automatic session management
  void _stopSessionManagement() {
    _cancelTokenRefresh();
    _sessionValidationTimer?.cancel();
    _sessionValidationTimer = null;
  }

  /// Schedule automatic token refresh
  void _scheduleTokenRefresh() {
    _cancelTokenRefresh();
    
    _tokenRefreshTimer = Timer(_tokenRefreshInterval, () async {
      if (_currentUser != null && _authToken != null) {
        try {
          final result = await refreshToken();
          if (!result.isSuccess) {
            print('Auth: Automatic token refresh failed: ${result.errorMessage}');
            // If refresh fails, logout user
            await logout();
          }
        } catch (e) {
          print('Auth: Error during automatic token refresh: $e');
          await logout();
        }
      }
    });
  }

  /// Cancel automatic token refresh
  void _cancelTokenRefresh() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  /// Validate current session
  Future<void> _validateSession() async {
    if (_currentUser == null || _authToken == null) return;

    try {
      // This method can be overridden by implementations for platform-specific validation
      final isValid = await validateCurrentSession();
      if (!isValid) {
        print('Auth: Session validation failed, logging out user');
        await logout();
      }
    } catch (e) {
      print('Auth: Error during session validation: $e');
    }
  }

  /// Validate current session - override in implementations
  Future<bool> validateCurrentSession() async {
    // Default implementation - override in platform-specific services
    return _currentUser != null && _authToken != null;
  }

  /// Clear all authentication state
  void clearAuthState() {
    _currentUser = null;
    _authToken = null;
    _userController.add(null);
    _stopSessionManagement();
  }

  /// Common logout implementation
  Future<void> performLogout() async {
    // Platform-specific implementations should call this
    clearAuthState();
    print('Auth: User logged out successfully');
  }

  /// Dispose mixin resources
  void disposeMixin() {
    _stopSessionManagement();
    _userController.close();
    _currentUser = null;
    _authToken = null;
    _isInitialized = false;
    print('Auth service resources disposed successfully');
  }
}

/// Authentication service configuration
class AuthConfig {
  final String apiUrl;
  final String apiKey;
  final Duration tokenExpiryDuration;
  final bool enableAutoRefresh;
  final bool enableSessionValidation;
  final Map<String, String> additionalHeaders;

  const AuthConfig({
    required this.apiUrl,
    required this.apiKey,
    this.tokenExpiryDuration = const Duration(hours: 1),
    this.enableAutoRefresh = true,
    this.enableSessionValidation = true,
    this.additionalHeaders = const {},
  });

  /// Create development configuration
  factory AuthConfig.development() {
    return const AuthConfig(
      apiUrl: 'http://localhost:3000/api/auth',
      apiKey: 'dev-key-12345',
      tokenExpiryDuration: Duration(minutes: 30),
    );
  }

  /// Create production configuration
  factory AuthConfig.production({
    required String apiUrl,
    required String apiKey,
  }) {
    return AuthConfig(
      apiUrl: apiUrl,
      apiKey: apiKey,
      tokenExpiryDuration: const Duration(hours: 2),
    );
  }
}
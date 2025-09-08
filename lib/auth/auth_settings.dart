import 'package:flutter/foundation.dart';
import 'dart:async';

import 'auth_service.dart';
import 'models/models.dart';

/// Authentication state provider for managing user authentication throughout the application.
/// 
/// Follows the same Provider pattern as WorkoutSettings and PlayerSettings.
/// Handles user login state, authentication service integration, and state persistence.
class AuthSettings extends ChangeNotifier {
  final AuthService _authService;
  
  User? _currentUser;
  bool _isLoading = false;
  String? _lastError;
  StreamSubscription<User?>? _userSubscription;

  AuthSettings() : _authService = AuthService() {
    _initialize();
  }

  /// Current authenticated user (null if not authenticated)
  User? get currentUser => _currentUser;

  /// Check if user is currently authenticated
  bool get isAuthenticated => _currentUser != null;

  /// Check if authentication operations are currently loading
  bool get isLoading => _isLoading;

  /// Get last authentication error message
  String? get lastError => _lastError;

  /// Get current user's display name
  String get displayName {
    if (!isAuthenticated) return 'Guest';
    return _currentUser!.profile.displayName.isNotEmpty 
        ? _currentUser!.profile.displayName 
        : _currentUser!.username;
  }

  /// Get current user's email
  String get userEmail {
    return _currentUser?.email ?? '';
  }

  /// Get current user's username
  String get username {
    return _currentUser?.username ?? '';
  }

  /// Get user's game statistics
  UserProfile get userProfile {
    return _currentUser?.profile ?? const UserProfile(displayName: 'Guest');
  }

  /// Check if current user's email is verified
  bool get isEmailVerified {
    // For mock implementation, always return true
    // Real implementation would check user's email verification status
    return isAuthenticated;
  }

  /// Get user's win rate as percentage
  String get winRatePercentage {
    if (!isAuthenticated) return '0%';
    return '${(_currentUser!.profile.winRate * 100).toStringAsFixed(1)}%';
  }

  /// Initialize the authentication settings
  Future<void> _initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.initialize();
      
      // Listen to authentication state changes
      _userSubscription = _authService.userStream.listen((user) {
        _currentUser = user;
        _clearError();
        notifyListeners();
      });

      // Load initial state
      _currentUser = _authService.currentUser;
      
    } catch (e) {
      _setError('Failed to initialize authentication: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register a new user account
  Future<bool> register({
    required String email,
    required String username,
    required String password,
    String? displayName,
  }) async {
    return _performAuthOperation(() async {
      final result = await _authService.register(
        email: email,
        username: username,
        password: password,
        displayName: displayName,
      );

      if (result.isSuccess) {
        _clearError();
        return true;
      } else {
        _setError(result.errorMessage);
        return false;
      }
    });
  }

  /// Login with email and password
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    return _performAuthOperation(() async {
      final result = await _authService.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );

      if (result.isSuccess) {
        _clearError();
        return true;
      } else {
        _setError(result.errorMessage);
        return false;
      }
    });
  }

  /// Login with saved authentication token
  Future<bool> loginWithToken(String token) async {
    return _performAuthOperation(() async {
      final result = await _authService.loginWithToken(token);

      if (result.isSuccess) {
        _clearError();
        return true;
      } else {
        _setError(result.errorMessage);
        return false;
      }
    });
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.logout();
      _clearError();
    } catch (e) {
      _setError('Failed to logout: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user profile information
  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    int? age,
    String? location,
  }) async {
    if (!isAuthenticated) {
      _setError('Must be logged in to update profile');
      return false;
    }

    return _performAuthOperation(() async {
      final result = await _authService.updateProfile(
        displayName: displayName,
        bio: bio,
        age: age,
        location: location,
      );

      if (result.isSuccess) {
        _clearError();
        return true;
      } else {
        _setError(result.errorMessage);
        return false;
      }
    });
  }

  /// Change user password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!isAuthenticated) {
      _setError('Must be logged in to change password');
      return false;
    }

    return _performAuthOperation(() async {
      final result = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (result.isSuccess) {
        _clearError();
        return true;
      } else {
        _setError(result.errorMessage);
        return false;
      }
    });
  }

  /// Request password reset email
  Future<bool> requestPasswordReset(String email) async {
    return _performAuthOperation(() async {
      final result = await _authService.requestPasswordReset(email);

      if (result.isSuccess) {
        _clearError();
        return true;
      } else {
        _setError(result.errorMessage);
        return false;
      }
    });
  }

  /// Send email verification
  Future<bool> sendEmailVerification() async {
    if (!isAuthenticated) {
      _setError('Must be logged in to verify email');
      return false;
    }

    return _performAuthOperation(() async {
      final result = await _authService.sendEmailVerification();

      if (result.isSuccess) {
        _clearError();
        return true;
      } else {
        _setError(result.errorMessage);
        return false;
      }
    });
  }

  /// Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    try {
      return await _authService.isEmailRegistered(email);
    } catch (e) {
      _setError('Failed to check email availability: ${e.toString()}');
      return false;
    }
  }

  /// Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      return await _authService.isUsernameAvailable(username);
    } catch (e) {
      _setError('Failed to check username availability: ${e.toString()}');
      return false;
    }
  }

  /// Delete user account
  Future<bool> deleteAccount() async {
    if (!isAuthenticated) {
      _setError('Must be logged in to delete account');
      return false;
    }

    return _performAuthOperation(() async {
      final result = await _authService.deleteAccount();

      if (result.isSuccess) {
        _clearError();
        return true;
      } else {
        _setError(result.errorMessage);
        return false;
      }
    });
  }

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    if (!isAuthenticated) return {};

    try {
      return await _authService.getUserStats();
    } catch (e) {
      _setError('Failed to load user stats: ${e.toString()}');
      return {};
    }
  }

  /// Refresh authentication token
  Future<bool> refreshToken() async {
    if (!isAuthenticated) return false;

    return _performAuthOperation(() async {
      final result = await _authService.refreshToken();

      if (result.isSuccess) {
        _clearError();
        return true;
      } else {
        _setError(result.errorMessage);
        return false;
      }
    });
  }

  /// Clear the last error message
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Validate registration input
  List<String> validateRegistration({
    required String email,
    required String username,
    required String password,
  }) {
    return User.getValidationErrors(
      email: email,
      username: username,
      password: password,
    );
  }

  /// Validate login input
  List<String> validateLogin({
    required String email,
    required String password,
  }) {
    final errors = <String>[];

    if (email.isEmpty) {
      errors.add('Email is required');
    } else if (!User.isValidEmail(email)) {
      errors.add('Please enter a valid email address');
    }

    if (password.isEmpty) {
      errors.add('Password is required');
    }

    return errors;
  }

  /// Check if user has played any games
  bool get hasPlayedGames {
    return isAuthenticated && _currentUser!.profile.totalGamesPlayed > 0;
  }

  /// Get user's competitive level based on games played and win rate
  String get competitiveLevel {
    if (!isAuthenticated) return 'Beginner';
    
    final gamesPlayed = _currentUser!.profile.totalGamesPlayed;
    final winRate = _currentUser!.profile.winRate;

    if (gamesPlayed < 10) return 'Beginner';
    if (gamesPlayed < 50) {
      return winRate > 0.6 ? 'Intermediate' : 'Casual';
    }
    if (gamesPlayed < 200) {
      return winRate > 0.7 ? 'Advanced' : winRate > 0.5 ? 'Intermediate' : 'Casual';
    }
    
    return winRate > 0.8 ? 'Expert' : winRate > 0.6 ? 'Advanced' : 'Intermediate';
  }

  /// Get user's total gaming time estimate (games * average duration)
  Duration get estimatedTotalGameTime {
    if (!isAuthenticated) return Duration.zero;
    
    final gamesPlayed = _currentUser!.profile.totalGamesPlayed;
    // Estimate average game duration as 5 minutes
    return Duration(minutes: gamesPlayed * 5);
  }

  /// Private helper methods

  /// Perform authentication operation with loading state management
  Future<T> _performAuthOperation<T>(Future<T> Function() operation) async {
    try {
      _isLoading = true;
      notifyListeners();

      return await operation();
    } catch (e) {
      _setError('Authentication error: ${e.toString()}');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set error message and notify listeners
  void _setError(String error) {
    _lastError = error;
    print('AuthSettings Error: $error');
  }

  /// Clear error message
  void _clearError() {
    _lastError = null;
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _authService.dispose();
    super.dispose();
  }
}
// Mock authentication service implementation for development and testing
// Uses SharedPreferences for local storage following PlayerSettings pattern

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'models/models.dart';

/// Mock authentication service for development and testing
/// 
/// Provides local-only authentication using SharedPreferences for storage.
/// Includes a mock user database for simulating various user scenarios.
class MockAuthService extends AuthService with AuthServiceMixin {
  static const String _keyCurrentUser = 'auth.currentUser';
  static const String _keyAuthToken = 'auth.authToken';
  static const String _keyUserDatabase = 'auth.userDatabase';
  static const String _keyNextUserId = 'auth.nextUserId';

  final Random _random = Random();
  
  Map<String, Map<String, dynamic>> _userDatabase = {};
  int _nextUserId = 1000;

  @override
  Future<void> initialize() async {
    if (isInitialized) return;

    await _loadUserDatabase();
    await _loadCurrentSession();
    
    // Add some default test users if database is empty
    if (_userDatabase.isEmpty) {
      await _createDefaultUsers();
    }

    markAsInitialized();
  }

  /// Load user database from SharedPreferences
  Future<void> _loadUserDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    
    final databaseJson = prefs.getString(_keyUserDatabase);
    if (databaseJson != null) {
      final decoded = jsonDecode(databaseJson) as Map<String, dynamic>;
      _userDatabase = decoded.map((key, value) => 
          MapEntry(key, Map<String, dynamic>.from(value as Map)));
    }

    _nextUserId = prefs.getInt(_keyNextUserId) ?? 1000;
  }

  /// Save user database to SharedPreferences
  Future<void> _saveUserDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserDatabase, jsonEncode(_userDatabase));
    await prefs.setInt(_keyNextUserId, _nextUserId);
  }

  /// Load current session from SharedPreferences
  Future<void> _loadCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    final userJson = prefs.getString(_keyCurrentUser);
    final token = prefs.getString(_keyAuthToken);
    
    if (userJson != null && token != null) {
      try {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        final user = User.fromJson(userData);
        
        // Validate token is still valid (simple expiry check)
        if (_isTokenValid(token)) {
          updateCurrentUser(user);
          updateAuthToken(token);
        } else {
          // Token expired, clear session
          await _clearSession();
        }
      } catch (e) {
        print('Mock Auth: Error loading session: $e');
        await _clearSession();
      }
    }
  }

  /// Clear current session from SharedPreferences
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
    await prefs.remove(_keyAuthToken);
    clearAuthState();
  }

  /// Save current session to SharedPreferences
  Future<void> _saveSession(User user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
    await prefs.setString(_keyAuthToken, token);
  }

  /// Create default test users for development
  Future<void> _createDefaultUsers() async {
    final defaultUsers = [
      {
        'email': 'test@example.com',
        'username': 'testuser',
        'password': 'Test123!',
        'displayName': 'Test User',
        'totalGamesPlayed': 25,
        'totalWins': 12,
      },
      {
        'email': 'demo@heartbeat.com',
        'username': 'demouser',
        'password': 'Demo123!',
        'displayName': 'Demo Player',
        'totalGamesPlayed': 100,
        'totalWins': 67,
      },
      {
        'email': 'competitor@example.com',
        'username': 'competitor',
        'password': 'Compete123!',
        'displayName': 'Pro Competitor',
        'totalGamesPlayed': 500,
        'totalWins': 385,
      },
    ];

    for (final userData in defaultUsers) {
      final userId = (_nextUserId++).toString();
      final now = DateTime.now();
      
      final profile = UserProfile(
        displayName: userData['displayName'] as String,
        joinedDate: now.subtract(Duration(days: _random.nextInt(365))),
        totalGamesPlayed: userData['totalGamesPlayed'] as int,
        totalWins: userData['totalWins'] as int,
        winRate: (userData['totalWins'] as int) / (userData['totalGamesPlayed'] as int),
      );

      _userDatabase[userData['email'] as String] = {
        'id': userId,
        'email': userData['email'],
        'username': userData['username'],
        'password': userData['password'], // In real implementation, this would be hashed
        'createdAt': now.toIso8601String(),
        'profile': profile.toJson(),
      };
    }

    await _saveUserDatabase();
  }

  /// Generate a mock authentication token
  String _generateToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(999999);
    return 'mock_token_${timestamp}_$random';
  }

  /// Check if token is valid (simple mock validation)
  bool _isTokenValid(String token) {
    if (!token.startsWith('mock_token_')) return false;
    
    try {
      final parts = token.split('_');
      final timestamp = int.parse(parts[2]);
      final tokenDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      // Token valid for 24 hours
      return now.difference(tokenDate).inHours < 24;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
    String? displayName,
    Map<String, dynamic>? metadata,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay

    // Validate input
    final validationErrors = User.getValidationErrors(
      email: email,
      username: username,
      password: password,
    );
    
    if (validationErrors.isNotEmpty) {
      if (!User.isValidEmail(email)) {
        return AuthResult.failure(status: AuthStatus.invalidEmail);
      }
      if (!User.isValidPassword(password)) {
        return AuthResult.failure(status: AuthStatus.weakPassword);
      }
      return AuthResult.failure(
        status: AuthStatus.unknown,
        message: validationErrors.first,
      );
    }

    // Check if email already exists
    if (_userDatabase.containsKey(email.toLowerCase())) {
      return AuthResult.failure(status: AuthStatus.emailAlreadyExists);
    }

    // Check if username already exists
    final existingUser = _userDatabase.values.firstWhere(
      (userData) => userData['username'] == username,
      orElse: () => <String, dynamic>{},
    );
    if (existingUser.isNotEmpty) {
      return AuthResult.failure(status: AuthStatus.usernameAlreadyExists);
    }

    // Create new user
    final userId = (_nextUserId++).toString();
    final now = DateTime.now();
    
    final profile = UserProfile(
      displayName: displayName ?? username,
      joinedDate: now,
    );

    final user = User(
      id: userId,
      email: email.toLowerCase(),
      username: username,
      createdAt: now,
      profile: profile,
    );

    // Store in database
    _userDatabase[email.toLowerCase()] = {
      'id': userId,
      'email': email.toLowerCase(),
      'username': username,
      'password': password, // In real implementation, this would be hashed
      'createdAt': now.toIso8601String(),
      'profile': profile.toJson(),
    };

    await _saveUserDatabase();

    // Create session
    final token = _generateToken();
    await _saveSession(user, token);
    
    updateCurrentUser(user);
    updateAuthToken(token);

    return AuthResult.success(
      user: user,
      token: token,
      message: 'Account created successfully',
    );
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate network delay

    final userData = _userDatabase[email.toLowerCase()];
    if (userData == null) {
      return AuthResult.failure(status: AuthStatus.userNotFound);
    }

    if (userData['password'] != password) {
      return AuthResult.failure(status: AuthStatus.invalidCredentials);
    }

    // Create user object
    final user = User(
      id: userData['id'] as String,
      email: userData['email'] as String,
      username: userData['username'] as String,
      createdAt: DateTime.parse(userData['createdAt'] as String),
      profile: UserProfile.fromJson(userData['profile'] as Map<String, dynamic>),
    );

    // Create session
    final token = _generateToken();
    await _saveSession(user, token);
    
    updateCurrentUser(user);
    updateAuthToken(token);

    return AuthResult.success(
      user: user,
      token: token,
      message: 'Login successful',
    );
  }

  @override
  Future<AuthResult> loginWithToken(String token) async {
    await Future.delayed(const Duration(milliseconds: 200)); // Simulate network delay

    if (!_isTokenValid(token)) {
      return AuthResult.failure(
        status: AuthStatus.invalidCredentials,
        message: 'Invalid or expired token',
      );
    }

    // In a real implementation, we'd decode the token to get user ID
    // For mock, we'll just load from current session
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyCurrentUser);
    
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        final user = User.fromJson(userData);
        
        updateCurrentUser(user);
        updateAuthToken(token);

        return AuthResult.success(
          user: user,
          token: token,
          message: 'Token login successful',
        );
      } catch (e) {
        return AuthResult.failure(
          status: AuthStatus.unknown,
          message: 'Failed to load user data',
        );
      }
    }

    return AuthResult.failure(
      status: AuthStatus.userNotFound,
      message: 'No user data found for token',
    );
  }

  @override
  Future<void> logout() async {
    await _clearSession();
    await performLogout();
  }

  @override
  Future<AuthResult> refreshToken() async {
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate network delay

    if (currentUser == null) {
      return AuthResult.failure(
        status: AuthStatus.userNotFound,
        message: 'No user to refresh token for',
      );
    }

    final newToken = _generateToken();
    await _saveSession(currentUser!, newToken);
    updateAuthToken(newToken);

    return AuthResult.success(
      user: currentUser!,
      token: newToken,
      message: 'Token refreshed successfully',
    );
  }

  @override
  Future<AuthResult> updateProfile({
    String? displayName,
    String? bio,
    int? age,
    String? location,
  }) async {
    if (currentUser == null) {
      return AuthResult.failure(status: AuthStatus.userNotFound);
    }

    await Future.delayed(const Duration(milliseconds: 400)); // Simulate network delay

    final updatedProfile = currentUser!.profile.copyWith(
      displayName: displayName,
      bio: bio,
      age: age,
      location: location,
    );

    final updatedUser = currentUser!.copyWith(profile: updatedProfile);

    // Update in database
    final userData = _userDatabase[currentUser!.email];
    if (userData != null) {
      userData['profile'] = updatedProfile.toJson();
      await _saveUserDatabase();
      await _saveSession(updatedUser, authToken!);
    }

    updateCurrentUser(updatedUser);

    return AuthResult.success(
      user: updatedUser,
      token: authToken,
      message: 'Profile updated successfully',
    );
  }

  @override
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentUser == null) {
      return AuthResult.failure(status: AuthStatus.userNotFound);
    }

    await Future.delayed(const Duration(milliseconds: 300)); // Simulate network delay

    final userData = _userDatabase[currentUser!.email];
    if (userData == null || userData['password'] != currentPassword) {
      return AuthResult.failure(status: AuthStatus.invalidCredentials);
    }

    if (!User.isValidPassword(newPassword)) {
      return AuthResult.failure(status: AuthStatus.weakPassword);
    }

    // Update password in database
    userData['password'] = newPassword;
    await _saveUserDatabase();

    return AuthResult.success(
      user: currentUser!,
      token: authToken,
      message: 'Password changed successfully',
    );
  }

  @override
  Future<AuthResult> requestPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 600)); // Simulate network delay

    // For mock implementation, always return success
    // Real implementation would send email
    return AuthResult.success(
      user: null,
      message: 'Password reset email sent (mock implementation)',
    );
  }

  @override
  Future<AuthResult> sendEmailVerification() async {
    if (currentUser == null) {
      return AuthResult.failure(status: AuthStatus.userNotFound);
    }

    await Future.delayed(const Duration(milliseconds: 400)); // Simulate network delay

    // For mock implementation, always return success
    return AuthResult.success(
      user: currentUser!,
      message: 'Verification email sent (mock implementation)',
    );
  }

  @override
  Future<bool> isEmailRegistered(String email) async {
    await Future.delayed(const Duration(milliseconds: 150)); // Simulate network delay
    return _userDatabase.containsKey(email.toLowerCase());
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    await Future.delayed(const Duration(milliseconds: 150)); // Simulate network delay
    
    final existingUser = _userDatabase.values.firstWhere(
      (userData) => userData['username'] == username,
      orElse: () => <String, dynamic>{},
    );
    
    return existingUser.isEmpty;
  }

  @override
  Future<AuthResult> deleteAccount() async {
    if (currentUser == null) {
      return AuthResult.failure(status: AuthStatus.userNotFound);
    }

    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network delay

    // Remove from database
    _userDatabase.remove(currentUser!.email);
    await _saveUserDatabase();
    await logout();

    return AuthResult.success(
      user: null,
      message: 'Account deleted successfully',
    );
  }

  @override
  Future<Map<String, dynamic>> getUserStats() async {
    if (currentUser == null) {
      return {};
    }

    await Future.delayed(const Duration(milliseconds: 200)); // Simulate network delay

    return {
      'userId': currentUser!.id,
      'username': currentUser!.username,
      'totalGamesPlayed': currentUser!.profile.totalGamesPlayed,
      'totalWins': currentUser!.profile.totalWins,
      'winRate': currentUser!.profile.winRate,
      'accountAge': DateTime.now().difference(currentUser!.createdAt).inDays,
      'lastLogin': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> dispose() async {
    disposeMixin();
  }

  /// Get all registered users (for development/testing purposes)
  Map<String, Map<String, dynamic>> get registeredUsers => 
      Map.unmodifiable(_userDatabase);

  /// Clear all user data (for testing purposes)
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserDatabase);
    await prefs.remove(_keyNextUserId);
    await _clearSession();
    
    _userDatabase.clear();
    _nextUserId = 1000;
    
    await _createDefaultUsers();
  }
}
// Mobile/Desktop authentication service implementation
// Uses mock service for development and testing

import 'auth_service.dart';
import 'auth_service_impl_mock.dart';

/// Create platform-specific authentication service for mobile/desktop
AuthService createAuthService() {
  // For development phase, use mock authentication service
  // In production, this would be replaced with Firebase Auth or similar
  return MockAuthService();
}
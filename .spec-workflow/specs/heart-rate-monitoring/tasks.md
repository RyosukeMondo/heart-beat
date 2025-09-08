# Heart Rate Monitoring System - Tasks Document

- [x] 1. Create BLE types and enums in lib/ble/ble_types.dart
  - File: lib/ble/ble_types.dart
  - Define DeviceInfo class with id, platformName, manufacturerData, rssi
  - Create BleConnectionState enum (idle, scanning, connecting, connected, disconnected, error)
  - Add BleError enum for standardized error handling
  - Purpose: Establish type safety for BLE operations across platform implementations
  - _Leverage: Existing Dart type system and enum patterns_
  - _Requirements: 1.1, 3.1_

- [x] 2. Implement heart rate data parser in lib/ble/heart_rate_parser.dart
  - File: lib/ble/heart_rate_parser.dart
  - Create static parseHeartRate method handling 8-bit and 16-bit formats
  - Add validation for malformed data packets
  - Support little-endian 16-bit format as per Bluetooth specification
  - Purpose: Convert raw BLE heart rate measurement data to integer BPM values
  - _Leverage: Bluetooth Heart Rate Service specification (0x180D)_
  - _Requirements: 2.1, 2.2_

- [x] 3. Create abstract BLE service interface in lib/ble/ble_service.dart
  - File: lib/ble/ble_service.dart
  - Define abstract BleService class with factory constructor
  - Add heartRateStream getter returning Stream<int>
  - Include initializeIfNeeded, scanAndConnect, disconnect methods
  - Implement platform detection for factory pattern
  - Purpose: Provide unified interface for cross-platform BLE implementations
  - _Leverage: Dart factory patterns and abstract classes_
  - _Requirements: 1.1, 3.1, 3.2_

- [x] 4. Implement mobile BLE service in lib/ble/ble_service_impl_mobile.dart
  - File: lib/ble/ble_service_impl_mobile.dart
  - Create BleServiceImplMobile extending BleService
  - Integrate flutter_blue_plus for Android and iOS
  - Add win_ble support for Windows platform
  - Implement device scanning filtered by Heart Rate Service UUID (0x180D)
  - Purpose: Handle BLE operations for mobile and desktop platforms
  - _Leverage: flutter_blue_plus plugin, win_ble plugin, HeartRateParser_
  - _Requirements: 3.1, 3.2, 7.1_

- [x] 5. Implement web BLE service in lib/ble/ble_service_impl_web.dart
  - File: lib/ble/ble_service_impl_web.dart
  - Create BleServiceImplWeb extending BleService
  - Integrate flutter_web_bluetooth for browser compatibility
  - Handle Web Bluetooth API limitations and HTTPS requirements
  - Implement error handling for unsupported browsers
  - Purpose: Enable heart rate monitoring in web browsers
  - _Leverage: flutter_web_bluetooth plugin, Web Bluetooth API_
  - _Requirements: 3.3_

- [x] 6. Add Android permission handling in lib/ble/ble_service_impl_mobile.dart
  - File: lib/ble/ble_service_impl_mobile.dart (extend existing)
  - Integrate permission_handler for runtime permission requests
  - Handle Android 12+ BLUETOOTH_SCAN and BLUETOOTH_CONNECT permissions
  - Add fallback for legacy location permissions
  - Provide user-friendly error messages in Japanese
  - Purpose: Ensure proper Android BLE permission management
  - _Leverage: permission_handler plugin, platform detection_
  - _Requirements: 7.1, 7.2_

- [x] 7. Create BLE service unit tests in test/ble/ble_service_test.dart
  - File: test/ble/ble_service_test.dart
  - Mock platform-specific implementations for testing
  - Test factory pattern platform selection
  - Verify stream subscription management
  - Test error handling scenarios
  - Purpose: Ensure BLE service reliability and catch regressions
  - _Leverage: Flutter test framework, mockito for mocking_
  - _Requirements: 1.1, 3.1, 3.2_

- [x] 8. Create heart rate parser tests in test/ble/heart_rate_parser_test.dart
  - File: test/ble/heart_rate_parser_test.dart
  - Test parsing of valid 8-bit heart rate data
  - Test parsing of valid 16-bit little-endian heart rate data
  - Test handling of malformed and empty data packets
  - Verify edge cases and boundary conditions
  - Purpose: Ensure data parsing accuracy and error handling
  - _Leverage: Flutter test framework, test data fixtures_
  - _Requirements: 2.1, 2.2_

- [x] 9. Implement workout configuration model in lib/workout/workout_config.dart
  - File: lib/workout/workout_config.dart
  - Create WorkoutConfig class with name, minHeartRate, maxHeartRate, duration
  - Add factory constructors for common workout types
  - Implement JSON serialization for persistence
  - Add validation methods for heart rate ranges
  - Purpose: Define workout profile structure and validation
  - _Leverage: Dart built-in JSON support_
  - _Requirements: 4.1, 4.2_

- [x] 10. Enhance workout settings in lib/workout/workout_settings.dart
  - File: lib/workout/workout_settings.dart (modify existing)
  - Integrate WorkoutConfig model with existing settings
  - Add methods for creating, updating, deleting workout profiles
  - Implement persistence using SharedPreferences
  - Add change notification for UI updates
  - Purpose: Manage workout configurations with proper state management
  - _Leverage: existing WorkoutSettings class, Provider pattern, shared_preferences_
  - _Requirements: 4.1, 4.2, 6.1_

- [x] 11. Create workout settings tests in test/workout/workout_settings_test.dart
  - File: test/workout/workout_settings_test.dart
  - Test workout profile creation, modification, deletion
  - Test persistence and loading from SharedPreferences
  - Test change notification to dependent widgets
  - Mock SharedPreferences for isolated testing
  - Purpose: Ensure workout configuration management reliability
  - _Leverage: Flutter test framework, mockito, shared_preferences_test_
  - _Requirements: 4.1, 4.2_

- [x] 12. Enhance main UI in lib/main.dart
  - File: lib/main.dart (modify existing)
  - Update HeartRatePage to use BLE service abstraction
  - Improve error handling and status display
  - Add proper stream subscription management
  - Enhance connection button to work with any BLE heart rate sensor
  - Purpose: Integrate new BLE architecture with existing UI
  - _Leverage: existing HeartRatePage, Provider integration, Material Design_
  - _Requirements: 1.1, 2.1, 8.1_

- [x] 13. Create workout configuration UI in lib/workout/workout_config_page.dart
  - File: lib/workout/workout_config_page.dart (enhance existing)
  - Add workout profile creation and editing interface
  - Implement heart rate zone configuration
  - Add form validation and user feedback
  - Integrate with WorkoutSettings provider
  - Purpose: Provide user interface for workout customization
  - _Leverage: existing WorkoutConfigPage, Material Design, Provider pattern_
  - _Requirements: 4.1, 4.3_

- [x] 14. Enhance YouTube player integration in lib/player/player_page.dart
  - File: lib/player/player_page.dart (modify existing)
  - Add real-time heart rate overlay on video content
  - Implement heart rate data synchronization during playback
  - Handle connection status display during video sessions
  - Maintain video playback during sensor disconnections
  - Purpose: Integrate heart rate monitoring with multimedia content
  - _Leverage: existing PlayerPage, flutter_inappwebview, BLE service stream_
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 15. Add integration tests in test/integration/ble_integration_test.dart
  - File: test/integration/ble_integration_test.dart
  - Test full BLE connection workflow with mock devices
  - Test platform-specific implementations
  - Test error recovery and reconnection scenarios
  - Verify real-time data streaming performance
  - Purpose: Ensure end-to-end BLE functionality works correctly
  - _Leverage: Flutter integration test framework, mock BLE devices_
  - _Requirements: All BLE requirements_

- [x] 16. Create widget tests in test/widget/heart_rate_page_test.dart
  - File: test/widget/heart_rate_page_test.dart
  - Test heart rate display updates with mock data streams
  - Test connection button functionality and state changes
  - Test navigation to workout configuration and player pages
  - Test error state display and recovery
  - Purpose: Ensure UI components respond correctly to data changes
  - _Leverage: Flutter widget testing, mock providers_
  - _Requirements: 2.1, 2.2, UI requirements_

- [x] 17. Add performance optimization in lib/ble/ble_service.dart
  - File: lib/ble/ble_service.dart (enhance existing)
  - Implement stream throttling to maintain 60 FPS UI updates
  - Add automatic cleanup of unused resources
  - Optimize scanning intervals for battery efficiency
  - Add connection pooling for multiple device support
  - Purpose: Ensure real-time performance and resource efficiency
  - _Leverage: Dart streams, RxDart for advanced stream operations_
  - _Requirements: Performance requirements_

- [x] 18. Implement error recovery mechanisms in lib/ble/ble_service_impl_mobile.dart
  - File: lib/ble/ble_service_impl_mobile.dart (enhance existing)
  - Add exponential backoff for connection retry logic
  - Implement automatic reconnection on connection loss
  - Add connection health monitoring
  - Handle platform-specific error scenarios
  - Purpose: Provide robust connection management with graceful recovery
  - _Leverage: Dart Timer, async/await patterns_
  - _Requirements: Reliability requirements_

- [x] 19. Add comprehensive error handling in all BLE components
  - Files: lib/ble/*.dart (enhance existing)
  - Standardize error messages and user feedback
  - Implement logging for debugging and monitoring
  - Add user-friendly error messages in Japanese
  - Create error reporting mechanism for troubleshooting
  - Purpose: Provide comprehensive error handling across BLE system
  - _Leverage: Dart logging package, standardized error types_
  - _Requirements: All error handling requirements_

- [x] 20. Final integration testing and optimization
  - Files: All project files (validation and cleanup)
  - Test cross-platform compatibility on Android, Windows, Web
  - Verify performance requirements (200ms processing, 60 FPS UI)
  - Test with multiple BLE heart rate sensor brands
  - Optimize battery usage and memory consumption
  - Purpose: Ensure system meets all requirements and performs optimally
  - _Leverage: All implemented components, real device testing_
  - _Requirements: All requirements_
# Heart Rate Monitoring System - Requirements Document

## Introduction

The Heart Rate Monitoring System is a cross-platform Flutter application designed to provide real-time heart rate monitoring capabilities using Bluetooth Low Energy (BLE) heart rate sensors. The system serves fitness enthusiasts, athletes, and health-conscious individuals by offering scientific heart rate zone-based training guidance integrated with multimedia content for enhanced workout experiences.

The application addresses the need for precise, real-time cardiovascular monitoring during exercise, enabling users to optimize their training effectiveness while maintaining safety through objective biometric feedback.

## Alignment with Product Vision

This feature serves as the core foundation of the Heart Beat product vision by:

- **Enabling Real-time Monitoring**: Providing continuous heart rate tracking with instant BPM display as the primary value proposition
- **Supporting Training Optimization**: Facilitating heart rate zone-based workout guidance following scientific training principles
- **Delivering Cross-platform Compatibility**: Ensuring seamless operation across Android, Windows, and Web platforms as outlined in the technical specifications
- **Integrating with Media Content**: Combining precise heart rate data collection with multimedia integration for comprehensive fitness experiences

## Requirements

### Requirement 1: BLE Heart Rate Sensor Connection

**User Story:** As a fitness enthusiast, I want to connect my Bluetooth heart rate sensor to the application, so that I can monitor my heart rate in real-time during workouts.

#### Acceptance Criteria

1. WHEN the user taps the BLE heart rate sensor connection button THEN the system SHALL initiate BLE device scanning for any compatible heart rate sensors
2. WHEN a compatible BLE heart rate sensor is detected THEN the system SHALL automatically connect to the device and display connection status
3. IF the connection fails THEN the system SHALL display "デバイス未検出" status message
4. WHEN the device is successfully connected THEN the system SHALL display "接続済み: [device name]" status
5. WHEN multiple compatible devices are found THEN the system SHALL connect to the first detected heart rate sensor

### Requirement 2: Real-time Heart Rate Display

**User Story:** As a user exercising with a connected heart rate sensor, I want to see my current heart rate prominently displayed, so that I can monitor my exercise intensity in real-time.

#### Acceptance Criteria

1. WHEN heart rate data is received from the connected BLE sensor THEN the system SHALL parse the data using the Heart Rate Service specification (UUID 0x180D)
2. WHEN valid heart rate data is available THEN the system SHALL display the BPM value in large, bold text (72pt font)
3. IF the connection is temporarily lost THEN the system SHALL continue displaying the last known BPM value
4. WHEN no heart rate data has been received THEN the system SHALL display "--" instead of a numeric value
5. WHEN heart rate data format is 16-bit THEN the system SHALL parse little-endian format correctly

### Requirement 3: Cross-Platform BLE Implementation

**User Story:** As a user on different platforms (Android, Windows, Web), I want the heart rate monitoring to work consistently, so that I can use the same application across my devices.

#### Acceptance Criteria

1. WHEN running on Android THEN the system SHALL use flutter_blue_plus for BLE communication
2. WHEN running on Windows THEN the system SHALL use win_ble backend for native Windows BLE integration
3. WHEN running on Web platforms THEN the system SHALL use flutter_web_bluetooth API
4. IF the platform lacks BLE support THEN the system SHALL display appropriate error messaging
5. WHEN on Android 12+ THEN the system SHALL request BLUETOOTH_SCAN and BLUETOOTH_CONNECT permissions
6. WHEN scanning for devices THEN the system SHALL filter by Heart Rate Service UUID (0x180D) to find compatible sensors

### Requirement 4: Workout Configuration Management

**User Story:** As a fitness user, I want to configure different workout profiles, so that I can customize my training based on specific fitness goals.

#### Acceptance Criteria

1. WHEN the user accesses workout settings THEN the system SHALL display available workout configurations
2. WHEN a workout profile is selected THEN the system SHALL persist the selection using SharedPreferences
3. WHEN the app is restarted THEN the system SHALL load and display the previously selected workout configuration
4. WHEN workout settings are modified THEN the system SHALL notify dependent components of the changes

### Requirement 5: YouTube Player Integration

**User Story:** As a user doing guided workouts, I want to watch YouTube videos while monitoring my heart rate, so that I can follow along with training content while tracking my performance.

#### Acceptance Criteria

1. WHEN the user taps "YouTube プレイヤー (心拍連動)" THEN the system SHALL navigate to the YouTube player interface
2. WHEN the YouTube player is active AND heart rate data is available THEN the system SHALL overlay real-time BPM data on the video
3. WHEN video content is playing THEN the system SHALL maintain heart rate data streaming without interruption
4. IF heart rate sensor is disconnected during video playback THEN the system SHALL continue video playback but indicate sensor status

### Requirement 6: Settings Persistence

**User Story:** As a regular user of the application, I want my preferences and configurations to be remembered, so that I don't need to reconfigure the app each time I use it.

#### Acceptance Criteria

1. WHEN user preferences are modified THEN the system SHALL automatically save settings to local storage
2. WHEN the application launches THEN the system SHALL load and apply previously saved settings
3. WHEN settings data is corrupted or missing THEN the system SHALL use sensible default values
4. IF settings fail to load THEN the system SHALL continue operation with defaults and log the error

### Requirement 7: Permission Management

**User Story:** As a user on Android devices, I want the application to handle Bluetooth permissions appropriately, so that I can use heart rate monitoring features without manual permission configuration.

#### Acceptance Criteria

1. WHEN the app launches on Android THEN the system SHALL check for required BLE permissions
2. IF permissions are not granted THEN the system SHALL request BLUETOOTH_SCAN and BLUETOOTH_CONNECT permissions
3. WHEN permissions are denied THEN the system SHALL display "権限が拒否されました" and disable BLE functionality
4. IF legacy Android versions require location permission THEN the system SHALL request locationWhenInUse permission as fallback

### Requirement 8: Universal BLE Heart Rate Device Support

**User Story:** As a user with any BLE-compatible heart rate sensor, I want to connect my device to the application, so that I can use my existing fitness hardware regardless of brand or model.

#### Acceptance Criteria

1. WHEN scanning for devices THEN the system SHALL detect any BLE device advertising Heart Rate Service (0x180D)
2. WHEN connecting to a heart rate device THEN the system SHALL use standard Bluetooth Heart Rate Profile regardless of manufacturer
3. IF a device supports Heart Rate Measurement characteristic (0x2A37) THEN the system SHALL be able to read heart rate data
4. WHEN displaying connected device THEN the system SHALL show the actual device name as reported by the BLE device
5. IF device-specific optimizations exist THEN the system MAY apply them while maintaining universal compatibility

## Non-Functional Requirements

### Code Architecture and Modularity
- **Single Responsibility Principle**: BLE service, UI components, and settings management are properly separated into distinct modules
- **Modular Design**: BLE abstraction layer supports multiple platform implementations through factory pattern
- **Dependency Management**: Platform-specific implementations are isolated behind abstract interfaces
- **Clear Interfaces**: BleService abstract class defines clean contract for heart rate data streaming

### Performance
- **Real-time Data Processing**: Heart rate data must be processed and displayed within 200ms of sensor transmission
- **UI Responsiveness**: Application must maintain 60 FPS during heart rate data updates
- **Memory Efficiency**: Stream subscriptions must be properly managed to prevent memory leaks
- **Battery Optimization**: BLE scanning and connection management should minimize battery impact

### Security
- **Local Data Processing**: All heart rate data must be processed locally without external transmission
- **Permission Scope**: Application must request only necessary permissions for BLE functionality
- **Data Validation**: All incoming BLE data must be validated before processing to prevent malformed data issues

### Reliability
- **Connection Recovery**: System must handle temporary BLE disconnections gracefully with automatic reconnection attempts
- **Error Handling**: All BLE errors must be caught and handled with appropriate user feedback
- **State Preservation**: Application state must be maintained during configuration changes and background/foreground transitions
- **Device Compatibility**: System must work with any standard-compliant BLE heart rate sensor

### Usability
- **Large Text Display**: Heart rate value must be displayed in easily readable format during exercise (72pt font)
- **Clear Status Communication**: Connection status must be clearly communicated in Japanese for target user base
- **Single-Touch Connection**: Heart rate sensor connection must be achievable with single button press
- **Intuitive Navigation**: Access to workout configuration and YouTube player must be easily discoverable from main interface
- **Universal Device Support**: Users should be able to connect any BLE heart rate sensor without brand-specific configuration
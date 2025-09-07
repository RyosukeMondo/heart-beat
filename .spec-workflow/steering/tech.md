# Heart Beat - Technical Specification

## Architecture Overview

Heart Beat is built using Flutter's cross-platform framework with a modular architecture that abstracts platform-specific Bluetooth Low Energy (BLE) implementations behind a unified service interface.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                      │
├─────────────────────────────────────────────────────────────┤
│  HeartRatePage  │  PlayerPage  │  WorkoutConfigPage        │
├─────────────────────────────────────────────────────────────┤
│                    State Management                         │
├─────────────────────────────────────────────────────────────┤
│  PlayerSettings │ WorkoutSettings (Provider Pattern)       │
├─────────────────────────────────────────────────────────────┤
│                    Business Logic                           │
├─────────────────────────────────────────────────────────────┤
│                    BleService                               │
├─────────────────────────────────────────────────────────────┤
│                Platform Abstraction                         │
├─────────────────────────────────────────────────────────────┤
│ BleServiceMobile │ BleServiceWeb │ HeartRateParser          │
├─────────────────────────────────────────────────────────────┤
│                   Native Platform                           │
├─────────────────────────────────────────────────────────────┤
│ flutter_blue_plus│ win_ble      │ flutter_web_bluetooth    │
└─────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Framework & Language
- **Flutter SDK**: ^3.7.2
- **Dart**: Null-safe, latest stable version
- **Target Platforms**: Android, Windows, Web, iOS, macOS, Linux

### Core Dependencies

#### BLE & Communication
```yaml
flutter_blue_plus: ^1.34.5           # Primary BLE for mobile/desktop
flutter_blue_plus_windows: ^1.26.1   # Windows-specific BLE support
win_ble: ^1.1.1                      # Native Windows BLE backend
flutter_web_bluetooth: ^1.1.0        # Web Bluetooth API wrapper
```

#### State Management & Persistence
```yaml
provider: ^6.1.5                     # State management pattern
shared_preferences: ^2.2.3           # Local data persistence
```

#### UI & Media
```yaml
cupertino_icons: ^1.0.8              # iOS-style icons
flutter_inappwebview: ^6.0.0         # Web content integration
```

#### System Integration
```yaml
permission_handler: ^12.0.1          # Runtime permissions management
```

#### Development & Quality
```yaml
flutter_lints: ^5.0.0               # Static analysis and linting
flutter_test: sdk: flutter          # Unit and widget testing
```

## Platform-Specific Implementations

### Android Implementation
- **BLE Backend**: flutter_blue_plus
- **Permissions Required**:
  - `BLUETOOTH_SCAN` (Android 12+)
  - `BLUETOOTH_CONNECT` (Android 12+)
  - `ACCESS_FINE_LOCATION` (legacy compatibility)
- **Minimum API**: Level 21 (Android 5.0)

### Windows Implementation
- **BLE Backend**: win_ble
- **System Requirements**: Windows 10 version 1903+
- **Native Integration**: Direct Windows BLE API access

### Web Implementation
- **BLE Backend**: flutter_web_bluetooth
- **Browser Compatibility**: Chrome 56+, Edge 79+, Opera 43+
- **HTTPS Requirement**: Web Bluetooth requires secure context

### iOS/macOS Implementation
- **BLE Backend**: flutter_blue_plus (Core Bluetooth framework)
- **Permissions**: Bluetooth usage descriptions in Info.plist

## Core Components

### BleService Architecture

```dart
abstract class BleService {
  static BleService get instance;
  Stream<int> get heartRateStream;
  
  Future<void> initializeIfNeeded();
  Future<DeviceInfo?> scanAndConnect();
  Future<void> disconnect();
}
```

#### Platform Factory Pattern
```dart
BleService._createPlatformInstance() {
  if (kIsWeb) {
    return BleServiceImplWeb();
  } else if (Platform.isWindows) {
    return BleServiceImplMobile(); // Uses win_ble backend
  } else {
    return BleServiceImplMobile(); // Uses flutter_blue_plus
  }
}
```

### Heart Rate Data Processing

#### BLE Service Discovery
- **Service UUID**: `0x180D` (Heart Rate Service)
- **Characteristic UUID**: `0x2A37` (Heart Rate Measurement)
- **Data Format**: Standard Bluetooth SIG specification

#### Data Parsing Algorithm
```dart
class HeartRateParser {
  static int parseHeartRate(List<int> data) {
    if (data.isEmpty) return 0;
    
    // Check format flag (bit 0)
    bool is16Bit = (data[0] & 0x01) != 0;
    
    if (is16Bit && data.length >= 3) {
      // 16-bit heart rate value (little-endian)
      return data[1] | (data[2] << 8);
    } else if (data.length >= 2) {
      // 8-bit heart rate value
      return data[1];
    }
    
    return 0;
  }
}
```

### State Management Implementation

#### Provider Pattern Usage
```dart
class PlayerSettings extends ChangeNotifier {
  late SharedPreferences _prefs;
  
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    notifyListeners();
  }
  
  void updateSetting(String key, dynamic value) {
    // Update logic with persistence
    notifyListeners();
  }
}
```

#### Workout Configuration
```dart
class WorkoutSettings extends ChangeNotifier {
  WorkoutConfig _selected = WorkoutConfig.defaultConfig();
  
  WorkoutConfig get selected => _selected;
  
  void setWorkout(WorkoutConfig config) {
    _selected = config;
    notifyListeners();
    _persistToStorage();
  }
}
```

## Data Flow Architecture

### Heart Rate Data Pipeline

```
BLE Sensor → Platform BLE Stack → Flutter BLE Plugin → BleService → 
HeartRateParser → Stream<int> → UI Widget → Display
```

### Permission Flow (Android)

```
App Launch → Check BLE Permissions → Request if Missing → 
Initialize BLE Service → Ready for Connection
```

### Connection State Machine

```
Idle → Scanning → Connecting → Connected → Streaming → Disconnected
  ↑                                                        ↓
  └─────────────── Reconnection Logic ←──────────────────────
```

## Performance Specifications

### Real-time Requirements
- **Heart Rate Update Frequency**: 1-2 Hz (sensor dependent)
- **UI Refresh Rate**: 60 FPS maintained during data updates
- **Connection Latency**: <2 seconds for device discovery
- **Data Latency**: <200ms from sensor to display

### Memory Management
- **Stream Management**: Automatic subscription cleanup on widget disposal
- **Connection Pooling**: Single active BLE connection per session
- **Data Buffering**: Minimal buffering to reduce memory footprint

### Battery Optimization
- **Efficient Scanning**: Targeted UUID-based device discovery
- **Connection Management**: Automatic disconnection on app backgrounding
- **Minimal Processing**: Lightweight data parsing algorithms

## Security Considerations

### Data Privacy
- **Local Processing**: All heart rate data processed locally
- **No Cloud Storage**: No transmission of personal health data
- **Permission Scope**: Minimal required permissions requested

### BLE Security
- **Device Authentication**: Connection limited to heart rate devices
- **Secure Pairing**: Standard BLE security protocols
- **Data Validation**: Input validation on all BLE data packets

## Testing Strategy

### Unit Testing
- **Heart Rate Parser**: Comprehensive test coverage for data parsing logic
- **Settings Management**: State persistence and restoration validation
- **Platform Abstraction**: Mock implementations for cross-platform testing

### Integration Testing
- **BLE Connection**: Automated testing with simulated devices
- **Permission Handling**: Platform-specific permission flow validation
- **Cross-platform Compatibility**: Automated testing across target platforms

### Widget Testing
- **UI Responsiveness**: Heart rate display update validation
- **State Management**: Provider pattern integration testing
- **Navigation**: Page transition and state preservation

## Build & Deployment

### Build Configuration
```yaml
# analysis_options.yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    invalid_annotation_target: ignore
```

### Platform-Specific Build Commands
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# Windows
flutter build windows --release

# Web
flutter build web --release --web-renderer html
```

### CI/CD Pipeline Considerations
- **Multi-platform Testing**: Automated testing across all target platforms
- **Dependency Management**: Regular dependency updates and compatibility testing
- **Code Quality**: Static analysis and linting enforcement
- **Performance Testing**: Automated performance regression testing

## Scalability & Future Enhancements

### Horizontal Scaling
- **Multi-device Support**: Architecture supports multiple simultaneous BLE connections
- **Plugin Architecture**: Modular design allows for easy feature extensions
- **Cloud Integration**: Ready for optional cloud features (analytics, sharing)

### Vertical Scaling
- **Enhanced Analytics**: Real-time heart rate zone calculations
- **Data Export**: Multiple format support (CSV, GPX, TCX)
- **Advanced Training**: Integration with training plans and coaching features

### Technical Debt Management
- **Regular Refactoring**: Continuous code quality improvement
- **Dependency Updates**: Proactive framework and package updates
- **Performance Monitoring**: Continuous performance optimization

## Error Handling & Recovery

### BLE Connection Errors
```dart
enum BleError {
  deviceNotFound,
  connectionFailed,
  serviceNotFound,
  characteristicNotFound,
  permissionDenied,
  bluetoothOff,
  platformNotSupported
}
```

### Recovery Strategies
- **Automatic Reconnection**: Exponential backoff retry logic
- **Graceful Degradation**: Fallback to manual connection modes
- **User Guidance**: Clear error messages with actionable solutions
- **State Preservation**: Maintain application state during connection issues

## Monitoring & Observability

### Logging Strategy
- **Structured Logging**: JSON-formatted logs for analysis
- **Log Levels**: Appropriate use of debug, info, warning, error levels
- **Performance Metrics**: Connection times, data throughput monitoring
- **Error Tracking**: Comprehensive error capture and reporting

### Analytics Integration Points
- **Connection Success Rates**: Track BLE connection reliability
- **Session Duration**: Monitor user engagement metrics
- **Feature Usage**: Track adoption of different application features
- **Performance Metrics**: Monitor application performance characteristics
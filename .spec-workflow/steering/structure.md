# Heart Beat - Project Structure & Architecture

## Directory Structure

```
heart_beat/
├── .github/                    # GitHub workflows and templates
├── .serena/                    # Serena MCP configuration
├── .spec-workflow/             # Project specification documents
│   ├── product.md             # Product specification
│   ├── tech.md                # Technical specification
│   └── structure.md           # This document
├── android/                    # Android-specific configuration
├── ios/                       # iOS-specific configuration
├── linux/                     # Linux-specific configuration
├── macos/                     # macOS-specific configuration
├── web/                       # Web-specific configuration
├── windows/                   # Windows-specific configuration
├── lib/                       # Main Flutter application code
│   ├── ble/                   # Bluetooth Low Energy module
│   │   ├── ble_service.dart           # Abstract BLE service interface
│   │   ├── ble_service_impl_mobile.dart # Mobile/Desktop BLE implementation
│   │   ├── ble_service_impl_web.dart   # Web BLE implementation
│   │   ├── ble_types.dart             # BLE data types and models
│   │   └── heart_rate_parser.dart     # Heart rate data parsing logic
│   ├── player/                # Media player module
│   │   ├── player_page.dart          # YouTube player interface
│   │   └── settings.dart             # Player settings management
│   ├── workout/               # Workout and training module
│   │   ├── profile.dart              # User profile management
│   │   ├── workout_config_page.dart  # Workout configuration UI
│   │   └── workout_settings.dart     # Workout settings state
│   └── main.dart              # Application entry point
├── test/                      # Unit and widget tests
├── specs/                     # Documentation and specifications
│   └── heart-beat.md         # Comprehensive heart rate training guide (Japanese)
├── .gitignore                # Git ignore rules
├── .metadata                 # Flutter metadata
├── analysis_options.yaml    # Dart analysis configuration
├── pubspec.yaml             # Package dependencies and metadata
├── pubspec.lock             # Locked dependency versions
└── README.md                # Project overview and setup instructions
```

## Module Architecture

### 1. Core Application Layer (`lib/main.dart`)

**Purpose**: Application bootstrap and root widget configuration

**Key Components**:
- `HeartBeatApp`: Root MaterialApp with theme and provider setup
- `HeartRatePage`: Main heart rate monitoring interface
- Multi-provider configuration for state management

**Dependencies**:
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'player/player_page.dart';
import 'player/settings.dart';
import 'workout/workout_settings.dart';
import 'workout/workout_config_page.dart';
import 'ble/ble_service.dart';
```

**Architectural Responsibilities**:
- Application initialization and lifecycle management
- Root-level state provider configuration
- Platform-specific permission handling
- Navigation and routing setup

### 2. Bluetooth Low Energy Module (`lib/ble/`)

**Purpose**: Cross-platform BLE abstraction and heart rate sensor integration

#### 2.1 BLE Service Interface (`ble_service.dart`)
```dart
abstract class BleService {
  static BleService get instance;           // Singleton factory
  Stream<int> get heartRateStream;          // Heart rate data stream
  Future<void> initializeIfNeeded();       // Platform initialization
  Future<DeviceInfo?> scanAndConnect();    // Device discovery & connection
  Future<void> disconnect();               // Connection cleanup
}
```

#### 2.2 Platform Implementations
- **Mobile/Desktop** (`ble_service_impl_mobile.dart`): flutter_blue_plus + win_ble
- **Web** (`ble_service_impl_web.dart`): flutter_web_bluetooth API

#### 2.3 Data Processing (`heart_rate_parser.dart`)
- BLE Heart Rate Service (0x180D) data parsing
- Support for 8-bit and 16-bit heart rate formats
- Robust error handling for malformed data

#### 2.4 Type Definitions (`ble_types.dart`)
- Device information models
- Connection state enums
- BLE-specific data structures

**Architecture Pattern**: Factory + Strategy Pattern
- Abstract interface with platform-specific implementations
- Runtime platform detection and appropriate implementation selection

### 3. Media Player Module (`lib/player/`)

**Purpose**: YouTube video integration with heart rate overlay

#### 3.1 Player Interface (`player_page.dart`)
- YouTube video embedding and controls
- Real-time heart rate data overlay
- Synchronized playback with fitness content

#### 3.2 Settings Management (`settings.dart`)
```dart
class PlayerSettings extends ChangeNotifier {
  SharedPreferences _prefs;
  
  // Persistent settings for player configuration
  // Volume, quality, overlay preferences
}
```

**Integration Pattern**: 
- Uses flutter_inappwebview for YouTube embedding
- Provider pattern for settings persistence
- Stream subscription for real-time heart rate updates

### 4. Workout & Training Module (`lib/workout/`)

**Purpose**: Training configuration and user profile management

#### 4.1 Workout Configuration (`workout_config_page.dart`)
- Training zone setup interface
- Heart rate zone calculations (220-age, Karvonen method)
- Workout type selection and customization

#### 4.2 Settings State (`workout_settings.dart`)
```dart
class WorkoutSettings extends ChangeNotifier {
  WorkoutConfig _selected;
  
  // Training parameters management
  // Zone thresholds, workout types, user preferences
}
```

#### 4.3 User Profile (`profile.dart`)
- User demographic data (age, fitness level)
- Training history and preferences
- Heart rate zone calculations

**Data Flow**:
User Input → WorkoutSettings → Calculations → UI Update → Persistence

## State Management Architecture

### Provider Pattern Implementation

```
MultiProvider (Root)
├── PlayerSettings
│   ├── Video preferences
│   ├── Overlay settings
│   └── Playback configuration
└── WorkoutSettings
    ├── Training zones
    ├── User profile
    └── Workout configurations
```

### State Persistence Strategy
- **SharedPreferences**: Local key-value storage for user settings
- **Automatic Loading**: Settings loaded at app initialization
- **Change Notification**: Provider pattern for reactive UI updates

## Cross-Platform Abstraction

### Platform Detection Strategy
```dart
// Runtime platform detection
if (kIsWeb) {
  // Web-specific implementation
} else if (Platform.isWindows) {
  // Windows-specific implementation  
} else {
  // Mobile/other platforms
}
```

### Platform-Specific Implementations

#### Android
- **BLE**: flutter_blue_plus
- **Permissions**: Runtime permission requests
- **Background**: Service limitations awareness

#### Windows
- **BLE**: win_ble native integration
- **System**: Windows 10 1903+ requirement
- **Permissions**: Automatic system-level handling

#### Web
- **BLE**: Web Bluetooth API
- **Security**: HTTPS requirement
- **Browser**: Chrome/Edge compatibility

## Data Flow Architecture

### Heart Rate Data Pipeline
```
BLE Sensor
    ↓ (Bluetooth HRS Protocol)
Platform BLE Stack
    ↓ (Native Plugin Bridge)
Flutter BLE Plugin
    ↓ (Platform Channel)
BleService Implementation
    ↓ (Data Parsing)
HeartRateParser
    ↓ (Stream Processing)
Stream<int> heartRateStream
    ↓ (UI Binding)
StreamBuilder Widget
    ↓ (Display)
User Interface
```

### Settings Data Flow
```
User Input
    ↓
ChangeNotifier (Settings)
    ↓ (Parallel)
├── UI Update (notifyListeners)
└── Persistence (SharedPreferences)
```

## Error Handling Strategy

### Layered Error Handling

#### 1. BLE Layer Errors
```dart
enum BleError {
  deviceNotFound,
  connectionFailed, 
  serviceNotFound,
  permissionDenied,
  bluetoothOff
}
```

#### 2. Application Layer Errors
- Graceful degradation for connection failures
- User-friendly error messages
- Automatic retry mechanisms

#### 3. UI Layer Errors
- Loading states during connections
- Error state displays with action buttons
- Status indicators for connection health

## Testing Architecture

### Test Organization
```
test/
├── unit/
│   ├── ble/
│   │   ├── heart_rate_parser_test.dart
│   │   └── ble_service_test.dart
│   ├── workout/
│   │   └── workout_settings_test.dart
│   └── player/
│       └── settings_test.dart
├── widget/
│   ├── heart_rate_page_test.dart
│   └── workout_config_page_test.dart
└── integration/
    └── ble_connection_test.dart
```

### Testing Strategies
- **Unit Tests**: Business logic validation
- **Widget Tests**: UI component behavior
- **Integration Tests**: Cross-module interactions
- **Mock Services**: BLE service mocking for CI/CD

## Performance Considerations

### Memory Management
- **Stream Subscriptions**: Automatic cleanup in widget disposal
- **Connection Pooling**: Single active BLE connection
- **State Management**: Minimal state retention

### Real-time Performance
- **Data Streaming**: Efficient stream processing
- **UI Updates**: 60 FPS maintenance during data updates
- **Background Processing**: Minimal main thread blocking

### Battery Optimization
- **Efficient Scanning**: UUID-filtered device discovery
- **Connection Management**: Automatic background disconnection
- **Minimal Processing**: Lightweight algorithms

## Security & Privacy

### Data Protection
- **Local Processing**: No cloud data transmission
- **Minimal Permissions**: Only required permissions requested
- **Secure Storage**: Local settings encryption

### BLE Security
- **Device Filtering**: Heart rate service UUID validation
- **Connection Security**: Standard BLE security protocols
- **Data Validation**: Input sanitization and validation

## Build & Deployment Structure

### Configuration Files
- **analysis_options.yaml**: Dart static analysis rules
- **pubspec.yaml**: Dependencies and metadata
- **Platform configs**: Android, iOS, Windows, Web specific settings

### Asset Management
- **No external assets**: Minimal app bundle size
- **Platform icons**: Generated for each target platform
- **Localization**: Japanese UI text (hardcoded)

## Future Architecture Considerations

### Scalability Enhancements
- **Plugin Architecture**: Modular feature additions
- **Multi-device Support**: Concurrent BLE connections
- **Cloud Integration**: Optional analytics and sync

### Maintainability
- **Dependency Management**: Regular updates and compatibility
- **Code Quality**: Continuous refactoring and optimization
- **Documentation**: Inline documentation and API docs

This structure provides a solid foundation for a cross-platform heart rate monitoring application with clear separation of concerns, robust error handling, and scalable architecture patterns.
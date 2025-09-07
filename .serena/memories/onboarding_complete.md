# Heart Beat Flutter App - Project Overview

## Purpose
A Flutter cross-platform app (Android/Windows/Web) for heart rate monitoring using Bluetooth Low Energy (BLE) devices. Specifically designed to connect to Coospo HW9 heart rate sensors and display real-time BPM data.

## Key Features
- Real-time heart rate monitoring via BLE
- Cross-platform support (Android, Windows, Web)
- Heart rate zone-based training guidance
- YouTube video playback with heart rate data integration
- Workout configuration and settings management

## Tech Stack
- **Framework**: Flutter 3.7.2+
- **Languages**: Dart
- **BLE Libraries**: flutter_blue_plus (mobile), win_ble (Windows), flutter_web_bluetooth (Web)
- **State Management**: Provider pattern
- **Permissions**: permission_handler
- **Web Integration**: flutter_inappwebview

## Project Structure
- `lib/main.dart` - App entry point with BLE initialization
- `lib/ble/` - BLE service abstraction with platform-specific implementations
- `lib/player/` - YouTube player with heart rate integration
- `lib/workout/` - Workout configuration and settings
- `specs/` - Contains heart rate training documentation in Japanese

## Development Commands
- `flutter pub get` - Install dependencies
- `flutter run` - Run on connected device
- `flutter build [platform]` - Build for specific platform
- `flutter test` - Run tests

## Platform Support
- Android: Uses flutter_blue_plus with runtime permissions
- Windows: Uses win_ble backend
- Web: Uses flutter_web_bluetooth API

## Code Style
- Follows standard Dart conventions
- Uses provider pattern for state management
- Japanese UI text for user interface
- Null-safety enabled
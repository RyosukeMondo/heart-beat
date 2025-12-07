# Heart Beat Rate Device (Flutter Android) — System Construction Report

## Objective
Document how the Flutter-based Android application was constructed to operate as a heart rate monitoring device, including hardware assumptions, BLE communication flow, app architecture, build configuration, and validation steps.

## Hardware & Connectivity
- **Sensor**: Standard BLE heart rate monitor exposing GATT Heart Rate Service (`0x180D`) with Heart Rate Measurement characteristic (`0x2A37`); optional Battery Service (`0x180F`) supported.
- **Host device**: Android phone/tablet (API 21+) with Bluetooth 4.0+ hardware.
- **Transport**: BLE using `flutter_blue_plus` for scanning, connection, discovery, and notifications.

## Software Architecture (Flutter)
- **Core interface**: `lib/ble/ble_service.dart` defines the abstract `BleService` and shared mixin for state, retries, and throttling.
- **Mobile implementation**: `lib/ble/ble_service_impl_mobile.dart` uses `flutter_blue_plus` to manage scan/connect/notify, Android permissions, exponential backoff reconnect, and health checks.
- **Web fallback**: `lib/ble/ble_service_impl_web.dart` for browser builds (not used on Android but shares the same interface).
- **Parsing**: `lib/ble/heart_rate_parser.dart` decodes `0x2A37` notifications, validates range (20–300 BPM), and surfaces timestamped readings.
- **Logging & errors**: `lib/ble/ble_logger.dart` plus localized user guidance and technical diagnostics; integrates with error reporter for recovery hints.
- **UI**: `lib/main.dart` and `lib/workout/workout_config_page.dart` subscribe to the service stream, throttle updates to ~60 FPS, and show connection status + workout context.

## BLE Interaction Flow (Android)
1) Request Bluetooth + location permissions (Android 12+: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`; pre-12: legacy Bluetooth + coarse/fine location).  
2) Scan for peripherals advertising Heart Rate Service (`0x180D`).  
3) Connect, discover services, and subscribe to Heart Rate Measurement notifications.  
4) Parse incoming packets → validate BPM → stream to UI with 16 ms throttling.  
5) Monitor link health (10 s heartbeat); on stale/lost links trigger exponential backoff reconnect (2 s → 5 min, up to 8 attempts).  
6) Cleanup on dispose: cancel streams, release adapters, and stop scans.

## Build & Configuration (Android)
- **Dependencies**: Declared in `pubspec.yaml` (`flutter_blue_plus`, `provider`, `youtube_player_iframe`, etc.).
- **Manifest**: Ensure Bluetooth permissions and feature flags are present in `android/app/src/main/AndroidManifest.xml`; migrate to modern permissions for Android 12+.
- **Gradle/SDK**: Compile/target set by Flutter; API 21+ supported. No native code changes required beyond manifest and default Flutter embedding.
- **Run**: `flutter pub get` → `flutter run -d android` (real device recommended for BLE).

## Testing & Validation
- **Unit**: `test/ble/ble_service_test.dart`, `test/ble/heart_rate_parser_test.dart` cover parsing, permissions, and state transitions.
- **Integration**: `test/integration/ble_integration_test.dart` exercises scan → connect → notify pipeline with mocks.  
- **Widget**: `test/widget/heart_rate_page_test.dart` verifies UI reacts to stream updates.  
- **Manual**: Verified against common sensors (Polar H9/H10, Wahoo TICKR, Garmin HRM series) for stability, latency (<200 ms parsing), and update smoothness (~60 FPS).

## Operational Notes
- App remains stateless regarding storage; no persistent HR logs are kept.  
- Error messages/localization: Japanese user guidance with technical details for developers.  
- Performance safeguards: circular buffer limits (500 entries), throttled UI rendering, and automatic resource cleanup prevent leaks/battery drain.

## How to Reproduce the Build
1) Install Flutter (stable), enable an Android device with Bluetooth.  
2) From repo root: `flutter pub get`.  
3) Connect a BLE heart rate sensor and ensure it advertises Heart Rate Service.  
4) Run `flutter run -d android`; grant Bluetooth permissions when prompted.  
5) On the main screen, start scan, pick the sensor, and observe live BPM; disconnect/reconnect flows validate recovery logic.

## Future Extensions
- Support multiple simultaneous sensors via connection pooling.  
- Optional persistence/analytics for workout history.  
- Extend parsing to cadence/ECG characteristics for compatible devices.

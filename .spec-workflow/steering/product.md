# Heart Beat - Product Specification

## Product Overview

**Heart Beat** is a cross-platform Flutter application designed for real-time heart rate monitoring and training optimization using Bluetooth Low Energy (BLE) heart rate sensors. The application now emphasizes an **adaptive coaching frontend** that guides users through daily and weekly goals with clear visual cues, subjective feedback capture, and adaptive progression.

### Core Value Proposition
- **Real-time Monitoring**: Continuous heart rate tracking with instant BPM display
- **Adaptive Coaching**: Daily “charge” goal, zone guidance, and weekly adjustments based on HR data and RPE
- **Clarity Under Load**: Bar-style UI with high-contrast, glanceable state (UP/KEEP/DOWN)
- **Cross-platform Compatibility**: Seamless operation across Android, Windows, and Web platforms
- **Device Integration**: Optimized for Coospo HW9 and compatible BLE heart rate sensors

## Target Audience

### Primary Users
- **Fitness Enthusiasts**: Individuals seeking data-driven training optimization
- **Runners & Cyclists**: Athletes requiring heart rate zone training for endurance sports
- **Health-conscious Individuals**: Users monitoring cardiovascular health during exercise

### Secondary Users
- **Personal Trainers**: Professionals requiring client heart rate monitoring
- **Rehabilitation Patients**: Individuals with prescribed heart rate-controlled exercise

## Product Features

### Core Features

#### 1. Real-time Heart Rate Monitoring
- **Live BPM Display**: Large, clear numerical display of current heart rate
- **Connection Status**: Real-time device connection and data transmission status
- **Data Persistence**: Maintains last known BPM value during brief disconnections

#### 2. BLE Device Management
- **Device Discovery**: Automatic scanning for compatible heart rate sensors
- **Connection Management**: Robust connection handling with reconnection capabilities
- **Multi-platform Support**: 
  - Android: flutter_blue_plus with runtime permissions
  - Windows: win_ble backend integration
  - Web: flutter_web_bluetooth API utilization

#### 3. Adaptive Coaching UI
- **Daily Charge Bar**: Progress toward today’s target minutes inside zone
- **Zone Meter**: UP/KEEP/DOWN cues with color semantics (blue, green/orange, red)
- **Contextual Messages**: State-based prompts for motivation and safety

#### 4. Training Logic
- **Zone Calculation**: Tanaka MaxHR + Karvonen HRR for individualized targets
- **Goal Modes**: Maintenance vs improvement weekly prescriptions
- **Adaptive Loop**: Weekly adjustments driven by completion + RPE feedback

#### 5. Multimedia Integration
- **YouTube Player**: Integrated video playback with heart rate overlay
- **Heart Rate Synchronization**: Real-time BPM data display during video content
- **Workout Videos**: Support for guided training video content

### Advanced Features

#### 1. Settings & Profiles
- **User Preferences**: Persistent storage of user settings and configurations
- **Profile Inputs**: Age, resting HR, goals, and subjective effort (RPE) capture
- **Permission Management**: Automatic handling of platform-specific permissions

#### 2. Cross-platform Optimization
- **Responsive Design**: Adaptive UI for different screen sizes and orientations
- **Platform-specific Features**: Optimized functionality per operating system
- **Web Compatibility**: Full feature set available in web browsers

## Technical Requirements

### Performance Specifications
- **Connection Latency**: < 2 seconds for BLE device discovery and connection
- **Data Refresh Rate**: Real-time BPM updates (typically 1-2 Hz from sensor)
- **Battery Optimization**: Minimal impact on device battery life
- **Memory Usage**: Lightweight application footprint

### Compatibility Requirements
- **Flutter SDK**: 3.7.2 or higher
- **Android**: API level 21+ (Android 5.0)
- **Windows**: Windows 10 version 1903 or higher
- **Web**: Modern browsers with Web Bluetooth support
- **BLE Devices**: Heart Rate Service (HRS) compatible sensors

## User Experience Design

### Interface Principles
- **Minimalist Design**: Clean, uncluttered interface focusing on essential data
- **High Contrast**: Clear visibility during exercise conditions
- **Large Touch Targets**: Easy interaction during physical activity
- **Immediate Feedback**: Instant response to user actions
- **Glanceable Semantics**: UP/KEEP/DOWN cues and daily progress always visible

### Accessibility
- **Font Sizing**: Large, readable text for heart rate display
- **Color Coding**: Intuitive color schemes for different heart rate zones (blue/green-orange/red)
- **Status Indicators**: Clear visual and textual status communication
- **Error Handling**: User-friendly error messages and recovery guidance

## Success Metrics

### Primary KPIs
- **Connection Success Rate**: >95% successful BLE connections
- **Data Accuracy**: Heart rate readings within ±2 BPM of reference devices
- **User Retention**: >70% monthly active user retention
- **Session Duration**: Average workout session >20 minutes

### Secondary Metrics
- **Platform Distribution**: Usage across Android, Windows, and Web
- **Feature Adoption**: Utilization of training zones and multimedia features
- **Error Rate**: <5% application crashes or connection failures
- **User Satisfaction**: >4.5/5 rating in app stores

## Development Roadmap

### Phase 1: Core Functionality (Current)
- ✅ BLE heart rate sensor integration
- ✅ Real-time BPM display
- ✅ Cross-platform compatibility
- ✅ Basic settings management

### Phase 2: Enhanced Training Features
- 🔄 Advanced workout zone configurations
- 🔄 Training history and analytics
- 🔄 Multiple sensor support
- 🔄 Export capabilities

### Phase 3: Advanced Integration
- 📋 Fitness app integrations (Strava, Google Fit)
- 📋 Advanced analytics and reporting
- 📋 Social features and sharing
- 📋 Wearable device support

## Risk Assessment

### Technical Risks
- **BLE Connectivity**: Platform-specific BLE implementation challenges
- **Permission Changes**: Evolving mobile OS permission requirements
- **Sensor Compatibility**: Variability in BLE heart rate sensor implementations

### Market Risks
- **Competition**: Established fitness tracking applications
- **Hardware Dependency**: Reliance on specific BLE sensor availability
- **Platform Changes**: Flutter framework and OS API evolution

### Mitigation Strategies
- **Robust Error Handling**: Comprehensive connection failure recovery
- **Multi-sensor Support**: Compatibility with various BLE heart rate devices
- **Regular Updates**: Continuous framework and platform compatibility updates
- **User Support**: Clear documentation and troubleshooting guides

## Conclusion

Heart Beat represents a focused, technically robust solution for heart rate-based fitness training. By combining precise BLE sensor integration with scientific training principles and cross-platform accessibility, the application addresses the core needs of data-driven fitness enthusiasts while maintaining simplicity and reliability.

The product's success will be measured through connection reliability, data accuracy, and user engagement metrics, with continuous development focused on enhancing the core heart rate monitoring experience while expanding training and integration capabilities.

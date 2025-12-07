# Frontend Rebuild for Adaptive Heart Rate Coach

## Introduction
Rebuild the Flutter frontend to deliver the adaptive coaching experience described in `docs/spec.md`, shifting from a passive monitor to an action-oriented daily/weekly coach with clear visual cues and subjective feedback capture.

## Alignment with Product Vision
Supports Heart Beat’s vision of an adaptive coaching companion by emphasizing glanceable guidance (UP/KEEP/DOWN), daily progress visibility, and weekly adjustments aligned to scientific HRR calculations.

## Requirements

### Requirement 1 — Daily Coaching Surface
**User Story:** As a fitness enthusiast, I want a “Daily Charge” surface that shows how much of today’s target I have completed so I can stay motivated during workouts.

#### Acceptance Criteria
1. WHEN a session is active AND current HR is within target zone THEN the Daily Charge bar SHALL increment time inside zone and display “X / Y mins”.
2. IF the app loses sensor connection THEN the Daily Charge bar SHALL pause accumulation and show a reconnect prompt.
3. WHEN the day changes (local time) THEN the Daily Charge bar SHALL reset progress and load the new day’s target.

### Requirement 2 — Real-time Zone Guidance
**User Story:** As a user in a workout, I want clear real-time cues to speed up or slow down so I can stay in the target heart rate zone.

#### Acceptance Criteria
1. WHEN BPM < targetLower THEN the Zone Meter SHALL display “UP ↑” with blue state and haptic/visual emphasis.
2. WHEN BPM within [targetLower, targetUpper] THEN the Zone Meter SHALL display “KEEP ⟷” with green→orange gradient and a gentle pulse animation.
3. WHEN BPM > targetUpper THEN the Zone Meter SHALL display “DOWN ↓” with red state and safety copy; cues update within 300 ms of new BPM samples.

### Requirement 3 — Session Summary with RPE
**User Story:** As a trainee, I want to log how hard the session felt so the coach can adjust future targets.

#### Acceptance Criteria
1. WHEN a session ends THEN a summary SHALL show total time in zone, max/avg BPM, and a required RPE input (1–10 scale).
2. WHEN the user submits RPE THEN the value SHALL be persisted with the session record and surfaced to the weekly adaptive logic.
3. IF the user dismisses the summary without RPE THEN the app SHALL prompt once more; skipping leaves the session marked “RPE missing”.

### Requirement 4 — Weekly Adaptive Loop
**User Story:** As a returning user, I want weekly adjustments based on my completion and RPE so the plan stays appropriate.

#### Acceptance Criteria
1. WHEN the week ends THEN the system SHALL compute completion % of planned minutes and average RPE.
2. IF completion ≥ target AND avg RPE < “Hard” (<=6/10) THEN next week’s daily target SHALL increase by 10% (rounded to nearest minute) and intensity band +2% HRR.
3. IF completion < 70% OR avg RPE ≥ 8 THEN next week SHALL hold or reduce targets (no increase) and show guidance in the weekly report surface.

### Requirement 5 — Device & Permission Resilience
**User Story:** As a mobile user, I want the app to handle BLE permissions and reconnections seamlessly so workouts are not interrupted.

#### Acceptance Criteria
1. WHEN launching or starting a session on Android 12+ THEN the app SHALL request `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` and block start until granted.
2. WHEN connection drops THEN the app SHALL retry with exponential backoff and show inline status without exiting the session screen.
3. WHEN a reconnect succeeds THEN streaming SHALL resume automatically and UI SHALL continue accumulating Daily Charge with a gap indicator for missing time.

## Non-Functional Requirements

### Code Architecture and Modularity
- Single Responsibility: UI widgets (Daily Charge, Zone Meter, Session Summary) isolated from data sources.
- Clear Interfaces: Coaching logic exposed via Riverpod providers; BLE hidden behind `BleService`.
- Reusability: Animations and color semantics centralized for consistent use.

### Performance
- Zone cue latency: <300 ms from new BPM sample to UI update.
- UI frame rate: Maintain 60 FPS during active session animations.
- Storage: Local session writes must not block UI thread (>16 ms).

### Security
- Permissions: Request minimal Bluetooth/location permissions; no extra sensors.
- Data locality: Session and RPE data remain on-device; no network sync.
- Validation: Reject BPM outside 20–300 range before applying to coaching logic.

### Reliability
- Reconnection: Up to 8 attempts with exponential backoff before surfacing a hard failure.
- Persistence: Session and RPE data safely written even if app is backgrounded immediately after end-session action.
- Error UX: User-facing copy for connection/permission errors with actionable steps.

### Usability
- Glanceability: Primary cues (UP/KEEP/DOWN) and Daily Charge progress visible at arm’s length.
- Accessibility: High-contrast colors, large targets, and voice-over labels for key widgets.
- Localization: Support existing Japanese localization strings for new surfaces.

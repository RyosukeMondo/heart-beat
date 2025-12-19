# Tasks Document — Frontend Rebuild for Adaptive Heart Rate Coach

- [x] 1. Implement coaching controller and state
  - Files: `lib/workout/coaching_controller.dart`, `lib/workout/coaching_state.dart`
  - Create Riverpod `StateNotifier` to compute zone cue (up/keep/down), track minutes-in-zone, and expose view model.
  - Handle start/end session, onHeartRate updates, day rollover reset, and invalid BPM filtering (20–300).
  - _Leverage: `lib/ble/ble_service.dart`, `lib/ble/heart_rate_parser.dart`, `lib/workout/workout_settings.dart`, `lib/workout/profile.dart`_
  - _Requirements: 1, 2, 3, 5_
  - _Prompt: Implement the task for spec frontend-rebuild, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter engineer with Riverpod expertise | Task: Build coaching controller/state that consumes BleService stream, computes cue, tracks minutes-in-zone, handles day reset and session lifecycle, and filters invalid BPM per requirements 1/2/3/5 | Restrictions: Do not modify BleService APIs; keep calculations pure and deterministic; maintain <300 ms cue latency | _Leverage: lib/ble/ble_service.dart; lib/ble/heart_rate_parser.dart; lib/workout/workout_settings.dart; lib/workout/profile.dart_ | _Requirements: 1,2,3,5_ | Success: State updates correctly in unit tests for under/inside/over zone, rollover reset works, invalid BPM ignored_

- [x] 2. Build DailyChargeBar widget
  - File: `lib/workout/daily_charge_bar.dart`
  - Render progress toward today’s target minutes with paused/reconnecting states and gap notice; animate fill without stutter.
  - _Leverage: `lib/workout/coaching_state.dart`, theme tokens_
  - _Requirements: 1, 5, Usability_
  - _Prompt: Implement the task for spec frontend-rebuild, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter UI engineer | Task: Create DailyChargeBar widget that consumes coaching state to display achieved/target minutes, paused/reconnecting states, and smooth animated progress per requirements 1 and 5 | Restrictions: Keep 60 FPS; no heavy rebuilds; use theme colors; ensure accessibility labels | _Leverage: lib/workout/coaching_state.dart; theme_ | _Requirements: 1,5,Usability_ | Success: Widget matches states in golden/widget tests and animates smoothly without dropped frames_

- [x] 3. Build ZoneMeter widget with cues
  - File: `lib/workout/zone_meter.dart`
  - Display UP/KEEP/DOWN cue, BPM, target range, color semantics (blue/green→orange/red), and pulse animation in KEEP.
  - _Leverage: `lib/workout/coaching_state.dart`, shared animation helpers (to be added if missing)_
  - _Requirements: 2, Usability, Performance_
  - _Prompt: Implement the task for spec frontend-rebuild, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter animation specialist | Task: Build ZoneMeter widget with real-time cue updates and animations that respond within 300 ms to BPM changes per requirement 2 | Restrictions: Avoid setState polling; rely on Riverpod consumers; keep animations lightweight | _Leverage: lib/workout/coaching_state.dart_ | _Requirements: 2,Usability,Performance_ | Success: Widget tests validate cue transitions and color semantics for under/inside/over zone; animation stays at 60 FPS_

- [x] 4. Add session summary with required RPE persistence
  - Files: `lib/workout/session_summary_sheet.dart`, `lib/workout/session_repository.dart`
  - Present end-of-session sheet with metrics (time in zone, avg/max BPM) and required RPE input; persist SessionRecord with RPE; handle “RPE missing” state if skipped.
  - _Leverage: `lib/workout/coaching_controller.dart`, `lib/workout/coaching_state.dart`, `lib/workout/profile.dart`_
  - _Requirements: 3, Reliability, Security_
  - _Prompt: Implement the task for spec frontend-rebuild, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter + local persistence engineer | Task: Build session summary UI and repository to store SessionRecord with RPE per requirement 3; ensure safe writes and retry-friendly API | Restrictions: On-device only; no network; writes must be async without blocking UI; expose methods for later weekly calculations | _Leverage: lib/workout/coaching_controller.dart; lib/workout/profile.dart_ | _Requirements: 3,Reliability,Security_ | Success: Repository unit tests cover save/read; widget tests ensure RPE required prompt and “RPE missing” handling_

- [x] 5. Implement weekly adaptive logic
  - File: `lib/workout/weekly_adapter.dart`
  - Compute next-week plan based on completion % and avg RPE; apply +10% progression when easy, hold/regress when underperformed or high RPE; persist updated plans.
  - _Leverage: `lib/workout/session_repository.dart`, `lib/workout/workout_settings.dart`, `lib/workout/profile.dart`_
  - _Requirements: 4, Reliability_
  - _Prompt: Implement the task for spec frontend-rebuild, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Algorithms engineer for training logic | Task: Implement weekly_adapter to calculate plan deltas per requirement 4 using stored sessions and profiles | Restrictions: Deterministic calculations; no floating rounding errors; ensure idempotent weekly runs | _Leverage: lib/workout/session_repository.dart; lib/workout/workout_settings.dart; lib/workout/profile.dart_ | _Requirements: 4,Reliability_ | Success: Unit tests cover progression, hold, and regress scenarios with precise rounding rules_

- [x] 6. Integrate coaching UI into main experience
  - Files: `lib/main.dart` (wiring), `lib/workout/workout_config_page.dart` (plan selection), `lib/player/player_page.dart` (overlay hookup as needed)
  - Replace legacy frontend segments with new DailyChargeBar, ZoneMeter, and summary flow; ensure permissions gate session start and reconnection banners surface inline.
  - _Leverage: `lib/ble/ble_service.dart`, `lib/workout/coaching_controller.dart`, `lib/workout/zone_meter.dart`, `lib/workout/daily_charge_bar.dart`, localization strings_
  - _Requirements: 1,2,3,5,Usability_
  - _Prompt: Implement the task for spec frontend-rebuild, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter integration engineer | Task: Wire new coaching UI into main flow, enforce permission gating, reconnection UX, and session summary flow per requirements 1/2/3/5 | Restrictions: Do not regress existing BLE handling; keep overlays responsive; maintain localization support | _Leverage: lib/ble/ble_service.dart; lib/workout/coaching_controller.dart; UI widgets_ | _Requirements: 1,2,3,5,Usability_ | Success: Manual flow test passes (connect → cues → summary with RPE); widget/integration tests updated; old UI elements removed or hidden_

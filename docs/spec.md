I have compiled all the requirements, design concepts, scientific logic, and technical architecture into a comprehensive specification document (`spec.md`).

You can copy the content below and save it as `spec.md`.

---

````markdown
# Heart Rate Coach: Adaptive Monitoring System Specification

**Version:** 1.0.0
**Platform:** Android (via Flutter)
**Date:** 2025-12-07

---

## 1. Executive Summary

This document outlines the specifications for a Flutter-based Android application designed to transition from a passive heart rate monitor to an active **Personal Health Coach**. The system leverages Bluetooth Low Energy (BLE) to monitor heart rate in real-time and uses scientific indicators (Karvonen method) to plan, encourage, and adapt exercise intensity for the user.

### Core Value Proposition

- **Scientific Accuracy:** Uses Heart Rate Reserve (HRR) rather than simple age-based maximums.
- **Action-Oriented:** "Daily Charge" visualization to motivate completion of daily quotas.
- **Adaptive Feedback:** A weekly review loop that adjusts difficulty based on performance and subjective feedback (RPE).

---

## 2. Scientific Logic & Algorithms

### 2.1. Heart Rate Calculations

The system uses the **Karvonen Method** to determine target intensity zones, which accounts for individual fitness levels via Resting Heart Rate (RHR).

#### Formulas

1.  **Max Heart Rate (MaxHR):** Using the Tanaka Equation (more accurate for adults).
    $$\text{MaxHR} = 208 - (0.7 \times \text{Age})$$
2.  **Heart Rate Reserve (HRR):**
    $$\text{HRR} = \text{MaxHR} - \text{RestingHR}$$
3.  **Target Heart Rate (TargetHR):**
    $$\text{TargetHR} = (\text{HRR} \times \text{Intensity\%}) + \text{RestingHR}$$

### 2.2. Intensity Zones

| Zone       | Intensity (%) | Description        | User Goal                            |
| :--------- | :------------ | :----------------- | :----------------------------------- |
| **Zone 1** | 50% - 60%     | Warm Up / Recovery | Basic health, warm-up                |
| **Zone 2** | 60% - 70%     | Fat Burn (Base)    | Weight loss, endurance base          |
| **Zone 3** | 70% - 80%     | Aerobic (Cardio)   | Cardiovascular improvement           |
| **Zone 4** | 80% - 90%     | Anaerobic (Hard)   | High-speed endurance                 |
| **Zone 5** | 90% - 100%    | Maximum            | **Warning Zone** (Short bursts only) |

### 2.3. Planning Algorithm (WHO/ACSM Guidelines)

- **Maintenance Mode:** Target ~150 minutes/week of Moderate Intensity (Zone 2-3).
- **Improvement Mode:** Target ~75 minutes/week of Vigorous Intensity (Zone 4) OR ~200 minutes Mixed.
- **Progression Rule:** If weekly goal achieved + Avg RPE (Rating of Perceived Exertion) < "Hard", increase volume by 10% next week.

---

## 3. User Experience (UX) Flow

### Phase 1: Onboarding (One Time)

1.  **User Input:** Age, Gender, Current Activity Level.
2.  **Calibration:** \* Instruction: "Sit still for 1 minute."
    - Action: Measure average HR to establish **RestingHR**.
3.  **Goal Setting:** Select "Weight Loss", "Cardio Health", or "Maintenance".

### Phase 2: The Daily Loop

1.  **Notification (Morning):** "Your goal today: 30 mins in Zone 2."
2.  **Action (Workout):** User opens app -> Connects Sensor -> Starts Session.
3.  **Real-time Guidance:** Visual feedback (Bar UI) guides user to speed up or slow down.
4.  **Completion:** Session summary displayed. User inputs **RPE** (Subjective feeling: 1-10).

### Phase 3: The Adaptive Loop (Weekly)

1.  **Review:** Sunday night report. "You hit 90% of your targets."
2.  **Adjustment:** "Your heart rate is lower for the same work. Let's increase target intensity by 2% next week."

---

## 4. UI/Design Specifications

### 4.1. Design Philosophy

- **Bar-Style Wireframe:** High contrast, minimal text, readable at a glance (arm's length).
- **Color Semantics:**
  - **Blue:** Below Target (Cold)
  - **Green/Orange Gradient:** In Target Zone (Active)
  - **Red:** Above Target (Warning)

### 4.2. Main Dashboard Components

#### A. The "Daily Charge Bar" (Top Section)

- **Visual:** A horizontal progress bar representing the _Volume_ of exercise required today.
- **Behavior:** Fills up as time is spent _inside_ the target zone.
- **Text:** "15 / 30 mins achieved"

#### B. The "Zone Meter" (Middle Section)

- **Visual:** A dynamic scale representing _Intensity_ (Real-time BPM).
- **Indicator:** A prominent needle or marker moving along the scale.
- **Feedback:** \* If `Current < Target`: Display "UP ↑"
  - If `Current == Target`: Display "KEEP ⟷" (Pulsing animation)
  - If `Current > Target`: Display "DOWN ↓"

#### C. Action & Message (Bottom Section)

- **Contextual Text:** Large, bold messages triggered by state changes.
  - _Example:_ "Zone Reached! Hold it!"
- **Controls:** Big buttons for [START], [PAUSE], [STOP].

---

## 5. Technical Architecture (Flutter/Android)

### 5.1. Tech Stack

- **Language:** Dart (Flutter)
- **Communication:** `flutter_blue_plus` (Reuse existing stable connection layer).
- **State Management:** `flutter_riverpod` (For managing streams of BLE data vs. UI state).
- **Local Database:** `drift` or `isar` (High-performance NoSQL for storing time-series HR data).
- **Background Tasks:** `flutter_background_service` + `flutter_local_notifications` (To keep monitoring active when screen is off and send prompts).

### 5.2. Data Model (Schema Concept)

```dart
// User Profile
class UserProfile {
  int id;
  int age;
  int restingHeartRate;
  int maxHeartRate; // Calculated
  DateTime lastUpdated;
}

// Daily Plan
class DailyPlan {
  DateTime date;
  int targetZoneMinBpm;
  int targetZoneMaxBpm;
  int targetDurationMinutes;
  int achievedDurationMinutes;
  bool isCompleted;
}

// Workout Session
class Session {
  int id;
  DateTime startTime;
  DateTime endTime;
  int averageBpm;
  int maxBpm;
  int subjectiveRpe; // 1-10 scale input by user
}
```
````

### 5.3. Notification Strategy

- **Trigger:** Time-based (Scheduled) AND Event-based.
- **Logic:**
  - If `DailyPlan.achieved < DailyPlan.target` AND `Time > 18:00`: Send "Still time to close your ring\! 10 mins left."

---

## 6\. Implementation Roadmap

1.  **Refactor:** Isolate existing BLE logic into a robust `Repository` class.
2.  **Database:** Set up Drift/Isar to store User Profile and Plans.
3.  **Logic Core:** Implement `KarvonenCalculator` and `PlanGenerator` classes.
4.  **UI Construction:** Build the `ZoneMeter` and `DailyChargeBar` widgets.
5.  **Integration:** Connect BLE Stream -\> Logic -\> UI.
6.  **Background:** Implement Android foreground service for uninterrupted recording.

<!-- end list -->

```

***

### Next Steps for You

Since you already have the BLE connection working:

1.  **Download this `spec.md`** to keep as your project blueprint.
2.  I recommend starting with the **"Logic Core"**. Would you like me to write the Dart class for the `KarvonenCalculator` so you can verify the "scientific" part first?
```

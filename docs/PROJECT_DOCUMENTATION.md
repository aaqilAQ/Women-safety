# 📐 Project Documentation — SafeStep Women Safety Application

**Version:** 1.0.0  
**Date:** February 2026  
**Platform:** Android (Flutter)  
**Academic Context:** Regional College Project — Women Safety Technology  

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Problem Statement](#2-problem-statement)
3. [Objectives](#3-objectives)
4. [System Architecture](#4-system-architecture)
5. [Module Documentation](#5-module-documentation)
6. [Database Design](#6-database-design)
7. [API & Service Documentation](#7-api--service-documentation)
8. [UI/UX Flow](#8-uiux-flow)
9. [Algorithm Documentation](#9-algorithm-documentation)
10. [Security Design](#10-security-design)
11. [Testing Strategy](#11-testing-strategy)
12. [Deployment Guide](#12-deployment-guide)
13. [Known Issues & Limitations](#13-known-issues--limitations)
14. [Future Enhancements](#14-future-enhancements)
15. [References](#15-references)

---

## 1. Project Overview

### 1.1 Introduction

**SafeStep** is a mobile application designed to enhance personal safety for women. The application provides a multi-modal emergency alert system that can be triggered through:
- **Voice commands** (say "help")
- **Phone shaking** 
- **Volume button presses**
- **Manual button press** in the app

When triggered, the system automatically:
1. Retrieves the user's GPS location
2. Constructs a detailed emergency SMS message
3. Sends it to all pre-configured emergency contacts
4. Starts recording ambient audio as evidence

### 1.2 Scope

| In Scope | Out of Scope |
|---|---|
| Android mobile application | iOS support (planned) |
| SMS-based emergency alerts | Push notification alerts |
| GPS location sharing | Real-time location tracking |
| Voice keyword detection | Custom ML model training |
| Background monitoring service | Wearable device integration |
| Firebase authentication | Biometric authentication |
| Contact management | Group/broadcast alerts |

### 1.3 Stakeholders

| Role | Responsibility |
|---|---|
| **Developer** | Design, implement, test the application |
| **End User** | Women using the app for personal safety |
| **Emergency Contacts** | Family/friends receiving SOS alerts |
| **College Faculty** | Academic review and evaluation |

---

## 2. Problem Statement

Women's personal safety remains a critical concern in India and globally. Existing solutions often require deliberate, visible actions (pressing a button, opening an app) that may not be possible in dangerous situations where the attacker is watching.

**Key Gaps Identified:**
1. Manual SOS apps require visible phone interaction
2. SMS-only solutions don't include location
3. No existing app combines voice + shake + button triggers
4. Background services often terminate, leaving users unprotected
5. Complex setup discourages actual use

**SafeStep addresses these gaps** by providing a discreet, multi-modal, always-on system that activates with natural actions like saying "help" or shaking the phone.

---

## 3. Objectives

### 3.1 Primary Objectives

1. **Develop** a real-time emergency alert system for Android
2. **Implement** three independent trigger mechanisms (voice, shake, buttons)
3. **Integrate** GPS location sharing in emergency messages
4. **Build** a reliable background service that survives app closure
5. **Ensure** instant SMS delivery to trusted contacts

### 3.2 Secondary Objectives

1. Provide simple, non-technical user interface
2. Support offline operation (cached contacts, local storage)
3. Allow customization of trigger sensitivity
4. Record audio evidence during emergencies
5. Provide Hindi language voice command support

---

## 4. System Architecture

### 4.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SAFESTEP ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   ┌─────────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│   │   PRESENTATION  │    │   BUSINESS LOGIC │    │  DATA LAYER   │  │
│   │     LAYER       │    │     LAYER        │    │               │  │
│   ├─────────────────┤    ├──────────────────┤    ├───────────────┤  │
│   │ • home_screen   │    │ • AlertService   │    │ • Firebase    │  │
│   │ • auth_screen   │◀──▶│ • EmergDet.      │◀──▶│   Firestore  │  │
│   │ • config_page   │    │ • VoiceService   │    │ • SharedPrefs │  │
│   │ • contacts_scr  │    │ • SmsService     │    │ • Hive DB     │  │
│   │ • voice_train   │    │ • AuthService    │    │ • Filesystem  │  │
│   └─────────────────┘    └──────────────────┘    └───────────────┘  │
│                                   │                                   │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                    BACKGROUND LAYER                          │   │
│   │  BackgroundService (flutter_background_service)              │   │
│   │  • Runs as Android Foreground Service                        │   │
│   │  • Initializes EmergencyDetector in background isolate       │   │
│   │  • Survives app closure                                      │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                       │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                    NATIVE/PLATFORM LAYER                     │   │
│   │  • SMS Sender Plugin (custom Kotlin plugin)                  │   │
│   │  • Android Permissions (via permission_handler)              │   │
│   │  • Volume Button Stream (PerfectVolumeControl)               │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Flutter Isolate Architecture

```
MAIN ISOLATE (UI Thread)
├── Flutter Widget Tree
├── Provider (AuthService)
├── EmergencyDetector (foreground monitoring)
└── VoiceService (foreground listening)

BACKGROUND ISOLATE (Android Service)
├── BackgroundService entry point
├── DatabaseHelper.init() (Hive)
├── EmergencyDetector (background monitoring)
└── VoiceService (background listening)

Communication: FlutterBackgroundService.invoke('event')
```

### 4.3 Technology Choices & Rationale

| Choice | Alternative | Reason |
|---|---|---|
| Flutter | React Native / Native | Single codebase, fast UI, strong plugin ecosystem |
| Firebase Auth | Custom backend | Rapid development, secure, scalable |
| Firestore | PostgreSQL/MySQL | Document-based, real-time sync, Firebase integration |
| SharedPreferences | SQLite | Works across isolates, simpler for key-value data |
| Hive | SQLite | Isolate-safe, doesn't require platform channel |
| speech_to_text | Custom ML | Ready-to-use, device-native speech engine |
| Custom SMS plugin | url_launcher | Sends SMS without user confirmation dialog |

---

## 5. Module Documentation

### 5.1 AlertService (`alert_service.dart`)

**Purpose:** Orchestrates the complete SOS alert workflow

**Responsibilities:**
- Prevent duplicate alerts (`_isAlertInProgress` flag)
- Load user name and contacts from SharedPreferences
- Fetch GPS coordinates via Geolocator
- Compose detailed SMS message with location
- Dispatch SMS to all contacts via SmsService
- Start audio recording
- Show UI feedback (snackbar, navigation)

**Key Method:**
```dart
Future<void> triggerAlert() async
```

**State Machine:**
```
IDLE → IN_PROGRESS → (get location) → (build SMS) → (send SMS) → COMPLETE → IDLE
```

---

### 5.2 EmergencyDetector (`emergency_detector.dart`)

**Purpose:** Singleton that manages all trigger detection streams simultaneously

**Responsibilities:**
- Read settings from SharedPreferences
- Initialize VoiceService (if enabled)
- Subscribe to accelerometer stream (shake detection)
- Subscribe to volume button stream (button detection)
- Call AlertService on any trigger

**Triggers Managed:**

| Trigger | Detection Method | Threshold |
|---|---|---|
| Shake | AccelerometerEvent X/Y/Z | Configurable (default: 25.0 m/s²) |
| Voice | speech_to_text keyword match | Any trigger word in recognized speech |
| Volume (rapid) | 5 presses within 1 second | 5 events within 1000ms window |
| Volume (hold) | Rapid event stream (hold detection) | 10 events within 100ms window |

**Force Restart Feature:**
When the foreground app starts, it calls `startMonitoring(forceRestart: true)` to ensure foreground monitoring overrides background and all triggers are freshly initialized.

---

### 5.3 VoiceService (`voice_service.dart`)

**Purpose:** Continuous keyword detection service with reliable auto-restart

**Architecture:**
```
init() → _initEngine() [ONCE — sets callbacks]
             │
startListening() → _beginListening() → speech.listen()
                                             │
                              onStatus('done') / onError()
                                             │
                              _scheduleRestartIfEnabled()
                                             │
                         check voice_enabled in SharedPreferences
                                    │           │
                                [true]       [false]
                                    │           │
                              _beginListening() STOP (stay off)
```

**Key Design Decision:** `initialize()` is called **only once** at startup. Every restart only calls `listen()`. This prevents the Android bug where calling `initialize()` repeatedly returns `false`.

**Trigger Word Sources:**
- **Hardcoded baseline:** help, sos, emergency, bachao, madad
- **User-configured:** from SharedPreferences `custom_voice_triggers`

---

### 5.4 SmsService (`sms_service.dart`)

**Purpose:** Sends SMS directly without any user-facing dialog

**Implementation:**
- Uses a custom Kotlin native plugin (`sms_sender`)
- Communicates via Flutter Platform Channel
- Supports multi-SIM selection
- Returns delivery status per contact

**Platform Channel:**
```dart
MethodChannel: 'sms_sender'
Method: 'sendSMS'
Arguments: {phone: String, message: String}
```

---

### 5.5 BackgroundService (`background_service.dart`)

**Purpose:** Keeps the app monitoring even when the UI is closed

**Type:** Android `FOREGROUND_SERVICE` (shows persistent notification)

**Lifecycle:**
```
Service Start → (background isolate created)
              → Hive.initFlutter() [isolate init]
              → DatabaseHelper.init()
              → EmergencyDetector().startMonitoring()
              → [listen for 'stopService' / 'refreshSettings' events]
```

**Events:**
| Event | Handler |
|---|---|
| `stopService` | Terminates the service |
| `refreshSettings` | Re-reads SharedPreferences, restarts monitoring |

---

### 5.6 AuthService (`auth_service.dart`)

**Purpose:** All Firebase Authentication operations

**Methods:**

| Method | Description |
|---|---|
| `registerUser(email, password, name, phone)` | Create new account |
| `loginUser(email, password)` | Sign in existing user |
| `signOut()` | Log out and navigate to auth screen |
| `getUser(uid)` | Fetch UserModel from Firestore |
| `updateContacts(uid, contacts)` | Save emergency contacts to Firestore |

---

### 5.7 DatabaseHelper (`database_helper.dart`)

**Purpose:** Local Hive database for contact persistence across isolates

**Box Name:** `contacts`

**Operations:**

| Method | Description |
|---|---|
| `init()` | Initialize Hive, open contacts box |
| `saveAllContacts(contacts)` | Write all contacts (full replace) |
| `getContacts()` | Read all contacts from box |
| `clearContacts()` | Remove all contacts |

**Isolate Safety:** Hive does not use platform channels, making it safe to call from background isolates where `sqflite` would throw `MissingPluginException`.

---

## 6. Database Design

### 6.1 Firebase Firestore Schema

```
firestore/
└── users/
    └── {uid}/
        ├── name: "Priya Sharma"
        ├── phone: "+919876543210"
        ├── email: "priya@example.com"
        ├── isActive: true
        └── emergencyContacts: [
                {name: "Mom", phone: "+911234567890", relation: "Mother"},
                {name: "Sis", phone: "+919988776655", relation: "Sister"}
            ]
```

### 6.2 SharedPreferences Keys

| Key | Type | Description |
|---|---|---|
| `cached_user_name` | String | User's display name |
| `cached_contacts` | JSON String | Emergency contacts array |
| `voice_trained` | Boolean | Whether voice setup is done |
| `custom_voice_triggers` | StringList | User's custom wake words |
| `shake_enabled` | Boolean | Shake trigger on/off |
| `voice_enabled` | Boolean | Voice trigger on/off |
| `hold_button_enabled` | Boolean | Button trigger on/off |
| `shake_threshold_x/y/z` | Double | Shake sensitivity |
| `button_trigger_type` | String | `volume` or `power` |

### 6.3 Hive Storage

| Box | Key | Value Type |
|---|---|---|
| `contacts` | Integer index | Map (contact data) |

---

## 7. API & Service Documentation

### 7.1 Firebase Authentication API

```dart
// Registration
FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: email,
  password: password,
)

// Login
FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
)

// Auth state stream (used in AuthWrapper)
FirebaseAuth.instance.authStateChanges()
```

### 7.2 Geolocator API

```dart
// Check & request permissions
await Geolocator.checkPermission();
await Geolocator.requestPermission();

// Get current position
Position position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
);
```

### 7.3 speech_to_text API

```dart
// Initialize once
bool available = await _speech.initialize(
  onStatus: (status) { ... },
  onError: (error) { ... },
);

// Start listening (NOT awaited — fires callbacks async)
_speech.listen(
  onResult: (result) {
    String heard = result.recognizedWords;
    // Check for trigger words
  },
  listenFor: Duration(seconds: 30),
  pauseFor: Duration(seconds: 10),
  listenOptions: SpeechListenOptions(partialResults: true),
);

// Stop
await _speech.stop();
await _speech.cancel();
```

### 7.4 Platform Channel — SMS Sender

```dart
// Flutter side
static const _channel = MethodChannel('sms_sender');

await _channel.invokeMethod('sendSMS', {
  'phone': phoneNumber,
  'message': messageText,
});
```

```kotlin
// Kotlin (Android) side — plugins/sms_sender/
channel.setMethodCallHandler { call, result ->
    if (call.method == "sendSMS") {
        val phone = call.argument<String>("phone")
        val message = call.argument<String>("message")
        // Use SmsManager.sendTextMessage()
        result.success(true)
    }
}
```

---

## 8. UI/UX Flow

### 8.1 App Navigation Map

```
App Launch
    │
    ▼
AuthWrapper (StreamBuilder)
    │
    ├─── [Not logged in] ──▶ AuthScreen
    │                            ├── Login Tab
    │                            └── Register Tab
    │
    └─── [Logged in] ──────▶ HomeScreen (with Drawer)
                                  │
                    ┌─────────────┼──────────────┐
                    ▼             ▼               ▼
              ContactsScreen  ConfigPage    VoiceTrainingPage
              (manage trusted (trigger      (set trigger words)
               contacts)       settings)
                    │             │               │
              ContactDetail  ShakeTraining   Word saved →
              Page           Wizard          Done screen
                    
              Also from Drawer:
              ├── ProfilePage
              ├── ComplaintsPage
              ├── HistoryScreen
              ├── SettingsScreen
              └── StealthScreen
```

### 8.2 Emergency Alert Flow (User Perspective)

```
1. User enables Protection on HomeScreen
           │
2. SafeStep starts background monitoring
           │
3. Trigger event occurs (voice / shake / button)
           │
4. 🔴 RED snackbar: "SOS Triggered! Opening tracker..."
           │
5. SMS sent to all contacts with GPS location
           │
6. Audio recording starts
           │
7. SOS Status screen shows delivery confirmations
```

### 8.3 First-Time Setup Flow

```
Download App → Register → Add Contacts → Enable Protection
                              │
                         (Optional)
                              ▼
                    Voice Training Page
                    (pre-loaded with "help")
```

---

## 9. Algorithm Documentation

### 9.1 Shake Detection Algorithm

```
Input: AccelerometerEvent {x, y, z} in m/s² (continuous stream)

For each event:
  if |x| > threshold_x OR |y| > threshold_y OR |z| > threshold_z:
    → trigger_event(type: 'shake')

Default thresholds: x=25.0, y=25.0, z=25.0 m/s²
User can calibrate via "Train Now" in settings (records their shake pattern)
```

### 9.2 Volume Button Rapid Press Algorithm

```
Input: VolumeEvent stream (volume level changes)
State: click_count = 0, last_click_time = null

For each event:
  now = DateTime.now()
  
  if last_click_time == null OR (now - last_click_time) < 1000ms:
    click_count++
  else:
    click_count = 1   # Reset window
  
  last_click_time = now
  
  if click_count >= 5:
    click_count = 0
    → trigger_event(type: 'volume_rapid')
```

### 9.3 Volume Button Hold Algorithm

```
Input: VolumeEvent stream
State: hold_score = 0, last_hold_time = null

For each event:
  now = DateTime.now()
  
  if (now - last_hold_time) < 100ms:
    hold_score++
  else:
    hold_score = 0   # Gap too large, reset
  
  last_hold_time = now
  
  if hold_score >= 10:
    hold_score = 0
    → trigger_event(type: 'volume_hold')
```

### 9.4 Voice Keyword Detection Algorithm

```
Input: SpeechRecognitionResult (partial + final)
State: _triggers = ['help', 'sos', 'emergency', 'bachao', 'madad', ...custom]

For each speech result:
  heard = result.recognizedWords.toLowerCase().trim()
  
  if heard is empty: skip
  if _alertInProgress: skip (cooldown period)
  
  for each trigger_word in _triggers:
    if heard.contains(trigger_word):
      _alertInProgress = true
      → trigger_event(type: 'voice', word: trigger_word)
      start 15-second cooldown
      break

Auto-restart logic:
  onStatus('done') → wait 800ms → re-check voice_enabled → listen()
  onError → wait 2-3 seconds → listen()
  Safety timer: restart every 31 seconds minimum
```

---

## 10. Security Design

### 10.1 Authentication

- **Firebase Auth** with email/password
- Passwords hashed server-side by Firebase
- JWT tokens auto-refreshed by Firebase SDK
- `authStateChanges()` stream handles session validity

### 10.2 Data Privacy

- Emergency contacts stored in user's private Firestore document
- Firestore Security Rules: users can only read/write their own document
- SharedPreferences data is stored on-device, not accessible to other apps
- Audio recordings stored in app-private filesystem directory

### 10.3 SMS Security

- SMS sent directly via Android `SmsManager` — no third-party server
- Location data sent via SMS only (not stored externally)
- User phone number used as sender identity

### 10.4 Permissions Philosophy

```
Request-at-Use Pattern:
  • Permissions requested at the exact moment they are needed
  • Location requested only during alert
  • Microphone requested only during activation
  • Contacts read requested only in contacts screen
  
Minimum Required:
  • No unnecessary permissions collected
  • Background location NOT required (snapshot only)
```

### 10.5 `.env` File (API Keys)

```env
GEMINI_API_KEY=...      # AI features (optional)
GEOCODING_API_KEY=...   # Convert GPS → address (optional, falls back to coordinates)
```

**Never commit `.env` to version control.** It is listed in `.gitignore`.

---

## 11. Testing Strategy

### 11.1 Manual Test Cases

| Test ID | Test Case | Steps | Expected Result |
|---|---|---|---|
| TC-01 | Voice trigger "help" | Enable protection → Say "help" clearly | SOS SMS sent within 10 seconds |
| TC-02 | Shake trigger | Enable protection → Shake phone vigorously | SOS SMS sent |
| TC-03 | Volume 5× press | Enable protection → Press Volume Up 5 times in 1 second | SOS SMS sent |
| TC-04 | No contacts | Enable protection → Trigger alert with no contacts added | Error snackbar: "No emergency contacts" |
| TC-05 | Voice disabled | Disable voice in settings → Say "help" | No alert triggered |
| TC-06 | Background listening | Enable protection → Close app → Say "help" | SOS SMS sent |
| TC-07 | Add contact | Open contacts screen → Add contact | Contact saved to Firestore + SharedPrefs |
| TC-08 | Voice word setup | Open voice training → Add word "stop" | Word saved, visible in list |
| TC-09 | Default "help" | Fresh install with no setup | "help" pre-loaded as trigger word |
| TC-10 | Auth: Register | Fill form → Register → | Navigate to HomeScreen |
| TC-11 | Auth: Login | Existing credentials → Login | Navigate to HomeScreen |
| TC-12 | Auth: Wrong pass | Wrong password → Login | Error message shown |
| TC-13 | Offline contacts | No internet + trigger | Contacts loaded from SharedPrefs cache |

### 11.2 Performance Targets

| Metric | Target |
|---|---|
| Alert trigger → SMS sent | < 10 seconds |
| App startup time | < 3 seconds |
| Voice keyword detection latency | < 2 seconds |
| GPS fix time | < 5 seconds |
| Background service startup | < 2 seconds |

---

## 12. Deployment Guide

### 12.1 Prerequisites

```bash
# Flutter SDK
flutter --version  # Must be ^3.9.2

# Android SDK
android_sdk/tools/sdkmanager "build-tools;33.0.0"

# Firebase Setup
# 1. Create project at console.firebase.google.com
# 2. Add Android app with package name: com.example.safestep
# 3. Download google-services.json → android/app/
```

### 12.2 Environment Setup

```bash
# Clone
git clone https://github.com/your-org/women-safety.git
cd women-safety

# Dependencies
flutter pub get

# Environment file
cp .env.example .env
# Edit .env with your API keys

# Run
flutter run --debug         # Debug mode
flutter run --release       # Release mode (APK)
```

### 12.3 Build for Production

```bash
# APK (for direct install)
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### 12.4 Required Firebase Rules

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null 
                         && request.auth.uid == userId;
    }
  }
}
```

---

## 13. Known Issues & Limitations

| Issue | Impact | Workaround / Status |
|---|---|---|
| Voice recognition requires internet on some devices | Voice trigger fails on offline devices with no offline pack | Prompt user to install offline speech pack |
| Background service may be killed by aggressive battery savers | Protection disabled silently | Show notification; guide user to disable battery optimization |
| SMS requires SIM card | No SIM = no alerts sent | App shows warning snackbar |
| Voice detection latency on older devices | Delay in trigger | Extend `listenFor` to 45 seconds |
| Location accuracy in buildings | Approximate GPS only | App uses cached last known location as fallback |
| Volume button detection varies by OEM | Some Android skins block volume events | User can switch to shake/voice triggers |
| `speech_to_text` locale `en_IN` failure | No results on some devices | **Fixed**: Removed locale; use device default |

---

## 14. Future Enhancements

### Phase 2 (Planned)

| Feature | Priority | Description |
|---|---|---|
| 📍 Live location streaming | High | Share real-time location URL that updates every 30s |
| 🔔 Push notifications | High | Alert contacts with push notification + SMS |
| 🔐 Stealth mode | High | Make app look like a calculator/calendar |
| 📊 Alert history dashboard | Medium | View past alerts with timestamps and locations |
| 🌐 Multi-language support | Medium | Hindi, Tamil, Telugu UI |
| 🤖 AI threat detection | Low | Camera-based threat estimation using ML |
| ⌚ Smartwatch integration | Low | Trigger from watch button press |
| 📲 Contact app widget | Medium | One-tap SOS from home screen widget |
| 🔋 Better battery optimization | High | Hybrid background + push listening model |

---

## 15. References

| Resource | URL / Citation |
|---|---|
| Flutter Documentation | https://docs.flutter.dev |
| Firebase Auth Docs | https://firebase.google.com/docs/auth |
| Firestore Docs | https://firebase.google.com/docs/firestore |
| speech_to_text Package | https://pub.dev/packages/speech_to_text |
| flutter_background_service | https://pub.dev/packages/flutter_background_service |
| geolocator Package | https://pub.dev/packages/geolocator |
| Hive Database | https://pub.dev/packages/hive |
| Android SmsManager | https://developer.android.com/reference/android/telephony/SmsManager |
| permission_handler | https://pub.dev/packages/permission_handler |

---

## Appendix A — Abbreviations

| Term | Full Form |
|---|---|
| SOS | Save Our Souls (international distress signal) |
| GPS | Global Positioning System |
| SMS | Short Message Service |
| UI | User Interface |
| UX | User Experience |
| DFD | Data Flow Diagram |
| ER | Entity-Relationship |
| JWT | JSON Web Token |
| APK | Android Package Kit |
| ML | Machine Learning |
| TFLite | TensorFlow Lite |
| UID | Unique Identifier |
| CRUD | Create, Read, Update, Delete |
| API | Application Programming Interface |

---

## Appendix B — Glossary

| Term | Definition |
|---|---|
| **Trigger** | Any event that causes the SOS alert to be sent |
| **Background Isolate** | A separate execution thread in Flutter used for background services |
| **Foreground Service** | An Android service with a persistent notification that cannot be killed by the OS |
| **Wake Word** | A specific phrase that activates voice recognition (e.g., "help") |
| **SharedPreferences** | Android/iOS key-value storage that is fast and accessible from any isolate |
| **Hive** | A lightweight NoSQL database for Flutter that works safely in background isolates |
| **Platform Channel** | Flutter mechanism to call native Android/iOS code from Dart |
| **Geocoding** | Converting GPS coordinates (lat/lng) to a human-readable address |

---

*SafeStep Project Documentation — Regional College Project | February 2026*  
*Developed with Flutter & Firebase*

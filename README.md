# 🛡️ SafeStep — Women Safety App

> **A real-time personal safety application for Android, built with Flutter & Firebase.**
> SafeStep empowers women with multi-modal emergency triggers, instant SOS alerts, GPS location sharing, and audio recording — all running silently in the background.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Documentation](#documentation)
- [Permissions Required](#permissions-required)
- [Configuration](#configuration)
- [Contributing](#contributing)

---

## Overview

SafeStep is a **regional college safety project** designed to provide women with a discreet, always-on emergency alert system. The app monitors multiple input channels simultaneously — voice commands, phone shakes, volume button presses — and instantly sends SMS alerts with live GPS location to pre-configured trusted contacts.

The system operates both **in the foreground** (with visible UI) and **in the background** (as a persistent Android service), ensuring protection even when the phone screen is off.

---

## Key Features

| Feature | Description |
|---|---|
| 🎙️ **Voice Trigger** | Says "help", "sos", "bachao" → instant SOS |
| 📳 **Shake Detection** | Rapid phone shake → instant SOS |
| 🔊 **Volume Button Press** | 5× rapid press or hold → instant SOS |
| 📍 **GPS Location Sharing** | Live coordinates + Google Maps link in SMS |
| 📱 **SMS Alert** | Sends to all emergency contacts simultaneously |
| 🎤 **Audio Recording** | Records ambient audio, saves as evidence |
| 👥 **Trusted Contacts** | Add up to 5 trusted contacts from phone book |
| 🔒 **Background Service** | Monitors even with screen off |
| 🧠 **AI Gesture Classifier** | TFLite-based gesture recognition |
| 🗣️ **Voice Word Setup** | Custom emergency trigger words |
| 📝 **Complaint Filing** | File incident reports internally |
| 🔐 **Firebase Auth** | Secure phone/email authentication |

---

## Tech Stack

| Layer | Technology |
|---|---|
| **UI Framework** | Flutter 3.x (Dart) |
| **State Management** | Provider |
| **Authentication** | Firebase Auth |
| **Cloud Database** | Cloud Firestore |
| **Local Storage** | Hive (isolate-safe) + SharedPreferences |
| **Background Service** | `flutter_background_service` |
| **Speech Recognition** | `speech_to_text` v7 |
| **Location** | `geolocator` |
| **Sensors** | `sensors_plus`, `perfect_volume_control` |
| **SMS** | Custom native plugin (`sms_sender`) |
| **ML Inference** | `tflite_flutter` |
| **Audio Recording** | `record` |
| **Contacts** | `flutter_contacts` |

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.9.2`
- Android Studio or VS Code with Flutter/Dart plugins
- Android device or emulator (API 21+)
- Firebase project (see [Configuration](#configuration))

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-org/women-safety.git
cd women-safety

# 2. Install dependencies
flutter pub get

# 3. Copy environment file
cp .env.example .env
# Fill in your Firebase and API keys in .env

# 4. Run on device
flutter run
```

### Build APK

```bash
flutter build apk --release
```

---

## Project Structure

```
lib/
├── main.dart                    # App entry point, Firebase & Hive init
├── firebase_options.dart        # Auto-generated Firebase config
│
├── models/
│   ├── user_model.dart          # User data model (uid, name, contacts)
│   └── contact_model.dart       # Emergency contact model
│
├── services/
│   ├── alert_service.dart       # Orchestrates full SOS alert flow
│   ├── auth_service.dart        # Firebase Auth (login/register/logout)
│   ├── background_service.dart  # Android background service entry point
│   ├── database_helper.dart     # Hive local storage for contacts
│   ├── emergency_detector.dart  # Master trigger: shake, voice, buttons
│   ├── gesture_classifier.dart  # TFLite AI gesture recognition
│   ├── shake_trainer.dart       # Shake threshold calibration
│   ├── sms_service.dart         # Native SMS dispatch via platform channel
│   └── voice_service.dart       # Continuous voice keyword detection
│
└── views/
    ├── auth_screen.dart         # Login / Register screens
    ├── home_screen.dart         # Main dashboard with protection toggle
    ├── contacts_screen.dart     # Add/manage emergency contacts
    ├── contacts_detail_page.dart# Contact detail view
    ├── config_page.dart         # Trigger settings & calibration
    ├── voice_training_page.dart # Voice trigger word setup
    ├── profile_page.dart        # User profile
    ├── complaints_page.dart     # Incident complaint form
    ├── history_screen.dart      # Alert history
    ├── settings_screen.dart     # App settings
    └── stealth_screen.dart      # Disguise/stealth mode UI
```

---

## Documentation

| Document | Description |
|---|---|
| 📊 [ER Diagram](docs/ER_DIAGRAM.md) | Entity-Relationship diagram of all data models |
| 🔄 [DFD](docs/DFD.md) | Level 0, 1 & 2 Data Flow Diagrams |
| 📐 [Project Documentation](docs/PROJECT_DOCUMENTATION.md) | Full technical specification |

---

## Permissions Required

| Permission | Purpose |
|---|---|
| `SEND_SMS` | Send emergency SMS to contacts |
| `ACCESS_FINE_LOCATION` | Get precise GPS coordinates |
| `RECORD_AUDIO` | Voice command detection + audio recording |
| `READ_CONTACTS` | Browse phone contacts when adding trusted contacts |
| `FOREGROUND_SERVICE` | Keep background service alive |
| `RECEIVE_BOOT_COMPLETED` | Auto-start service on device reboot |
| `VIBRATE` | Alert feedback |
| `POST_NOTIFICATIONS` | Background service notification |

---

## Configuration

Create a `.env` file in the project root (copy from `.env.example`):

```env
GEMINI_API_KEY=your_gemini_key_here
GEOCODING_API_KEY=your_google_maps_key_here
```

Firebase configuration is handled via `google-services.json` placed in `android/app/`.

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m "feat: add your feature"`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

---

## License

This project is developed as an academic project for regional college. All rights reserved.

---

*Built with ❤️ for women's safety — SafeStep v1.0.0*

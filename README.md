# SafeStep - Women Safety App

SafeStep is a stealthy, background-running safety application built with Flutter. It detects emergencies via voice commands ("Help"/"SOS") or phone shaking and instantly sends your GPS location to trusted contacts.

## 🚀 Features
- **Stealth Mode**: Runs in background, looks like a calculator (optional overly).
- **Multi-Trigger Detection**: Shake, Voice, and Gesture.
- **Instant Alerts**: Sends SMS with Google Maps link.
- **Firebase Integration**: securely stores emergency contacts.

## 🛠 Project Setup

### 1. Prerequisites
- Flutter SDK (3.x+)
- Android Studio / VS Code
- Firebase CLI (`npm install -g firebase-tools`)

### 2. Installation
```bash
# Clone or Unzip project
cd safestep

# Install dependencies
flutter pub get
```

### 3. Firebase Configuration
This app uses Firebase Auth and Firestore. You must configure it for your project:

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com/).
2. Enable **Authentication** (Email/Password).
3. Enable **Cloud Firestore** and set rules (see below).
4. Run FlutterFire configuration:
```bash
flutterfire configure
```
Select "safestep" (or your project) and the platforms (Android/iOS).
This will generate `lib/firebase_options.dart`.

5. **Uncomment** the `firebase_options.dart` import in `lib/services/background_service.dart` and `lib/main.dart` if it was commented out.

### 4. TFLite Model Setup (Optional for Voice)
The app includes a fallback to standard Speech-to-Text. For offline custom model usage:
1. Train a model using [Teachable Machine](https://teachablemachine.withgoogle.com/train/audio) for words "Help" and "SOS".
2. Download the `.tflite` file.
3. Rename it to `voice_help.tflite` and place it in `assets/models/`.
4. Uncomment the TFLite logic in `lib/services/emergency_detector.dart` (currently configured for standard SpeechToText for easier setup).

### 5. Permissions
The app requires the following permissions on Android (already added to manifest):
- Location (Background)
- SMS (via URL scheme)
- Microphone
- System Alert Window (for overlays)

## 📱 Architecture
- **MVVM**: Clean separation of Views, ViewModels (Providers), and Models.
- **Services**: `EmergencyDetector`, `BackgroundService`, `AuthService`.
- **State Management**: Provider.

## 🧪 Testing
1. **Login**: Create an account.
2. **Setup**: Add emergency contacts in the specific screen.
3. **Start Service**: Toggle "Start" on Home Screen. Status should verify "Protected".
4. **Test**: Long press the SOS button or Shake the phone.

## 🔒 Logic Details
- `EmergencyDetector`: Listens to sensor streams.
- `AlertService`: Fetches current GPS coordinates and iterates through Firestore contacts to construct the SMS.

## ⚠️ Note
For production use, ensure you comply with Google Play/App Store policies regarding Background Location and SMS permissions.

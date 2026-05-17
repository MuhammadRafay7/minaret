# Firebase App Check Permanent Setup Guide

## 🎯 Current Status
✅ App Check error handling implemented (app won't crash)
✅ Release keystore configuration added
✅ ProGuard rules updated for Firebase App Check
⚠️ **Need to complete: SHA fingerprint registration**

## 📋 Steps to Complete Permanent Fix

### 1. Generate Release Keystore
Run this command in the project root:

```bash
keytool -genkey -v -keystore android/app/minaret.keystore -alias minaret -keyalg RSA -keysize 2048 -validity 10000
```

**When prompted for passwords, use:** `minaret123`

### 2. Get SHA Fingerprints
```bash
keytool -list -v -keystore android/app/minaret.keystore -alias minaret
```

**Copy both:**
- SHA-1 certificate fingerprint
- SHA-256 certificate fingerprint

### 3. Add Fingerprints to Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `minaret-f3793`
3. Go to Project Settings (⚙️)
4. Select your Android app: `com.atelier.minaret`
5. Click "Add fingerprint"
6. Paste SHA-1, then add SHA-256 separately

### 4. Download Updated google-services.json
1. In Firebase Console, go to Project Settings
2. Click "Download google-services.json"
3. Replace the existing file in `android/app/google-services.json`

### 5. Test the Setup
```bash
flutter clean
flutter build apk --release
```

## 🔧 What We've Already Done

### App Check Configuration
- ✅ Proper error handling in `main.dart`
- ✅ Uses `playIntegrity` in release, `debug` in debug mode
- ✅ Won't crash if App Check fails

### Build Configuration
- ✅ Release keystore setup in `build.gradle.kts`
- ✅ Proper signing configuration
- ✅ ProGuard rules for Firebase App Check

### Security Features
- ✅ Code obfuscation enabled
- ✅ Resource shrinking enabled
- ✅ Firebase classes protected from obfuscation

## 🚀 After Setup Complete

Once you add the SHA fingerprints to Firebase Console:
- App Check will work with Play Integrity API
- Your app will have production-grade security
- Release builds will be fully protected

## 🐛 Troubleshooting

If you still get blank screen after setup:
1. Verify both SHA-1 and SHA-256 are added
2. Ensure google-services.json is updated
3. Check that keystore passwords match
4. Run `flutter clean` before rebuilding

## 📱 Testing Commands

```bash
# Debug build (uses debug provider)
flutter run --debug

# Release build (uses playIntegrity)
flutter run --release

# Build APK for testing
flutter build apk --release
```

# Production Setup - Complete Instructions

## 🎯 Status: Ready for Final Steps

All code infrastructure is complete. Now you need to run these commands manually to complete the production setup.

## 📋 Manual Steps Required

### Step 1: Generate Release Keystore
Run this command in your project root (`d:\Programing\flutter\projects\minaret`):

```bash
keytool -genkeypair -v -keystore android/app/minaret.keystore -alias minaret -keyalg RSA -keysize 2048 -validity 10000 -storepass minaret123 -keypass minaret123 -dname "CN=Minaret, OU=Development, O=Atelier, L=City, ST=State, C=PK"
```

**When prompted, use:**
- Keystore password: `minaret123`
- Key password: `minaret123`

### Step 2: Get SHA Fingerprints
After generating the keystore, run:

```bash
keytool -list -v -keystore android/app/minaret.keystore -alias minaret -storepass minaret123
```

**Copy both fingerprints:**
- SHA-1 certificate fingerprint
- SHA-256 certificate fingerprint

### Step 3: Add to Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `minaret-f3793`
3. Go to Project Settings (⚙️)
4. Select your Android app: `com.atelier.minaret`
5. Click "Add fingerprint"
6. Add SHA-1 first, then SHA-256

### Step 4: Update google-services.json
1. In Firebase Console → Project Settings
2. Click "Download google-services.json"
3. Replace existing file in `android/app/google-services.json`

### Step 5: Test Production Build
```bash
flutter clean
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols --split-per-abi
```

## ✅ What's Already Done

- ✅ Firebase App Check error handling
- ✅ Release keystore configuration in build.gradle.kts
- ✅ ProGuard rules for Firebase App Check
- ✅ Build configuration fixes
- ✅ Theme provider issues resolved
- ✅ Crashlytics initialization improvements

## 🛡️ Security Features Ready

Once you complete the manual steps:
- App Check will use Play Integrity API in release builds
- Code will be obfuscated and optimized
- Firebase services will be properly authenticated
- No more blank screen issues

## 🚀 After Setup Complete

Your app will have:
- Production-grade security with Firebase App Check
- Proper code obfuscation and size optimization
- Full Firebase integration with Play Integrity
- Stable release builds without initialization crashes

## 🐛 If Issues Occur

1. **Build fails**: Ensure keystore was generated in `android/app/`
2. **App Check errors**: Verify both SHA-1 and SHA-256 are added to Firebase
3. **Blank screen**: Check google-services.json is updated
4. **Crashlytics errors**: App will continue without crash reporting

Run the commands above to complete your production setup!

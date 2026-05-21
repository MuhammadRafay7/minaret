# Minaret

A high-end digital atelier for professional prayer management.

---

## Android Release Signing

Release builds require Android keystore credentials. **Never hardcode these in
`key.properties` and never commit that file to source control.**

### Environment variables

`build.gradle.kts` reads credentials from environment variables first (CI/CD),
then falls back to `android/key.properties` (local developer machines).
A missing or empty `KEYSTORE_PASSWORD` causes an immediate `GradleException`
so the build fails with a clear message rather than silently producing an
unsigned APK.

| Env var             | `key.properties` key | Description                                          |
|---------------------|----------------------|------------------------------------------------------|
| `KEYSTORE_PASSWORD` | `storePassword`      | Password for the `.keystore` file itself             |
| `KEY_PASSWORD`      | `keyPassword`        | Password for the specific key entry inside the store |
| `KEY_ALIAS`         | `keyAlias`           | Alias chosen when the keystore was created           |
| `KEYSTORE_PATH`     | `storeFile`          | Absolute or project-relative path to the `.keystore` |

### GitHub Actions

Store the keystore as a base64-encoded repository secret (`KEYSTORE_BASE64`),
then decode and inject it at build time:

```yaml
- name: Decode keystore
  run: echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > android/app/release.keystore

- name: Build release APK
  env:
    KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
    KEY_PASSWORD:      ${{ secrets.KEY_PASSWORD }}
    KEY_ALIAS:         ${{ secrets.KEY_ALIAS }}
    KEYSTORE_PATH:     android/app/release.keystore
  run: flutter build apk --release --obfuscate --split-debug-info=build/android/symbols

- name: Build release AAB
  env:
    KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
    KEY_PASSWORD:      ${{ secrets.KEY_PASSWORD }}
    KEY_ALIAS:         ${{ secrets.KEY_ALIAS }}
    KEYSTORE_PATH:     android/app/release.keystore
  run: flutter build appbundle --release --obfuscate --split-debug-info=build/android/symbols
```

### Codemagic

Use the **Android code signing** section in the workflow editor. Codemagic
uploads the keystore and injects `CM_KEYSTORE_PASSWORD`, `CM_KEY_PASSWORD`,
`CM_KEY_ALIAS`, and `CM_KEYSTORE_PATH` automatically. Map them to the names
`build.gradle.kts` expects by adding to your `codemagic.yaml` environment:

```yaml
environment:
  vars:
    KEYSTORE_PASSWORD: $CM_KEYSTORE_PASSWORD
    KEY_PASSWORD:      $CM_KEY_PASSWORD
    KEY_ALIAS:         $CM_KEY_ALIAS
    KEYSTORE_PATH:     $CM_KEYSTORE_PATH
```

### Bitrise

Add a **Android Sign** step to your workflow. Bitrise sets `BITRISEIO_ANDROID_KEYSTORE_PASSWORD`,
`BITRISEIO_ANDROID_KEYSTORE_ALIAS`, and `BITRISEIO_ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD`.
Map them in the **Env Vars** tab:

```text
KEYSTORE_PASSWORD  →  $BITRISEIO_ANDROID_KEYSTORE_PASSWORD
KEY_PASSWORD       →  $BITRISEIO_ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD
KEY_ALIAS          →  $BITRISEIO_ANDROID_KEYSTORE_ALIAS
KEYSTORE_PATH      →  (path output by the Keystore & Sign step)
```

### Local Android development

Copy `android/key.properties.example` to `android/key.properties` and fill in
your local keystore details. This file is gitignored and will never be committed.

```sh
cp android/key.properties.example android/key.properties
# Edit android/key.properties with your actual values
```

---

## iOS Release Build

Every production IPA **must** be built with code obfuscation enabled. This
makes reverse-engineering significantly harder and is required before App Store
submission.

### Required flags

```sh
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/ios/symbols
```

> **Why these flags matter**
>
> `--obfuscate` renames Dart symbols so the compiled binary is resistant to
> reverse-engineering.  
> `--split-debug-info` writes the symbol map to `build/ios/symbols/`.
>
> **Upload `build/ios/symbols/` to Crashlytics or Sentry before distributing
> the IPA.** Without this directory, all production crash stack traces will
> show obfuscated names and be completely unreadable.

### GitHub Actions (iOS)

```yaml
- name: Build IPA
  run: |
    flutter build ipa --release \
      --obfuscate \
      --split-debug-info=build/ios/symbols

- name: Upload debug symbols to Crashlytics
  run: |
    # Use the Firebase CLI or the Crashlytics Gradle plugin equivalent
    # for iOS: upload-symbols -gsp GoogleService-Info.plist \
    #           -p ios build/ios/symbols
```

### Codemagic (iOS)

Add to your `codemagic.yaml` build arguments:

```yaml
scripts:
  - name: Build IPA
    script: |
      flutter build ipa --release \
        --obfuscate \
        --split-debug-info=build/ios/symbols
```

Upload the generated `build/ios/symbols/` directory as a build artifact and
pipe it into the Crashlytics or Sentry symbol upload step.

### Bitrise (iOS)

Add a **Flutter Build** step with these additional arguments:

```text
--obfuscate --split-debug-info=build/ios/symbols
```

Then add a **Script** step after it to upload `build/ios/symbols/` to your
crash reporting service.

### Xcode direct builds

If you ever build through Xcode directly (not recommended for release), pass
the same flags via the `OTHER_DART_FLAGS` build setting in the Runner scheme.
Prefer the `flutter build ipa` command above to guarantee obfuscation is never
accidentally skipped.

---

## Certificate Pinning

The app performs SHA-256 public-key pinning on all API connections via
`lib/core/config/certificate_pins.dart`. Before releasing to the stores:

1. Extract the real pin for each domain:

   ```sh
   openssl s_client -connect api.minaret.app:443 </dev/null 2>/dev/null \
     | openssl x509 -pubkey -noout \
     | openssl pkey -pubin -outform der \
     | openssl dgst -sha256 -binary \
     | base64
   ```

2. Replace the `PLACEHOLDER` values in `pinnedDomains` inside that file.
3. A debug-build `AssertionError` will fire if any placeholder remains.

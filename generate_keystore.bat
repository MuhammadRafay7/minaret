@echo off
echo Generating Minaret release keystore...
echo.

cd /d "%~dp0android\app"

keytool -genkeypair -v -keystore minaret.keystore -alias minaret -keyalg RSA -keysize 2048 -validity 10000 -storepass minaret123 -keypass minaret123 -dname "CN=Minaret, OU=Development, O=Atelier, L=City, ST=State, C=PK"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Keystore generated successfully!
    echo.
    echo Getting SHA fingerprints...
    echo.
    keytool -list -v -keystore minaret.keystore -alias minaret -storepass minaret123
    echo.
    echo 📋 Copy the SHA-1 and SHA-256 fingerprints above and add them to Firebase Console
    echo    Firebase Console → Project Settings → Your Android App → Add fingerprint
) else (
    echo.
    echo ❌ Failed to generate keystore
    echo    Make sure Java is installed and keytool is in your PATH
)

pause

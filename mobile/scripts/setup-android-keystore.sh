#!/usr/bin/env bash
# One-time: create Play upload keystore + android/key.properties (gitignored).
#
# BACK UP upload-keystore.jks and the passwords somewhere safe.
# Losing them blocks future updates (Play App Signing can recover via Google
# if you enrolled Play App Signing — still back up).
set -euo pipefail
# Prefer Android Studio's bundled JDK (macOS often has no system java).
if [[ -z "${JAVA_HOME:-}" ]]; then
  for candidate in \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
    "/Applications/Android Studio.app/Contents/jre/Contents/Home"
  do
    if [[ -x "$candidate/bin/keytool" ]]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      break
    fi
  done
fi
cd "$(dirname "$0")/../android"

KEYSTORE="upload-keystore.jks"
PROPS="key.properties"

if [[ -f "$KEYSTORE" && -f "$PROPS" ]]; then
  echo "Already set up: $KEYSTORE and $PROPS exist."
  exit 0
fi

if [[ -f "$KEYSTORE" ]]; then
  echo "Keystore exists but key.properties is missing — create key.properties manually."
  exit 1
fi

# Random passwords (printed once — copy to a password manager).
STORE_PASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
KEY_PASS="$STORE_PASS"
ALIAS="upload"

echo "→ Generating $KEYSTORE (alias=$ALIAS)..."
keytool -genkey -v \
  -keystore "$KEYSTORE" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "$ALIAS" \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "CN=UltraForge LLC, OU=TrekTrack, O=UltraForge LLC, L=New Jersey, ST=NJ, C=US"

cat > "$PROPS" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$ALIAS
storeFile=../upload-keystore.jks
EOF

echo ""
echo "✓ Created:"
echo "  android/$KEYSTORE"
echo "  android/$PROPS"
echo ""
echo "⚠ BACK THESE UP OFF THIS MACHINE (password manager + encrypted drive)."
echo "  Passwords are only in key.properties (gitignored)."
echo ""
echo "Next: ./scripts/build-android-release.sh"

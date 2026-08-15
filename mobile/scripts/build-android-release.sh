#!/usr/bin/env bash
# Build a Play Console Android App Bundle **with** Supabase credentials baked in.
#
# Prerequisites:
#   • mobile/.env.local with SUPABASE_URL and SUPABASE_ANON_KEY
#   • android/key.properties + upload-keystore.jks (see script output if missing)
#
# Usage:
#   ./scripts/build-android-release.sh
#   # then Play Console → Testing → Internal testing → Create new release → upload .aab
set -euo pipefail
if [[ -z "${JAVA_HOME:-}" ]]; then
  for candidate in \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
    "/Applications/Android Studio.app/Contents/jre/Contents/Home"
  do
    if [[ -x "$candidate/bin/java" ]]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      break
    fi
  done
fi
cd "$(dirname "$0")/.."

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

: "${SUPABASE_URL:?Missing SUPABASE_URL — put it in mobile/.env.local}"
: "${SUPABASE_ANON_KEY:?Missing SUPABASE_ANON_KEY — put it in mobile/.env.local}"
PRIVACY_URL="${PRIVACY_URL:-https://trektrack.pro/privacy.html}"

if [[ ! -f android/key.properties ]]; then
  echo "Missing android/key.properties (upload signing)."
  echo "Create an upload keystore first, then a key.properties file."
  echo "See scripts/setup-android-keystore.sh"
  exit 1
fi

echo "→ SUPABASE_URL=$SUPABASE_URL"
echo "→ Building release App Bundle (com.ultraforge.trektrack)..."

flutter pub get

flutter build appbundle \
  --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=PRIVACY_URL="$PRIVACY_URL"

AAB="build/app/outputs/bundle/release/app-release.aab"
if [[ ! -f "$AAB" ]]; then
  echo "AAB not found at $AAB"
  exit 1
fi

echo ""
echo "✓ Built: $AAB"
echo "  Package: com.ultraforge.trektrack"
echo ""
echo "Upload to Google Play Console:"
echo "  1. Open https://play.google.com/console"
echo "  2. Select TrekTrack (com.ultraforge.trektrack)"
echo "  3. Testing → Internal testing (or Closed testing)"
echo "  4. Create new release → Upload $AAB"
echo "  5. Add release notes → Save → Review → Start rollout to Internal testing"
echo "  6. Testers → create email list / copy opt-in link"
echo ""
open -R "$AAB" 2>/dev/null || true

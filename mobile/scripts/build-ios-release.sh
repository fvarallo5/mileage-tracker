#!/usr/bin/env bash
# Build a TestFlight / App Store IPA **with** Supabase credentials baked in.
#
# Why: archiving from Xcode alone does not pass --dart-define, so the app
# shows "Supabase not configured". Always run this before upload.
#
# Usage:
#   ./scripts/build-ios-release.sh
#   # then Transporter / Organizer upload of build/ios/ipa/*.ipa
set -euo pipefail
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

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if [[ ! -d "$DEVELOPER_DIR" ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi

echo "→ Xcode tools: $DEVELOPER_DIR"
xcodebuild -version || true
echo "→ SUPABASE_URL=$SUPABASE_URL"
echo "→ Building IPA with dart-defines (Supabase + privacy URL)..."

flutter pub get

# Ensure CocoaPods plugins are current
(cd ios && pod install)

flutter build ipa \
  --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=PRIVACY_URL="$PRIVACY_URL" \
  --export-options-plist=ios/ExportOptions.plist

IPA=$(find build/ios/ipa -name '*.ipa' 2>/dev/null | head -1)
if [[ -z "${IPA:-}" ]]; then
  echo "IPA not found — check errors above. If only an .xcarchive was made, open Organizer."
  exit 1
fi

# Confirm defines landed in Generated.xcconfig
if grep -q 'SUPABASE' ios/Flutter/Generated.xcconfig 2>/dev/null || \
   python3 - <<'PY'
import base64, pathlib
p = pathlib.Path("ios/Flutter/Generated.xcconfig")
if not p.exists():
    raise SystemExit(1)
text = p.read_text()
for line in text.splitlines():
    if line.startswith("DART_DEFINES="):
        raw = line.split("=", 1)[1]
        decoded = ",".join(
            base64.b64decode(part).decode() for part in raw.split(",") if part
        )
        print(decoded)
        raise SystemExit(0 if "SUPABASE_ANON_KEY=" in decoded else 1)
raise SystemExit(1)
PY
then
  echo "✓ Supabase dart-defines present in build"
else
  echo "⚠ Could not verify DART_DEFINES — open the IPA on a device and confirm sign-in works"
fi

echo ""
echo "✓ Built: $IPA"
echo ""
echo "Upload:"
echo "  • open -a Transporter   (drag the IPA), or"
echo "  • Xcode → Window → Organizer (if archive listed)"
echo ""
open -R "$IPA"
open -a Transporter 2>/dev/null || true

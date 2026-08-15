#!/usr/bin/env bash
# Build and upload TrekTrack to App Store Connect / TestFlight.
# Prerequisites:
#   1. Xcode → Settings → Accounts → UltraForge LLC Apple ID signed in
#   2. ios/Runner.xcworkspace → Runner → Signing → Team = UltraForge LLC
#   3. mobile/.env.local has SUPABASE_URL and SUPABASE_ANON_KEY
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

: "${SUPABASE_URL:?Missing SUPABASE_URL in .env.local}"
: "${SUPABASE_ANON_KEY:?Missing SUPABASE_ANON_KEY in .env.local}"

echo "→ Checking code signing identities..."
if ! security find-identity -v -p codesigning | grep -q "iPhone Distribution\|Apple Distribution\|iPhone Developer\|Apple Development"; then
  echo ""
  echo "No Apple signing certificate found on this Mac."
  echo "Do this once:"
  echo "  1. open ios/Runner.xcworkspace"
  echo "  2. Select Runner target → Signing & Capabilities"
  echo "  3. Team: UltraForge LLC (Automatic signing)"
  echo "  4. Let Xcode create certificates / profiles"
  echo "  5. Re-run: ./scripts/upload_ios.sh"
  open ios/Runner.xcworkspace
  exit 1
fi

echo "→ flutter pub get"
flutter pub get

echo "→ Building IPA (App Store)..."
flutter build ipa \
  --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --export-options-plist=ios/ExportOptions.plist

IPA=$(find build/ios/ipa -name "*.ipa" 2>/dev/null | head -1)
if [[ -z "${IPA:-}" ]]; then
  echo "IPA not found under build/ios/ipa — open Xcode Organizer if archive was created."
  exit 1
fi

echo ""
echo "Built: $IPA"
echo ""
echo "Upload options:"
echo "  A) Xcode → Window → Organizer → Distribute App → App Store Connect"
echo "  B) Transporter app: drag the .ipa"
echo "  C) If you have an App Store Connect API key:"
echo "       xcrun altool --upload-app --type ios -f \"$IPA\" \\"
echo "         --apiKey \$ASC_KEY_ID --apiIssuer \$ASC_ISSUER_ID"
echo ""
open -R "$IPA"

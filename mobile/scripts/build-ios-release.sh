#!/usr/bin/env bash
# Build iOS release IPA prep — run archive in Xcode after this.
set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:?Set SUPABASE_URL}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY}"
PRIVACY_URL="${PRIVACY_URL:-https://raw.githubusercontent.com/fvarallo5/mileage-tracker/main/static/privacy.html}"

cd "$(dirname "$0")/.."

echo "Building iOS release..."
echo "  SUPABASE_URL=$SUPABASE_URL"
echo "  PRIVACY_URL=$PRIVACY_URL"

flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create

flutter build ios --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=PRIVACY_URL="$PRIVACY_URL"

echo ""
echo "✓ Release build complete."
echo "  Next: open ios/Runner.xcworkspace in Xcode"
echo "  Product → Archive → Distribute to App Store Connect"
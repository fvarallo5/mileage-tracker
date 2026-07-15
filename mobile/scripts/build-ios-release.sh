#!/usr/bin/env bash
# Build iOS release IPA prep — run archive in Xcode after this.
set -euo pipefail

API_URL="${API_URL:-https://mileage-tracker-api.onrender.com/api}"
PRIVACY_URL="${PRIVACY_URL:-https://mileage-tracker-api.onrender.com/privacy}"

cd "$(dirname "$0")/.."

echo "Building iOS release..."
echo "  API_URL=$API_URL"
echo "  PRIVACY_URL=$PRIVACY_URL"

flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create

flutter build ios --release \
  --dart-define=API_URL="$API_URL" \
  --dart-define=PRIVACY_URL="$PRIVACY_URL"

echo ""
echo "✓ Release build complete."
echo "  Next: open ios/Runner.xcworkspace in Xcode"
echo "  Product → Archive → Distribute to App Store Connect"
#!/usr/bin/env bash
# Install and run on a physical iPhone or Android phone (USB).
# Uses your live Render API — no local backend required.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

SUPABASE_URL="${SUPABASE_URL:-https://gfpyqkbhszczuzaoldly.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

echo "Looking for a physical phone (USB)..."
echo ""

flutter pub get
./scripts/patch_android_sdk.sh 2>/dev/null || true

# Prefer a real device over emulator/simulator
DEVICE_ID=""
while IFS= read -r line; do
  id=$(echo "$line" | awk '{print $1}')
  name=$(echo "$line" | sed 's/ • /|/g' | cut -d'|' -f1)
  platform=$(echo "$line" | awk -F'•' '{print $(NF-1)}' | xargs)
  if [[ "$id" == "emulator-"* ]] || [[ "$platform" == *"simulator"* ]]; then
    continue
  fi
  if [[ "$id" =~ ^(macos|chrome|web-javascript)$ ]]; then
    continue
  fi
  if [[ -n "$id" && "$id" != "Found" && "$id" != "Run" ]]; then
    DEVICE_ID="$id"
    echo "Using device: $name ($DEVICE_ID)"
    break
  fi
done < <(flutter devices 2>/dev/null | grep "•")

if [[ -z "$DEVICE_ID" ]]; then
  echo "No physical phone detected."
  echo ""
  echo "iPhone:"
  echo "  1. Connect USB cable"
  echo "  2. Tap Trust on the phone"
  echo "  3. Settings → Privacy & Security → Developer Mode → On (restart if asked)"
  echo "  4. Open ios/Runner.xcworkspace in Xcode"
  echo "     Runner → Signing & Capabilities → Team: your Apple ID"
  echo ""
  echo "Android:"
  echo "  1. Settings → About → tap Build number 7× (enable Developer options)"
  echo "  2. Developer options → USB debugging → On"
  echo "  3. Connect USB, accept debugging prompt on phone"
  echo ""
  echo "Then run: ./scripts/run-phone.sh"
  exit 1
fi

echo ""
if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "Set SUPABASE_URL and SUPABASE_ANON_KEY before running."
  echo "  export SUPABASE_URL=https://xxxx.supabase.co"
  echo "  export SUPABASE_ANON_KEY=eyJ..."
  exit 1
fi

echo "SUPABASE_URL=$SUPABASE_URL"
echo "Building and installing (first run may take a few minutes)..."
echo ""

flutter run -d "$DEVICE_ID" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
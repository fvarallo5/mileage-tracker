#!/usr/bin/env bash
# Build and run on Android emulator (applies file_picker SDK patch after pub get).
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-emulator-5554}"

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

SUPABASE_URL="${SUPABASE_URL:-https://gfpyqkbhszczuzaoldly.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

if [[ -z "$SUPABASE_ANON_KEY" ]]; then
  echo "Missing SUPABASE_ANON_KEY. Add it to mobile/.env.local or export it."
  exit 1
fi

flutter pub get
./scripts/patch_android_sdk.sh
flutter run -d "$DEVICE" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
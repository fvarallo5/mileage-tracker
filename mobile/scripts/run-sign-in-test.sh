#!/usr/bin/env bash
# Integration test: sign in on iOS simulator.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

SUPABASE_URL="${SUPABASE_URL:-https://gfpyqkbhszczuzaoldly.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY in .env.local}"
DEVICE="${1:-iPhone 16 Plus}"

open -a Simulator 2>/dev/null || true
xcrun simctl boot "$DEVICE" 2>/dev/null || true

flutter pub get
flutter test integration_test/sign_in_test.dart -d "$DEVICE" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
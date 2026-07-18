#!/usr/bin/env bash
# Run on iOS simulator with Supabase (set anon key once).
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
DEVICE="${1:-iPhone 16 Plus}"

if [[ -z "$SUPABASE_ANON_KEY" ]]; then
  echo "Missing SUPABASE_ANON_KEY. Add it to mobile/.env.local or export it."
  exit 1
fi

flutter pub get
flutter run -d "$DEVICE" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
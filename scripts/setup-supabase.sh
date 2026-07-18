#!/usr/bin/env bash
# Supabase setup and verify for Mileage Tracker.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "═══════════════════════════════════════════"
echo "  Mileage Tracker — Supabase"
echo "═══════════════════════════════════════════"
echo ""
echo "Project: https://gfpyqkbhszczuzaoldly.supabase.co"
echo ""
echo "Dashboard checklist:"
echo "  ✓ Tables: trips, settings (Table Editor)"
echo "  ✓ Authentication → Providers:"
echo "      • Email → ON"
echo "      • Anonymous sign-ins → ON (optional guest mode)"
echo "  ✓ For dev: Authentication → Email → disable Confirm email"
echo "  ✓ SQL migration applied (supabase/migrations/001_initial_schema.sql)"
echo ""
echo "Local config (gitignored):"
echo "  mobile/.env.local     — SUPABASE_URL + SUPABASE_ANON_KEY"
echo "  frontend/.env         — VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY"
echo ""
echo "Copy from examples:"
echo "  cp mobile/.env.example mobile/.env.local"
echo "  cp frontend/.env.example frontend/.env"
echo ""
echo "Run apps:"
echo "  ./mobile/scripts/run-android.sh"
echo "  ./mobile/scripts/run-simulator.sh"
echo "  ./mobile/scripts/run-phone.sh"
echo "  npm run dev:frontend"
echo ""

if [[ -f "$ROOT/mobile/.env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/mobile/.env.local"
  set +a
  if [[ -n "${SUPABASE_ANON_KEY:-}" ]]; then
    echo "→ Checking Supabase auth..."
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${SUPABASE_URL}/auth/v1/signup" \
      -H "apikey: $SUPABASE_ANON_KEY" -H "Content-Type: application/json" -d '{}' || echo "000")
    if [[ "$HTTP" == "200" ]]; then
      echo "✓ Anonymous auth OK"
    else
      echo "  Auth check returned HTTP $HTTP — verify anon key and anonymous sign-ins"
    fi
  fi
fi

echo ""
echo "Privacy policy: static/privacy.html (link from app settings)"
echo ""
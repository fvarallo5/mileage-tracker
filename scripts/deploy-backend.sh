#!/usr/bin/env bash
# Prepare and deploy Mileage Tracker API to Render.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API_URL="https://mileage-tracker-api.onrender.com"
SERVICE_NAME="mileage-tracker-api"

echo "═══════════════════════════════════════════"
echo "  Mileage Tracker — API Deploy"
echo "═══════════════════════════════════════════"
echo ""

# ── 1. Git repo (required for Render) ──────────────────────────────────────
if [[ ! -d .git ]]; then
  echo "→ Initializing git repository..."
  git init
  git add .
  git commit -m "Initial commit — Mileage Tracker app"
  echo "✓ Git repo created"
  echo ""
  echo "  Next: push to GitHub, then connect Render:"
  echo "    1. Create repo at https://github.com/new (e.g. mileage-tracker)"
  echo "    2. git remote add origin git@github.com:YOU/mileage-tracker.git"
  echo "    3. git push -u origin main"
  echo ""
else
  echo "✓ Git repo exists"
  if ! git rev-parse HEAD &>/dev/null; then
    git add .
    git commit -m "Prepare for API deploy"
  fi
fi

# ── 2. Local smoke test ─────────────────────────────────────────────────────
echo "→ Testing API locally..."
if curl -sf http://localhost:3001/api/health &>/dev/null; then
  echo "✓ Local API healthy at http://localhost:3001"
else
  echo "  Local API not running (optional). Start with: npm run dev:backend"
fi

# ── 3. Check production URL ─────────────────────────────────────────────────
echo ""
echo "→ Checking production URL: $API_URL"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/health" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
  echo "✓ API is LIVE at $API_URL"
  curl -s "$API_URL/api/health" | head -1
  echo ""
  echo "Mobile app is already configured for this URL in:"
  echo "  mobile/lib/config/app_config.dart"
  exit 0
fi

echo "  Not deployed yet (HTTP $HTTP_CODE)"
echo ""
echo "═══════════════════════════════════════════"
echo "  Deploy to Render (one-time setup)"
echo "═══════════════════════════════════════════"
echo ""
echo "1. Push this repo to GitHub (if not already)"
echo ""
echo "2. Go to https://dashboard.render.com"
echo "   → New + → Blueprint"
echo "   → Connect your GitHub repo"
echo "   → Render reads render.yaml at repo root"
echo ""
echo "3. Service settings (auto-filled by blueprint):"
echo "   • Name: $SERVICE_NAME"
echo "   • Root directory: backend"
echo "   • Runtime: Docker"
echo "   • Health check: /api/health"
echo "   • Disk: 1 GB at /app/data (SQLite persistence)"
echo ""
echo "4. After deploy (~5 min), verify:"
echo "   curl $API_URL/api/health"
echo ""
echo "5. Your apps will use:"
echo "   API:     $API_URL/api"
echo "   Privacy: $API_URL/privacy"
echo ""
echo "Note: Render free tier sleeps after 15 min idle."
echo "      First request after sleep may take ~30s to wake."
echo ""
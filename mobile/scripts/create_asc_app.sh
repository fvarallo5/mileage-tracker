#!/usr/bin/env bash
# Create TrekTrack in App Store Connect via API (optional automation).
# Prerequisites:
#   - App Store Connect API key (.p8) with App Manager or Admin
#   - Bundle ID already registered at developer.apple.com (or register via portal first)
#   - python3 + PyJWT + cryptography  (or use token from another tool)
#
# Usage:
#   export ASC_KEY_ID=...
#   export ASC_ISSUER_ID=...
#   export ASC_KEY_PATH=~/AuthKey_XXX.p8
#   ./scripts/create_asc_app.sh
set -euo pipefail

BUNDLE_ID="${ASC_BUNDLE_ID:-com.ultraforge.trektrack}"
APP_NAME="${ASC_APP_NAME:-TrekTrack}"
SKU="${ASC_SKU:-trektrack-ios}"
PRIMARY_LOCALE="${ASC_LOCALE:-en-US}"

: "${ASC_KEY_ID:?Set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID}"
: "${ASC_KEY_PATH:?Set ASC_KEY_PATH to your AuthKey_XXX.p8}"

KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
if [[ ! -f "$KEY_PATH" ]]; then
  echo "Key file not found: $KEY_PATH"
  exit 1
fi

echo "Generating App Store Connect JWT..."
TOKEN=$(python3 - <<PY
import time, pathlib
try:
    import jwt
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "PyJWT", "cryptography", "-q"])
    import jwt

key_id = "${ASC_KEY_ID}"
issuer = "${ASC_ISSUER_ID}"
key = pathlib.Path("${KEY_PATH}").read_text()
now = int(time.time())
token = jwt.encode(
    {"iss": issuer, "iat": now, "exp": now + 20 * 60, "aud": "appstoreconnect-v1"},
    key,
    algorithm="ES256",
    headers={"kid": key_id, "typ": "JWT"},
)
print(token if isinstance(token, str) else token.decode())
PY
)

AUTH="Authorization: Bearer ${TOKEN}"
API="https://api.appstoreconnect.apple.com/v1"

echo "Looking up bundle ID ${BUNDLE_ID}..."
BUNDLE_JSON=$(curl -sS -H "$AUTH" \
  "${API}/bundleIds?filter[identifier]=${BUNDLE_ID}&limit=1")
BUNDLE_REF=$(python3 - <<PY
import json,sys
d=json.loads('''${BUNDLE_JSON}''')
data=d.get("data") or []
if not data:
    print("")
else:
    print(data[0]["id"])
PY
)

if [[ -z "$BUNDLE_REF" ]]; then
  echo "Bundle ID not registered yet. Create it at:"
  echo "  https://developer.apple.com/account/resources/identifiers/list"
  echo "  Explicit App ID: ${BUNDLE_ID}"
  echo "Then re-run this script."
  exit 1
fi
echo "Bundle ID resource: ${BUNDLE_REF}"

echo "Creating app ${APP_NAME} (SKU ${SKU})..."
RESP=$(curl -sS -X POST "${API}/apps" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d @- <<JSON
{
  "data": {
    "type": "apps",
    "attributes": {
      "name": "${APP_NAME}",
      "primaryLocale": "${PRIMARY_LOCALE}",
      "sku": "${SKU}",
      "bundleId": "${BUNDLE_ID}"
    }
  }
}
JSON
)

python3 - <<PY
import json,sys
d=json.loads('''${RESP}''')
if "errors" in d:
    print("API error:")
    print(json.dumps(d["errors"], indent=2))
    sys.exit(1)
app=d.get("data") or {}
attrs=app.get("attributes") or {}
print("Created / found app:")
print("  id:", app.get("id"))
print("  name:", attrs.get("name"))
print("  bundleId:", attrs.get("bundleId"))
print("  Open: https://appstoreconnect.apple.com/apps/" + str(app.get("id")) + "/appstore")
PY

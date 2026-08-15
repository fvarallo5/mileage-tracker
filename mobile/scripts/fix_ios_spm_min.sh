#!/usr/bin/env bash
# Flutter SPM aggregator often regenerates at iOS 13.0; plugins need 14+.
# Force the top-level FlutterGeneratedPluginSwiftPackage to iOS 16.0.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EPHEMERAL="$ROOT/ios/Flutter/ephemeral"
if [[ ! -d "$EPHEMERAL" ]]; then
  echo "No ephemeral dir yet — run: flutter build ios --config-only"
  exit 0
fi
find "$EPHEMERAL" -name 'Package.swift' -print0 | while IFS= read -r -d '' f; do
  if grep -q '\.iOS("' "$f"; then
    # Only bump the aggregator package and any still on 13.x
    if [[ "$f" == *FlutterGeneratedPluginSwiftPackage* ]] || grep -q '\.iOS("13\.' "$f"; then
      sed -i '' -E 's/\.iOS\("1[0-3]\.[0-9]+"\)/.iOS("16.0")/g' "$f"
    fi
  fi
done
# Always force aggregator
AGG="$EPHEMERAL/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
if [[ -f "$AGG" ]]; then
  sed -i '' -E 's/\.iOS\("[0-9]+\.[0-9]+"\)/.iOS("16.0")/g' "$AGG"
  echo "OK: $(grep -A2 'platforms:' "$AGG" | tr -s ' \n' ' ')"
else
  echo "Missing $AGG — run flutter build ios --config-only first"
fi

#!/usr/bin/env bash
# Patch plugin compileSdk for Android API 36 compatibility (local dev fix).
set -euo pipefail
CACHE="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev"
for pkg in file_picker-8.3.7; do
  GRADLE="$CACHE/$pkg/android/build.gradle"
  if [[ -f "$GRADLE" ]]; then
    sed -i '' 's/compileSdk 34/compileSdk 36/g' "$GRADLE"
    sed -i '' 's/compileSdkVersion 34/compileSdkVersion 36/g' "$GRADLE"
    echo "Patched $GRADLE"
  fi
done
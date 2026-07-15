#!/usr/bin/env bash
# Build and run on Android emulator (applies file_picker SDK patch after pub get).
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-emulator-5554}"

flutter pub get
./scripts/patch_android_sdk.sh
flutter run -d "$DEVICE"
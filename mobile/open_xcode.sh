#!/usr/bin/env bash
# Always open the FULL Flutter iOS app (not the empty SwiftUI stub).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
open "$ROOT/ios/Runner.xcworkspace"
echo "Opened: $ROOT/ios/Runner.xcworkspace"
echo "Scheme: Runner or TrekTrack (same full app)"
echo "Bundle: com.ultraforge.trektrack"

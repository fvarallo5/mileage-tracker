# App Store screenshots

## What App Store Connect wants

**Required for App Store release (not for TestFlight internal builds):**

| Display | Size (px) | Simulator |
|---------|-----------|-----------|
| **iPhone 6.7"** (required) | **1290 × 2796** | iPhone 16 Plus / 15 Pro Max |
| iPhone 6.5" (optional if 6.7 filled) | 1284 × 2778 | older |
| iPad 13" (only if you support iPad) | 2064 × 2752 | iPad Pro |

- Minimum **1** screenshot per required size; up to **10**
- **App Previews** (videos) are **optional** — skip for soft launch
- Portrait is fine for TrekTrack

## Upload location

App Store Connect → your app → **App Store** tab → iOS version →  
**Previews and Screenshots** → iPhone 6.7" display

## Suggested set (5–6 frames)

1. Track / auto-detect (hero)
2. Trip map + recent trips
3. Reports / tax numbers
4. Import platforms
5. Pro / pricing
6. Settings / privacy gates (optional)

## Capture more from Simulator

With app running on **iPhone 16 Plus**:

```bash
# Device → Screenshot, or:
xcrun simctl io booted screenshot store/screenshots/iphone-6.7/NN-name.png
```

Files in this folder are ready to drag into ASC if size is 1290×2796.

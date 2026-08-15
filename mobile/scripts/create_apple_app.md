# Create TrekTrack on App Store Connect

Do this once under the **UltraForge LLC** organization account.

## Values (copy exactly)

| Field | Value |
|--------|--------|
| **Platforms** | iOS |
| **Name** | TrekTrack |
| **Primary Language** | English (U.S.) |
| **Bundle ID** | `com.ultraforge.trektrack` |
| **SKU** | `trektrack-ios` |
| **User Access** | Full Access (or limit as you prefer) |

### URLs

| Field | URL |
|--------|-----|
| Privacy Policy | https://trektrack.pro/privacy.html |
| Support / Marketing | https://trektrack.pro |
| Support email | info@trektrack.pro |

### Bundle ID (if not listed yet)

1. [Identifiers](https://developer.apple.com/account/resources/identifiers/list) → **+** → App IDs → App
2. Description: `TrekTrack`
3. Bundle ID (Explicit): `com.ultraforge.trektrack`
4. Capabilities (enable as needed later):
   - Push Notifications (optional for now)
   - In-App Purchase (required for Pro)
   - Associated Domains (only if you add deep links later)
5. Location / Background Modes are declared in the app binary (Info.plist), not only on the identifier.

## App Store Connect steps

1. Open [Create app](https://appstoreconnect.apple.com/apps) → blue **+** → **New App**
2. Fill the table above → **Create**
3. **App Information**
   - Category: **Business** (primary); secondary optional **Finance** or **Navigation**
   - Content Rights: does not contain third-party content you don’t have rights to
4. **App Privacy** → start questionnaire (location, identifiers, purchase history)
5. **Pricing** → Free (with auto-renewable subscriptions)
6. **Subscriptions** (after app exists)
   - Group name: `TrekTrack Pro` (or `Premium`)
   - Products (must match code):
     - `com.ultraforge.trektrack.premium.monthly` — $3.99 / month — 7-day free trial
     - `com.ultraforge.trektrack.premium.yearly` — $29.99 / year — 7-day free trial
7. **Paid Apps Agreement** + banking/tax under **Business** (if not already Active)

## Xcode / local project

- Bundle ID in project: `com.ultraforge.trektrack`
- Display name: **TrekTrack**
- IAP product IDs: `mobile/lib/config/billing_config.dart`

After the app exists in ASC:

```bash
# In Xcode: open ios/Runner.xcworkspace
# Signing & Capabilities → Team → UltraForge LLC
# Then archive for TestFlight when ready:
cd mobile && flutter build ipa
```

## Optional: API create (automation)

If you create an App Store Connect API key (Users and Access → Integrations → App Store Connect API):

```bash
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_PATH=~/AuthKey_XXXXXXXXXX.p8
# Optional if your team has multiple orgs:
# export ASC_BUNDLE_ID=com.ultraforge.trektrack
./scripts/create_asc_app.sh
```

# HackerPillar Launch Readiness

Last updated: 2026-02-14

## Local Build Gates

- [x] App scheme (`HackerNewsApp`) Release build succeeds on iOS Simulator.
- [x] Widget scheme (`HackerPillarWidgetExtension`) Release build succeeds on iOS Simulator.
- [x] Share extension scheme (`HackerPillarShareExtension`) Release build succeeds on iOS Simulator.

## Launch-Critical Configuration

- [x] StoreKit product IDs in code are production IDs:
  - `hackerpillar.pro.monthly`
  - `hackerpillar.pro.yearly`
- [x] Legal links are wired with runtime fallbacks:
  - Terms: `https://smartcodeapps-website.vercel.app/hackerpillar/terms`
  - Privacy: `https://smartcodeapps-website.vercel.app/hackerpillar/privacy`
- [x] App Group entitlement is present across app/widget/share:
  - `group.com.hackerpillar.shared`
- [x] iCloud KVS entitlement is present in app target:
  - `com.apple.developer.ubiquity-kvstore-identifier`
- [x] Live Activities plist support is enabled:
  - `NSSupportsLiveActivities = YES`

## Settings/Product UX Launch Fixes Completed

- [x] Removed `Story Feed Card Style` from Settings (no longer exposed).
- [x] Feed is pinned to current production card style (`.normal`).
- [x] Restored default iOS nav title typography in Saved Stories / Settings / Offline.
- [x] Fixed Custom Feeds navigation trap by preserving back button while showing `Edit`.

## Remaining Release Gates (Manual / Device / ASC)

- [ ] Physical-device QA for:
  - Widget refresh behavior after bookmark/history/thread changes.
  - Share extension visibility in Safari and successful import pipeline.
  - iCloud sync correctness on multiple signed-in devices.
  - Live Activities lifecycle behavior.
- [ ] Full free-tier regression pass.
- [ ] Full Pro-tier regression pass (HN account actions, offline/download, advanced features).
- [ ] Sandbox purchase checklist: purchase, restore, cancel, offline behavior.
- [ ] App Store Connect finalization:
  - Subscription metadata/copy/pricing verification.
  - Final app metadata and policy links.
- [ ] Final App Store screenshot set (free + Pro surfaces).
- [ ] Final TestFlight smoke pass before submission.

## Known Non-Blocking Warning

- `HNAccount.swift` currently uses a deprecated API:
  - `NSKeyedUnarchiver.unarchiveTopLevelObjectWithData`
  - Not a blocker for submission, but should be modernized in a cleanup pass.

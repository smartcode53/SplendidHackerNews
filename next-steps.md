# HackerPillar Next Steps

This file tracks remaining implementation work after the current shipped branch state.

## Current Status

Completed in current branch:
- Pro/paywall foundation and Pro gating
- HN account (login/vote/reply) in production, Pro-gated
- Offline reading, advanced filters, smart feed, enhanced reader, iCloud sync, custom feeds
- User profiles, advanced search, thread tracking/notification core, custom themes, accessibility pass, iPad split behavior
- Phase 3 partial: onboarding, Spotlight, Siri shortcuts, widget extension target, share extension target, Live Activities scaffolding, performance dashboard scaffolding
- App Store subscription shipping pass:
  - product IDs aligned to `hackerpillar.pro.monthly` and `hackerpillar.pro.yearly`
  - entitlement refresh on transaction updates + app foreground
  - Settings includes first-class Pro upgrade/manage + restore surface
  - legal links configured and fallback URLs added in code
  - Settings UI migrated to native iOS `.insetGrouped` table layout
  - device build blocker in `ShortcutsProvider` fixed (`suggestedInvocationPhrase` removal)

## Remaining Plan

### 1. Stabilize Widget + Share on real devices (High Priority)
1. Validate App Group capability is enabled for all three targets in Apple Developer portal + provisioning profiles.
   - Status: completed in Apple Developer portal/profiles.
2. Verify widget refresh behavior after bookmark/history/thread changes on device.
3. Verify share extension appears in Safari and imports URLs into bookmarks reliably.
4. Add user-facing error telemetry/logging for share import failures.
   - Status: implemented in-branch via `ShareImportTelemetry` with app-group-backed counters/last-error details, instrumentation in share extension + app import path, and visible status/reset control in Settings. Still needs physical-device verification.

### 2. Complete Phase 3 Delivery Gaps (High Priority)
1. Build App Clip target (`HNAppClip`) with minimal story viewer and "Get Full App" CTA.
2. Harden Live Activities from scaffold to full feature:
   - user controls to start/stop per story
   - background refresh cadence and termination behavior
   - stale state UI handling
   - Status: partially implemented in-branch. Start/stop controls exist in thread tracking flow, and refresh loop now self-terminates when no active activities remain. Stale-state UI behavior still needs product/UI pass and on-device validation.
3. Finish performance dashboard UX polish:
   - chart readability
   - retention window controls
   - clear/reset controls
   - Status: implemented in-branch. Added retention window segmented control (24H/7D/30D/All), richer launch summary readability (avg/median/p95 + distribution), and clear-all control for local performance samples. Still needs physical-device QA.

### 3. Entitlements and Capability Audit (High Priority)
1. Confirm `com.apple.developer.ubiquity-kvstore-identifier` is configured and functioning for iCloud sync on physical devices.
   - Status: entitlement key added to app target (`HackerNewsApp/HackerNewsApp.entitlements`); still needs physical-device verification.
2. Confirm App Groups are consistent across app/widget/share in all build configurations.
   - Status: all three entitlements currently use `group.com.hackerpillar.shared`; portal/provisioning alignment completed.
3. Verify notification background modes/task scheduler identifiers are release-safe.
   - Status: no `BGTaskScheduler` identifiers found in current code path; still needs release/device verification for end-to-end notification behavior.
4. Verify Live Activities plist support is release-safe.
   - Status: `NSSupportsLiveActivities = YES` added for app Debug/Release build configs; still needs physical-device validation.

### 4. Productization and QA Pass (High Priority)
1. Run full free-tier regression (without Pro entitlement):
   - all free features usable
   - Pro surfaces show paywall gracefully
2. Run full Pro regression:
   - HN account actions, Pro tabs, Pro settings, offline/download flows
3. Navigation stress test:
   - Feed -> Comments -> Reader -> back
   - repeated tab switching and deep-link paths
4. Visual regression review:
   - card layout, shimmer, sun gradient/parallax, theme tint reactivity, iPad layouts

### 5. Store Readiness (Medium Priority)
1. Finalize subscription product metadata and review paywall copy.
   - Status: in progress. Product IDs and baseline localization copy are set; continue App Store Connect completion.
2. Complete sandbox purchase QA checklist.
   - Status: step 1 completed (sandbox setup). Continue purchase/restore/cancel/offline validation.
3. Prepare App Store screenshots for free and Pro surfaces.
4. Final TestFlight smoke pass on physical devices before submission.

### 6. Technical Debt Cleanup (Medium Priority)
1. Address key deprecations/warnings seen in builds:
   - `UITextItemInteraction` replacement
   - iOS 26 `UIScreen.main` and `UIBarButtonItem.Style.done` replacements
   - Swift 6 `nonisolated` warning on `NSCache`
   - Status: completed for current identified call sites in app target.
2. Reduce `HackerNewsAppApp.swift` size by extracting newly added services/controllers into focused files.
   - Status: in progress. Extracted so far:
     - `HackerNewsApp/Other/FeedImagePipeline.swift`
     - `HackerNewsApp/Views/UIKit Views/SunGradientView.swift`
     - `HackerNewsApp/Views/UIKit Views/ShimmerLayer.swift`
     - `HackerNewsApp/Views/UIKit Views/FeedStoryCell.swift`
     - `HackerNewsApp/Views/UIKit Views/StoryCommentsPagerViewController.swift`
     - `HackerNewsApp/Views/UIKit Views/SavedStoriesViewController.swift`
     - `HackerNewsApp/Views/UIKit Views/HistoryUIKitViewController.swift`
     - `HackerNewsApp/Views/UIKit Views/SettingsUIKitViewController.swift`
     - `HackerNewsApp/Views/UIKit Views/CustomFeedManagerViewController.swift`
     - `HackerNewsApp/Views/UIKit Views/TrackedThreadsViewController.swift`
     - `HackerNewsApp/Views/UIKit Views/PerformanceDashboardViewController.swift`
     - `HackerNewsApp/Views/UIKit Views/SearchViewController.swift`
     - `HackerNewsApp/Views/UIKit Views/UserProfileViewController.swift`
     - `HackerNewsApp/Views/UIKit Views/ReaderViewController.swift`
     - `HackerNewsApp/Views/UIKit Views/FeedViewController.swift`
     - `HackerNewsApp/Views/UIKit Views/OnboardingViewController.swift`
     - `HackerNewsApp/Other/PerformanceMonitor.swift`
     - `HackerNewsApp/Other/ShortcutsProvider.swift`
     - `HackerNewsApp/Other/WidgetShareBridge.swift`
     - `HackerNewsApp/Other/NotificationTracking.swift`
     - `HackerNewsApp/Other/LiveActivityManager.swift`
     - `HackerNewsApp/Other/HNAlgoliaClient.swift`
     - `HackerNewsApp/Other/CustomFeedManager.swift`
     - `HackerNewsApp/Other/ThemeManager.swift`
     - `HackerNewsApp/Other/SpotlightIndexer.swift`
     - `HackerNewsApp/Other/HNTabBarController.swift`
     - `HackerNewsApp/Other/HNIPadSplitViewController.swift`
   - Current footprint: `HackerNewsApp/Other/HackerNewsAppApp.swift` reduced to ~218 lines in this branch.
   - Validation status: simulator build + app launch pass after each extraction step in this session.
3. Add targeted tests for pure-model logic where feasible (filters/ranking/reader extraction).

## Suggested Execution Order

1. Stabilize widget/share on device.
2. Complete App Clip + Live Activities hardening.
3. Run entitlements audit and full QA pass.
4. Resolve high-risk warnings/deprecations.
5. Final store-readiness sweep.

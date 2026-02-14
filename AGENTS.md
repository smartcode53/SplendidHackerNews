# Repository Guidelines

## Project Structure & Module Organization
Xcode project: `HackerNewsApp.xcodeproj`. UIKit app target + extension targets.

- `HackerNewsApp/Other/HackerNewsAppApp.swift`: app entry point (`AppDelegate`) and root app routing helpers.
- `HackerNewsApp/Views/TabView/ContentView/Subviews/CommentsView.swift`: `CommentsUIKitViewController` and `UIKitCommentCell`.
- `HackerNewsApp/ViewModels/`: screen/state logic (`GlobalSettingsViewModel`, `ContentViewModel`, `BookmarksViewModel`, `CommentsThreadViewModel`, `ReaderViewModel`, etc.).
- `HackerNewsApp/Other/`: networking (`HNAPIClient`, `NetworkManager`, `StoryRepository`), persistence (`SettingsPersistenceCoordinator`, `ReadStateStore`, `HistoryStore`), caching, reader extraction.
- `HackerNewsApp/Models/`: `Story`, `Bookmark`, `Comment`, `Settings`, `Item`, `StoryWrapper`, `HistoryEntry`.
- `HackerNewsApp/Cache/`: `CommentsCache`, `AttributedStringCache`.
- `HackerNewsApp/Other/Assets.xcassets`: app colors/icons.
- `HackerNewsWidget/`: Widget extension source (`HackerPillarWidget.swift`, `WidgetSnapshot*`, `Info.plist`).
- `ShareExtension/`: Share extension source (`ShareViewController.swift`, `Info.plist`).

## Current Baseline (Important Context)
- Product naming in UI is **HackerPillar** / **HackerPillar Pro**.
- **UIKit throughout** — the app was fully converted from SwiftUI to UIKit. ViewModels are `ObservableObject` observed via Combine `.sink()`. No SwiftUI views remain.
- Freemium/Pro infrastructure is in place (StoreKit 2 manager + paywall + feature gating + offline entitlement grace).
- HN account functionality (login/vote/reply) has been promoted from debug-only to production, gated by Pro entitlement.
- Debug/simulator convenience toggle exists to force Pro during local testing.
- Feed smoothness has been optimized; preserve existing low-jank behavior when editing feed rows.
- Story images in feed cards must stay clipped to card bounds (no vertical overflow).
- Feed card "trash" action was replaced with bookmark save.
- Reader mode entry is detail-first:
  - feed cards show a tappable title that opens `SFSafariViewController`
  - comments/detail header exposes reader + safari + share actions
- **Feed card design (`FeedStoryCell`):**
  - Large hero image (200pt) with `ShimmerLayer` animated placeholder; collapses when no image
  - Orange domain pill (`systemOrange` tinted)
  - Title with orange `arrow.up.right` safari indicator
  - Meta label (author + relative time)
  - Hairline divider
  - Action bar: orange points badge on left; filled capsule buttons for comments (with count), share, bookmark on right
  - Card: 16pt continuous corner radius, subtle shadow, alpha 0.75 for read stories
- **Sun gradient (`SunGradientView`):**
  - Radial orange gradient overlaying top-right corner of `FeedViewController`
  - Adapts to dark/light mode; fades to 0 alpha over first 120pt of scroll
  - Navigation bar `scrollEdgeAppearance` is transparent so gradient shows through title area
  - `isUserInteractionEnabled = false`; do not remove or reposition
- Bookmark UX supports:
  - save-only-once behavior (`addBookmarkIfNeeded`)
  - visual saved state (orange `bookmark.fill`, disabled after saving)
  - success feedback (haptic + temporary "Saved" toast)
- Comments thread rendering was refactored for stability/performance:
  - comments are preprocessed and flattened into `visibleRows` in `CommentsThreadViewModel`
  - UI uses row-based rendering in `CommentsView`/`UIKitCommentCell` (not recursive nested child views)
  - indentation is visually capped to prevent deep-thread trailing overflow
  - descendant reply counts are precomputed (avoid per-render recursive counting)
- Reader typography was tightened for production readability:
  - default `readerLineSpacing` is `2.0`
  - line-spacing controls use `0...6` with `0.5` step
- Theme changes are now reactive at runtime (tint updates immediately without tab switching).

## Roadmap Progress Snapshot
- Implemented major Phase 1 and Phase 2 features in current branch, including offline reading, advanced filters, smart feed, enhanced reader, iCloud sync, custom feeds, user profiles, advanced search, thread tracking/notifications core, custom themes, accessibility pass, and iPad split behavior.
- Implemented Phase 3 integrations in current branch:
  - onboarding flow
  - Spotlight indexing
  - Siri shortcuts routing/donation
  - Widget target (`HackerPillarWidgetExtension`) and app-group snapshot pipeline
  - Share extension target (`HackerPillarShareExtension`) and bridge import pipeline
  - Live Activities manager scaffolding
  - local performance dashboard scaffolding
- Widget now uses `containerBackground` API and has a proper `@main` widget bundle entrypoint.
- Apple Developer portal App Group/provisioning alignment is completed for app + widget + share (`group.com.hackerpillar.shared`).

## Completed Recently
- `HackerNewsAppApp.swift` extraction pass completed; file now focuses on app entry/routing while services/controllers live in focused files under `HackerNewsApp/Other/` and `HackerNewsApp/Views/UIKit Views/`.
- Feed image latency improvements shipped:
  - wider/earlier prefetch windows
  - additional prefetch on viewport settle
  - safer cell-level image task cancellation.
- Comments latency improvements shipped:
  - parallelized initial comments screen async work
  - comment plain-text path now reads `AttributedStringCache` before reparsing.
- Share import telemetry + user-facing health shipped:
  - app-group-backed failure/success telemetry
  - instrumentation in app import + share extension
  - settings surface for status and reset.
- Store-readiness UX improvements shipped:
  - legal links support in paywall/settings via `LegalTermsURL` and `LegalPrivacyURL`
  - clearer offline/no-store restore/purchase/load messaging in paywall.

## Build, Test, and Development Commands
Use from repo root:

```bash
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

XcodeBuildMCP is available — prefer `session-set-defaults` + `build_sim` / `build_run_sim` / `test_sim` over raw xcodebuild commands.

Extension scheme checks:
```bash
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerPillarWidgetExtension -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerPillarShareExtension -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected workflow: after every code change, run build + simulator launch to validate behavior end-to-end.

## Coding Style & Naming Conventions
- Swift/UIKit, 4-space indentation, `// MARK:` for structure.
- `UpperCamelCase` for types, `lowerCamelCase` for members.
- Prefer Auto Layout with `NSLayoutConstraint` for UIKit views.
- Keep view controller logic lightweight; move action logic into helper methods.
- Gate debug-only features with `#if DEBUG`.

## Testing & PR Guidelines
- No dedicated unit-test target; rely on targeted simulator smoke tests.
- Verify feed scrolling, image loading/shimmer, bookmark state, sun gradient fade, and Saved Stories persistence on each related PR.
- PRs should include: scope, user-visible impact, manual test steps, and screenshots/video for UI changes.

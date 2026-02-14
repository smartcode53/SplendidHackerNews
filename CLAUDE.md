# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

Build for iOS Simulator (Debug):
```
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Build for iOS Simulator (Release):
```
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

XcodeBuildMCP is available — prefer `session-set-defaults` + `build_sim` / `build_run_sim` / `test_sim` over raw xcodebuild commands.

Build widget/share extension schemes (Debug):
```
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerPillarWidgetExtension -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerPillarShareExtension -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

There are no automated tests. The project has no test targets. Validate changes by building and running on the simulator.

## Architecture

**UIKit iOS app** (iOS 15+, iPhone & iPad) using **MVVM** with Combine observation. Fully converted from SwiftUI to UIKit — all UI is pure UIKit with no SwiftUI hosting controllers. Product-facing naming is **HackerPillar**.

### Layers

| Layer | Location | Role |
|-------|----------|------|
| Models | `HackerNewsApp/Models/` | `Story`, `Comment`, `Item` (Algolia), `Bookmark`, `Settings`, `HistoryEntry`, `StoryWrapper` |
| ViewModels | `HackerNewsApp/ViewModels/` | `@MainActor ObservableObject` classes — one per major view, observed via Combine `.sink()` |
| Services | `HackerNewsApp/Other/` | Networking, caching, persistence, reader extraction |
| Views | `HackerNewsApp/Other/` + `HackerNewsApp/Views/` | UIKit view controllers (`HackerNewsAppApp.swift` now primarily `AppDelegate`/routing) |
| Widget Extension | `HackerNewsWidget/` | WidgetKit timeline/provider/view + shared snapshot loader |
| Share Extension | `ShareExtension/` | URL capture from system share sheet into app-group queue |

### UIKit View Controllers

Core view controllers are split into focused files under `HackerNewsApp/Other/` and `HackerNewsApp/Views/UIKit Views/`:

- **`HNTabBarController`** — root tab bar (Feed, Saved, Settings)
- **`FeedViewController`** — main feed with `UITableView` (grouped style), prefetching, pull-to-refresh, `FeedStoryCell`, sun gradient overlay
- **`FeedStoryCell`** — custom card cell with large hero image, shimmer placeholder, domain pill, title with safari indicator, action buttons
- **`SunGradientView`** — radial orange gradient in top-right corner, fades on scroll via `scrollViewDidScroll`
- **`ShimmerLayer`** — `CAGradientLayer` subclass for animated loading placeholders
- **`CommentsUIKitViewController`** (in `CommentsView.swift`) — comment threads with hero image parallax, search via `UISearchController`, `UIKitCommentCell`
- **`SavedStoriesViewController`** — bookmarks list
- **`HistoryUIKitViewController`** — browsing history
- **`SettingsUIKitViewController`** — settings in native iOS `.insetGrouped` table layout
- **`ReaderViewController`** — article reader with UITextView and typography controls

### ViewModel-UIKit Binding Pattern

ViewModels remain `ObservableObject` with `@Published` properties. UIKit view controllers observe via Combine:

```swift
vm.$stories
    .receive(on: RunLoop.main)
    .sink { [weak self] stories in
        self?.applyStoriesChange(stories)
    }
    .store(in: &cancellables)
```

### Data Flow

- **HNAPIClient** — low-level calls to the HN Firebase API (`hacker-news.firebaseio.com/v0`) and Algolia API (`hn.algolia.com/api/v1`)
- **StoryRepository** — wraps HNAPIClient with a 10-minute actor-based TTL cache; all ViewModels fetch stories through this
- **NetworkManager** — singleton for image fetching and URL metadata
- **FeedImagePipeline** — actor for thread-safe image caching with Core Graphics downsampling, deduplication, and NSCache (180 item limit)
- **CommentsCache / AttributedStringCache** — NSCache-based in-memory caches

### Concurrency Model

- `async/await` throughout the networking layer
- `actor` isolation for shared state: `StoryCache` (inside StoryRepository), `ReadStateStore`, `HistoryStore`, `FeedImagePipeline`
- `@MainActor` on all ViewModels
- `Task.detached(priority: .utility)` for background HTML parsing
- Iterative DFS for comment tree flattening (avoids stack overflow on deep threads)

### Performance Patterns

- `UITableViewDataSourcePrefetching` for images and pagination in the feed
- Background image downsampling via Core Graphics
- Pre-parsing entire comment trees on background threads
- Debounced saves via `SettingsPersistenceCoordinator`
- Comments preprocessed and flattened into `visibleRows` (not recursive nested views)
- Indentation visually capped to prevent deep-thread overflow

### Persistence

All file-based, stored in the Documents directory:
- `settings.txt` — user preferences (theme, card style, reader font settings)
- `bookmark.txt` — saved stories
- `read_state.json` — which stories have been read + per-feed hide-read flags
- `history.json` — browsing history with timestamps
- `debug-settings.json` — debug-only settings

App Group shared data:
- group id: `group.com.hackerpillar.shared`
- widget snapshot file: `widget_snapshot.json`
- pending share URLs key: `share.pending.urls`
- Apple Developer portal/provisioning alignment for this App Group is completed for app + widget + share targets.

### Navigation

Tab-based (`HNTabBarController`): **Feed**, **Saved**, **Settings**.

Navigation is direct UIKit push/pop:
```swift
navigationController?.pushViewController(
    CommentsUIKitViewController(vm: commentsVM, onOpenReader: { ... }),
    animated: true
)
```

`SFSafariViewController` for in-app web browsing. `GlobalSettingsViewModel` is passed to view controllers at creation and available throughout the app.

### Pro/Debug Gating

- Pro gating is implemented via StoreKit 2 and `ProFeatureGate`.
- HN account login/session, voting, and replying are production features gated by Pro entitlement.
- Keep diagnostics-style tooling debug-gated where appropriate.
- Local testing supports a debug/simulator "Force Pro" switch in Settings.

## Feed Card Design (`FeedStoryCell`)

Modern card-based feed cells in `HackerNewsAppApp.swift`:

- **Hero image** (200pt) with `ShimmerLayer` animated placeholder + centered photo icon while loading; collapses entirely when no image is available
- **Orange domain pill** — `systemOrange` tinted badge showing the source hostname
- **Title row** — semibold headline (up to 3 lines) with an orange `arrow.up.right` safari indicator; tapping opens `SFSafariViewController`
- **Meta label** — author and relative timestamp
- **Divider** — hairline separator
- **Action bar** — orange points badge (arrow + score) on left; filled capsule buttons for comments (with count), share, and bookmark on right
- **Bookmark state** — orange `bookmark.fill` when saved, disabled after saving; save triggers haptic + "Saved" toast
- **Read state** — card alpha dimmed to 0.75 when story has been read
- Card uses 16pt continuous corner radius with subtle shadow (opacity 0.06, radius 8)

## Sun Gradient Effect

`SunGradientView` overlays the top-right corner of `FeedViewController`:

- Radial `CAGradientLayer` emanating from top-right `(1.0, 0.0)` outward
- Orange color stops that adapt to dark/light mode (stronger in dark mode)
- Navigation bar uses transparent `scrollEdgeAppearance` so gradient shows through the title area
- `scrollViewDidScroll` fades gradient alpha to 0 over the first 120pt of scroll
- `isUserInteractionEnabled = false` — touches pass through to the table

## Dependencies (SPM)

- **OpenGraph** — OG metadata extraction from URLs
- **SwiftSoup** — HTML parsing
- **Atributika** — rich text rendering
- **HTML2Markdown** — HTML-to-Markdown conversion
- **Glur** — visual blur effects

## Key Protocols

- `SafariViewLoader` — provides URL loading into in-app Safari
- `CommentsButtonProtocol` — standardized comments loading interface
- `ErrorPresenter` — centralized error display
- `RetryPolicy` — network retry logic

## State Management Pattern

ViewModels use a `LoadState` enum (`.idle`, `.loading`, `.loaded`, `.empty`, `.error`) to drive view state. View controllers switch on this enum to show appropriate UI (skeleton, content, empty state, error with retry).

## Current Baseline

- Feed smoothness has been optimized; preserve existing low-jank behavior when editing feed rows.
- Story images in feed cards must stay clipped to card bounds (no vertical overflow).
- Reader mode entry is detail-first: feed cards don't show a reader button; comments/detail header exposes reader + safari + share actions.
- Bookmark UX supports save-only-once behavior with visual saved state and haptic feedback.
- Sun gradient in top-right corner fades on scroll; do not remove or reposition.
- Theme tint updates are reactive at runtime (no tab-switch needed).

## Roadmap Progress (Current Branch)

- Phase 1/2 core work has been landed (Pro/paywall foundation, HN account promotion, offline reading, advanced filters, smart feed, enhanced reader, iCloud sync, custom feeds, profiles, search, thread tracking core, gestures, custom themes, accessibility, iPad split behavior).
- Phase 3 currently landed:
  - onboarding flow
  - Spotlight indexing
  - Siri shortcuts
  - widget extension target + integration
  - share extension target + integration
  - Live Activities scaffolding
  - performance dashboard scaffolding

## Completed Recently

- `HackerNewsAppApp.swift` extraction completed: app entry/routing remains there; major services/controllers are now in focused files.
- Feed image latency improvements:
  - wider/earlier image prefetch window
  - prefetch on viewport settle
  - safer cell image-task cancellation to avoid stale late completions.
- Comments load latency improvements:
  - initial comments async tasks now run in parallel
  - comment plain-text path now uses `AttributedStringCache` before reparsing HTML.
- Share import telemetry + user-facing health controls:
  - app-group-backed telemetry utility
  - instrumentation in share extension and app import bridge
  - settings surface + reset.
- Store-readiness UX additions:
  - legal links in paywall/settings via `LegalTermsURL` + `LegalPrivacyURL`
  - improved restore/purchase/load edge-case copy for offline/no-store states.
- Subscription shipping hardening:
  - product IDs aligned to `hackerpillar.pro.monthly` / `hackerpillar.pro.yearly`
  - entitlement refresh on transaction updates and app foreground
  - first-class Pro management in Settings (upgrade/manage + restore)
  - legal-link runtime fallback URLs added for resilience.
- Device build compatibility fix:
  - removed `NSUserActivity.suggestedInvocationPhrase` usage in `ShortcutsProvider` for current SDK/device builds.

## Coding Style

- Swift, 4-space indentation, `// MARK:` for structure.
- `UpperCamelCase` for types, `lowerCamelCase` for members.
- Prefer Auto Layout with `NSLayoutConstraint` for UIKit views.
- Keep view controller logic lightweight; move action logic into helper methods.
- Gate debug-only features with `#if DEBUG`.

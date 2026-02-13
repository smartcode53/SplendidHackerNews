# Repository Guidelines

## Project Structure & Module Organization
Single-app Xcode project: `HackerNewsApp.xcodeproj`. Pure UIKit (no SwiftUI).

- `HackerNewsApp/Other/HackerNewsAppApp.swift`: app entry point and most view controllers (`FeedViewController`, `FeedStoryCell`, `SunGradientView`, `ShimmerLayer`, `SavedStoriesViewController`, `HistoryUIKitViewController`, `SettingsUIKitViewController`, `ReaderViewController`, `FeedImagePipeline`).
- `HackerNewsApp/Views/TabView/ContentView/Subviews/CommentsView.swift`: `CommentsUIKitViewController` and `UIKitCommentCell`.
- `HackerNewsApp/ViewModels/`: screen/state logic (`GlobalSettingsViewModel`, `ContentViewModel`, `BookmarksViewModel`, `CommentsThreadViewModel`, `ReaderViewModel`, etc.).
- `HackerNewsApp/Other/`: networking (`HNAPIClient`, `NetworkManager`, `StoryRepository`), persistence (`SettingsPersistenceCoordinator`, `ReadStateStore`, `HistoryStore`), caching, reader extraction.
- `HackerNewsApp/Models/`: `Story`, `Bookmark`, `Comment`, `Settings`, `Item`, `StoryWrapper`, `HistoryEntry`.
- `HackerNewsApp/Cache/`: `CommentsCache`, `AttributedStringCache`.
- `HackerNewsApp/Other/Assets.xcassets`: app colors/icons.

## Current Baseline (Important Context)
- **UIKit throughout** — the app was fully converted from SwiftUI to UIKit. ViewModels are `ObservableObject` observed via Combine `.sink()`. No SwiftUI views remain.
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

## Build, Test, and Development Commands
Use from repo root:

```bash
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

XcodeBuildMCP is available — prefer `session-set-defaults` + `build_sim` / `build_run_sim` / `test_sim` over raw xcodebuild commands.

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

# Repository Guidelines

## Project Structure & Module Organization
Single-app Xcode project: `HackerNewsApp.xcodeproj`.

- `HackerNewsApp/Views/TabView/`: main tabs (`ContentView`, `BookmarksView`, `SettingsView`).
- `HackerNewsApp/Views/TabView/ContentView/Subviews/PostView.swift`: primary feed card UI (compact + featured).
- `HackerNewsApp/ViewModels/`: screen/state logic (`GlobalSettingsViewModel`, `ContentViewModel`, `BookmarksViewModel`).
- `HackerNewsApp/Other/`: networking, persistence, routing, diagnostics.
- `HackerNewsApp/Models/`: `Story`, `Bookmark`, `Comment`, `Settings`.
- `HackerNewsApp/Other/Assets.xcassets`: app colors/icons.

## Current Baseline (Important Context)
- Feed smoothness has been optimized in recent work; preserve existing low-jank behavior when editing feed rows.
- Story images in feed cards must stay clipped to card bounds (no vertical overflow), without introducing new `GeometryReader`-based layout for this fix path.
- Feed card “trash” action was replaced with bookmark save.
- Reader mode entry is now detail-first:
  - feed cards no longer show a reader button
  - comments/detail header now exposes reader + safari + share actions
- Bookmark UX now supports:
  - save-only-once behavior (`addBookmarkIfNeeded`)
  - visual saved state (`bookmark.fill`, dimmed, disabled)
  - success feedback (haptic + temporary “Saved” toast in `PostView`)
- Comments thread rendering was refactored for stability/performance:
  - comments are preprocessed and flattened into `visibleRows` in `CommentsThreadViewModel`
  - UI uses row-based rendering in `CommentsView`/`SingleCommentView` (not recursive nested child views)
  - indentation is visually capped to prevent deep-thread trailing overflow
  - descendant reply counts are precomputed (avoid per-render recursive counting)
- Reader typography was tightened for production readability:
  - default `readerLineSpacing` is `2.0`
  - line-spacing controls now use `0...6` with `0.5` step
  - `LinkTextView` sizing now respects container width (no `UIScreen.main.bounds` dependence)

## Build, Test, and Development Commands
Use from repo root:

```bash
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected workflow for this repo: after every code change, run build + simulator launch to validate behavior end-to-end.

## Coding Style & Naming Conventions
- Swift/SwiftUI, 4-space indentation, `// MARK:` for structure.
- `UpperCamelCase` for types, `lowerCamelCase` for members.
- Keep view `body` lightweight; move action logic into helper methods.
- Prefer modern SwiftUI APIs (`foregroundStyle`, `clipShape`) and avoid unnecessary view invalidations.
- Gate debug-only features with `#if DEBUG`.

## Testing & PR Guidelines
- No dedicated unit-test target currently; rely on targeted simulator smoke tests.
- Verify feed scrolling, image clipping, bookmark state, and Saved Stories persistence on each related PR.
- PRs should include: scope, user-visible impact, manual test steps, and screenshots/video for UI changes.

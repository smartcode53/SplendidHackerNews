# Repository Guidelines

## Project Structure & Module Organization
The app is a single Xcode project: `HackerNewsApp.xcodeproj` with source under `HackerNewsApp/`.

- `HackerNewsApp/Views/`: SwiftUI UI, organized by tab (`ContentView`, `BookmarksView`, `SettingsView`) plus reusable/UIKit wrappers.
- `HackerNewsApp/ViewModels/`: `@MainActor` observable view models and route state.
- `HackerNewsApp/Models/`: domain models (`Story`, `Comment`, `Settings`, etc.).
- `HackerNewsApp/Other/`: services/infrastructure (API client, repository, parsers, persistence, keychain, routing).
- `HackerNewsApp/Cache/`, `HackerNewsApp/Extensions/`, `HackerNewsApp/ViewModifiers/`: shared supporting code.
- Assets live in `HackerNewsApp/Other/Assets.xcassets` and `HackerNewsApp/Preview Content/`.

## Build, Test, and Development Commands
Use Xcode or `xcodebuild` from repo root:

```bash
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project HackerNewsApp.xcodeproj -scheme HackerNewsApp -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

- `Debug` build: daily development and debug-only features.
- `Release` build: verify debug-only UI/flows are excluded.

## Coding Style & Naming Conventions
- Swift + SwiftUI with MVVM and async/await.
- Use 4-space indentation and keep files organized with `// MARK:` sections.
- Types/protocols: `UpperCamelCase`; variables/functions: `lowerCamelCase`.
- One primary type per file; filename should match the main type (for example, `ContentViewModel.swift`).
- Gate non-production functionality with `#if DEBUG`.

## Testing Guidelines
There is currently **no automated test target**. Validate changes with:
1. Debug build + simulator smoke test for affected flows.
2. Release build check to confirm debug-only features are not reachable (Settings debug section, HN account/diagnostics, vote/reply paths).
3. Include manual test notes in PRs.

## Commit & Pull Request Guidelines
Recent history uses short, informal subjects (for example, `Update`, `Minor changes`). For new work, prefer clear imperative summaries:

- Commit format: `Area: concise change` (example: `Feed: fix pagination retry state`).
- Keep commits focused and logically grouped.
- PRs should include: purpose, key changes, manual verification steps, and screenshots/videos for UI updates.
- Link related issues when applicable.

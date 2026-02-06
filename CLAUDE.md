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

There are no automated tests. The project has no test targets.

## Architecture

**SwiftUI iOS app** (iOS 15+, iPhone & iPad) using **MVVM** with a repository/service layer.

### Layers

| Layer | Location | Role |
|-------|----------|------|
| Models | `HackerNewsApp/Models/` | `Story`, `Comment`, `Item` (Algolia), `Bookmark`, `Settings`, `HistoryEntry` |
| ViewModels | `HackerNewsApp/ViewModels/` | `@MainActor ObservableObject` classes — one per major view |
| Services | `HackerNewsApp/Other/` | Networking, caching, persistence, reader extraction |
| Views | `HackerNewsApp/Views/` | SwiftUI views organized by tab |

### Data Flow

- **HNAPIClient** — low-level calls to the HN Firebase API (`hacker-news.firebaseio.com/v0`) and Algolia API (`hn.algolia.com/api/v1`)
- **StoryRepository** — wraps HNAPIClient with a 10-minute actor-based TTL cache; all ViewModels fetch stories through this
- **NetworkManager** — singleton for image fetching and URL metadata
- **CommentsCache / ReaderContentCache** — NSCache-based in-memory caches

### Concurrency Model

- `async/await` throughout the networking layer
- `actor` isolation for shared state: `StoryCache` (inside StoryRepository), `ReadStateStore`, `HistoryStore`
- `@MainActor` on all ViewModels

### Persistence

All file-based, stored in the Documents directory:
- `settings.txt` — user preferences (theme, card style, reader font settings)
- `read_state.json` — which stories have been read + per-feed hide-read flags
- `history.json` — browsing history with timestamps
- `debug-settings.json` — debug-only settings

### Navigation

Tab-based (`TabEnclosingView`): **Feed**, **Saved**, **Settings**.

Programmatic navigation via `AppRoute` enum (`.comments(Story)`, `.reader(Story)`, `.history`, plus debug-only routes).

`GlobalSettingsViewModel` is injected as `@EnvironmentObject` at the root and available throughout the app.

### Debug-Only Code

Significant functionality is gated behind `#if DEBUG`: HN account login/session, voting, replying, diagnostics panel, reader preview, and debug logging. These files live alongside production code but are excluded from Release builds. When adding debug features, always wrap them in `#if DEBUG`.

**Release verification:** Debug section must not appear in Settings; HN Account, Diagnostics, Reader Preview, vote buttons, and reply actions must be unreachable.

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

ViewModels use a `LoadState` enum (`.idle`, `.loading`, `.loaded`, `.empty`, `.error`) to drive view state. Views switch on this enum to show appropriate UI (skeleton, content, empty state, error with retry).

# SplendidHackerNews - Performance Optimization Memory

## Architecture Overview
- **MVVM** with SwiftUI, targeting iOS
- Xcode project at `/HackerNewsApp.xcodeproj`, single scheme `HackerNewsApp`
- Feed pipeline: `HNAPIClient` -> `StoryRepository` (actor TTL cache) -> `ContentViewModel` -> `PostView`
- Image pipeline: `NetworkManager` (OpenGraph) -> `UltimatePostViewModel` -> `PostView` via AsyncImage
- Three-layer image caching: `ImageURLCache` (OG URL), `ImageAvailabilityCache` (bool), `ImageCache` (SwiftUI Image)

## Key Files
- `HackerNewsApp/Other/HNAPIClient.swift` - Firebase HN API client with optimized URLSession
- `HackerNewsApp/Other/StoryRepository.swift` - Story cache + fetch orchestration
- `HackerNewsApp/Other/NetworkManager.swift` - OpenGraph image fetching with deduplication + Algolia comment fetching
- `HackerNewsApp/Other/CommentHTMLParser.swift` - Lightweight SwiftSoup HTML->AttributedString parser for comments
- `HackerNewsApp/Cache/AttributedStringCache.swift` - NSCache for parsed comment AttributedStrings (keyed by HTML string)
- `HackerNewsApp/ViewModels/ContentViewModel.swift` - Feed state, pagination, prefetch
- `HackerNewsApp/ViewModels/CommentsThreadViewModel.swift` - Comment thread orchestration, flat search index, pre-parsing
- `HackerNewsApp/ViewModels/UltimatePostViewModel.swift` - Per-post VM with image loading
- `HackerNewsApp/Other/Protocols.swift` - Contains `RetryPolicy`, `ErrorPresenter`, `CommentsButtonProtocol`

## Optimizations Applied (2026-02-06)
See [optimizations.md](optimizations.md) for details.

1. **URLSession**: Custom session with `httpMaximumConnectionsPerHost=12` for HN API
2. **Story fetching**: Sliding-window TaskGroup (max 20 concurrent) replaces sequential chunks of 8
3. **OG deduplication**: Actor-based in-flight request coalescing in NetworkManager
4. **Image prefetch**: Fire-and-forget (non-blocking), all candidates launched concurrently
5. **Infinite scroll**: 70% threshold trigger (stories.count - 10) instead of last-item-only
6. **Cache re-check**: UltimatePostViewModel re-checks URL cache before OG fetch

## Comment Optimizations Applied (2026-02-06)
7. **HTML parser**: Replaced NSAttributedString(.html) with SwiftSoup-based `CommentHTMLParser` (~50x faster, any-thread)
8. **AttributedString cache**: `AttributedStringCache` (NSCache, keyed by HTML string) prevents re-parsing on re-renders
9. **Pre-parsing**: `CommentsThreadViewModel.loadComments` fires `Task.detached` to pre-parse all HTML on utility thread
10. **Flat search index**: Pre-lowercased text/author + ancestor chains built once on `setComments`, O(n) flat scan per query
11. **Algolia session**: Dedicated `algoliaSession` with `httpMaximumConnectionsPerHost=6`, `waitsForConnectivity=true`
12. **Comment retry**: `getComments` uses `RetryPolicy.runWithTransientRetry` for transient network errors
13. **Shared decoder**: Single `JSONDecoder` instance for comment responses (avoids per-request allocation)

## Comment Pipeline
- `CommentsView.onAppear` -> `CommentsThreadViewModel.loadComments` -> `CommentsButtonProtocol.loadComments` -> `CommentsCache` / `NetworkManager.getComments`
- HTML parsing: `SingleCommentView` calls `text.markdown` -> checks `AttributedStringCache` -> `CommentHTMLParser.parse`
- Pre-parse: after `loadComments` succeeds, `Task.detached(priority: .utility)` iteratively walks tree and fills cache
- HN HTML tags handled: p, a, i/em, b/strong, code, pre, blockquote, br

## Build Notes
- Pre-existing deprecation warnings (onChange, NavigationLink, UITextItemInteraction)
- `httpShouldUsePipelining` deprecated in iOS 18.4, removed
- OpenGraph library used for OG image extraction: `import OpenGraph`
- `#if DEBUG` blocks with `DebugEnvironment.shared.fixtureMode` must be preserved

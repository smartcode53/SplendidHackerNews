# Performance Optimizations Detail

## 1. HNAPIClient - URLSession & Concurrent Fetching
**Before**: Used `URLSession.shared` (4-6 connections/host). `fetchStories` launched ALL tasks unbounded.
**After**: Custom session with 12 connections/host, 15s request timeout, waitsForConnectivity.
`fetchStories` uses sliding-window TaskGroup with max 20 concurrent tasks: seeds N tasks, then adds one as each completes.

## 2. StoryRepository - Eliminated Sequential Chunking
**Before**: Split missing IDs into chunks of 8, fetched each chunk sequentially (await between chunks). For 30 stories = 4 sequential round-trips.
**After**: Single call to `client.fetchStories(ids: missing, maxConcurrent: 20)`. The sliding-window concurrency inside HNAPIClient handles throttling. For 30 stories = ~1.5 waves instead of 4.

## 3. NetworkManager - In-Flight OG Deduplication
**Before**: Both `prefetchImageURLs` (ContentViewModel) and `loadImage` (UltimatePostViewModel via PostView's .task) could fire concurrent OpenGraph fetches for the same URL.
**After**: `OpenGraphDeduplicator` actor tracks in-flight Tasks keyed by URL string. Second caller awaits existing Task instead of issuing duplicate fetch.

## 4. ContentViewModel - Non-Blocking Image Prefetch
**Before**: `await prefetchImageURLs(for: page.appended)` blocked before setting `stories` (in refresh) or before `loadMoreState = .idle` (in loadNextPage). The entire feed display was delayed by OG fetch time.
**After**: Stories are set immediately. `prefetchImageURLs` fires in a detached `Task { }` (fire-and-forget). Images load in background while user sees content.

## 5. ContentViewModel - Image Prefetch Batch Size
**Before**: Sequential batches of 6 with `while` loop + `withTaskGroup` per batch.
**After**: Single `withTaskGroup` launches all candidates. URLSession's per-host limits naturally throttle connections. OG deduplicator prevents redundant work.

## 6. ContentViewModel - Early Infinite Scroll
**Before**: `loadMoreIfNeeded(currentID:)` only triggered when `currentID == stories.last?.id`.
**After**: Triggers when `currentIndex >= stories.count - 10` (~70% threshold). User never sees the end of content.

## 7. UltimatePostViewModel - Cache Re-check Before Fetch
**Before**: Went straight to `networkManager.getImage(fromUrl:)` if init didn't find cache.
**After**: Re-checks `imageURLCache` and `imageAvailabilityCache` before network call (prefetcher may have populated them between init and .task fire). If found, returns immediately without network call.

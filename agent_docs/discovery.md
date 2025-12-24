# Discovery Feature

Random article exploration from independent blogs and small websites.

## Overview

The Discovery feature allows users to explore random articles from independent blogs and small websites. Users can browse articles, save interesting ones to their reading list, or skip to find something else. The feature supports multiple discovery sources that users can switch between.

## Data Sources

Discovery supports multiple sources via the `DiscoverySourceProtocol`:

### Kagi Small Web

**URL**: `https://kagi.com/smallweb/opml`

The OPML feed provides direct article URLs (not RSS feed URLs). Each `<outline>` element contains:
- `xmlUrl`: Direct link to the article
- `title` / `text`: Article or site title
- `htmlUrl`: Optional site homepage

Example entry:
```xml
<outline type="rss" text="Example Blog" title="Example Blog"
         xmlUrl="https://example.com/interesting-post"
         htmlUrl="https://example.com"/>
```

**Important**: Despite `type="rss"`, these are article URLs, not feed URLs. Do not attempt RSS parsing.

**XML Sanitization**: Kagi's OPML contains unescaped ampersands in URLs (e.g., `&p=123` instead of `&amp;p=123`). The `OPMLDataSource` sanitizes these before parsing using a regex that escapes lone ampersands while preserving valid XML entities.

### Blogroll.org

**URL**: `https://blogroll.org/feed`

A curated directory of independent blogs. Unlike Kagi Small Web, this is a two-step process:
1. Fetch the blogroll RSS feed to get a list of blogs (with their feed URLs)
2. Pick a random blog, fetch its RSS feed, then pick a random post from that blog

This provides fresher content since it fetches the latest posts from each blog rather than a static article list.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        DiscoveryReaderView                       │
│                              │                                   │
│                    DiscoveryViewModel                            │
└─────────────────────────────────────────────────────────────────┘
                               │
            ┌──────────────────┼──────────────────┐
            ▼                  ▼                  ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Discovery       │  │ Article         │  │ Preferences     │
│ Service         │  │ Service         │  │ DataSource      │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                    │
         ▼                    ▼
┌─────────────────┐  ┌─────────────────┐
│ Discovery       │  │ SwiftData       │
│ DataSources     │  │ ModelContext    │
│ (Protocol)      │  └─────────────────┘
└─────────────────┘
    │         │
    ▼         ▼
┌───────┐ ┌───────┐
│ Kagi  │ │Blogroll│
│DataSrc│ │DataSrc│
└───────┘ └───────┘
    │         │
    ▼         ▼
┌───────┐ ┌───────────┐
│ OPML  │ │ RSS       │
│DataSrc│ │DataSources│
└───────┘ └───────────┘
```

## Data Flow

1. **Fetch Random Article** (two-phase with progress callback):
   - `DiscoverySourceProtocol.randomArticleEntry()` returns a random `SmallWebArticleEntry`
   - Uses cached data if valid (24-hour cache per source)
   - **Progress callback** fires immediately with the article URL (enables early UI feedback)
   - `MetadataDataSource.fetchContent()` fetches article content from the URL (slow, up to 10s)
   - Returns `EphemeralArticle` (not persisted until user saves)

2. **Save to Reading List**:
   - `ArticleService.saveEphemeralArticle()` converts `EphemeralArticle` to `Article`
   - Persists via SwiftData ModelContext

3. **Check if Already Saved**:
   - ViewModel queries `ArticleService.getAllArticles()` to check URL match
   - Updates `isSaved` state to show checkmark instead of save button

4. **Source Selection**:
   - User preference stored via `DiscoveryPreferencesDataSource`
   - `DiscoveryService` routes to appropriate DataSource based on selected source

## Files

### Models

| File | Description |
|------|-------------|
| `Models/SmallWebFeed.swift` | `SmallWebArticleEntry` - parsed entry with title and articleUrl (shared by all sources) |
| `Models/EphemeralArticle.swift` | Temporary article not yet saved to reading list |
| `Models/DiscoverySource.swift` | Enum defining available discovery sources (kagiSmallWeb, blogroll) |

### DataSources

| File | Description |
|------|-------------|
| `DataSources/OPMLDataSource.swift` | XML parser for Kagi OPML format with ampersand sanitization |
| `DataSources/BlogrollRSSDataSource.swift` | RSS parser for blogroll.org feed (extracts blog feed URLs) |
| `DataSources/GenericRSSDataSource.swift` | Generic RSS parser for individual blog feeds (extracts post URLs) |
| `DataSources/KagiSmallWebDataSource.swift` | Fetches/caches Kagi OPML, provides random articles. Implements `DiscoverySourceProtocol`. |
| `DataSources/BlogrollDataSource.swift` | Fetches/caches blogroll, fetches blog feeds, provides random posts. Implements `DiscoverySourceProtocol`. |
| `DataSources/DiscoveryPreferencesDataSource.swift` | Stores user's selected discovery source preference |
| `Core/DataSources/SeenItemTracker.swift` | Hash-based tracking of seen items with auto-reset |

### Services

| File | Description |
|------|-------------|
| `Services/DiscoveryService.swift` | Orchestrates random article fetching from all sources. Supports progress callback via `fetchRandomArticle(from:onArticleEntryFetched:)`. |

### Views

| File | Description |
|------|-------------|
| `Views/DiscoveryViewModel.swift` | State management with auto-retry on fetch errors (up to 5 attempts). Exposes `pendingArticleURL` for early loading feedback. |
| `Views/DiscoveryReaderView.swift` | Main view with toolbar, loading, error states |
| `Views/DiscoveryArticleContentView.swift` | Article content display with markdown |
| `Views/BlogrollLoadingView.swift` | Loading view specific to blogroll source |

### Shared UI

| File | Description |
|------|-------------|
| `Core/UI/ShimmerModifier.swift` | Reusable animated gradient overlay for loading states. Apply via `.shimmer()` modifier. |

### Shared Reader Components

Located in `Core/UI/Readers/`, shared with the Reader feature. See [reader.md](reader.md) for details.

| File | Description |
|------|-------------|
| `MarkdownUtilities.swift` | H1 stripping to avoid duplicate titles in markdown |
| `ReaderTheme.swift` | `.gitHubBackground` color and `.reader` markdown theme |

## Caching

Discovery uses a **two-layer caching strategy**: article pool caching and seen-item tracking.

### Article Pool Cache

Each discovery source caches its article/blog list in UserDefaults:

| Source | Cache Key | Timestamp Key | Duration |
|--------|-----------|---------------|----------|
| Kagi Small Web | `smallweb_articles_v2` | `smallweb_cache_timestamp_v2` | 24 hours |
| Blogroll.org | `blogroll_articles_v1` | `blogroll_cache_timestamp_v1` | 24 hours |

Cache stores JSON-encoded arrays containing title, URL, and optional htmlUrl for each entry.

### Seen-Item Tracking

`SeenItemTracker` (`Core/DataSources/SeenItemTracker.swift`) prevents showing the same article/blog twice using **djb2 hashing**:

```swift
private func stableHash(_ string: String) -> UInt64 {
    var hash: UInt64 = 5381
    for byte in string.utf8 {
        hash = ((hash << 5) &+ hash) &+ UInt64(byte)
    }
    return hash
}
```

| Source | Storage Key | Tracks |
|--------|-------------|--------|
| Kagi | `smallweb_shown_articles` | Individual article URLs |
| Blogroll | `blogroll_shown_blogs` | Blog feed URLs (not individual posts) |

**Why hashing?** Storing ~5000 URL strings would consume ~500KB+. Storing 64-bit hashes uses ~40KB—a 12x memory reduction.

**Auto-Reset**: When 80%+ of items have been seen (configurable via `resetThreshold`), the tracker automatically resets to allow repeat selections.

### Force Refresh

Users can clear the cache via "Refresh Article Pool" in the Discovery menu. This calls `clearCache()` on DiscoveryService, clearing both the article pool and seen-item hashes.

## Error Handling

**10-Second Timeout**: Discovery article fetches use a 10-second timeout (passed to MetadataDataSource). If an article doesn't respond in time, the system automatically moves to the next article. This timeout is specific to Discovery—the normal reader uses URLSession's default timeout.

**Auto-Skip Behavior**: When an article fails to load (timeout, dead URL, etc.), the ViewModel automatically tries another article. Errors are only shown after 5 consecutive failures, indicating a likely network issue.

### Kagi Small Web Errors

| Error | Cause | User Message |
|-------|-------|--------------|
| `SmallWebError.fetchFailed` | Network error fetching OPML | "Could not load the article list" |
| `SmallWebError.parsingFailed` | Empty or invalid OPML | "Could not parse the article list" |
| `SmallWebError.noArticlesAvailable` | Empty article list | "No articles available" |

### Blogroll Errors

| Error | Cause | User Message |
|-------|-------|--------------|
| `BlogrollError.fetchFailed` | Network error fetching blogroll | "Could not load the blogroll" |
| `BlogrollError.parsingFailed` | Empty or invalid blogroll | "Could not parse the blogroll" |
| `BlogrollError.noArticlesAvailable` | Empty blog list | "No blogs available" |
| `BlogrollError.blogFeedFetchFailed` | Failed to fetch individual blog's RSS | "Could not load the blog's feed" |
| `BlogrollError.noPostsInBlogFeed` | Blog feed has no posts | "No posts found in this blog" |

**Blogroll Retry Logic**: `BlogrollDataSource` retries up to 5 times when fetching random articles, automatically skipping blogs with broken feeds.

### General Errors

| Error | Cause | User Message |
|-------|-------|--------------|
| `DiscoveryError.contentFetchFailed` | Article content fetch failed | "Could not load article content: {underlying error}" |

## Entry Points

1. **Home Screen**: Dice icon button in top-left toolbar opens `DiscoveryReaderView`
2. **ArticleListView**: `DiscoveryToolbarButton` triggers sheet presentation

## DI Container Integration

```swift
// In DIContainer.swift
private lazy var opmlDataSource: OPMLDataSource
private lazy var blogrollRSSDataSource: BlogrollRSSDataSource
private lazy var genericRSSDataSource: GenericRSSDataSource
private lazy var kagiSmallWebDataSource: KagiSmallWebDataSource
private lazy var blogrollDataSource: BlogrollDataSource
private lazy var discoveryService: DiscoveryServiceProtocol

func makeDiscoveryViewModel() -> DiscoveryViewModel
```

## UI Components

- **DiscoveryLoadingView**: Spinner with "Finding something interesting..." and domain chip (when URL is known)
- **BlogrollLoadingView**: Loading view for blogroll source
- **LoadingDomainChip**: Displays target domain with shimmer animation during content fetch
- **DiscoveryErrorView**: Error message with "Try Another" button
- **DiscoveryToolbar**: Menu with Save, Try Another (dice), Share, Open in Browser, Refresh Article Pool, Source Selection

**Shimmer Effect**: The `ShimmerModifier` (`Core/UI/ShimmerModifier.swift`) creates an animated gradient highlight that sweeps across the chip, providing visual feedback that content is loading.

## Debug Logging

Debug builds include logging (wrapped in `#if DEBUG`) for:
- OPML/RSS download size and parse count
- Article/blog selection and shown/unseen counts
- Cache clearing events
- XML parse errors with line/column numbers

## Testing Considerations

- Mock `DiscoveryServiceProtocol` to control article fetching behavior
- Mock `ArticleServiceProtocol` to control save operations
- Mock `DiscoverySourceProtocol` to return controlled `SmallWebArticleEntry` values
- Mock `MetadataDataSourceProtocol` to avoid network calls
- Test auto-retry logic in `DiscoveryViewModel` by simulating consecutive failures
- Test cache expiration logic in both `KagiSmallWebDataSource` and `BlogrollDataSource`
- Test XML sanitization with malformed ampersands in `OPMLDataSource`
- Test `SeenItemTracker` hash persistence and auto-reset behavior
- Test blogroll's two-step fetch (blogroll → blog feed → random post)
- Verify `@MainActor` isolation prevents data races in concurrent access scenarios

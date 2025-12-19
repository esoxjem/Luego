# Discovery Feature

Random article exploration using Kagi Small Web.

## Overview

The Discovery feature allows users to explore random articles from independent blogs and small websites curated by Kagi's Small Web initiative. Users can browse articles, save interesting ones to their reading list, or skip to find something else.

## Data Source

**Kagi Small Web OPML**: `https://kagi.com/smallweb/opml`

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
│ FetchRandom     │  │ SaveDiscovered  │  │ Article         │
│ ArticleUseCase  │  │ ArticleUseCase  │  │ Repository      │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                    │                    │
         ▼                    │                    │
┌─────────────────┐           │                    │
│ SmallWeb        │           │                    │
│ Repository      │           └────────────────────┘
└─────────────────┘                    │
         │                             ▼
         ▼                    ┌─────────────────┐
┌─────────────────┐           │ SwiftData       │
│ OPMLDataSource  │           │ ModelContext    │
└─────────────────┘           └─────────────────┘
         │
         ▼
┌─────────────────┐
│ Metadata        │
│ Repository      │
└─────────────────┘
```

## Data Flow

1. **Fetch Random Article**:
   - `SmallWebRepository.randomArticleEntry()` returns a random `SmallWebArticleEntry`
   - Uses cached OPML data if valid (24-hour cache)
   - `MetadataRepository.fetchContent()` fetches article content from the URL
   - Returns `EphemeralArticle` (not persisted until user saves)

2. **Save to Reading List**:
   - `SaveDiscoveredArticleUseCase` converts `EphemeralArticle` to `Article`
   - Persists via `ArticleRepository`

3. **Check if Already Saved**:
   - ViewModel queries `ArticleRepository.getAll()` to check URL match
   - Updates `isSaved` state to show checkmark instead of save button

## Files

### Models

| File | Description |
|------|-------------|
| `Models/SmallWebFeed.swift` | `SmallWebArticleEntry` - parsed OPML entry with title and articleUrl |
| `Models/EphemeralArticle.swift` | Temporary article not yet saved to reading list |

### DataSources

| File | Description |
|------|-------------|
| `DataSources/OPMLDataSource.swift` | XML parser for Kagi OPML format with ampersand sanitization. Marked `@MainActor` for thread-safe SwiftData integration. |

### Repositories

| File | Description |
|------|-------------|
| `Repositories/SmallWebRepository.swift` | Fetches/caches OPML, provides random entries |

### UseCases

| File | Description |
|------|-------------|
| `UseCases/FetchRandomArticleUseCase.swift` | Gets random article from SmallWeb |
| `UseCases/SaveDiscoveredArticleUseCase.swift` | Converts ephemeral article to persisted Article |

### Views

| File | Description |
|------|-------------|
| `Views/DiscoveryViewModel.swift` | State management with auto-retry on fetch errors (up to 5 attempts) |
| `Views/DiscoveryReaderView.swift` | Main view with toolbar, loading, error states |
| `Views/DiscoveryArticleContentView.swift` | Article content display with markdown |

## Caching

`SmallWebRepository` caches OPML data in UserDefaults:
- `smallweb_articles_v2`: JSON-encoded array of `CachedArticle`
- `smallweb_cache_timestamp_v2`: Cache creation date
- `smallweb_shown_articles`: Set of djb2 URL hashes (`UInt64`) for non-repeat selection
- Duration: 24 hours

Cache stores title, articleUrl, and htmlUrl for each entry.

**Hash-Based Tracking**: Shown articles are tracked using 64-bit djb2 hashes instead of full URL strings, reducing memory usage by ~12x while maintaining stable persistence across app launches.

**Force Refresh**: Users can clear the cache via "Refresh Article Pool" in the Discovery menu. This clears all cached data and fetches fresh OPML (~5000 articles, ~1.4MB download).

## Error Handling

**Auto-Skip Behavior**: When an article fails to load (timeout, dead URL, etc.), the ViewModel automatically tries another article. Errors are only shown after 5 consecutive failures, indicating a likely network issue.

| Error | Cause | User Message |
|-------|-------|--------------|
| `SmallWebError.fetchFailed` | Network error fetching OPML | "Could not load the article list" |
| `SmallWebError.parsingFailed` | Empty or invalid OPML | "Could not parse the article list" |
| `SmallWebError.noArticlesAvailable` | Empty article list | "No articles available" |
| `DiscoveryError.contentFetchFailed` | Article content fetch failed | "Could not load article content: {underlying error}" |

**Error Context**: `DiscoveryError.contentFetchFailed` includes the underlying error's `localizedDescription` for better debugging (e.g., network timeouts, parsing failures).

## Entry Points

1. **Home Screen**: Dice icon button in top-left toolbar opens `DiscoveryReaderView`
2. **ArticleListView**: `DiscoveryToolbarButton` triggers sheet presentation

## DI Container Integration

```swift
// In DIContainer.swift
private lazy var opmlDataSource: OPMLDataSource
private lazy var smallWebRepository: SmallWebRepositoryProtocol
private lazy var fetchRandomArticleUseCase: FetchRandomArticleUseCaseProtocol
private lazy var saveDiscoveredArticleUseCase: SaveDiscoveredArticleUseCaseProtocol

func makeDiscoveryViewModel() -> DiscoveryViewModel
```

## UI Components

- **DiscoveryLoadingView**: Spinner with "Finding something interesting..."
- **DiscoveryErrorView**: Error message with "Try Another" button
- **DiscoveryToolbar**: Menu with Save, Try Another (dice), Share, Open in Browser, Refresh Article Pool

## Debug Logging

Debug builds include logging (wrapped in `#if DEBUG`) for:
- OPML download size and parse count
- Article selection and shown/unseen counts
- Cache clearing events
- XML parse errors with line/column numbers

## Testing Considerations

- Mock `SmallWebRepositoryProtocol` to return controlled `SmallWebArticleEntry` values
- Mock `MetadataRepositoryProtocol` to avoid network calls
- Test auto-retry logic in `DiscoveryViewModel` by simulating consecutive failures
- Test cache expiration logic in `SmallWebRepository`
- Test XML sanitization with malformed ampersands in `OPMLDataSource`
- Test hash-based shown article tracking persists correctly across app launches
- Verify `@MainActor` isolation prevents data races in concurrent access scenarios

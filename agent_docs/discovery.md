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
| `DataSources/OPMLDataSource.swift` | XML parser for Kagi OPML format |

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
- Duration: 24 hours

Cache stores title, articleUrl, and htmlUrl for each entry.

## Error Handling

**Auto-Skip Behavior**: When an article fails to load (timeout, dead URL, etc.), the ViewModel automatically tries another article. Errors are only shown after 5 consecutive failures, indicating a likely network issue.

| Error | Cause | User Message |
|-------|-------|--------------|
| `SmallWebError.fetchFailed` | Network error fetching OPML | "Could not load the article list" |
| `SmallWebError.parsingFailed` | Empty or invalid OPML | "Could not parse the article list" |
| `SmallWebError.noArticlesAvailable` | Empty article list | "No articles available" |
| `DiscoveryError.contentFetchFailed` | Article content fetch failed | "Could not load article content" |

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
- **DiscoveryToolbar**: Menu with Save, Try Another (dice), Share, Open in Browser

## Testing Considerations

- Mock `SmallWebRepositoryProtocol` to return controlled `SmallWebArticleEntry` values
- Mock `MetadataRepositoryProtocol` to avoid network calls
- Test auto-retry logic in `DiscoveryViewModel` by simulating consecutive failures
- Test cache expiration logic in `SmallWebRepository`

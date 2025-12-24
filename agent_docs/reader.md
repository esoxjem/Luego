# Reader Feature

Article reading experience with markdown rendering and read position tracking.

## Overview

The Reader feature displays saved articles in a clean, distraction-free reading interface. It fetches article content on-demand, renders markdown with a custom theme, and tracks reading progress.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          ReaderView                              │
│                              │                                   │
│                       ReaderViewModel                            │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   ReaderService     │
                    └─────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
┌─────────────────────┐              ┌─────────────────────┐
│ Metadata            │              │ SwiftData           │
│ DataSource          │              │ ModelContext        │
└─────────────────────┘              └─────────────────────┘
```

## Data Flow

1. **Load Content**:
   - `ReaderViewModel.loadContent()` checks if article already has content
   - If not, `ReaderService.fetchContent()` fetches markdown via `MetadataDataSource`
   - Content is persisted to the `Article` model for future access

2. **Read Position Tracking**:
   - `ScrollPositionTracker` monitors scroll position via GeometryReader
   - Position updates are debounced (1 second delay) to avoid excessive writes
   - `ReaderService.updateReadPosition()` persists position (0.0 to 1.0)
   - On view appear, scroll position is restored from saved value

## Files

### Services

| File | Description |
|------|-------------|
| `Services/ReaderService.swift` | Fetches article markdown content (supports force refresh), persists read position (0.0-1.0) to article |

### Views

| File | Description |
|------|-------------|
| `Views/ReaderView.swift` | Main reader view with loading, content, and error states |
| `Views/ReaderViewModel.swift` | State management for article content and read position |

## Shared Reader Components

Located in `Core/UI/Readers/`, these components are shared between Reader and Discovery features.

| File | Description |
|------|-------------|
| `MarkdownUtilities.swift` | H1 stripping to avoid duplicate titles, fuzzy title matching |
| `ReaderTheme.swift` | `.gitHubBackground` color and `.reader` markdown theme |
| `DomainChip.swift` | Clickable domain chip linking to article URL |
| `ReaderMarkdownImageView.swift` | Async image loading for markdown content |
| `ReaderImageProvider.swift` | MarkdownUI ImageProvider using shared image view |

### Markdown H1 Stripping

The `stripFirstH1FromMarkdown(_:matchingTitle:)` function removes duplicate titles:
- Searches first 3 H1 headings in markdown
- Uses Jaccard similarity (>0.7 threshold) for fuzzy matching
- Handles normalized comparison (lowercase, no punctuation)
- Removes matching H1 and trailing blank lines

## Read Position Tracking

### How It Works

1. **ScrollPositionTracker** uses nested GeometryReader to track:
   - `contentHeight`: Total scrollable content height
   - `viewHeight`: Visible viewport height
   - `scrollPosition`: Current scroll offset from top

2. **Position Calculation**:
   ```swift
   let maxScroll = contentHeight - viewHeight
   let position = scrollPosition / maxScroll  // 0.0 to 1.0
   ```

3. **Debouncing**: Updates are debounced with 1-second delay to prevent excessive persistence calls during active scrolling.

4. **Restoration**: On view appear, saved position is restored using ScrollViewReader with interpolated anchor.

## UI Components

- **ArticleLoadingView**: Spinner with "Loading article..." text
- **ArticleReaderModeView**: Main content display with header, divider, markdown
- **ArticleErrorView**: Error state with "Open in Browser" and "Retry" buttons
- **ReaderViewToolbar**: Menu with Refresh, Open in Browser, Share options
- **ArticleHeaderView**: Title, domain chip, and formatted date
- **ScrollPositionTracker**: GeometryReader-based scroll position monitor

## Entry Points

1. **Reading List**: Tap any article in ArticleListView navigates to ReaderView
2. **Navigation**: Uses NavigationLink with ArticleReaderDestination wrapper

## DI Container Integration

```swift
// In DIContainer.swift
private lazy var readerService: ReaderServiceProtocol

func makeReaderViewModel(article: Article) -> ReaderViewModel
```

## Content Fetching

- **On-Demand**: Content is fetched only when user opens article
- **Caching**: Once fetched, content is persisted to Article.content
- **Force Refresh**: Toolbar "Refresh Content" option re-fetches from source
- **Error Handling**: Failed fetches show error view with retry option

## Testing Considerations

- Mock `ReaderServiceProtocol` for content loading and position update tests
- Test debouncing logic with rapid scroll position changes
- Test position restoration with various saved positions
- Test H1 stripping with various title formats and edge cases

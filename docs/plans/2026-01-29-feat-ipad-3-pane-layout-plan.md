---
title: "feat: Add iPad Support with 3-Pane Adaptive Layout"
type: feat
date: 2026-01-29
status: reviewed
---

# Add iPad Support with 3-Pane Adaptive Layout

## Overview

Add iPad support to Luego with a 3-pane `NavigationSplitView` layout that adapts to screen orientation. The layout provides a sidebar for navigation, a content pane for article lists, and a detail pane for reading articles.

## User Decisions

| Decision | Choice |
|----------|--------|
| Orientation behavior | **Adaptive**: 3 panes in landscape, 2 panes in portrait (sidebar hidden, accessible via toolbar) |
| Tabs pane content | **Navigation tabs only**: All Articles, Favorites, Archived, Discovery |
| Discovery integration | **Special sidebar item**: Shows shuffle UI directly in content+detail panes (no article list) |
| Empty detail state | **Simple placeholder**: "Select an article" text centered (NetNewsWire-style) |

## Review Summary

Plan reviewed by DHH, Kieran, and Simplicity reviewers. Key changes incorporated:

| Issue | Resolution |
|-------|------------|
| NavigationState class over-engineered | Use `@State` variables directly in ContentView |
| SidebarItem duplicates ArticleFilter | Extend `ArticleFilter` with `.discovery` case |
| iPad/ subdirectory creates false separation | Keep views flat in feature folders |
| ViewModel lifecycle bug in DetailPaneView | Use `@State` + `onChange` for proper lifecycle |
| @Query fetching all articles inefficient | Pass article directly to DetailPaneView |

## Current State

**File references:**
- `Luego/App/ContentView.swift:11-35` - iPhone TabView with 3 tabs + NavigationStack per tab
- `Luego/Features/ReadingList/Views/ArticleFilter.swift:1-56` - Filter enum (.readingList, .favorites, .archived)
- `Luego/Features/ReadingList/Views/ArticleListView.swift:154-159` - NavigationLink to ReaderView
- `Luego/Features/Discovery/Views/DiscoveryReaderView.swift` - Current fullScreenCover modal

**Architecture:**
- iPhone-only with TabView navigation
- No existing size class handling
- Discovery accessed via toolbar button (fullScreenCover)
- Services and ViewModels are UI-agnostic (can be reused)

## Proposed Solution

### Layout Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    iPad Landscape (3-pane)                   │
├──────────┬─────────────────────┬────────────────────────────┤
│ Sidebar  │    Content Pane     │       Detail Pane          │
│          │                     │                            │
│ ○ All    │  [ArticleRow 1]     │   Article Title            │
│ ○ Favs   │  [ArticleRow 2]     │   ─────────────            │
│ ○ Archive│  [ArticleRow 3] ←   │   Article content...       │
│ ○ Discover│ [ArticleRow 4]     │                            │
│          │                     │                            │
└──────────┴─────────────────────┴────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    iPad Portrait (2-pane)                    │
├─────────────────────────┬───────────────────────────────────┤
│     Content Pane        │          Detail Pane              │
│  [≡ Sidebar toggle]     │                                   │
│  [ArticleRow 1]         │   Article Title                   │
│  [ArticleRow 2]         │   ─────────────                   │
│  [ArticleRow 3] ←       │   Article content...              │
│  [ArticleRow 4]         │                                   │
└─────────────────────────┴───────────────────────────────────┘
```

### Device Detection Strategy

Use `horizontalSizeClass` environment value:
- **Regular width** → NavigationSplitView (iPad in most configurations)
- **Compact width** → TabView (iPhone, iPad in Slide Over/narrow Split View)

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

var body: some View {
    if horizontalSizeClass == .regular {
        iPadLayout
    } else {
        iPhoneLayout
    }
}
```

## Technical Approach

### Phase 1: Extend ArticleFilter

Extend the existing `ArticleFilter` enum to support sidebar navigation (no new types).

**Modified file: `Luego/Features/ReadingList/Views/ArticleFilter.swift`**

```swift
enum ArticleFilter: CaseIterable, Hashable {
    case readingList
    case favorites
    case archived
    case discovery

    var title: String {
        switch self {
        case .readingList: "All Articles"
        case .favorites: "Favourites"
        case .archived: "Archived"
        case .discovery: "Discovery"
        }
    }

    var icon: String {
        switch self {
        case .readingList: "list.bullet"
        case .favorites: "heart"
        case .archived: "archivebox.fill"
        case .discovery: "die.face.5"
        }
    }

    var isArticleList: Bool {
        self != .discovery
    }

    func filtered(_ articles: [Article]) -> [Article] {
        switch self {
        case .readingList: articles.filter { !$0.isFavorite && !$0.isArchived }
        case .favorites: articles.filter { $0.isFavorite }
        case .archived: articles.filter { $0.isArchived }
        case .discovery: [] // Discovery doesn't filter articles
        }
    }
}
```

**Tasks:**
- [x] Add `.discovery` case to ArticleFilter
- [x] Add `icon` computed property
- [x] Add `isArticleList` computed property
- [x] Update `CaseIterable` conformance

### Phase 2: iPad Layout in ContentView

Refactor `ContentView.swift` to support both iPhone and iPad layouts using simple `@State`.

**Modified file: `Luego/App/ContentView.swift`**

```swift
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.diContainer) private var diContainer

    // iPad navigation state (simple @State, no wrapper class)
    @State private var selectedFilter: ArticleFilter = .readingList
    @State private var selectedArticle: Article?

    // iPhone state
    @State private var selectedTab = 0

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedFilter)
        } content: {
            contentPane
        } detail: {
            DetailPaneView(
                article: selectedArticle,
                onPositionSave: saveCurrentArticlePosition
            )
        }
    }

    @ViewBuilder
    private var contentPane: some View {
        if selectedFilter.isArticleList {
            ArticleListPane(
                filter: selectedFilter,
                selectedArticle: $selectedArticle
            )
        } else {
            DiscoveryPane()
        }
    }

    private var iPhoneLayout: some View {
        // Existing TabView code (unchanged)
        TabView(selection: $selectedTab) {
            Tab("", systemImage: "list.bullet", value: 0) {
                NavigationStack {
                    ArticleListView(filter: .readingList)
                }
            }
            Tab("", systemImage: "heart", value: 1) {
                NavigationStack {
                    ArticleListView(filter: .favorites)
                }
            }
            Tab("", systemImage: "archivebox.fill", value: 2) {
                NavigationStack {
                    ArticleListView(filter: .archived)
                }
            }
        }
    }

    private func saveCurrentArticlePosition() {
        // Called before article changes to persist read position
    }
}
```

**Tasks:**
- [x] Add `horizontalSizeClass` environment
- [x] Add `@State` for `selectedFilter` and `selectedArticle`
- [x] Implement conditional layout switching
- [x] Preserve existing iPhone TabView code unchanged

### Phase 3: Sidebar Component

**New file: `Luego/Features/ReadingList/Views/SidebarView.swift`**

```swift
struct SidebarView: View {
    @Binding var selection: ArticleFilter

    var body: some View {
        List(ArticleFilter.allCases, id: \.self, selection: $selection) { filter in
            Label(filter.title, systemImage: filter.icon)
        }
        .navigationTitle("Luego")
    }
}
```

**Tasks:**
- [x] Create `SidebarView.swift` in `Features/ReadingList/Views/`
- [x] Use `ArticleFilter.allCases` for sidebar items
- [x] Bind selection to parent's `selectedFilter`

### Phase 4: Article List Pane

**New file: `Luego/Features/ReadingList/Views/ArticleListPane.swift`**

```swift
struct ArticleListPane: View {
    let filter: ArticleFilter
    @Binding var selectedArticle: Article?
    @Environment(\.diContainer) private var diContainer
    @State private var viewModel: ArticleListViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                SelectableArticleList(
                    viewModel: vm,
                    filter: filter,
                    selection: $selectedArticle
                )
            }
        }
        .task {
            if viewModel == nil, let container = diContainer {
                viewModel = container.makeArticleListViewModel()
            }
        }
        .navigationTitle(filter.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AddArticleButton()
            }
            ToolbarItem(placement: .primaryAction) {
                SettingsButton()
            }
        }
    }
}

struct SelectableArticleList: View {
    @Bindable var viewModel: ArticleListViewModel
    let filter: ArticleFilter
    @Binding var selection: Article?

    var body: some View {
        List(filter.filtered(viewModel.articles), id: \.id, selection: $selection) { article in
            ArticleRowView(article: article)
                .tag(article)
        }
    }
}
```

**Tasks:**
- [x] Create `ArticleListPane.swift`
- [x] Create `SelectableArticleList` that uses selection binding (not NavigationLink)
- [x] Handle toolbar items (Add, Settings)

### Phase 5: Detail Pane

**New file: `Luego/Features/ReadingList/Views/DetailPaneView.swift`**

```swift
struct DetailPaneView: View {
    let article: Article?
    let onPositionSave: () -> Void
    @Environment(\.diContainer) private var diContainer
    @State private var readerViewModel: ReaderViewModel?

    var body: some View {
        Group {
            if let article = article {
                readerContent(for: article)
            } else {
                EmptyDetailView()
            }
        }
        .onChange(of: article?.id) { oldID, newID in
            if oldID != nil, oldID != newID {
                // Save position before switching articles
                readerViewModel?.saveReadPosition()
            }
            // Create new ViewModel for new article
            if let newArticle = article, let container = diContainer {
                readerViewModel = container.makeReaderViewModel(article: newArticle)
            } else {
                readerViewModel = nil
            }
        }
        .task {
            // Initialize on first appear
            if let article = article, readerViewModel == nil, let container = diContainer {
                readerViewModel = container.makeReaderViewModel(article: article)
            }
        }
    }

    @ViewBuilder
    private func readerContent(for article: Article) -> some View {
        if let vm = readerViewModel {
            ReaderView(viewModel: vm)
        } else {
            ProgressView()
        }
    }
}

struct EmptyDetailView: View {
    var body: some View {
        ContentUnavailableView(
            "No Article Selected",
            systemImage: "doc.text",
            description: Text("Select an article to start reading")
        )
    }
}
```

**Tasks:**
- [x] Create `DetailPaneView.swift`
- [x] Use `@State` for `readerViewModel` with `onChange` lifecycle
- [x] Create `EmptyDetailView` placeholder
- [x] Save read position before article switch (handled by ReaderView's onDisappear)

### Phase 6: Discovery Pane

**New file: `Luego/Features/Discovery/Views/DiscoveryPane.swift`**

```swift
struct DiscoveryPane: View {
    @Environment(\.diContainer) private var diContainer
    @State private var viewModel: DiscoveryViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                DiscoveryInlineView(viewModel: vm)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil, let container = diContainer {
                viewModel = container.makeDiscoveryViewModel()
            }
        }
        .navigationTitle("Discovery")
    }
}

struct DiscoveryInlineView: View {
    @Bindable var viewModel: DiscoveryViewModel

    var body: some View {
        // Reuse existing DiscoveryReaderView content
        // but adapted for inline display (no fullScreenCover)
        GeometryReader { geometry in
            if let article = viewModel.currentArticle {
                DiscoveryArticleView(article: article, viewModel: viewModel)
            } else {
                DiscoveryEmptyState(onShuffle: { Task { await viewModel.fetchRandomArticle() } })
            }
        }
    }
}
```

**Tasks:**
- [x] Create `DiscoveryPane.swift` in `Features/Discovery/Views/`
- [x] Adapt existing DiscoveryReaderView for inline 3-pane display
- [x] Handle shuffle and save actions

## File Structure (Simplified)

```
Luego/
├── App/
│   └── ContentView.swift              # Modified: Add iPad layout
├── Features/
│   └── ReadingList/
│       └── Views/
│           ├── ArticleFilter.swift    # Modified: Add .discovery case
│           ├── SidebarView.swift      # New (~15 lines)
│           ├── ArticleListPane.swift  # New (~40 lines)
│           └── DetailPaneView.swift   # New (~45 lines)
│   └── Discovery/
│       └── Views/
│           └── DiscoveryPane.swift    # New (~30 lines)
```

**Total: 4 new files (~130 lines), 2 modified files**

## Acceptance Criteria

### Functional Requirements

- [x] iPad displays 3-pane NavigationSplitView in landscape
- [x] iPad displays 2-pane layout in portrait (sidebar hidden)
- [x] Sidebar contains 4 items: All Articles, Favorites, Archived, Discovery
- [x] Tapping sidebar item updates content pane with correct article list
- [x] Tapping article in list displays it in detail pane
- [x] iPhone continues to use existing TabView (no changes)
- [x] Empty detail pane shows "Select an article" placeholder
- [x] Discovery shows inline shuffle UI when selected in sidebar

### Non-Functional Requirements

- [x] No breaking changes to iPhone experience
- [x] Maintains existing service/ViewModel architecture
- [x] Read position saves correctly when switching articles
- [x] Handles iPad multitasking (falls back to TabView in compact width)

### Edge Cases

- [ ] Orientation change preserves article selection
- [ ] Archived/favorited article stays in detail pane (even if removed from list)
- [ ] Deleted article clears selection and shows empty state
- [ ] App launch shows empty detail pane (no auto-selection)

## Testing Checklist

- [ ] Test on iPad simulator (landscape orientation)
- [ ] Test on iPad simulator (portrait orientation)
- [ ] Test orientation changes while reading
- [ ] Test sidebar selection changes
- [ ] Test article selection in content pane
- [ ] Test swipe actions (archive, favorite, delete)
- [ ] Test Discovery flow in 3-pane
- [ ] Test read position persistence
- [ ] Verify iPhone experience unchanged
- [ ] Test iPad in Split View (compact width fallback)
- [ ] Test iPad in Slide Over (compact width fallback)

## References

### Internal

- `Luego/App/ContentView.swift:11-35` - Current TabView implementation
- `Luego/Features/ReadingList/Views/ArticleFilter.swift:1-56` - Filter enum
- `Luego/Features/ReadingList/Views/ArticleListView.swift:154-159` - NavigationLink pattern
- `Luego/Features/Reader/Views/ReaderView.swift:266-273` - Read position saving
- `Luego/Core/DI/DIContainer.swift:120-148` - ViewModel factory methods

### External

- [NavigationSplitView Documentation](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [Building a Great Mac App with SwiftUI (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10104/)
- NetNewsWire source code - Reference implementation for 3-pane RSS reader

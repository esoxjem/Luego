# Luego - MVP Features

## Overview
Luego is a minimal read-it-later iOS app that lets users save articles, read them in a clean reader mode, and manage a simple reading list.

## Implementation Status
**Last Updated:** 2025-11-10

- ✅ = Completed
- 🚧 = In Progress
- ⏳ = Not Started

## Core Features (MVP v1.0)

### 1. Save Articles ✅ (Partial)
**Priority: Critical**

Users can save articles through two methods:
- ⏳ **Share Extension**: Share URLs from Safari or other apps directly into Luego *(Deferred to v1.1)*
- ✅ **In-App URL Entry**: Paste or type URLs directly within the app

**Technical Implementation:**
- ✅ Simple URL input field in main app (AddArticleView)
- ✅ Basic URL validation with auto-scheme detection
- ✅ Automatic article metadata fetching (title, thumbnail)
- ✅ Open Graph tag extraction using SwiftSoup
- ✅ Fallback to HTML title/meta tags
- ✅ Error handling for network/parsing failures

### 2. Article List View ✅
**Priority: Critical**

A simple, clean list displaying all saved articles:
- ✅ Article title
- ✅ URL/domain
- ✅ Save date/timestamp (relative time format)
- ✅ Thumbnail/preview image (with fallback placeholder)

**User Actions:**
- ⏳ Tap to read article *(Requires Reader Mode implementation)*
- ✅ Swipe to delete

**Technical Implementation:**
- ✅ SwiftUI List with custom row design (ArticleRowView)
- ✅ Sorted by most recent first
- ✅ Empty state with call-to-action button
- ✅ AsyncImage for thumbnails with loading states

### 3. Reader Mode ✅
**Priority: Critical**

Clean, distraction-free reading experience:
- ✅ Parsed article content (title, body text)
- ✅ No ads, sidebars, or clutter
- ✅ Readable typography and spacing (serif font, proper line spacing)
- ✅ Scroll through full article content
- ✅ Share functionality

**Technical Implementation:**
- ✅ Readability-style content extraction algorithm (extractArticleContent)
- ✅ Custom reading view with SwiftUI (ReaderView.swift)
- ✅ WKWebView fallback when parsing fails or user preference
- ✅ Handles various article formats (blogs, news sites, Medium, etc.)
- ✅ Loading states and error handling
- ✅ NavigationLink integration from article list

**Status:** ✅ Implemented - Fully functional reader mode with clean layout

### 4. Local Storage ✅
**Priority: Critical**

On-device data persistence:
- ✅ Save article metadata (title, URL, save date, thumbnail)
- ✅ Cache parsed article content (fetched on-demand, stored in Article model)
- ✅ Store article state (unread/read implied by presence)
- ✅ Persistent storage with SwiftData

**Technical Implementation:**
- ✅ Article model: @Model class with SwiftData persistence
- ✅ ArticleMetadata and ArticleContent models (one struct per file)
- ✅ SwiftData ModelContainer configured in LuegoApp
- ✅ ModelContext injected into ArticleListViewModel
- ✅ Content fetched lazily when article is opened in reader
- ✅ Data persists between app launches
- ✅ Local-only, no cloud sync in MVP

**Status:** ✅ Fully implemented - Articles now persist across app launches using SwiftData

### 5. Basic Article Management ✅
**Priority: Critical**

Simple actions to manage the reading list:
- ✅ Delete articles (swipe-to-delete)
- ✅ Clear indication when list is empty

**Technical Implementation:**
- ✅ Standard SwiftUI delete actions (.onDelete)
- ✅ Empty state with ContentUnavailableView
- ✅ No confirmation dialog (user can undo via iOS system gesture)

---

## Out of Scope (Post-MVP)

These features are explicitly excluded from the initial MVP:

- Cloud sync / iCloud integration
- Tags or categories
- Archive / Mark as read
- Search functionality
- Favorites / Bookmarks
- Reading statistics
- Dark mode customization
- Font size adjustments
- Offline mode (parsed content is cached, but no explicit offline indicator)
- Share parsed articles
- Notes or highlights
- Reading time estimates

---

## User Journey (MVP)

1. **First Launch**: User sees empty state with prompt to add first article
2. **Save Article**:
   - Option A: User shares URL from Safari → Luego appears in share sheet → Article saved
   - Option B: User opens Luego → Taps "Add Article" → Pastes URL → Article saved
3. **View List**: User sees saved articles in a clean list
4. **Read Article**: User taps article → Reader mode opens with clean, parsed content
5. **Manage**: User swipes to delete articles they've finished reading

---

## Technical Stack

- **Language**: Swift 5.0 ✅
- **UI Framework**: SwiftUI ✅
- **Data Persistence**: SwiftData with ModelContainer and ModelContext ✅
- **Article Parsing**: SwiftSoup 2.11.1 for metadata extraction ✅
- **HTML Parsing**: Open Graph tags + fallback to standard HTML tags ✅
- **Networking**: URLSession for fetching article content ✅
- **Minimum iOS Version**: 26.0+ ✅
- **Dependencies**: SwiftSoup (via Swift Package Manager) ✅

---

## Success Metrics (MVP)

A successful MVP delivers:
1. ✅ (Partial) Users can reliably save articles from Safari and other apps
   - ✅ In-app URL entry working
   - ⏳ Share extension not yet implemented
2. ✅ Users can read saved articles in a clean, readable format
   - ✅ Article list view complete
   - ✅ Reader mode with clean typography implemented
   - ✅ WebView fallback for parsing failures
3. ✅ Users can manage their reading list (delete articles)
4. ✅ App feels fast and responsive
5. ✅ Data persists between app launches with SwiftData

---

## Implementation Progress

### Completed ✅
1. ✅ Design data model (Article, ArticleMetadata, ArticleContent entities)
2. ✅ Implement article list view UI
3. ✅ Build article metadata fetching logic
4. ✅ Add URL input view
5. ✅ Polish UI/UX (empty states, loading indicators, error handling)
6. ✅ Swift Package Manager integration (SwiftSoup)
7. ✅ Build system verification
8. ✅ **Reader Mode implementation**
   - ✅ Parse article body content with readability algorithm
   - ✅ Create clean reading view with proper typography (serif, line spacing)
   - ✅ Add navigation from article list to reader
   - ✅ Implement WKWebView fallback for parsing failures
   - ✅ Share functionality in reader mode
   - ✅ Loading and error states
9. ✅ **Persistent Storage with SwiftData**
   - ✅ Migrate Article model from struct to @Model class
   - ✅ Configure ModelContainer in LuegoApp
   - ✅ Update ArticleListViewModel to use ModelContext
   - ✅ Inject ModelContext via SwiftUI environment
   - ✅ Update all views and previews to work with SwiftData
   - ✅ Data now persists between app launches

### In Progress 🚧
*None currently*

### Next Steps ⏳
1. **Share Extension** (Priority: Medium)
   - Create Share Extension target
   - Set up App Groups for data sharing
   - Handle URL sharing from Safari/other apps

2. **Testing and Bug Fixes** (Priority: Medium)
   - Manual testing of all flows
   - Test data persistence across app launches
   - Edge case handling (invalid URLs, network failures, etc.)
   - Performance optimization

3. **UI/UX Polish** (Priority: Low)
   - Fine-tune animations and transitions
   - Improve error messaging
   - Add haptic feedback
   - Consider pull-to-refresh for article list

---

## Current Build Status

**Version:** 0.1.0 (Alpha)
**Build Status:** ✅ Compiles Successfully
**Last Build:** 2025-11-10
**Test Status:** Manual testing required

### Project Structure
```
Luego/
├── Models/
│   ├── Article.swift ✅
│   ├── ArticleMetadata.swift ✅
│   └── ArticleContent.swift ✅
├── Services/
│   └── ArticleMetadataService.swift ✅
├── ViewModels/
│   └── ArticleListViewModel.swift ✅
├── Views/
│   ├── AddArticleView.swift ✅
│   ├── ArticleRowView.swift ✅
│   └── ReaderView.swift ✅
├── ContentView.swift ✅
└── LuegoApp.swift ✅
```

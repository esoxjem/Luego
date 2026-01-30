# Brainstorm: macOS Native Support

**Date:** 2026-01-30
**Status:** Ready for planning

## What We're Building

Add native macOS support to Luego, achieving feature parity with the iPad version. Users will be able to:
- Save articles to their reading list
- Read articles in reader mode with markdown rendering
- Discover new articles via the Discovery feature
- Manage favorites and archived items
- Sync across devices via iCloud

## Why This Approach

**Native macOS target** (not Mac Catalyst) because:
- The app already uses SwiftUI with `NavigationSplitView` for iPad - this is the same paradigm macOS uses
- Native target provides cleaner platform separation and better Mac-native feel
- SwiftUI views are 95% shared - only 5 areas need platform adaptation
- Future Mac-specific enhancements (menu bar, keyboard shortcuts, multiple windows) will be easier to add

**iPad layout reuse** because:
- `ContentView` already switches layouts based on `horizontalSizeClass`
- iPad uses `NavigationSplitView` with sidebar/content/detail - identical to macOS pattern
- All ViewModels, Services, and Models are platform-agnostic

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Platform approach | Native macOS target | Cleaner separation, more Mac-native, easier future enhancements |
| Layout strategy | Reuse iPad layout | NavigationSplitView works identically on macOS |
| iOS-specific code | Separate platform files | Cleaner than #if conditionals scattered throughout |
| Share extension | Skip for now | Focus on main app first, add later if needed |
| Feature scope | Parity with iPad | Same read-it-later experience, no new features |

## Scope

### What's Included
- Main app running natively on macOS
- Full reading list management (add, delete, favorite, archive)
- Reader mode with markdown rendering
- Discovery feature for finding new articles
- Settings view accessible via macOS Settings scene
- iCloud sync (existing CloudKit integration)

### What's Excluded (For Now)
- macOS Share Extension
- Menu bar commands and keyboard shortcuts
- Multiple window support
- Touch Bar support (deprecated anyway)

## Technical Approach

### Already Cross-Platform (No Changes)
- All Services (ArticleService, ReaderService, DiscoveryService, SharingService)
- All DataSources (network and persistence code)
- All Models (SwiftData @Model classes)
- All ViewModels (@Observable classes)
- Most Views (NavigationSplitView, NavigationStack, List, Form, etc.)

### Requires Platform-Specific Files

| Component | iOS Version | macOS Version Needed |
|-----------|-------------|---------------------|
| GIF display | `GIFImageView.swift` (UIViewRepresentable) | `GIFImageView+macOS.swift` (NSViewRepresentable) |
| Share sheet | UIActivityViewController usage | ShareLink (cross-platform SwiftUI) |
| Nav bar styling | UINavigationBarAppearance | Skip or use SwiftUI equivalent |

### New Files for macOS

| File | Purpose |
|------|---------|
| `Luego/macOS.entitlements` | Sandbox + iCloud entitlements for macOS |
| `Luego/App/LuegoApp+macOS.swift` | Settings scene for macOS |

### Project Configuration Changes
- Add macOS destination to Luego target
- Set `MACOSX_DEPLOYMENT_TARGET` to 15.0+
- Add macOS to `SUPPORTED_PLATFORMS`
- Create macOS-specific entitlements file

## Open Questions

None - approach is clear and scope is well-defined.

## Next Steps

1. Run `/workflows:plan` to create detailed implementation plan
2. Implementation will involve:
   - Xcode project configuration
   - Platform-specific file creation
   - Share sheet refactoring to use ShareLink
   - Testing on macOS simulator/device

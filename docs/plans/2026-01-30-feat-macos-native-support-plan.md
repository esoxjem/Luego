---
title: "feat: Add macOS Native Support"
type: feat
date: 2026-01-30
---

# Add macOS Native Support

## Overview

Add native macOS support to Luego, achieving feature parity with the iPad version. The app already uses SwiftUI with `NavigationSplitView` for iPad—the same paradigm macOS uses. The codebase is 95% ready; only 5 UIKit dependencies need platform guards.

**Estimated effort:** 2-3 hours

## Problem Statement / Motivation

Users want to access their reading list on Mac. A native macOS app provides:
- Desktop reading experience with larger screen real estate
- Seamless sync across all Apple devices
- Mac-native interactions (eventually: keyboard shortcuts, menu bar, multiple windows)

## Proposed Solution

Add a native macOS target (not Mac Catalyst) that reuses the existing iPad layout:
1. Add macOS destination + entitlements
2. Fix 5 UIKit dependencies with platform conditionals
3. Add macOS Settings scene

## Technical Approach

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Platform Layer                          │
│  ┌───────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │  iPhone   │  │      iPad       │  │      macOS      │    │
│  │  TabView  │  │NavigationSplitView│ │NavigationSplitView│  │
│  └───────────┘  └─────────────────┘  └─────────────────┘    │
├─────────────────────────────────────────────────────────────┤
│                    Shared SwiftUI Views                      │
│        ArticleListPane, DetailPane, ReaderView, etc.         │
├─────────────────────────────────────────────────────────────┤
│                    ViewModels (@Observable)                  │
│     ArticleListViewModel, ReaderViewModel, DiscoveryViewModel│
├─────────────────────────────────────────────────────────────┤
│                    Services (@MainActor)                     │
│   ArticleService, ReaderService, DiscoveryService            │
├─────────────────────────────────────────────────────────────┤
│                    Core (Models, DataSources)                │
│            SwiftData Models, CloudKit Sync                   │
└─────────────────────────────────────────────────────────────┘
```

### Files to Modify

| File | Issue | Solution |
|------|-------|----------|
| `Luego.xcodeproj/project.pbxproj` | iOS-only | Add macOS destination |
| `Luego/Core/UI/GIFImageView.swift` | UIViewRepresentable | Add NSViewRepresentable with `#if os()` |
| `Luego/Features/Reader/Views/ReaderView.swift` | UIActivityViewController | Replace with inline ShareLink |
| `Luego/Features/Discovery/Views/DiscoveryPane.swift` | UIActivityViewController | Replace with inline ShareLink |
| `Luego/Features/Discovery/Views/DiscoveryReaderView.swift` | UIActivityViewController | Replace with inline ShareLink |
| `Luego/Features/ReadingList/Views/ArticleListView.swift` | UINavigationBarAppearance | Guard with `#if os(iOS)` |
| `Luego/Features/ReadingList/Views/AddArticleView.swift` | iOS-only modifiers | Guard with `#if os(iOS)` |
| `Luego/App/LuegoApp.swift` | No Settings scene | Add macOS Settings + window sizing |

### Files to Create

| File | Purpose |
|------|---------|
| `Luego/Luego-macOS.entitlements` | macOS sandbox + iCloud entitlements |

**Note:** No new Swift files needed. GIF platform code goes in existing file with `#if os()`. ShareLink used inline—no wrapper.

---

## Implementation Phases

### Phase 1: Project Configuration

**Tasks:**
- [x] Add macOS destination to Luego target in Xcode
- [x] Set `MACOSX_DEPLOYMENT_TARGET = 15.0`
- [x] Add `macosx` to `SUPPORTED_PLATFORMS`
- [x] Create `Luego-macOS.entitlements`

**Luego-macOS.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.esoxjem.Luego</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
```

---

### Phase 2: Platform Adaptation

All UIKit dependencies fixed in a single pass.

#### 2.1 GIFImageView.swift — Add macOS Support

Add `#if os()` conditionals to existing file (no separate file):

```swift
import SwiftUI
import ImageIO

#if os(iOS)
import UIKit

struct GIFImageView: UIViewRepresentable {
    let gifName: String

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit

        if let url = Bundle.main.url(forResource: gifName, withExtension: "gif"),
           let data = try? Data(contentsOf: url),
           let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let images = createAnimationImages(from: source)
            let duration = calculateDuration(from: source)
            imageView.animationImages = images
            imageView.animationDuration = duration
            imageView.startAnimating()
        }

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}

    private func createAnimationImages(from source: CGImageSource) -> [UIImage] {
        let frameCount = CGImageSourceGetCount(source)
        return (0..<frameCount).compactMap { index in
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { return nil }
            return UIImage(cgImage: cgImage)
        }
    }

    private func calculateDuration(from source: CGImageSource) -> TimeInterval {
        let frameCount = CGImageSourceGetCount(source)
        var duration: TimeInterval = 0
        for index in 0..<frameCount {
            guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                  let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any],
                  let frameDuration = gifProperties[kCGImagePropertyGIFDelayTime] as? TimeInterval else {
                continue
            }
            duration += frameDuration
        }
        return duration > 0 ? duration : Double(frameCount) * 0.1
    }
}

#elseif os(macOS)
import AppKit

struct GIFImageView: NSViewRepresentable {
    let gifName: String

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.animates = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.canDrawSubviewsIntoLayer = true

        if let url = Bundle.main.url(forResource: gifName, withExtension: "gif"),
           let data = try? Data(contentsOf: url),
           let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let frameCount = CGImageSourceGetCount(source)
            var images: [NSImage] = []

            for index in 0..<frameCount {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) {
                    let size = NSSize(width: cgImage.width, height: cgImage.height)
                    images.append(NSImage(cgImage: cgImage, size: size))
                }
            }

            if let firstImage = images.first {
                imageView.image = firstImage
                // NSImageView.animates handles GIF animation automatically when image is from GIF data
                if let image = NSImage(contentsOf: url) {
                    imageView.image = image
                }
            }
        }

        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {}
}
#endif
```

#### 2.2 Share Functionality — Replace with Inline ShareLink

Delete `shareArticle()` functions and replace with inline `ShareLink` in toolbar menus.

**ReaderViewToolbar.swift** — Replace share button:
```swift
// Before: Button(action: onShare) { Label("Share", ...) }
// After:
ShareLink(item: articleURL, subject: Text(articleTitle)) {
    Label("Share", systemImage: "square.and.arrow.up")
}
```

**DiscoveryToolbarMenu** and **DiscoveryReaderView** — Same pattern:
```swift
ShareLink(item: article.url, subject: Text(article.title)) {
    Label("Share", systemImage: "square.and.arrow.up")
}
```

This removes ~64 lines of UIActivityViewController code across 3 files.

#### 2.3 ArticleListView.swift — Guard UIKit Code

```swift
#if os(iOS)
import UIKit

private var serifBoldLargeTitleFont: UIFont {
    let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        .withDesign(.serif)?
        .withSymbolicTraits(.traitBold) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
    return UIFont(descriptor: descriptor, size: 0)
}

private func configureNavigationBarAppearance() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithDefaultBackground()
    appearance.largeTitleTextAttributes = [.font: serifBoldLargeTitleFont]
    UINavigationBar.appearance().standardAppearance = appearance
    UINavigationBar.appearance().scrollEdgeAppearance = appearance
}
#endif
```

And in `.onAppear`:
```swift
.onAppear {
    #if os(iOS)
    configureNavigationBarAppearance()
    #endif
}
```

#### 2.4 AddArticleView.swift — Guard iOS-Only Modifiers

```swift
TextField("Enter URL", text: $urlText)
    .textContentType(.URL)
    #if os(iOS)
    .keyboardType(.URL)
    .textInputAutocapitalization(.never)
    #endif
    .autocorrectionDisabled()
```

#### 2.5 Glass Effect Fallback (if needed)

Test if `.glassEffect()` compiles on macOS. If not, create modifier:

```swift
extension View {
    @ViewBuilder
    func adaptiveGlassEffect() -> some View {
        #if os(iOS)
        self.glassEffect(.regular.interactive().tint(.purple.opacity(0.8)))
        #else
        self.background(.ultraThinMaterial)
        #endif
    }
}
```

Same for `.buttonStyle(.glassProminent)` → `.buttonStyle(.borderedProminent)` fallback.

---

### Phase 3: macOS App Configuration & Testing

#### 3.1 LuegoApp.swift — Settings Scene + Window Sizing

```swift
@main
struct LuegoApp: App {
    private let sharedModelContainer: ModelContainer = { /* existing */ }()

    @MainActor
    private var diContainer: DIContainer {
        DIContainer(modelContext: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.diContainer, diContainer)
                .task(id: "sdkInit") {
                    await diContainer.sdkManager.ensureSDKReady()
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1000, height: 700)
        #endif

        #if os(macOS)
        Settings {
            SettingsView(viewModel: diContainer.makeSettingsViewModel())
        }
        #endif
    }
}
```

#### 3.2 Test All User Flows

- [ ] Launch app → NavigationSplitView renders with sidebar
- [ ] Add article → metadata fetches, appears in list
- [ ] Read article → content loads, scroll position tracked
- [ ] Discovery → GIF animation plays, articles load
- [ ] Share → ShareLink works from toolbar menu
- [ ] Settings → opens via Cmd+,
- [ ] Favorites/Archive → toggle works
- [ ] Delete → context menu works
- [ ] Window resize → layout adapts gracefully
- [ ] iCloud sync → articles sync with iOS devices

#### 3.3 Run Tests on macOS

```bash
xcodebuild test -project Luego.xcodeproj -scheme Luego -destination 'platform=macOS'
```

---

## Acceptance Criteria

- [ ] App launches on macOS 15.0+
- [ ] NavigationSplitView layout matches iPad
- [ ] All article management works (add, delete, favorite, archive)
- [ ] Reader mode displays markdown content
- [ ] Discovery loads articles with GIF animation
- [ ] Share works via ShareLink
- [ ] Settings accessible via Cmd+,
- [ ] iCloud sync works bidirectionally
- [ ] Unit tests pass on macOS

## What's Excluded

Per brainstorm decisions, NOT in scope:
- macOS Share Extension
- Menu bar commands and keyboard shortcuts
- Multiple window support

## Summary of Changes

| Change | Lines Removed | Lines Added | Net |
|--------|---------------|-------------|-----|
| Delete shareArticle() x3 | ~64 | 0 | -64 |
| Add ShareLink inline x3 | 0 | ~9 | +9 |
| GIF platform conditionals | 0 | ~40 | +40 |
| UIKit guards | 0 | ~10 | +10 |
| Settings scene | 0 | ~8 | +8 |
| Entitlements file | 0 | ~15 | +15 |
| **Total** | **~64** | **~82** | **+18** |

**Files created:** 1 (`Luego-macOS.entitlements`)
**Files deleted:** 0
**New abstractions:** 0

## References

- Brainstorm: `docs/brainstorms/2026-01-30-macos-support-brainstorm.md`
- iPad layout: `Luego/App/ContentView.swift:20-47`
- Existing entitlements: `Luego/Luego.entitlements`

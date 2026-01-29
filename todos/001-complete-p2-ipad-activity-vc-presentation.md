---
status: pending
priority: p2
issue_id: "001"
tags: [code-review, ipad, ui, swiftui]
dependencies: []
---

# UIActivityViewController iPad Presentation Missing Popover Configuration

## Problem Statement

The `UIActivityViewController` is presented without configuring `popoverPresentationController` for iPad. On iPad, `UIActivityViewController` must be presented as a popover; failing to configure `sourceView`/`sourceRect` can cause crashes or undefined behavior.

## Findings

**Location:**
- `Luego/Features/Discovery/Views/DiscoveryPane.swift:74-89`
- `Luego/Features/Discovery/Views/DiscoveryReaderView.swift:62-77`
- `Luego/Features/Reader/Views/ReaderView.swift:291-304`

**Current Code:**
```swift
private func shareArticle() {
    guard let article = viewModel.ephemeralArticle else { return }

    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first,
          let rootViewController = window.rootViewController else {
        return
    }

    let activityVC = UIActivityViewController(
        activityItems: [article.url],
        applicationActivities: nil
    )

    rootViewController.present(activityVC, animated: true)  // Missing popover config
}
```

## Proposed Solutions

### Option A: Add popover configuration (Recommended)
**Pros:** Minimal change, fixes crash
**Cons:** Still using UIKit approach
**Effort:** Small
**Risk:** Low

```swift
if let popover = activityVC.popoverPresentationController {
    popover.sourceView = window.rootViewController?.view
    popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
    popover.permittedArrowDirections = []
}
```

### Option B: Use SwiftUI ShareLink (iOS 16+)
**Pros:** Native SwiftUI, automatically handles iPad
**Cons:** Requires refactoring toolbar/button structure
**Effort:** Medium
**Risk:** Low

## Recommended Action

Option A for immediate fix; consider Option B as a follow-up improvement.

## Technical Details

**Affected files:**
- `Luego/Features/Discovery/Views/DiscoveryPane.swift`
- `Luego/Features/Discovery/Views/DiscoveryReaderView.swift`
- `Luego/Features/Reader/Views/ReaderView.swift`

## Acceptance Criteria

- [ ] Share button works on iPad without crashing
- [ ] Popover appears centered or near the share button
- [ ] Test on iPad simulator in landscape and portrait

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-29 | Identified in code review | iPad requires popover configuration for activity VCs |

## Resources

- [Apple: UIActivityViewController Documentation](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller)
- Branch: esoxjem/ipad-3-pane-view

---
status: pending
priority: p1
issue_id: 001
tags: [code-review, performance, swift-concurrency, cloudkit]
created: 2026-02-17
---

# P1: Blocking Main Thread with DispatchSemaphore in CloudKit Calls

## Problem Statement

The `CopyDiagnosticsButton.gatherDiagnostics()` function uses `DispatchSemaphore` to force asynchronous CloudKit APIs into synchronous blocking calls. This blocks the main thread while waiting for CloudKit network operations, which can cause:

- **UI freezing** during the operation (1-3+ seconds with poor connectivity)
- **Watchdog termination** on iOS - blocking the main thread for extended periods triggers system termination
- **Violation of SwiftUI fundamentals** - View bodies must never block

## Findings

**Location:** `Luego/Features/Settings/Views/SettingsView.swift`, lines ~534-557

**Problematic Code:**
```swift
let semaphore = DispatchSemaphore(value: 0)
CKContainer(identifier: "iCloud.com.esoxjem.Luego").accountStatus { status, error in
    // ... handle result
    semaphore.signal()
}
semaphore.wait()  // ❌ BLOCKS MAIN THREAD
```

Two sequential blocking calls:
1. `accountStatus()` - blocks
2. `fetchAllSubscriptions()` - blocks again

## Proposed Solutions

### Option A: Convert to Proper Swift Concurrency (Recommended)

Make `gatherDiagnostics()` async and use Swift concurrency properly:

```swift
private func gatherDiagnostics() async -> String {
    // Parallel async calls
    async let accountStatusTask = fetchAccountStatus()
    async let subscriptionsTask = fetchSubscriptions()
    
    let (status, subscriptions) = await (accountStatusTask, subscriptionsTask)
    // ... build result ...
}

private func copyDiagnostics() {
    Task {
        let diagnostics = await gatherDiagnostics()
        // Update pasteboard and UI on main actor
    }
}
```

**Pros:** Follows SwiftUI patterns, non-blocking, parallel execution
**Cons:** Requires restructuring button action
**Effort:** Small
**Risk:** Low

### Option B: Remove Subscription Fetching

Simplify diagnostics to only include app info and account status (no subscriptions).

**Pros:** Removes most blocking code, faster execution
**Cons:** Less diagnostic detail
**Effort:** Minimal
**Risk:** None

## Technical Details

- **Affected Files:** `SettingsView.swift`
- **Components:** `CopyDiagnosticsButton`, `gatherDiagnostics()`
- **Framework:** CloudKit, SwiftUI

## Acceptance Criteria

- [ ] No use of `DispatchSemaphore` in UI code
- [ ] CloudKit calls use proper async/await
- [ ] Button shows loading state during fetch
- [ ] UI remains responsive during diagnostics gathering

## Work Log

- **2026-02-17:** Issue identified during code review
- **2026-02-17:** P1 severity assigned due to main thread blocking risk

## Resources

- Review agent: `kieran-typescript-reviewer`
- Related: `performance-oracle` findings on same issue

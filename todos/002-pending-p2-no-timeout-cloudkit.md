---
status: pending
priority: p2
issue_id: 002
tags: [code-review, reliability, cloudkit]
created: 2026-02-17
---

# P2: No Timeout or Cancellation Handling on CloudKit Calls

## Problem Statement

CloudKit calls in both launch diagnostics and the CopyDiagnosticsButton lack timeout and cancellation handling. If CloudKit fails to respond (network unavailable, iCloud downtime), operations could hang indefinitely.

## Findings

**Locations:**
1. `LuegoApp.swift` - `logLaunchDiagnostics()` - async calls without timeout
2. `SettingsView.swift` - `gatherDiagnostics()` - semaphore blocks indefinitely

**Current Behavior:**
- No timeout on `accountStatus()` call
- No timeout on `allSubscriptions()` / `fetchAllSubscriptions()` call
- No cancellation support for long-running operations

## Proposed Solutions

### Option A: Add Timeout with withTimeout

Use Swift's `withTimeout` or task group with timeout:

```swift
let accountStatus = try await withTimeout(seconds: 5) {
    try await container.accountStatus()
} ?? .couldNotDetermine
```

**Pros:** Bounded execution time, better UX
**Cons:** Requires timeout helper or manual Task management
**Effort:** Small
**Risk:** Low

### Option B: Skip CloudKit Calls When Offline

Check network reachability before making CloudKit calls:

```swift
if networkMonitor.isConnected {
    // Make CloudKit calls
} else {
    Logger.cloudKit.info("Skipping CloudKit diagnostics - offline")
}
```

**Pros:** Avoids unnecessary timeouts
**Cons:** Less accurate diagnostics when offline
**Effort:** Small
**Risk:** Low

## Technical Details

- **Affected Files:** `LuegoApp.swift`, `SettingsView.swift`
- **Framework:** CloudKit, Network framework (for reachability)

## Acceptance Criteria

- [ ] CloudKit calls have maximum 5-second timeout
- [ ] Timeout gracefully degrades (shows "unknown" or "timeout" in diagnostics)
- [ ] Launch diagnostics don't delay app startup beyond acceptable threshold

## Work Log

- **2026-02-17:** Issue identified during code review

## Resources

- Review agent: `kieran-typescript-reviewer`, `performance-oracle`

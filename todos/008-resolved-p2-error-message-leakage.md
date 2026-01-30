---
status: resolved
priority: p2
issue_id: "008"
tags: [code-review, security, cloudkit, error-handling]
dependencies: []
---

# CloudKit Error Messages May Leak System Information

## Problem Statement

The `classifyError()` function in `SyncStatusObserver` passes `error.localizedDescription` directly to the UI for non-authentication errors. CloudKit errors can contain container identifiers, record zone names, and internal error codes.

**Why it matters:** Exposing raw error messages to users can reveal implementation details and is a poor UX.

## Findings

### Evidence

**File:** `Luego/Core/DataSources/SyncStatusObserver.swift` (lines 118-123)
```swift
private func classifyError(_ error: Error) -> (message: String, needsSignIn: Bool) {
    if let ckError = error as? CKError, ckError.code == .notAuthenticated {
        return ("Sign in to iCloud to sync", true)
    }
    return (error.localizedDescription, false)  // Raw error exposed
}
```

The error message is displayed in:
- `SettingsView.swift` (lines 188-194)
- Accessibility announcements (line 102 in SyncStatusObserver.swift)

### CloudKit Errors Not Handled

- `.quotaExceeded` - user's iCloud storage is full
- `.networkFailure` / `.networkUnavailable` - transient errors
- `.serverRecordChanged` - sync conflict
- `.partialFailure` - some records failed

## Proposed Solutions

### Option A: Comprehensive Error Classification (Recommended)

Expand error classification to handle common CloudKit errors with user-friendly messages.

```swift
private func classifyError(_ error: Error) -> (message: String, needsSignIn: Bool) {
    if let ckError = error as? CKError {
        switch ckError.code {
        case .notAuthenticated:
            return ("Sign in to iCloud to sync", true)
        case .networkUnavailable, .networkFailure:
            return ("Network unavailable. Please check your connection.", false)
        case .quotaExceeded:
            return ("iCloud storage is full", false)
        case .serverResponseLost:
            return ("Sync interrupted. Will retry automatically.", false)
        default:
            return ("Unable to sync. Please try again later.", false)
        }
    }
    return ("Unable to sync. Please try again later.", false)
}
```

**Pros:**
- User-friendly messages
- No information leakage
- Handles common scenarios

**Cons:**
- Less debugging info in production

**Effort:** Small
**Risk:** Low

## Recommended Action

Implement Option A - classify common CloudKit errors with user-friendly messages.

## Technical Details

**Affected Files:**
- `Luego/Core/DataSources/SyncStatusObserver.swift`

## Acceptance Criteria

- [ ] Common CloudKit errors have user-friendly messages
- [ ] No raw error descriptions shown to users
- [ ] Detailed errors logged for debugging
- [ ] All error states display appropriate messages

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by security-sentinel agent |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38
- [CKError.Code Documentation](https://developer.apple.com/documentation/cloudkit/ckerror/code)

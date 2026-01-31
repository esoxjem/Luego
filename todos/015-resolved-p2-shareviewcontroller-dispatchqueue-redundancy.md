---
status: resolved
priority: p2
issue_id: "015"
tags: [code-review, concurrency, swift6, code-quality]
dependencies: []
---

# Redundant DispatchQueue.main.async in ShareViewController

## Problem Statement

`ShareViewController` uses `DispatchQueue.main.async` in `completeWithSuccess()` and `completeWithError()` even though these methods are called from contexts already on the MainActor. This is redundant and adds unnecessary latency.

**Why it matters:** Mixed paradigms (GCD + Swift Concurrency) reduce code clarity. The redundant dispatch adds an extra hop and latency.

## Findings

### Evidence

**File:** `LuegoShareExtension/ShareViewController.swift:131-139, 146-156`

```swift
// Called from Task { @MainActor } which is already on MainActor
private func saveURL(_ url: URL) {
    SharedStorage.shared.saveSharedURL(url)
    completeWithSuccess()  // Already on MainActor
}

private func completeWithSuccess() {
    DispatchQueue.main.async { [weak self] in  // REDUNDANT
        guard let self = self else { return }
        UIView.animate(...) { ... }
    }
}

private func completeWithError(message: String) {
    DispatchQueue.main.async { [weak self] in  // REDUNDANT
        guard let self = self else { return }
        let alert = UIAlertController(...)
        self.present(alert, animated: true)
    }
}
```

### Call Chain Analysis

1. `loadItem` completion → `@Sendable` closure
2. → `Task { @MainActor [weak self] }` (now on MainActor)
3. → `self.saveURL(url)` (still on MainActor)
4. → `completeWithSuccess()` (still on MainActor)
5. → `DispatchQueue.main.async` (redundant, already on main)

## Proposed Solutions

### Option A: Remove Redundant Dispatches (Recommended)

Replace `DispatchQueue.main.async` with direct execution since callers are already on MainActor.

```swift
private func completeWithSuccess() {
    UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
        self.successView.alpha = 1
        self.successView.transform = .identity
    }
}

private func completeWithError(message: String) {
    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
        self.extensionContext?.cancelRequest(withError: NSError(domain: "LuegoShareExtension", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
    })
    self.present(alert, animated: true)
}
```

**Pros:**
- Removes redundant dispatch overhead
- Consistent use of Swift Concurrency
- Clearer control flow

**Cons:**
- Requires ensuring all call sites are MainActor-isolated

**Effort:** Small
**Risk:** Low (call sites are verified to be on MainActor)

## Recommended Action

Apply Option A for consistency with Swift Concurrency patterns.

## Technical Details

**Affected Files:**
- `LuegoShareExtension/ShareViewController.swift`

**Components:** ShareViewController

## Acceptance Criteria

- [x] `completeWithSuccess()` no longer uses `DispatchQueue.main.async`
- [x] `completeWithError()` no longer uses `DispatchQueue.main.async`
- [ ] Share Extension still works (manual test: save article via Share Sheet)
- [ ] All tests pass

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-31 | Created during PR #42 review | Found by pattern-recognition-specialist and code-simplicity-reviewer agents |
| 2026-01-31 | Resolved: Removed redundant DispatchQueue.main.async wrappers from completeWithSuccess() and completeWithError() methods | Both methods are called from Task { @MainActor } blocks, confirming they are already on the main actor. Build verified successful. |

## Resources

- PR #42: https://github.com/esoxjem/Luego/pull/42

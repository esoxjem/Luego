---
status: pending
priority: p3
issue_id: 003
tags: [code-review, maintainability, dry]
created: 2026-02-17
---

# P3: Hardcoded CloudKit Container Identifier (DRY Violation)

## Problem Statement

The CloudKit container identifier `"iCloud.com.esoxjem.Luego"` is hardcoded in multiple locations across the codebase, violating the DRY principle and making maintenance difficult if the identifier ever changes.

## Findings

**Occurrences:** 10+ hardcoded instances

**Files Affected:**
- `LuegoApp.swift` (5 occurrences)
- `SettingsView.swift` (3 occurrences)
- `Luego.entitlements` (1 occurrence)
- `Luego-macOS.entitlements` (1 occurrence)

## Proposed Solutions

### Option A: Extract to Shared Constant

Create a single source of truth:

```swift
// In a Constants.swift or CloudKitConfig.swift
enum CloudKitConfig {
    static let containerIdentifier = "iCloud.com.esoxjem.Luego"
}

// Usage:
let container = CKContainer(identifier: CloudKitConfig.containerIdentifier)
```

**Pros:** Single source of truth, type-safe, discoverable
**Cons:** Minor refactoring
**Effort:** Small
**Risk:** None

### Option B: Derive from Bundle Identifier

```swift
static let containerIdentifier = "iCloud.\(Bundle.main.bundleIdentifier ?? "")"
```

**Pros:** Automatically matches bundle, no hardcoding
**Cons:** Assumes container follows naming convention
**Effort:** Small
**Risk:** Low (convention-based)

## Technical Details

- **Affected Files:** Multiple across project
- **Pattern:** String literal `"iCloud.com.esoxjem.Luego"`

## Acceptance Criteria

- [ ] Container identifier defined in exactly one place
- [ ] All usages reference the constant
- [ ] Works across iOS and macOS targets

## Work Log

- **2026-02-17:** Issue identified during code review by `code-simplicity-reviewer`

---
status: pending
priority: p3
issue_id: 004
tags: [code-review, simplicity, yagni]
created: 2026-02-17
---

# P3: Simplify DeveloperSection and CopyDiagnosticsButton

## Problem Statement

The `DeveloperSection` struct is an unnecessary wrapper that only contains a single `CopyDiagnosticsButton`. Additionally, the button has macOS-specific styling that's redundant since the parent `SettingsCard` already provides container styling.

## Findings

**1. Empty Wrapper Struct:**
```swift
struct DeveloperSection: View {
    var body: some View {
        Section {
            CopyDiagnosticsButton()
        } header: { ... }
    }
}
```
This adds indirection with no benefit - the button can be inlined directly.

**2. Redundant macOS Styling:**
The `CopyDiagnosticsButton` has `#if os(macOS)` styling (padding, background, overlay) that duplicates what `SettingsCard` already provides for its children.

**3. Code Duplication:**
Launch diagnostics in `LuegoApp.swift` duplicates ~70% of the logic in `gatherDiagnostics()`.

## Proposed Solutions

### Option A: Inline and Simplify (Recommended)

1. Remove `DeveloperSection` struct
2. Remove macOS-specific button styling (let parent container handle it)
3. Use `CopyDiagnosticsButton()` directly in both layouts

```swift
// In SettingsMacLayout:
SettingsCard {
    SettingsSectionHeader(...)
    SettingsCardDivider()
    VStack(spacing: 10) {
        StreamingLogsToggle()
        CopyDiagnosticsButton()  // No wrapper, no extra styling
    }
}
```

**Pros:** Less code, less indirection, consistent styling
**Cons:** None
**Effort:** Minimal
**Risk:** None

### Option B: Consolidate Diagnostic Logic

Extract shared diagnostic gathering function used by both launch logging and button.

**Pros:** Single source of truth
**Cons:** Requires refactoring both locations
**Effort:** Small
**Risk:** Low

## Technical Details

- **Affected Files:** `SettingsView.swift`
- **Estimated LOC Reduction:** ~35 lines

## Acceptance Criteria

- [ ] `DeveloperSection` struct removed
- [ ] Button styling relies on parent container
- [ ] (Optional) Shared diagnostic gathering function

## Work Log

- **2026-02-17:** Issue identified during code review by `code-simplicity-reviewer`

---
status: resolved
priority: p2
issue_id: "006"
tags: [code-review, duplication, simplicity, swiftui]
dependencies: ["002"]
resolution: implemented
---

# SidebarSyncFooter and SidebarSyncStatus Are Nearly Identical

## Problem Statement

`SidebarSyncFooter` (lines 69-102) and `SidebarSyncStatus` (lines 158-185) have nearly identical implementations. Both also duplicate the `formattedTime` computed property. The only difference is padding values.

**Why it matters:** Code duplication of 50+ lines for a one-line difference. Three places with duplicated DateFormatter creation.

## Findings

### Evidence

**File:** `Luego/Features/ReadingList/Views/SidebarView.swift`

**SidebarSyncFooter** (lines 80-101):
```swift
var body: some View {
    VStack(spacing: 0) {
        Divider().opacity(0.5)
        HStack(spacing: 6) {
            SyncStatusIndicator(state: state, onErrorTap: nil)
                .font(.caption)
            if let timeText = formattedTime {
                Text("Synced at \(timeText)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)  // The only difference
    }
    .background(.bar)
}
```

**SidebarSyncStatus** (lines 169-184) is identical except `.padding(.top, 8)` instead of `.padding(.vertical, 8)`.

Both also duplicate `formattedTime` computed property (lines 73-78 and 162-167).

## Proposed Solutions

### Option A: Single Configurable Component (Recommended)

Create one `SyncStatusRow` view with padding parameter.

```swift
struct SyncStatusRow: View {
    let state: SyncState
    let lastSyncTime: Date?
    var verticalPadding: Edge.Set = .vertical

    private var formattedTime: String? {
        guard let time = lastSyncTime else { return nil }
        return DateFormatters.time.string(from: time)  // Use cached formatter
    }

    var body: some View {
        HStack(spacing: 6) {
            SyncStatusIndicator(state: state, onErrorTap: nil)
                .font(.caption)
            if let timeText = formattedTime {
                Text("Synced at \(timeText)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(verticalPadding, 8)
    }
}
```

**Pros:**
- ~27 LOC saved
- Single source of truth
- Consolidates DateFormatter usage

**Cons:**
- Minor API change

**Effort:** Small
**Risk:** Low

## Recommended Action

Implement Option A - create unified `SyncStatusRow` component.

## Technical Details

**Affected Files:**
- `Luego/Features/ReadingList/Views/SidebarView.swift`

**LOC Reduction:** ~27 lines

**Note:** Depends on #002 (DateFormatter caching) for full benefit.

## Acceptance Criteria

- [x] Single `SyncStatusRow` component replaces both
- [x] iPad and macOS sidebars use unified component
- [x] DateFormatter uses cached instance
- [x] No visual changes

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by code-simplicity and pattern-recognition agents |
| 2026-01-30 | Implemented Option A: SyncStatusRow with configurable padding | Removed SidebarSyncStatus, both sites now use SyncStatusRow |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38

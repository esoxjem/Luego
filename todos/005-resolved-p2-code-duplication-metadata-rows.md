---
status: resolved
priority: p2
issue_id: "005"
tags: [code-review, duplication, simplicity, swiftui]
dependencies: []
---

# ArticleMetadataRow and ArticleMetadataRowCompact Are Nearly Identical

## Problem Statement

`ArticleMetadataRow` (45 LOC) and `ArticleMetadataRowCompact` (37 LOC) share ~80% identical code. The only differences are that the compact version omits `estimatedReadingTime` and `hasContent` parameters.

**Why it matters:** Code duplication increases maintenance burden and risk of divergence. Changes to metadata display require updates in two places.

## Findings

### Evidence

**File:** `Luego/Features/ReadingList/Views/ArticleRowView.swift`

**ArticleMetadataRow** (lines 142-186):
```swift
struct ArticleMetadataRow: View {
    let domain: String
    let author: String?
    let readPercentage: Int
    let formattedDate: String
    let estimatedReadingTime: String  // Extra param
    let hasContent: Bool               // Extra param

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Text(domain).lineLimit(1)
                if let author, !author.isEmpty {
                    Text(" · ").foregroundStyle(.quaternary)
                    Text(author).lineLimit(1)
                }
                Spacer()
            }
            HStack(spacing: 0) {
                Text("Read \(readPercentage)%").foregroundStyle(.blue)
                if hasContent {  // Only difference
                    Text(" · ").foregroundStyle(.quaternary)
                    Text(estimatedReadingTime)
                }
                Text(" · ").foregroundStyle(.quaternary)
                Text(formattedDate)
                Spacer()
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}
```

**ArticleMetadataRowCompact** (lines 189-225) is nearly identical minus the reading time section.

## Proposed Solutions

### Option A: Single Parameterized Component (Recommended)

Merge into one component with optional parameters.

```swift
struct ArticleMetadataRow: View {
    let domain: String
    let author: String?
    let readPercentage: Int
    let formattedDate: String
    var estimatedReadingTime: String? = nil
    var showReadingTime: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // ... domain/author row
            HStack(spacing: 0) {
                Text("Read \(readPercentage)%").foregroundStyle(.blue)
                if showReadingTime, let time = estimatedReadingTime {
                    Text(" · ").foregroundStyle(.quaternary)
                    Text(time)
                }
                Text(" · ").foregroundStyle(.quaternary)
                Text(formattedDate)
                Spacer()
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}
```

**Pros:**
- Single source of truth
- ~38 LOC saved
- Changes apply to both layouts automatically

**Cons:**
- Minor API change at call sites

**Effort:** Small
**Risk:** Low

## Recommended Action

Implement Option A - merge into single component with optional parameters.

## Technical Details

**Affected Files:**
- `Luego/Features/ReadingList/Views/ArticleRowView.swift`

**LOC Reduction:** ~38 lines

## Acceptance Criteria

- [ ] Single `ArticleMetadataRow` component handles both cases
- [ ] macOS and iOS layouts use the unified component
- [ ] All existing functionality preserved
- [ ] No visual changes

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by pattern-recognition and code-simplicity agents |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38

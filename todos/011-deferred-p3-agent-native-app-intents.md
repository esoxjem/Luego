---
status: deferred
priority: p3
issue_id: "011"
tags: [code-review, agent-native, app-intents, shortcuts, accessibility]
dependencies: []
resolution: deferred-future-enhancement
---

# No Agent/Automation Infrastructure (App Intents)

## Problem Statement

The app has no App Intents, Shortcuts integration, or agent tool infrastructure. All new features in this PR are UI-only with no programmatic equivalents, making them inaccessible to agents and automation.

**Why it matters:** Agents, Shortcuts, and Siri cannot interact with the app at all. Users cannot automate common tasks.

## Findings

### Evidence

```bash
grep -ri "Shortcut\|Intent\|AppIntent" Luego/
# No results
```

### Capability Gap

| UI Action | Agent Tool | Status |
|-----------|-----------|--------|
| Add Article | None | Not accessible |
| Toggle Favorite | None | Not accessible |
| Toggle Archive | None | Not accessible |
| Delete Article | None | Not accessible |
| Check Sync Status | None | Not accessible |
| Change Settings | None | Not accessible |
| Discover Article | None | Not accessible |

**Agent-Native Score:** 0/13 capabilities are agent-accessible

## Proposed Solutions

### Option A: Add Core App Intents (Recommended)

Implement App Intents for the most common operations.

```swift
// Luego/Core/Intents/AddArticleIntent.swift
import AppIntents

struct AddArticleIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Article to Luego"

    @Parameter(title: "URL") var url: URL

    func perform() async throws -> some IntentResult {
        let container = DIContainer(...)
        let service = container.makeArticleService()
        try await service.addArticle(from: url)
        return .result()
    }
}

struct GetSyncStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Sync Status"

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let observer = SyncStatusObserver()
        return .result(value: observer.state.description)
    }
}
```

**Pros:**
- Enables Shortcuts integration
- Siri voice commands work
- Agents can interact with app

**Cons:**
- Additional code to maintain
- Requires iOS 16+/macOS 13+

**Effort:** Medium-Large
**Risk:** Low

### Priority Intents to Implement

1. `AddArticleIntent` - most common agent use case
2. `GetArticlesIntent` - list articles with filter
3. `GetSyncStatusIntent` - check sync health
4. `ToggleFavoriteIntent` - manage favorites

## Recommended Action

This is a P3 enhancement. Consider implementing after P1/P2 fixes are complete.

## Technical Details

**New Files:**
- `Luego/Core/Intents/AddArticleIntent.swift`
- `Luego/Core/Intents/GetArticlesIntent.swift`
- `Luego/Core/Intents/GetSyncStatusIntent.swift`
- `Luego/Core/Intents/LuegoShortcuts.swift`

## Acceptance Criteria

- [ ] AddArticleIntent allows adding articles via Shortcuts
- [ ] GetSyncStatusIntent returns current sync state
- [ ] AppShortcutsProvider exposes Siri phrases
- [ ] Intents work on both iOS and macOS

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by agent-native-reviewer agent |
| 2026-01-30 | Deferred: P3 enhancement, all P2 fixes complete | Future enhancement for post-PR implementation |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38
- [App Intents Documentation](https://developer.apple.com/documentation/appintents)

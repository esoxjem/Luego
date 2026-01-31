# Prevention Strategies Index

This directory contains best practices, checklists, and lessons learned from bugs that were solved in the Luego project. Use these guides to prevent similar issues in future development.

## Available Guides

### 1. [SwiftUI Task + CloudKit Race Conditions](./swiftui-task-cloudkit-race-conditions.md)

**When to read**: Before implementing async operations in SwiftUI views, particularly when dealing with CloudKit sync.

**Key sections**:
- SwiftUI Task Lifecycle Best Practices (`.task` vs `.task(id:)`)
- @Observable + Task Management Pattern
- SwiftData Actor Reentrancy Checklist
- CloudKit Sync Defensive Patterns
- Test Cases for Async + CloudKit scenarios
- Code Review Checklist

**Real-world issue**: Reader would get stuck with infinite spinner when CloudKit synced articles during content loading.

**Root causes**:
- `.task` without `id:` restarting unpredictably
- No concurrent operation protection
- SwiftData actor reentrancy with stale references
- CloudKit sync modifying data during suspension points

**Key takeaway**: Use `.task(id:)` with stable identifiers, manage tasks with `@ObservationIgnored`, and re-fetch from ModelContext after suspension points.

---

### 2. [SwiftData + CloudKit: Unique Constraints](./swiftdata-cloudkit-unique-constraints.md)

**When to read**: When designing data models that will be synced with CloudKit.

**Key sections**:
- Critical incompatibility warning
- Prevention checklist
- Alternative approaches for uniqueness
- Duplicate detection strategies
- App startup safety

**Real-world issue**: App would crash at startup if `@Attribute(.unique)` was added to CloudKit-synced models.

**Root cause**: CloudKit is a distributed database that doesn't support database-level unique constraints.

**Key takeaway**: Never use `@Attribute(.unique)` on CloudKit-synced models. Implement application-level uniqueness checks instead.

---

## How to Use These Guides

### Before Writing Code
1. Identify what area of Luego you're working in (Views, ViewModels, Services, Models)
2. Scan the relevant guide's checklist section
3. Review the code examples for the pattern you need

### Code Review Process
Use the "Code Review Checklist" section in each guide when reviewing PRs:
- SwiftUI async operations? → Review against Task & CloudKit guide
- New models with sync? → Review against Unique Constraints guide

### When a Bug Occurs
1. Identify the root cause
2. Search this directory for related prevention guides
3. Add test cases from the guide
4. Update the relevant guide if you discovered new insights

---

## Pattern Quick Reference

### SwiftUI Task Pattern
```swift
// VIEW: Use task(id:) with stable identifier
.task(id: viewModel.article.id) {
    await viewModel.loadContent()
}

// VIEWMODEL: Manage task with @ObservationIgnored
@ObservationIgnored
private var loadingTask: Task<Void, Never>?

func loadContent() async {
    loadingTask?.cancel()
    let task = Task { [weak self] in
        try Task.checkCancellation()
        let result = try await service.fetch()
        try Task.checkCancellation()
        self?.property = result
    }
    loadingTask = task
}

// SERVICE: Re-fetch after suspension
let id = entity.id
let data = try await fetch()
let fresh = try refetch(id: id)
fresh.data = data
```

### Model Design Pattern
```swift
// WRONG: Unique constraint with CloudKit sync
@Model
final class Article {
    @Attribute(.unique) var url: URL  // ❌ CRASH!
}

// CORRECT: Application-level uniqueness
@Model
final class Article {
    var id: UUID = UUID()
    var url: URL
    var isDuplicate: Bool = false
}

// Check for duplicates in service
func checkForDuplicate(url: URL) -> Article? {
    let predicate = #Predicate<Article> { $0.url == url && !$0.isDuplicate }
    let descriptor = FetchDescriptor<Article>(predicate: predicate)
    return try modelContext.fetch(descriptor).first
}
```

---

## Contributing to Prevention Guides

When you solve a bug in Luego:

1. **Create a prevention document** following the structure in existing guides
2. **Include real code examples** from the codebase
3. **Add test cases** that would catch the issue
4. **Update this INDEX.md** with a brief summary
5. **Link from related files** (e.g., ARCHITECTURE.md, CLAUDE.md)

---

## Prevention Principles

These guides are built on these principles:

1. **Clarity over Brevity**: Real code examples are better than abstract explanations
2. **Actionable Guidance**: Every section includes what to do and what not to do
3. **Test-Driven**: Include test cases for each pattern
4. **Context Matters**: Include the "why" not just the "how"
5. **Living Documentation**: Update as new issues are discovered

---

## Quick Links

- [ARCHITECTURE.md](../../ARCHITECTURE.md) - System design and dependency flow
- [CLAUDE.md](../../CLAUDE.md) - Development patterns and guidelines
- [agent_docs/](../../agent_docs/) - Feature-specific documentation
- [docs/solutions/](../solutions/) - Solved bugs and their fixes
- [docs/plans/](../plans/) - Implementation plans for features

---

## Version History

| Date | Guide | Issue | Status |
|------|-------|-------|--------|
| 2026-01-31 | SwiftUI Task + CloudKit Race Conditions | Reader stuck spinner on CloudKit sync | Documented |
| 2026-01-31 | SwiftData + CloudKit Unique Constraints | App crash on @Attribute(.unique) | Documented |

---

**Last Updated**: January 31, 2026

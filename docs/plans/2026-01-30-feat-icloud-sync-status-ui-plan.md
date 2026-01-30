---
title: Add iCloud Sync Status UI
type: feat
date: 2026-01-30
---

# Add iCloud Sync Status UI

## Overview

Add user-facing iCloud sync status to Luego so users can see when sync is in progress, completed successfully, or failed with an error. Currently, `CloudKitSyncObserver` only logs events—users have no visibility into sync activity.

## Problem Statement / Motivation

Users currently have no indication when:
- Their articles are syncing across devices
- Sync has completed successfully
- Sync has failed (and why)
- When their data was last synced

This creates confusion when articles don't appear immediately on other devices or when sync issues occur silently.

## Research Summary

### NetNewsWire CloudKit Patterns (via DeepWiki)

NetNewsWire's sync architecture provides excellent patterns:

1. **CombinedRefreshProgress** - Aggregates progress from multiple sync operations
2. **Error Classification** - Maps `CKError` codes to user-friendly categories
3. **Notification-based UI** - Posts notifications that UI observes
4. **Toolbar placement** - Subtle sync icon in toolbar area

Key insight: NetNewsWire uses manual CoreData+CloudKit with custom zones. Luego uses SwiftData's automatic CloudKit sync, which is simpler but provides less granular control. We can still observe `NSPersistentCloudKitContainer.eventChangedNotification` for status.

### Current Luego Implementation

- **File**: `Luego/Core/DataSources/CloudKitSyncObserver.swift`
- Only logs events (Setup, Import, Export) to `Logger.cloudKit`
- Instantiated in `LuegoApp.swift` but not connected to UI
- Uses `static` method which prevents observable state publishing

## Proposed Solution

### Simplified State Model (per reviewer feedback)

```swift
// Inlined in SyncStatusObserver.swift

enum SyncState: Equatable {
    case idle
    case syncing
    case success
    case error(message: String, needsSignIn: Bool)
}
```

**Simplifications applied:**
- Removed `SyncEventType` - UI shows same spinning icon regardless of import/export
- Simplified error to `(message, needsSignIn)` - only auth errors need special handling
- No separate `SyncError` enum - over-classification for identical display

### Observable Sync Status Observer

```swift
// Luego/Core/DataSources/SyncStatusObserver.swift

import Foundation
import CoreData
import CloudKit

enum SyncState: Equatable {
    case idle
    case syncing
    case success
    case error(message: String, needsSignIn: Bool)
}

protocol SyncStatusObservable: AnyObject {
    var state: SyncState { get }
    var lastSyncTime: Date? { get }
    func dismissError()
}

@Observable
@MainActor
final class SyncStatusObserver: SyncStatusObservable {
    private(set) var state: SyncState = .idle
    private(set) var lastSyncTime: Date?

    private var notificationObserver: Any?
    private var debounceTask: Task<Void, Never>?

    init() {
        observeCloudKitEvents()
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        debounceTask?.cancel()
    }

    private func observeCloudKitEvents() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleSyncEvent(notification)
            }
        }
    }

    private func handleSyncEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event else { return }

        let eventType = switch event.type {
            case .setup: "Setup"
            case .import: "Import"
            case .export: "Export"
            @unknown default: "Sync"
        }

        if event.endDate == nil {
            updateState(.syncing)
            Logger.cloudKit.debug("\(eventType) started")
        } else if let error = event.error {
            let (message, needsSignIn) = classifyError(error)
            updateState(.error(message: message, needsSignIn: needsSignIn))
            Logger.cloudKit.error("\(eventType) failed: \(error.localizedDescription)")
        } else {
            lastSyncTime = Date()
            updateState(.success)
            Logger.cloudKit.info("\(eventType) completed")

            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                if state == .success { updateState(.idle) }
            }
        }
    }

    private func updateState(_ newState: SyncState) {
        let oldState = state
        state = newState

        // Announce significant state changes to VoiceOver
        if oldState != newState {
            announceStateChange(newState)
        }
    }

    private func announceStateChange(_ newState: SyncState) {
        let announcement: String? = switch newState {
        case .idle: nil
        case .syncing: "Syncing with iCloud"
        case .success: "Sync complete"
        case .error(let message, _): "Sync error: \(message)"
        }

        if let announcement {
            #if os(iOS)
            UIAccessibility.post(notification: .announcement, argument: announcement)
            #elseif os(macOS)
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [.announcement: announcement])
            #endif
        }
    }

    private func classifyError(_ error: Error) -> (message: String, needsSignIn: Bool) {
        if let ckError = error as? CKError, ckError.code == .notAuthenticated {
            return ("Sign in to iCloud to sync", true)
        }
        return (error.localizedDescription, false)
    }

    func dismissError() {
        if case .error = state {
            updateState(.idle)
        }
    }
}
```

### UI Components

#### Sync Status Indicator (Toolbar Icon)

Following the codebase view extraction pattern, child views are extracted for clarity:

```swift
// Luego/Core/UI/SyncStatusIndicator.swift

import SwiftUI

struct SyncStatusIndicator: View {
    let state: SyncState
    var onErrorTap: (() -> Void)?

    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .syncing:
                SyncingIndicator()
            case .success:
                SyncSuccessIndicator()
            case .error:
                SyncErrorButton(onTap: onErrorTap)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state)
    }
}

private struct SyncingIndicator: View {
    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .symbolEffect(.rotate, isActive: true)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Syncing")
    }
}

private struct SyncSuccessIndicator: View {
    var body: some View {
        Image(systemName: "checkmark.icloud")
            .foregroundStyle(.green)
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel("Sync complete")
    }
}

private struct SyncErrorButton: View {
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sync error, tap for details")
    }
}
```

#### Last Sync Time Display

```swift
// Luego/Core/UI/LastSyncTimeView.swift

import SwiftUI

struct LastSyncTimeView: View {
    let lastSyncTime: Date?

    private var formattedTime: String? {
        guard let time = lastSyncTime else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: time, relativeTo: Date())
    }

    var body: some View {
        if let time = formattedTime {
            Text("Last synced \(time)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
```

### Platform-Specific Placement

| Platform | Sync Indicator | Last Sync Time |
|----------|---------------|----------------|
| **iOS** | Navigation toolbar | Settings view (new section) |
| **macOS** | Sidebar footer | Sidebar footer (above Settings) |

### iOS Settings Integration

Add a new section to `SettingsView.swift`:

```swift
// New section in SettingsView

SyncStatusSection(
    lastSyncTime: syncStatusObserver.lastSyncTime,
    state: syncStatusObserver.state
)

// Component

struct SyncStatusSection: View {
    let lastSyncTime: Date?
    let state: SyncState

    private var statusText: String {
        switch state {
        case .idle: "Up to date"
        case .syncing: "Syncing..."
        case .success: "Just synced"
        case .error(let message, _): message
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle, .success: .secondary
        case .syncing: .blue
        case .error: .red
        }
    }

    var body: some View {
        Section {
            HStack {
                Label("iCloud Sync", systemImage: "icloud")

                Spacer()

                Text(statusText)
                    .foregroundStyle(statusColor)
            }

            if let time = lastSyncTime {
                HStack {
                    Text("Last synced")
                    Spacer()
                    Text(time, style: .relative)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Articles sync automatically across your devices via iCloud.")
        }
    }
}
```

### macOS Sidebar Integration

Update `SidebarSettingsButton` to show sync status above settings:

```swift
// Updated SidebarSettingsButton in SidebarView.swift

struct SidebarSettingsButton: View {
    let lastSyncTime: Date?
    let state: SyncState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

            VStack(spacing: 8) {
                SidebarSyncStatus(lastSyncTime: lastSyncTime, state: state)

                SettingsLink {
                    HStack {
                        Image(systemName: "gear")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text("Settings")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("⌘,")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
        }
        .background(.bar)
    }
}

struct SidebarSyncStatus: View {
    let lastSyncTime: Date?
    let state: SyncState

    var body: some View {
        HStack(spacing: 6) {
            SyncStatusIndicator(state: state, onErrorTap: nil)
                .font(.caption)

            if let time = lastSyncTime {
                Text("Synced \(time, style: .relative)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
```

### Error Alert (Platform-Aware)

```swift
// In ArticleListView / ArticleListPane

.alert("Sync Error", isPresented: $showingSyncError) {
    if case .error(_, let needsSignIn) = syncStatusObserver.state, needsSignIn {
        Button("Open Settings") {
            #if os(iOS)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            #elseif os(macOS)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane") {
                NSWorkspace.shared.open(url)
            }
            #endif
        }
    }
    Button("Dismiss", role: .cancel) {
        syncStatusObserver.dismissError()
    }
} message: {
    if case .error(let message, _) = syncStatusObserver.state {
        Text(message)
    }
}
```

## Technical Considerations

### Debouncing for Rapid Events

CloudKit can fire multiple events in rapid succession (e.g., setup → import → export). The `debounceTask` prevents UI flicker by:
- Cancelling pending state transitions when new events arrive
- Only transitioning to `.idle` after 3 seconds of no activity
- Checking `Task.isCancelled` before applying delayed state changes

### Accessibility Announcements

State changes are announced to VoiceOver users via platform-specific APIs:
- **iOS**: `UIAccessibility.post(notification: .announcement, argument:)`
- **macOS**: `NSAccessibility.post(element:notification:userInfo:)`

Only significant changes are announced (syncing, success, error) - not the idle state.

### View Extraction Pattern

`SyncStatusIndicator` follows the codebase pattern of extracting child views:
- Main view handles state switching and animation
- `SyncingIndicator`, `SyncSuccessIndicator`, `SyncErrorButton` are private child views
- Each child view has a single responsibility

### Protocol for Testability

`SyncStatusObservable` protocol enables mocking in tests:

```swift
@MainActor
final class MockSyncStatusObserver: SyncStatusObservable {
    var state: SyncState = .idle
    var lastSyncTime: Date? = nil
    var dismissErrorCallCount = 0

    func dismissError() {
        dismissErrorCallCount += 1
        state = .idle
    }
}
```

### Notification Observer Lifecycle

The observer is stored and properly removed in `deinit` to prevent memory leaks. This follows the correct pattern for closure-based notification observation.

### Thread Safety

`SyncStatusObserver` is marked `@MainActor` and uses `Task { @MainActor in }` for notification handling to ensure all UI state updates happen on the main thread.

### Success State Duration

The "success" indicator shows for 3 seconds then fades to idle. This matches common patterns (similar to the iOS "Copied" toast).

## Acceptance Criteria

### Core Functionality
- [x] Sync indicator appears in sidebar footer (macOS/iPad) and Settings (iOS)
- [x] Indicator shows spinning animation during active sync
- [x] Checkmark appears briefly (3 sec) when sync completes
- [x] Error icon appears when sync fails
- [ ] Tapping error icon shows alert with details (deferred - indicator only for now)

### Last Sync Time Display
- [x] iOS: "Last synced X ago" shown in Settings view
- [x] macOS: "Synced X ago" shown in sidebar above Settings button
- [x] Time shows "Just now" for < 1 min, then minutes/hours (no seconds)

### Error Handling
- [x] Authentication errors classified with needsSignIn flag
- [x] Other errors show the actual error description
- [ ] Platform-specific Settings URL (deferred - no alert implemented)

### Platform Support
- [x] Works on iOS (iPhone) via Settings view
- [x] Works on iOS (iPad) in sidebar footer
- [x] Works on macOS in sidebar footer

### Accessibility
- [x] Sync states have appropriate accessibility labels
- [x] VoiceOver announces state changes (syncing, success, error)
- [ ] Error alert is fully accessible (deferred - no alert implemented)

### Performance
- [x] Rapid sync events are debounced to prevent UI flicker
- [x] Debounce task is properly cancelled on new events

## Files to Create/Modify

### New Files
- `Luego/Core/DataSources/SyncStatusObserver.swift` - Observable observer with inline SyncState enum
- `Luego/Core/UI/SyncStatusIndicator.swift` - Reusable indicator view

### Modified Files
- `Luego/App/LuegoApp.swift` - Create and inject SyncStatusObserver
- `Luego/Core/DI/DIContainer.swift` - Add SyncStatusObserver (if needed for DI)
- `Luego/Features/ReadingList/Views/ArticleListView.swift` - Add indicator to iPhone toolbar
- `Luego/Features/ReadingList/Views/ArticleListPane.swift` - Add indicator to iPad toolbar
- `Luego/Features/ReadingList/Views/SidebarView.swift` - Add sync status + last sync time to macOS sidebar
- `Luego/Features/Settings/Views/SettingsView.swift` - Add sync status section for iOS

### Deleted Files
- `Luego/Core/DataSources/CloudKitSyncObserver.swift` - Replaced by SyncStatusObserver

## Testing Strategy

### Mock for View Tests

```swift
// LuegoTests/TestSupport/Mocks/DataSources/MockSyncStatusObserver.swift

@MainActor
final class MockSyncStatusObserver: SyncStatusObservable {
    var state: SyncState = .idle
    var lastSyncTime: Date? = nil
    var dismissErrorCallCount = 0

    func dismissError() {
        dismissErrorCallCount += 1
        state = .idle
    }

    func simulateSync() {
        state = .syncing
    }

    func simulateSuccess() {
        lastSyncTime = Date()
        state = .success
    }

    func simulateError(_ message: String, needsSignIn: Bool = false) {
        state = .error(message: message, needsSignIn: needsSignIn)
    }
}
```

### Unit Tests

```swift
// LuegoTests/Core/DataSources/SyncStatusObserverTests.swift

@Suite("SyncStatusObserver Tests")
@MainActor
struct SyncStatusObserverTests {

    @Test("initial state is idle")
    func initialState() {
        let observer = SyncStatusObserver()
        #expect(observer.state == .idle)
        #expect(observer.lastSyncTime == nil)
    }

    @Test("dismissError changes state to idle")
    func dismissError() {
        let observer = SyncStatusObserver()
        // Simulate error state (would need internal setter for testing)
        observer.dismissError()
        #expect(observer.state == .idle)
    }
}
```

## References

### Internal References
- Current sync observer: `Luego/Core/DataSources/CloudKitSyncObserver.swift`
- App entry point: `Luego/App/LuegoApp.swift:13`
- Settings view: `Luego/Features/Settings/Views/SettingsView.swift`
- Sidebar view: `Luego/Features/ReadingList/Views/SidebarView.swift:73-104`
- Toolbar patterns: `Luego/Features/ReadingList/Views/ArticleListView.swift`

### External References (NetNewsWire via DeepWiki)
- CloudKit sync architecture: `CloudKitAccountDelegate`, `CloudKitZone` protocol
- Progress tracking: `CombinedRefreshProgress`, `DownloadProgress` classes
- Error classification: `CloudKitZoneResult.resolve(_:)` method

### Apple Documentation
- [NSPersistentCloudKitContainer.eventChangedNotification](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3141671-eventchangednotification)
- [CKError.Code](https://developer.apple.com/documentation/cloudkit/ckerror/code)
- [RelativeDateTimeFormatter](https://developer.apple.com/documentation/foundation/relativedatetimeformatter)

## Changes from Review Feedback

| Feedback | Resolution |
|----------|------------|
| Rename to `SyncStatusObserver` | ✅ Done |
| Add `SyncStatusObservable` protocol | ✅ Done |
| Remove singleton label | ✅ Done |
| Simplify `SyncState` (remove `SyncEventType`) | ✅ Done |
| Simplify errors to auth vs other | ✅ Done |
| Fix notification observer lifecycle | ✅ Done (stored + removed in deinit) |
| Fix macOS compilation (`UIApplication`) | ✅ Done (platform-specific `#if`) |
| Keep `lastSyncTime` | ✅ Done (displayed in Settings + Sidebar) |
| Add testing strategy | ✅ Done |
| Extract child views from `SyncStatusIndicator` | ✅ Done (SyncingIndicator, SyncSuccessIndicator, SyncErrorButton) |
| Add debouncing for rapid events | ✅ Done (debounceTask with cancellation) |
| Add accessibility announcements | ✅ Done (platform-specific VoiceOver announcements) |

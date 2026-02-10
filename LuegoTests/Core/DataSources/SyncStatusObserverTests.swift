import Testing
import Foundation
import SwiftData
@testable import Luego

@Suite("SyncStatusObserver Tests")
@MainActor
struct SyncStatusObserverTests {
    private func makeObserver() throws -> SyncStatusObserver {
        let container = try createTestModelContainer()
        return SyncStatusObserver(modelContext: container.mainContext)
    }

    @Test("initial state is idle")
    func initialStateIsIdle() async throws {
        let observer = try makeObserver()
        #expect(observer.state == .idle)
    }

    @Test("lastSyncTime starts as nil")
    func lastSyncTimeStartsNil() async throws {
        let observer = try makeObserver()
        #expect(observer.lastSyncTime == nil)
    }

    @Test("dismissError resets to idle when in error state")
    func dismissErrorResetsToIdleFromError() async {
        let observer = TestableSyncStatusObserver()
        observer.setState(.error(message: "Test error", needsSignIn: false))

        observer.dismissError()

        #expect(observer.state == .idle)
    }

    @Test("dismissError does nothing when in idle state")
    func dismissErrorDoesNothingWhenIdle() async throws {
        let observer = try makeObserver()
        #expect(observer.state == .idle)

        observer.dismissError()

        #expect(observer.state == .idle)
    }

    @Test("dismissError does nothing when in syncing state")
    func dismissErrorDoesNothingWhenSyncing() async {
        let observer = TestableSyncStatusObserver()
        observer.setState(.syncing)

        observer.dismissError()

        #expect(observer.state == .syncing)
    }

    @Test("dismissError does nothing when in success state")
    func dismissErrorDoesNothingWhenSuccess() async {
        let observer = TestableSyncStatusObserver()
        observer.setState(.success)

        observer.dismissError()

        #expect(observer.state == .success)
    }

    @Test("dismissError resets error with needsSignIn flag")
    func dismissErrorResetsErrorWithNeedsSignIn() async {
        let observer = TestableSyncStatusObserver()
        observer.setState(.error(message: "Sign in required", needsSignIn: true))

        observer.dismissError()

        #expect(observer.state == .idle)
    }
}

@Suite("SyncState Enum Tests")
struct SyncStateTests {
    @Test("idle states are equal")
    func idleStatesEqual() {
        #expect(SyncState.idle == SyncState.idle)
    }

    @Test("syncing states are equal")
    func syncingStatesEqual() {
        #expect(SyncState.syncing == SyncState.syncing)
    }

    @Test("success states are equal")
    func successStatesEqual() {
        #expect(SyncState.success == SyncState.success)
    }

    @Test("error states with same values are equal")
    func errorStatesWithSameValuesEqual() {
        let error1 = SyncState.error(message: "Test", needsSignIn: true)
        let error2 = SyncState.error(message: "Test", needsSignIn: true)
        #expect(error1 == error2)
    }

    @Test("error states with different messages are not equal")
    func errorStatesWithDifferentMessagesNotEqual() {
        let error1 = SyncState.error(message: "Error 1", needsSignIn: false)
        let error2 = SyncState.error(message: "Error 2", needsSignIn: false)
        #expect(error1 != error2)
    }

    @Test("error states with different needsSignIn are not equal")
    func errorStatesWithDifferentNeedsSignInNotEqual() {
        let error1 = SyncState.error(message: "Test", needsSignIn: true)
        let error2 = SyncState.error(message: "Test", needsSignIn: false)
        #expect(error1 != error2)
    }

    @Test("different states are not equal")
    func differentStatesNotEqual() {
        #expect(SyncState.idle != SyncState.syncing)
        #expect(SyncState.idle != SyncState.success)
        #expect(SyncState.syncing != SyncState.success)
        #expect(SyncState.idle != SyncState.error(message: "Error", needsSignIn: false))
    }
}

@Observable
@MainActor
final class TestableSyncStatusObserver: SyncStatusObservable {
    private(set) var state: SyncState = .idle
    private(set) var lastSyncTime: Date?

    func setState(_ newState: SyncState) {
        state = newState
    }

    func setLastSyncTime(_ date: Date?) {
        lastSyncTime = date
    }

    func dismissError() {
        if case .error = state {
            state = .idle
        }
    }
}

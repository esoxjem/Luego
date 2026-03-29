import CloudKit
import Foundation
import GRDB
import Observation

extension Notification.Name {
    static let luegoSyncEngineStatusDidChange = Notification.Name("com.esoxjem.Luego.syncEngineStatusDidChange")
}

enum SyncEngineStatusPayloadKey {
    static let state = "state"
    static let lastSyncTime = "lastSyncTime"
    static let errorMessage = "errorMessage"
    static let needsSignIn = "needsSignIn"
    static let accountStatus = "accountStatus"
    static let diagnosticHint = "diagnosticHint"
    static let cloudKitContainerIdentifier = "cloudKitContainerIdentifier"
    static let cloudKitIdentityTokenState = "cloudKitIdentityTokenState"
    static let cloudKitUserRecordID = "cloudKitUserRecordID"
    static let recentFailedSaveDetails = "recentFailedSaveDetails"
}

private enum ArticleSyncLocation: String {
    case missingLocally
    case localOnly
    case pendingUpload
    case serverConfirmed
    case pendingDeletion
    case conflictResolvedFromServer
    case unknownItemRecovered
}

private enum SyncRefreshError: LocalizedError {
    case refreshInProgress

    var errorDescription: String? {
        switch self {
        case .refreshInProgress:
            return "A sync is already in progress. Try again in a moment."
        }
    }
}

@Observable
@MainActor
final class SyncEngineManager: SyncEngineManagerProtocol {
    private static let watchedArticleRecordName = "DF060EDE-2119-4958-A5C5-50BBC3E8146F"
    private static let watchedArticleURLString = "https://www.patrickrhone.net/17175-2/"
    private static let bootstrapRestoreMarkerKey = "cloudkitBootstrapRestoreCompletedAt"

    private(set) var state: SyncState = .idle
    private(set) var lastSyncTime: Date?

    @ObservationIgnored
    private let database: AppDatabase

    @ObservationIgnored
    private let store: ArticleStoreProtocol

    @ObservationIgnored
    private let container: CKContainer

    @ObservationIgnored
    private var syncEngine: CKSyncEngine?

    @ObservationIgnored
    private var idleTask: Task<Void, Never>?

    @ObservationIgnored
    private var currentStateSerialization: CKSyncEngine.State.Serialization?

    @ObservationIgnored
    private var recentFailedSaveDetails: [String] = []

    @ObservationIgnored
    private var isRepairSyncRecoveryEnabled = false

    @ObservationIgnored
    private var isVisibleRestoreInProgress = false

    @ObservationIgnored
    private var isRefreshInProgress = false

    init(
        database: AppDatabase,
        store: ArticleStoreProtocol? = nil,
        container: CKContainer = CKContainer(identifier: AppConfiguration.cloudKitContainerIdentifier)
    ) {
        self.database = database
        self.store = store ?? GRDBArticleStore(database: database)
        self.container = container
    }

    func start() throws {
        guard syncEngine == nil else { return }

        let payload = try database.syncEngineStatePayload()
        lastSyncTime = payload?.lastSyncTime
        currentStateSerialization = payload?.stateSerialization

        let configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: payload?.stateSerialization,
            delegate: self
        )
        syncEngine = CKSyncEngine(configuration)
        publishStatus(.idle, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
        let cloudKitContainer = container
        Task {
            let diagnostics = await CloudKitRuntimeDiagnostics.collect(
                container: cloudKitContainer,
                containerIdentifier: AppConfiguration.cloudKitContainerIdentifier
            )
            Logger.cloudKit.info("Launch diagnostics — \(diagnostics.summaryLine)")
            for line in diagnostics.detailLines {
                Logger.cloudKit.info("Launch diagnostics — \(line)")
            }
            publishStatus(
                state,
                lastSyncTime: lastSyncTime,
                errorMessage: nil,
                needsSignIn: diagnostics.needsSignIn,
                accountStatus: diagnostics.accountStatus,
                diagnosticHint: diagnostics.actionableHint,
                cloudKitContainerIdentifier: diagnostics.containerIdentifier,
                cloudKitIdentityTokenState: diagnostics.identityTokenState,
                cloudKitUserRecordID: diagnostics.userRecordID
            )
        }
    }

    func refresh(mode: SyncRefreshMode) async throws -> Int {
        guard !isRefreshInProgress else {
            throw SyncRefreshError.refreshInProgress
        }

        isRefreshInProgress = true
        defer {
            isRefreshInProgress = false
            isVisibleRestoreInProgress = false
        }

        switch mode {
        case .smart:
            return try await performSmartRefresh()
        case .fullRepair:
            return try await performFullRepairRefresh()
        }
    }

    func enqueueSave(for recordID: CKRecord.ID) {
        syncEngine?.state.add(
            pendingRecordZoneChanges: [.saveRecord(recordID)]
        )
        logWatchedRecordTransition(
            prefix: "Watched article queue event",
            recordID: recordID,
            eventSource: "localQueue.save",
            overrideLocation: .pendingUpload
        )
        publishStatus(.syncing, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
    }

    func enqueueDelete(for recordID: CKRecord.ID) {
        syncEngine?.state.add(
            pendingRecordZoneChanges: [.deleteRecord(recordID)]
        )
        logWatchedRecordTransition(
            prefix: "Watched article queue event",
            recordID: recordID,
            eventSource: "localQueue.delete",
            overrideLocation: .pendingDeletion
        )
        publishStatus(.syncing, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
    }

    func fetchChanges() async throws {
        guard let syncEngine else { return }

        logWatchedRecordSummary(context: "fetchChanges:willFetch")
        publishRefreshStartState(isRestoring: isVisibleRestoreInProgress)

        do {
            try await syncEngine.fetchChanges()
            logWatchedRecordSummary(context: "fetchChanges:didFetch")
            endRepairSyncRecoveryIfPossible()
        } catch {
            Logger.cloudKit.error("Fetch changes failed: \(error.localizedDescription)")
            logWatchedRecordSummary(context: "fetchChanges:failed")
            await publishSyncFailure(error, prefix: "Fetch changes")
            throw error
        }
    }

    func sendChanges() async throws {
        guard let syncEngine else { return }

        logWatchedRecordSummary(context: "sendChanges:willSend")
        publishStatus(.syncing, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
        defer {
            endRepairSyncRecoveryIfPossible()
        }

        do {
            try await syncEngine.sendChanges()
            logWatchedRecordSummary(context: "sendChanges:didSend")
        } catch {
            Logger.cloudKit.error("Send changes failed: \(error.localizedDescription)")
            logWatchedRecordSummary(context: "sendChanges:failed")
            await publishSyncFailure(error, prefix: "Send changes")
            throw error
        }
    }

    func resetSyncStateForFullRefetch() async throws {
        let pendingChanges = Array(syncEngine?.state.pendingRecordZoneChanges ?? [])

        logWatchedRecordSummary(context: "repairSync:beforeStateReset")

        if let syncEngine {
            await syncEngine.cancelOperations()
        }

        idleTask?.cancel()
        syncEngine = nil
        currentStateSerialization = nil

        var payload = (try? database.syncEngineStatePayload()) ?? SyncEngineStatePayload()
        payload.stateSerialization = nil
        try database.saveSyncEngineStatePayload(payload)

        try start()

        if !pendingChanges.isEmpty {
            syncEngine?.state.add(pendingRecordZoneChanges: pendingChanges)
        }

        logWatchedRecordSummary(context: "repairSync:afterStateReset")
    }

    func backfillAllArticlesFromServer() async throws -> Int {
        var totalApplied = 0
        var cursor: CKQueryOperation.Cursor?
        var fetchedRecordNames = Set<String>()
        let database = container.privateCloudDatabase

        logWatchedRecordSummary(context: "repairSync:serverBackfill:start")

        repeat {
            let matchResults: [(CKRecord.ID, Result<CKRecord, Error>)]
            let nextCursor: CKQueryOperation.Cursor?

            if let cursor {
                let page = try await database.records(continuingMatchFrom: cursor)
                matchResults = Array(page.matchResults)
                nextCursor = page.queryCursor
            } else {
                let query = CKQuery(
                    recordType: ArticleRecord.recordType,
                    predicate: NSPredicate(format: "savedDate > %@", Date.distantPast as NSDate)
                )
                let page = try await database.records(matching: query)
                matchResults = Array(page.matchResults)
                nextCursor = page.queryCursor
            }

            for (recordID, result) in matchResults {
                switch result {
                case .success(let record):
                    fetchedRecordNames.insert(recordID.recordName)
                    do {
                        try await processIncomingRecord(record)
                        totalApplied += 1
                    } catch {
                        let detail = "Server backfill apply failed for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) error=\(describe(error: error))"
                        Logger.cloudKit.error(detail)
                        appendRecentFailedSaveDetail(detail)
                    }
                case .failure(let error):
                    let detail = structuredFailureLine(
                        recordID: recordID,
                        error: error,
                        context: "storedRecord=\(fetchStoredRecord(recordName: recordID.recordName) == nil ? "missing" : "present")",
                        prefix: "Server backfill match failure",
                        eventSource: "repairSync.serverBackfill"
                    )
                    Logger.cloudKit.error(detail)
                    appendRecentFailedSaveDetail(detail)
                }
            }

            cursor = nextCursor
        } while cursor != nil

        try reconcileLocalRecordsMissingFromServer(fetchedRecordNames: fetchedRecordNames)
        isRepairSyncRecoveryEnabled = true

        Logger.cloudKit.info("Server backfill applied \(totalApplied) Article records")
        logWatchedRecordSummary(context: "repairSync:serverBackfill:complete")
        return totalApplied
    }

    func logWatchedRecordSummary(context: String) {
        guard let line = watchedArticleStateLine(
            recordID: watchedRecordID,
            record: nil,
            storedRecord: fetchWatchedStoredRecord(),
            eventSource: "summary.\(context)"
        ) else {
            return
        }

        Logger.cloudKit.info("Watched article summary — \(line)")
    }

    func dismissError() {
        if case .error = state {
            publishStatus(.idle, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
        }
    }
}

extension SyncEngineManager: CKSyncEngineDelegate {
    func handleEvent(
        _ event: CKSyncEngine.Event,
        syncEngine: CKSyncEngine
    ) async {
        switch event {
        case .stateUpdate(let stateUpdate):
            await persistStateSerialization(stateUpdate.stateSerialization)
        case .fetchedRecordZoneChanges(let changes):
            await processFetchedRecordZoneChanges(changes)
        case .sentRecordZoneChanges(let sent):
            await processSentRecordZoneChanges(sent, syncEngine: syncEngine)
        case .accountChange(let change):
            handleAccountChange(change)
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges
            .filter { context.options.scope.contains($0) }

        let recordsByID = Dictionary(uniqueKeysWithValues: pendingChanges.compactMap { change -> (CKRecord.ID, ArticleRecord)? in
            guard case .saveRecord(let recordID) = change else {
                return nil
            }

            guard let record = try? store.fetchRecord(recordName: recordID.recordName) else {
                syncEngine.state.remove(
                    pendingRecordZoneChanges: [.saveRecord(recordID)]
                )
                return nil
            }

            return (recordID, record)
        })

        for pendingChange in pendingChanges {
            switch pendingChange {
            case .saveRecord(let recordID):
                logWatchedRecordTransition(
                    prefix: "Watched article send batch",
                    recordID: recordID,
                    storedRecord: recordsByID[recordID],
                    eventSource: "sendBatch.save",
                    overrideLocation: .pendingUpload
                )
            case .deleteRecord(let recordID):
                logWatchedRecordTransition(
                    prefix: "Watched article send batch",
                    recordID: recordID,
                    storedRecord: fetchStoredRecord(recordName: recordID.recordName),
                    eventSource: "sendBatch.delete",
                    overrideLocation: .pendingDeletion
                )
            @unknown default:
                break
            }
        }

        return await CKSyncEngine.RecordZoneChangeBatch(
            pendingChanges: pendingChanges
        ) { recordID in
            recordsByID[recordID]?.makeCKRecord(recordID: recordID)
        }
    }
}

private extension SyncEngineManager {
    func processFetchedRecordZoneChanges(
        _ changes: CKSyncEngine.Event.FetchedRecordZoneChanges
    ) async {
        var didFail = false

        for modification in changes.modifications {
            do {
                try await processIncomingRecord(modification.record)
            } catch {
                didFail = true
                Logger.cloudKit.error(
                    "Failed to process record \(modification.record.recordID.recordName): \(error.localizedDescription)"
                )
            }
        }

        for deletion in changes.deletions {
            do {
                try await processIncomingDeletion(deletion.recordID)
            } catch {
                didFail = true
                Logger.cloudKit.error(
                    "Failed to process deletion \(deletion.recordID.recordName): \(error.localizedDescription)"
                )
            }
        }

        if didFail {
            publishStatus(.error(message: "Unable to apply changes from iCloud", needsSignIn: false), lastSyncTime: lastSyncTime, errorMessage: "Unable to apply changes from iCloud", needsSignIn: false, accountStatus: nil)
        } else {
            markSyncSuccess()
        }
    }

    func processIncomingRecord(_ record: CKRecord) async throws {
        guard record.recordType == ArticleRecord.recordType else { return }
        logWatchedRecordTransition(
            prefix: "Watched article inbound record",
            recordID: record.recordID,
            record: record,
            storedRecord: fetchStoredRecord(recordName: record.recordID.recordName),
            eventSource: "remoteFetch.beforeApply",
            overrideLocation: .serverConfirmed
        )
        try store.saveRecord(try ArticleRecord(record: record))
        logWatchedRecordTransition(
            prefix: "Watched article inbound record",
            recordID: record.recordID,
            record: record,
            storedRecord: fetchStoredRecord(recordName: record.recordID.recordName),
            eventSource: "remoteFetch.afterApply",
            overrideLocation: .serverConfirmed
        )
    }

    func processIncomingDeletion(_ recordID: CKRecord.ID) async throws {
        logWatchedRecordTransition(
            prefix: "Watched article inbound deletion",
            recordID: recordID,
            storedRecord: fetchStoredRecord(recordName: recordID.recordName),
            eventSource: "remoteFetch.delete",
            overrideLocation: .pendingDeletion
        )
        try store.deleteRecord(recordName: recordID.recordName)
        syncEngine?.state.remove(
            pendingRecordZoneChanges: [.saveRecord(recordID), .deleteRecord(recordID)]
        )
    }

    func processSentRecordZoneChanges(
        _ sent: CKSyncEngine.Event.SentRecordZoneChanges,
        syncEngine: CKSyncEngine
    ) async {
        var didFail = false

        for savedRecord in sent.savedRecords {
            await updateSystemFields(for: savedRecord)
            logWatchedRecordTransition(
                prefix: "Watched article send confirmation",
                recordID: savedRecord.recordID,
                record: savedRecord,
                storedRecord: fetchStoredRecord(recordName: savedRecord.recordID.recordName),
                eventSource: "sendConfirmation.savedRecord",
                overrideLocation: .serverConfirmed
            )
        }

        for failedSave in sent.failedRecordSaves {
            logWatchedRecordTransition(
                prefix: "Watched article send failure",
                recordID: failedSave.record.recordID,
                record: failedSave.record,
                storedRecord: fetchStoredRecord(recordName: failedSave.record.recordID.recordName),
                eventSource: "sendConfirmation.failedRecord",
                overrideLocation: nil
            )
            if await handleSendFailure(failedSave, syncEngine: syncEngine) {
                didFail = true
            }
        }

        if didFail {
            publishStatus(.error(message: "Unable to sync with iCloud", needsSignIn: false), lastSyncTime: lastSyncTime, errorMessage: "Unable to sync with iCloud", needsSignIn: false, accountStatus: nil)
        } else {
            markSyncSuccess()
        }
    }

    func updateSystemFields(for record: CKRecord) async {
        do {
            guard let articleID = UUID(uuidString: record.recordID.recordName),
                  var articleRecord = try store.fetchRecord(id: articleID) else {
                return
            }

            articleRecord.cloudKitSystemFields = ArticleRecord.encodeSystemFields(record)
            try store.saveRecord(articleRecord)
        } catch {
            Logger.cloudKit.error(
                "Failed to update system fields for \(record.recordID.recordName): \(error.localizedDescription)"
            )
        }
    }

    func handleSendFailure(
        _ failedSave: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave,
        syncEngine: CKSyncEngine
    ) async -> Bool {
        let ckError = failedSave.error
        let recordID = failedSave.record.recordID
        let storedRecord = fetchStoredRecord(recordName: recordID.recordName)
        let recordContext = recordDiagnosticsContext(
            for: failedSave.record,
            storedRecord: storedRecord,
            eventSource: "sendFailure.recordContext"
        )

        if ckError.code == .serverRecordChanged,
           let serverRecord = ckError.serverRecord {
            logWatchedRecordTransition(
                prefix: "Watched article conflict resolution",
                recordID: recordID,
                record: serverRecord,
                storedRecord: storedRecord,
                eventSource: "sendFailure.serverRecordChanged",
                overrideLocation: .conflictResolvedFromServer
            )
            Logger.cloudKit.warning(
                "Resolved serverRecordChanged for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) context=\(recordContext)"
            )
            do {
                try await processIncomingRecord(serverRecord)
                syncEngine.state.remove(
                    pendingRecordZoneChanges: [.saveRecord(recordID)]
                )
                return false
            } catch {
                Logger.cloudKit.error(
                    "Failed to apply server record during conflict resolution for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) error=\(describe(error: error))"
                )
                appendRecentFailedSaveDetail(
                    "Conflict resolution failed for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) error=\(describe(error: error))"
                )
                return true
            }
        }

        if shouldRecoverMissingServerRecord(
            error: ckError,
            storedRecord: storedRecord
        ) {
            if !isRepairSyncRecoveryEnabled {
                let detail = [
                    "Remote deletion detected for local record \(recordID.recordName)",
                    "zone=\(recordZoneDescription(for: recordID))",
                    "action=deletedLocalCopy",
                    recordContext
                ].joined(separator: " | ")
                Logger.cloudKit.warning(detail)
                appendRecentFailedSaveDetail(detail)

                do {
                    try store.deleteRecord(recordName: recordID.recordName)
                    syncEngine.state.remove(
                        pendingRecordZoneChanges: [.saveRecord(recordID), .deleteRecord(recordID)]
                    )
                    return false
                } catch {
                    Logger.cloudKit.error(
                        "Failed to delete local record after remote deletion detection for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) error=\(describe(error: error))"
                    )
                    appendRecentFailedSaveDetail(
                        "Remote deletion recovery failed for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) error=\(describe(error: error))"
                    )
                    return true
                }
            }

            let detail = [
                "Recovered missing server record for local record \(recordID.recordName)",
                "zone=\(recordZoneDescription(for: recordID))",
                "action=clearedSystemFieldsAndRequeuedSave",
                recordContext
            ].joined(separator: " | ")
            Logger.cloudKit.warning(detail)
            appendRecentFailedSaveDetail(detail)

            do {
                try store.clearCloudKitSystemFields(recordName: recordID.recordName)
                syncEngine.state.remove(
                    pendingRecordZoneChanges: [.deleteRecord(recordID)]
                )
                syncEngine.state.add(
                    pendingRecordZoneChanges: [.saveRecord(recordID)]
                )
                logWatchedRecordTransition(
                    prefix: "Watched article unknownItem recovery",
                    recordID: recordID,
                    storedRecord: fetchStoredRecord(recordName: recordID.recordName),
                    eventSource: "sendFailure.unknownItem",
                    overrideLocation: .unknownItemRecovered
                )
                return false
            } catch {
                Logger.cloudKit.error(
                    "Failed to recover local record after missing server record for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) error=\(describe(error: error))"
                )
                appendRecentFailedSaveDetail(
                    "Missing server record recovery failed for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) error=\(describe(error: error))"
                )
                return true
            }
        }

        let topLevelLine = structuredFailureLine(
            recordID: recordID,
            error: ckError,
            context: recordContext,
            prefix: "Failed to save record",
            eventSource: "sendFailure.topLevel"
        )
        Logger.cloudKit.error(topLevelLine)
        appendRecentFailedSaveDetail(topLevelLine)

        if ckError.code == .partialFailure {
            let partialErrors = partialErrorsByRecordID(from: ckError)
            if partialErrors.isEmpty {
                Logger.cloudKit.error(
                    "Partial failure for \(recordID.recordName) zone=\(recordZoneDescription(for: recordID)) had no itemized suberrors"
                )
            } else {
                for (partialRecordID, partialError) in partialErrors.sorted(by: { $0.0.recordName < $1.0.recordName }) {
                    let partialLine = structuredFailureLine(
                        recordID: partialRecordID,
                        error: partialError,
                        context: recordContext,
                        prefix: "Partial failure item",
                        eventSource: "sendFailure.partial"
                    )
                    Logger.cloudKit.error(partialLine)
                    appendRecentFailedSaveDetail(partialLine)

                    if let partialCKError = partialError as? CKError,
                       partialCKError.code == .partialFailure {
                        let nestedPartialErrors = partialErrorsByRecordID(from: partialCKError)
                        for (nestedRecordID, nestedError) in nestedPartialErrors.sorted(by: { $0.0.recordName < $1.0.recordName }) {
                            let nestedLine = structuredFailureLine(
                                recordID: nestedRecordID,
                                error: nestedError,
                                context: recordContext,
                                prefix: "Nested partial failure item",
                                eventSource: "sendFailure.partialNested"
                            )
                            Logger.cloudKit.error(nestedLine)
                            appendRecentFailedSaveDetail(nestedLine)
                        }
                    }
                }
            }
        }

        return true
    }

    func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn:
            publishStatus(.idle, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: "signed in")
        case .signOut:
            publishStatus(.error(message: "Sign in to iCloud to sync", needsSignIn: true), lastSyncTime: lastSyncTime, errorMessage: "Sign in to iCloud to sync", needsSignIn: true, accountStatus: "signed out")
        case .switchAccounts:
            publishStatus(.error(message: "iCloud account changed", needsSignIn: true), lastSyncTime: lastSyncTime, errorMessage: "iCloud account changed", needsSignIn: true, accountStatus: "switched accounts")
        @unknown default:
            publishStatus(.error(message: "iCloud account changed", needsSignIn: false), lastSyncTime: lastSyncTime, errorMessage: "iCloud account changed", needsSignIn: false, accountStatus: "unknown")
        }
    }

    func markSyncSuccess() {
        lastSyncTime = Date()
        let successState: SyncState = isVisibleRestoreInProgress ? .restoring : .success
        publishStatus(successState, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
        idleTask?.cancel()
        guard !isVisibleRestoreInProgress else {
            Task {
                await persistCurrentSyncState()
            }
            return
        }
        idleTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if state == .success {
                publishStatus(.idle, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
            }
        }

        Task {
            await persistCurrentSyncState()
        }
    }

    func updateState(_ newState: SyncState) {
        publishStatus(newState, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
    }

    func publishStatus(
        _ newState: SyncState,
        lastSyncTime: Date?,
        errorMessage: String?,
        needsSignIn: Bool,
        accountStatus: String?,
        diagnosticHint: String? = nil,
        cloudKitContainerIdentifier: String? = nil,
        cloudKitIdentityTokenState: String? = nil,
        cloudKitUserRecordID: String? = nil
    ) {
        state = newState
        NotificationCenter.default.post(
            name: .luegoSyncEngineStatusDidChange,
            object: self,
            userInfo: [
                SyncEngineStatusPayloadKey.state: newState,
                SyncEngineStatusPayloadKey.lastSyncTime: lastSyncTime as Any,
                SyncEngineStatusPayloadKey.errorMessage: errorMessage as Any,
                SyncEngineStatusPayloadKey.needsSignIn: needsSignIn,
                SyncEngineStatusPayloadKey.accountStatus: accountStatus as Any,
                SyncEngineStatusPayloadKey.diagnosticHint: diagnosticHint as Any,
                SyncEngineStatusPayloadKey.cloudKitContainerIdentifier: cloudKitContainerIdentifier as Any,
                SyncEngineStatusPayloadKey.cloudKitIdentityTokenState: cloudKitIdentityTokenState as Any,
                SyncEngineStatusPayloadKey.cloudKitUserRecordID: cloudKitUserRecordID as Any,
                SyncEngineStatusPayloadKey.recentFailedSaveDetails: recentFailedSaveDetails as Any
            ]
        )
    }

    func persistStateSerialization(_ serialization: CKSyncEngine.State.Serialization) async {
        currentStateSerialization = serialization
        await persistSyncState(serialization: serialization, updateLastSyncTime: false)
    }

    func persistCurrentSyncState() async {
        await persistSyncState(serialization: currentStateSerialization, updateLastSyncTime: true)
    }

    func persistSyncState(
        serialization: CKSyncEngine.State.Serialization?,
        updateLastSyncTime: Bool
    ) async {
        do {
            var payload = (try? database.syncEngineStatePayload()) ?? SyncEngineStatePayload()
            payload.stateSerialization = serialization ?? payload.stateSerialization
            if updateLastSyncTime {
                payload.lastSyncTime = lastSyncTime
            }
            try database.saveSyncEngineStatePayload(payload)
        } catch {
            Logger.cloudKit.error("Failed to persist sync state: \(error.localizedDescription)")
        }
    }

    func appendRecentFailedSaveDetail(_ detail: String) {
        guard !detail.isEmpty else { return }
        recentFailedSaveDetails.removeAll { $0 == detail }
        recentFailedSaveDetails.insert(detail, at: 0)
        if recentFailedSaveDetails.count > 5 {
            recentFailedSaveDetails = Array(recentFailedSaveDetails.prefix(5))
        }
    }

    func recordZoneDescription(for recordID: CKRecord.ID) -> String {
        "\(recordID.zoneID.zoneName) owner=\(recordID.zoneID.ownerName)"
    }

    func recordPayloadSummary(record: CKRecord, storedRecord: ArticleRecord?) -> String {
        let urlString = (record["url"] as? String) ?? storedRecord?.url.absoluteString ?? "missing"
        let title = (record["title"] as? String) ?? storedRecord?.title ?? ""
        let content = (record["content"] as? String) ?? storedRecord?.content ?? ""
        let author = (record["author"] as? String) ?? storedRecord?.author ?? ""
        let wordCount = (record["wordCount"] as? Int) ?? storedRecord?.wordCount
        let readPosition = (record["readPosition"] as? Double) ?? storedRecord?.readPosition ?? 0
        let isFavorite = (record["isFavorite"] as? Bool) ?? storedRecord?.isFavorite ?? false
        let isArchived = (record["isArchived"] as? Bool) ?? storedRecord?.isArchived ?? false
        let thumbnailPresent = (record["thumbnailURL"] as? String) != nil || storedRecord?.thumbnailURL != nil
        let publishedDatePresent = (record["publishedDate"] as? Date) != nil || storedRecord?.publishedDate != nil
        let systemFieldsState = storedRecord.map { $0.cloudKitSystemFields == nil ? "absent" : "present" } ?? "unknown"

        return [
            "url=\(urlString)",
            "titleChars=\(title.count)",
            "contentChars=\(content.count)",
            "authorChars=\(author.count)",
            "wordCount=\(wordCount.map { String($0) } ?? "nil")",
            "readPosition=\(readPosition)",
            "isFavorite=\(isFavorite)",
            "isArchived=\(isArchived)",
            "thumbnailURL=\(thumbnailPresent ? "present" : "absent")",
            "publishedDate=\(publishedDatePresent ? "present" : "absent")",
            "deletedAt=\(storedRecord?.deletedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil")",
            "cloudKitSystemFields=\(systemFieldsState)"
        ].joined(separator: " | ")
    }

    func structuredFailureLine(
        recordID: CKRecord.ID,
        error: Error,
        context: String,
        prefix: String,
        eventSource: String
    ) -> String {
        let nsError = error as NSError
        let retryAfterSeconds = retryAfterSeconds(for: nsError)
        let errorSummary = "domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
        let retrySummary = retryAfterSeconds.map { "retryAfterSeconds=\($0)" } ?? "retryAfterSeconds=nil"

        return [
            "\(prefix) \(recordID.recordName)",
            "zone=\(recordZoneDescription(for: recordID))",
            "error=\(errorSummary)",
            retrySummary,
            "clientRecord=\(ckRecordPresence(error: error, keyPath: \.clientRecord))",
            "serverRecord=\(ckRecordPresence(error: error, keyPath: \.serverRecord))",
            "ancestorRecord=\(ckRecordPresence(error: error, keyPath: \.ancestorRecord))",
            "eventSource=\(eventSource)",
            context
        ].joined(separator: " | ")
    }

    func ckRecordPresence(error: Error, keyPath: KeyPath<CKError, CKRecord?>) -> String {
        guard let ckError = error as? CKError else { return "unknown" }
        return ckError[keyPath: keyPath] == nil ? "absent" : "present"
    }

    func retryAfterSeconds(for error: NSError) -> TimeInterval? {
        if let value = error.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            return value
        }
        if let value = error.userInfo[CKErrorRetryAfterKey] as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    func partialErrorsByRecordID(from error: CKError) -> [(CKRecord.ID, Error)] {
        if let errors = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
            return errors.map { ($0.key, $0.value) }
        }

        if let errors = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            return errors.compactMap { key, value in
                guard let recordID = key as? CKRecord.ID else { return nil }
                return (recordID, value)
            }
        }

        if let errors = error.userInfo[CKPartialErrorsByItemIDKey] as? NSDictionary {
            return errors.compactMap { key, value in
                guard let recordID = key as? CKRecord.ID else { return nil }
                guard let nestedError = value as? Error else { return nil }
                return (recordID, nestedError)
            }
        }

        return []
    }

    func describe(error: Error) -> String {
        let nsError = error as NSError
        return "domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
    }

    func shouldRecoverMissingServerRecord(
        error: CKError,
        storedRecord: ArticleRecord?
    ) -> Bool {
        error.code == .unknownItem && storedRecord?.cloudKitSystemFields != nil
    }

    func reconcileLocalRecordsMissingFromServer(fetchedRecordNames: Set<String>) throws {
        let localRecords = try store.fetchAllRecords()

        for record in localRecords {
            guard record.deletedAt == nil,
                  record.cloudKitSystemFields != nil,
                  !fetchedRecordNames.contains(record.id) else {
                continue
            }

            try store.clearCloudKitSystemFields(recordName: record.id)
        }
    }

    func endRepairSyncRecoveryIfPossible() {
        guard isRepairSyncRecoveryEnabled,
              syncEngine?.state.pendingRecordZoneChanges.isEmpty ?? true else {
            return
        }

        isRepairSyncRecoveryEnabled = false
    }

    func performSmartRefresh() async throws -> Int {
        let shouldRestore = try shouldAttemptBootstrapRestore()
        var didCompleteFetchChanges = false
        isVisibleRestoreInProgress = shouldRestore
        publishRefreshStartState(isRestoring: shouldRestore)

        do {
            try await fetchChanges()
            didCompleteFetchChanges = true

            if shouldRestore, try store.countArticles() == 0 {
                _ = try await backfillAllArticlesFromServer()
            }

            if shouldRestore {
                try markBootstrapRestoreCompleted()
                isVisibleRestoreInProgress = false
            }

            markSyncSuccess()
            return 0
        } catch {
            if shouldRestore, didCompleteFetchChanges {
                await publishSyncFailure(error, prefix: "Bootstrap restore")
            }
            isVisibleRestoreInProgress = false
            throw error
        }
    }

    func performFullRepairRefresh() async throws -> Int {
        isVisibleRestoreInProgress = false
        logWatchedRecordSummary(context: "repairSync:start")

        do {
            try await resetSyncStateForFullRefetch()
            try await fetchChanges()
            _ = try await backfillAllArticlesFromServer()
            let records = try store.fetchAllRecords()

            for record in records {
                enqueueSave(for: ArticleRecord.makeRecordID(for: record.id))
            }

            try await sendChanges()
            try await fetchChanges()
            try markBootstrapRestoreCompleted()
            logWatchedRecordSummary(context: "repairSync:complete")
            return records.count
        } catch {
            logWatchedRecordSummary(context: "repairSync:failed")
            throw error
        }
    }

    func shouldAttemptBootstrapRestore() throws -> Bool {
        try store.countArticles() == 0 &&
        database.migrationValue(for: Self.bootstrapRestoreMarkerKey) == nil
    }

    func markBootstrapRestoreCompleted() throws {
        try database.saveMigrationValue(
            ISO8601DateFormatter().string(from: Date()),
            for: Self.bootstrapRestoreMarkerKey
        )
    }

    func publishRefreshStartState(isRestoring: Bool) {
        let refreshState: SyncState = isRestoring ? .restoring : .syncing
        publishStatus(refreshState, lastSyncTime: lastSyncTime, errorMessage: nil, needsSignIn: false, accountStatus: nil)
    }

    func publishSyncFailure(_ error: Error, prefix: String) async {
        let diagnostics = await CloudKitRuntimeDiagnostics.collect(
            container: container,
            containerIdentifier: AppConfiguration.cloudKitContainerIdentifier
        )
        Logger.cloudKit.info("\(prefix) diagnostics — \(diagnostics.summaryLine)")
        for line in diagnostics.detailLines {
            Logger.cloudKit.info("\(prefix) diagnostics — \(line)")
        }
        publishStatus(
            .error(message: diagnostics.actionableHint, needsSignIn: diagnostics.needsSignIn),
            lastSyncTime: lastSyncTime,
            errorMessage: diagnostics.actionableHint,
            needsSignIn: diagnostics.needsSignIn,
            accountStatus: diagnostics.accountStatus,
            diagnosticHint: diagnostics.actionableHint,
            cloudKitContainerIdentifier: diagnostics.containerIdentifier,
            cloudKitIdentityTokenState: diagnostics.identityTokenState,
            cloudKitUserRecordID: diagnostics.userRecordID
        )
    }

    func recordDiagnosticsContext(
        for record: CKRecord,
        storedRecord: ArticleRecord?,
        eventSource: String,
        overrideLocation: ArticleSyncLocation? = nil
    ) -> String {
        guard let articleID = UUID(uuidString: record.recordID.recordName) else {
            return "storedRecord=unavailable | eventSource=\(eventSource)"
        }

        let storageSummary = watchedArticleStateLine(
            recordID: record.recordID,
            record: record,
            storedRecord: storedRecord,
            eventSource: eventSource,
            overrideLocation: overrideLocation
        ) ?? "id=\(articleID.uuidString) | eventSource=\(eventSource)"

        if storedRecord == nil {
            return "storedRecord=missing | \(storageSummary)"
        }

        return "storedRecord=present | \(storageSummary)"
    }

    var watchedRecordID: CKRecord.ID {
        ArticleRecord.makeRecordID(for: Self.watchedArticleRecordName)
    }

    func fetchWatchedStoredRecord() -> ArticleRecord? {
        if let record = fetchStoredRecord(recordName: Self.watchedArticleRecordName) {
            return record
        }

        guard let url = URL(string: Self.watchedArticleURLString) else {
            return nil
        }

        return fetchStoredRecord(url: url)
    }

    func fetchStoredRecord(recordName: String) -> ArticleRecord? {
        (try? store.fetchRecord(recordName: recordName)) ?? nil
    }

    func fetchStoredRecord(url: URL) -> ArticleRecord? {
        (try? store.fetchRecord(url: url)) ?? nil
    }

    func logWatchedRecordTransition(
        prefix: String,
        recordID: CKRecord.ID,
        record: CKRecord? = nil,
        storedRecord: ArticleRecord? = nil,
        eventSource: String,
        overrideLocation: ArticleSyncLocation? = nil
    ) {
        guard let line = watchedArticleStateLine(
            recordID: recordID,
            record: record,
            storedRecord: storedRecord,
            eventSource: eventSource,
            overrideLocation: overrideLocation
        ) else {
            return
        }

        Logger.cloudKit.info("\(prefix) — \(line)")
    }

    func watchedArticleStateLine(
        recordID: CKRecord.ID,
        record: CKRecord?,
        storedRecord: ArticleRecord?,
        eventSource: String,
        overrideLocation: ArticleSyncLocation? = nil
    ) -> String? {
        guard isWatched(recordID: recordID, record: record, storedRecord: storedRecord) else {
            return nil
        }

        let pendingChanges = pendingChangeFlags(for: recordID)
        let effectiveStoredRecord = storedRecord ?? fetchWatchedStoredRecord()
        let effectiveURL = (record?["url"] as? String) ?? effectiveStoredRecord?.url.absoluteString ?? "missing"
        let effectiveLocation = deriveSyncLocation(
            recordID: recordID,
            storedRecord: effectiveStoredRecord,
            pendingSave: pendingChanges.save,
            pendingDelete: pendingChanges.delete,
            overrideLocation: overrideLocation
        )

        return [
            "recordID=\(recordID.recordName)",
            "url=\(effectiveURL)",
            "syncLocation=\(effectiveLocation.rawValue)",
            "hasSystemFields=\(effectiveStoredRecord?.cloudKitSystemFields != nil)",
            "deletedAt=\(effectiveStoredRecord?.deletedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil")",
            "visible=\(effectiveStoredRecord?.deletedAt == nil && effectiveStoredRecord != nil)",
            "pendingSave=\(pendingChanges.save)",
            "pendingDelete=\(pendingChanges.delete)",
            "eventSource=\(eventSource)"
        ].joined(separator: " | ")
    }

    func isWatched(recordID: CKRecord.ID, record: CKRecord?, storedRecord: ArticleRecord?) -> Bool {
        if recordID.recordName == Self.watchedArticleRecordName {
            return true
        }

        if let recordURL = record?["url"] as? String, recordURL == Self.watchedArticleURLString {
            return true
        }

        return storedRecord?.url.absoluteString == Self.watchedArticleURLString
    }

    func pendingChangeFlags(for recordID: CKRecord.ID) -> (save: Bool, delete: Bool) {
        guard let syncEngine else {
            return (false, false)
        }

        var hasPendingSave = false
        var hasPendingDelete = false

        for pendingChange in syncEngine.state.pendingRecordZoneChanges {
            switch pendingChange {
            case .saveRecord(let pendingRecordID) where pendingRecordID == recordID:
                hasPendingSave = true
            case .deleteRecord(let pendingRecordID) where pendingRecordID == recordID:
                hasPendingDelete = true
            default:
                break
            }
        }

        return (hasPendingSave, hasPendingDelete)
    }

    func deriveSyncLocation(
        recordID: CKRecord.ID,
        storedRecord: ArticleRecord?,
        pendingSave: Bool,
        pendingDelete: Bool,
        overrideLocation: ArticleSyncLocation?
    ) -> ArticleSyncLocation {
        if let overrideLocation {
            return overrideLocation
        }

        if pendingDelete || storedRecord?.deletedAt != nil {
            return .pendingDeletion
        }

        if pendingSave {
            return .pendingUpload
        }

        if storedRecord == nil && recordID.recordName == Self.watchedArticleRecordName {
            return .missingLocally
        }

        if storedRecord?.cloudKitSystemFields != nil {
            return .serverConfirmed
        }

        return .localOnly
    }
}

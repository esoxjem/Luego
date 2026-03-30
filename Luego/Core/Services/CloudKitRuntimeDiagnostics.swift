import CloudKit
import Foundation

struct CloudKitRuntimeDiagnostics: Sendable {
    let containerIdentifier: String
    let databaseScope: String
    let accountStatus: String
    let accountStatusError: String?
    let identityTokenState: String
    let userRecordID: String
    let actionableHint: String

    var needsSignIn: Bool {
        accountStatus == "noAccount"
    }

    var summaryLine: String {
        [
            "container=\(containerIdentifier)",
            "database=\(databaseScope)",
            "accountStatus=\(accountStatus)",
            "identityToken=\(identityTokenState)",
            "userRecordID=\(userRecordID)"
        ].joined(separator: " | ")
    }

    var detailLines: [String] {
        var lines = [
            "CloudKit Container: \(containerIdentifier)",
            "CloudKit Database Scope: \(databaseScope)",
            "iCloud Account Status: \(accountStatus)",
            "iCloud Identity Token: \(identityTokenState)",
            "CloudKit User Record ID: \(userRecordID)"
        ]

        if let accountStatusError {
            lines.append("iCloud Account Status Error: \(accountStatusError)")
        }

        lines.append("Recommended Action: \(actionableHint)")
        return lines
    }

    static func collect(container: CKContainer, containerIdentifier: String) async -> CloudKitRuntimeDiagnostics {
        let probe = await fetchAccountStatus(for: container)
        let identityTokenState = FileManager.default.ubiquityIdentityToken == nil ? "absent" : "present"
        let userRecordID = await fetchUserRecordID(for: container)
        let accountStatus = accountStatusName(for: probe.status)
        let actionableHint = recommendation(
            for: probe.status,
            identityTokenState: identityTokenState,
            userRecordID: userRecordID,
            accountStatusError: probe.errorDescription
        )

        return CloudKitRuntimeDiagnostics(
            containerIdentifier: containerIdentifier,
            databaseScope: "private",
            accountStatus: accountStatus,
            accountStatusError: probe.errorDescription,
            identityTokenState: identityTokenState,
            userRecordID: userRecordID,
            actionableHint: actionableHint
        )
    }

    private static func fetchAccountStatus(for container: CKContainer) async -> (status: CKAccountStatus, errorDescription: String?) {
        do {
            return (try await container.accountStatus(), nil)
        } catch {
            return (.couldNotDetermine, error.localizedDescription)
        }
    }

    private static func fetchUserRecordID(for container: CKContainer) async -> String {
        do {
            let recordID = try await container.userRecordID()
            return recordID.recordName
        } catch {
            return "unavailable: \(error.localizedDescription)"
        }
    }

    private static func accountStatusName(for status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "available"
        case .noAccount:
            return "noAccount"
        case .restricted:
            return "restricted"
        case .couldNotDetermine:
            return "couldNotDetermine"
        case .temporarilyUnavailable:
            return "temporarilyUnavailable"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }

    private static func recommendation(
        for status: CKAccountStatus,
        identityTokenState: String,
        userRecordID: String,
        accountStatusError: String?
    ) -> String {
        switch status {
        case .available:
            if userRecordID.hasPrefix("unavailable:") {
                return "CloudKit is available, but fetching the user record ID failed. Retry after confirming network access."
            }
            if identityTokenState == "absent" {
                return "CloudKit is available. Some environments may not expose a local iCloud identity token even when sync works, so only investigate this further if sync fails."
            }
            return "CloudKit is available."
        case .noAccount:
            return "Sign into iCloud on this device, then retry sync."
        case .restricted:
            return "iCloud access is restricted on this device. Check Screen Time, parental controls, or device management settings."
        case .couldNotDetermine:
            if let accountStatusError {
                return "CloudKit could not determine account status: \(accountStatusError). Confirm iCloud sign-in and network connectivity, then retry."
            }
            return "CloudKit could not determine account status. Confirm iCloud sign-in and network connectivity, then retry."
        case .temporarilyUnavailable:
            return "CloudKit is temporarily unavailable. Retry after a short delay."
        @unknown default:
            return "CloudKit returned an unknown account status."
        }
    }
}

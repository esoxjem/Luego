import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    var syncStatusObserver: SyncStatusObserver?
    @Environment(SyncStatusObserver.self) private var envSyncStatusObserver: SyncStatusObserver?
    @Environment(\.dismiss) private var dismiss

    private var resolvedObserver: SyncStatusObserver? {
        syncStatusObserver ?? envSyncStatusObserver
    }

    var body: some View {
        Form {
            SyncStatusSection(
                state: resolvedObserver?.state ?? .idle,
                lastSyncTime: resolvedObserver?.lastSyncTime,
                syncStatusObserver: resolvedObserver,
                isSyncing: viewModel.isForceSyncing,
                didSync: viewModel.didForceSync,
                repairErrorMessage: viewModel.forceSyncErrorMessage,
                onSync: { Task { await viewModel.forceReSync() } }
            )

            DiscoverySettingsSection(
                selectedSource: $viewModel.selectedDiscoverySource,
                onSourceChanged: viewModel.updateDiscoverySource
            )

            RefreshArticlePoolSection(
                didRefresh: viewModel.didRefreshPool,
                onRefresh: viewModel.refreshArticlePool
            )

            SDKUpdateSection(
                isChecking: viewModel.isCheckingForUpdates,
                onCheck: { Task { await viewModel.checkForSDKUpdates() } }
            )

            Section {
                CopyDiagnosticsButton(
                    viewModel: viewModel,
                    syncStatusObserver: resolvedObserver
                )
            } header: {
                Text("Developer")
            } footer: {
                Text("Tools for monitoring and debugging.")
            }
            .listRowBackground(Color.paperCream)

            AppVersionSection(sdkVersionString: viewModel.sdkVersionString)
        }
        .scrollContentBackground(.hidden)
        .background(Color.regularPanelBackground)
        .navigationTitle("Settings")
        .tint(Color.regularSelectionInk)
        .appNavigationStyle(.contentLargeTitle)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .alert(
            viewModel.updateAlertTitle,
            isPresented: $viewModel.showUpdateAlert
        ) {
            Button("OK") { }
        } message: {
            Text(viewModel.updateAlertMessage)
        }
        .font(.nunito(.body))
    }
}

struct IOSSettingsRow<TitleAccessory: View, Trailing: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var showsIcon: Bool = true
    var iconColor: Color = .secondary
    @ViewBuilder var titleAccessory: TitleAccessory
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            if showsIcon {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .foregroundStyle(.primary)

                    titleAccessory
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            trailing
        }
        .contentShape(Rectangle())
    }
}

extension IOSSettingsRow where TitleAccessory == EmptyView {
    init(
        title: String,
        subtitle: String,
        systemImage: String,
        showsIcon: Bool = true,
        iconColor: Color = .secondary,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.showsIcon = showsIcon
        self.iconColor = iconColor
        self.titleAccessory = EmptyView()
        self.trailing = trailing()
    }
}

struct IOSDiscoverySourceRow: View {
    let source: DiscoverySource
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: onTap) {
            IOSSettingsRow(
                title: source.displayName,
                subtitle: source.descriptionText,
                systemImage: "safari",
                showsIcon: false,
                iconColor: .regularSelectionInk
            ) {
                if let websiteURL = source.websiteURL {
                    SourceWebsiteLinkButton(url: websiteURL, openURL: openURL)
                }
            } trailing: {
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.regularSelectionInk)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct DiscoverySettingsSection: View {
    @Binding var selectedSource: DiscoverySource
    let onSourceChanged: (DiscoverySource) -> Void

    var body: some View {
        Section {
            DiscoverySettingsContent(
                selectedSource: $selectedSource,
                onSourceChanged: onSourceChanged
            )
        } header: {
            Text("Discovery")
        } footer: {
            Text("Choose a source for finding new articles.")
        }
        .listRowBackground(Color.paperCream)
    }
}

struct DiscoverySettingsContent: View {
    @Binding var selectedSource: DiscoverySource
    let onSourceChanged: (DiscoverySource) -> Void

    var body: some View {
        ForEach(DiscoverySource.allCases, id: \.self) { source in
            IOSDiscoverySourceRow(
                source: source,
                isSelected: selectedSource == source,
                onTap: {
                    selectedSource = source
                    onSourceChanged(source)
                }
            )
        }
    }
}

struct SourceWebsiteLinkButton: View {
    let url: URL
    let openURL: OpenURLAction

    var body: some View {
        Button {
            openURL(url)
        } label: {
            Image(systemName: "arrow.up.right.square")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

struct RefreshArticlePoolSection: View {
    let didRefresh: Bool
    let onRefresh: () -> Void

    var body: some View {
        Section {
            Button(action: onRefresh) {
                IOSSettingsRow(
                    title: "Refresh Article Pool",
                    subtitle: "Clears cached articles and fetches fresh results.",
                    systemImage: "arrow.clockwise"
                ) {
                    if didRefresh {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(didRefresh)
        } footer: {
            Text("Clears the cached article pool and fetches fresh articles on next discovery.")
        }
        .listRowBackground(Color.paperCream)
    }
}

struct SDKUpdateSection: View {
    let isChecking: Bool
    let onCheck: () -> Void

    var body: some View {
        Section {
            Button(action: onCheck) {
                IOSSettingsRow(
                    title: "Check for SDK Updates",
                    subtitle: "Downloads the latest parser rules when available.",
                    systemImage: "arrow.triangle.2.circlepath"
                ) {
                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isChecking)
        } footer: {
            Text("Downloads the latest parsing rules and parser if available.")
        }
        .listRowBackground(Color.paperCream)
    }
}

struct SyncStatusSection: View {
    let state: SyncState
    let lastSyncTime: Date?
    let syncStatusObserver: SyncStatusObserver?
    let isSyncing: Bool
    let didSync: Bool
    let repairErrorMessage: String?
    let onSync: () -> Void

    private var statusText: String {
        switch state {
        case .idle: "Up to date"
        case .syncing: "Syncing..."
        case .restoring: "Restoring..."
        case .success: "Just synced"
        case .error(let message, _): message
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle, .success: .secondary
        case .syncing, .restoring: .blue
        case .error: .red
        }
    }

    private var formattedTime: String? {
        guard let time = lastSyncTime else { return nil }
        return DateFormatters.time.string(from: time)
    }

    private var accessibilityStatusValue: String {
        if let timeText = formattedTime {
            return "\(statusText). Last synced at \(timeText)"
        }
        return statusText
    }

    private var statusSubtitle: String {
        if state == .restoring {
            return "Downloading your reading list from iCloud."
        }
        if let timeText = formattedTime {
            return "Last synced at \(timeText)"
        }
        return "Sync status is shown after your first successful update."
    }

    var body: some View {
        Section {
            IOSSettingsRow(
                title: "iCloud Sync",
                subtitle: statusSubtitle,
                systemImage: "icloud",
                iconColor: .secondary
            ) {
                Text(statusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("iCloud Sync")
            .accessibilityValue(accessibilityStatusValue)

            if syncStatusObserver?.cloudKitNeedsAttention == true,
               let diagnosticSummary = syncStatusObserver?.cloudKitDiagnosticSummary {
                Text(diagnosticSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if syncStatusObserver?.cloudKitNeedsAttention == true,
               let diagnosticHint = syncStatusObserver?.cloudKitDiagnosticHint {
                Text(diagnosticHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForceReSyncButton(
                isSyncing: isSyncing,
                didSync: didSync,
                onSync: onSync
            )

            if let repairErrorMessage {
                Text(repairErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            Text("Articles sync automatically across your devices via iCloud.")
        }
        .listRowBackground(Color.paperCream)
    }
}

struct AppVersionSection: View {
    let sdkVersionString: String?

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        Section {
            VStack(spacing: 4) {
                Text(appVersionString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let sdkVersion = sdkVersionString {
                    Text(sdkVersion)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.paperCream)
        }
    }
}

struct CopyDiagnosticsButton: View {
    let viewModel: SettingsViewModel
    let syncStatusObserver: SyncStatusObserver?
    @State private var showCopiedToast = false
    @State private var isLoading = false

    var body: some View {
        Button(action: {
            Task { await copyDiagnostics() }
        }) {
            IOSSettingsRow(
                title: "Copy Diagnostics",
                subtitle: "Export device info for troubleshooting sync issues.",
                systemImage: "doc.on.doc"
            ) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if showCopiedToast {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private func copyDiagnostics() async {
        isLoading = true
        defer { isLoading = false }

        let diagnostics = await viewModel.gatherDiagnostics(syncStatusObserver: syncStatusObserver)

        await MainActor.run {
            UIPasteboard.general.string = diagnostics
            showCopiedToast = true
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)

        await MainActor.run {
            showCopiedToast = false
        }
    }
}

struct ForceReSyncButton: View {
    let isSyncing: Bool
    let didSync: Bool
    let onSync: () -> Void

    var body: some View {
        Button(action: onSync) {
            IOSSettingsRow(
                title: isSyncing ? "Repairing Sync..." : "Repair Sync",
                subtitle: "Fetch from iCloud, resend local changes, and reconcile drift",
                systemImage: "arrow.clockwise.icloud"
            ) {
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else if didSync {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isSyncing)
    }
}

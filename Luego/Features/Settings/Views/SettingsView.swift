import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    var syncStatusObserver: SyncStatusObserver?
    @Environment(SyncStatusObserver.self) private var envSyncStatusObserver: SyncStatusObserver?
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingFileImporter = false

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

            MaintenanceSettingsSection(
                didRefresh: viewModel.didRefreshPool,
                isChecking: viewModel.isCheckingForUpdates,
                onRefresh: viewModel.refreshArticlePool,
                onCheck: { Task { await viewModel.checkForSDKUpdates() } }
            )

            SavedArticleTransferSection(
                isImporting: viewModel.isImporting,
                isPreparingExport: viewModel.isPreparingExport,
                totalSavedArticleCount: viewModel.totalSavedArticleCount,
                readingListArticleCount: viewModel.readingListArticleCount,
                onImportFromFile: {
                    isShowingFileImporter = true
                },
                onPasteArticleList: {
                    viewModel.beginPasteImport()
                },
                onExportAllArticles: {
                    viewModel.prepareExport(scope: .allArticles)
                },
                onExportReadingList: {
                    viewModel.prepareExport(scope: .readingList)
                }
            )

            DeveloperToolsSection(
                viewModel: viewModel,
                syncStatusObserver: resolvedObserver
            )

            AppVersionSection(sdkVersionString: viewModel.sdkVersionString)
        }
        .listSectionSpacing(.compact)
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
        .alert(
            viewModel.alertContent?.title ?? "",
            isPresented: $viewModel.showAlert
        ) {
            Button("OK") { }
        } message: {
            Text(viewModel.alertContent?.message ?? "")
        }
        .sheet(
            isPresented: $viewModel.isShowingPasteImportSheet,
            onDismiss: {
                viewModel.dismissPasteImport()
            }
        ) {
            SavedArticlePasteImportSheet(viewModel: viewModel)
        }
        .sheet(
            item: $viewModel.exportPresentation,
            onDismiss: {
                viewModel.dismissExportPresentation()
            }
        ) { presentation in
            SettingsShareSheet(activityItems: [presentation.fileURL])
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.plainText, .text]
        ) { result in
            handleFileImport(result)
        }
        .task {
            await viewModel.refreshTransferCounts()
        }
        .font(.nunito(.body))
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task {
                do {
                    let text = try readPlainTextFile(at: url)
                    await viewModel.importArticlesFromFileText(text)
                } catch {
                    await MainActor.run {
                        viewModel.presentImportReadError(error)
                    }
                }
            }
        case .failure(let error):
            guard !isUserCancelledFileImport(error) else { return }
            viewModel.presentImportReadError(error)
        }
    }

    private func isUserCancelledFileImport(_ error: Error) -> Bool {
        if let cocoaError = error as? CocoaError, cocoaError.code == .userCancelled {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain
            && nsError.code == CocoaError.Code.userCancelled.rawValue
    }

    private func readPlainTextFile(at url: URL) throws -> String {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let encodings: [String.Encoding] = [
            .utf8,
            .unicode,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian
        ]

        for encoding in encodings {
            if let string = String(data: data, encoding: encoding) {
                return string
            }
        }

        throw CocoaError(.fileReadInapplicableStringEncoding)
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
            SettingsSubsectionLabel(title: "Discovery")

            DiscoverySettingsContent(
                selectedSource: $selectedSource,
                onSourceChanged: onSourceChanged
            )
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

struct MaintenanceSettingsSection: View {
    let didRefresh: Bool
    let isChecking: Bool
    let onRefresh: () -> Void
    let onCheck: () -> Void

    var body: some View {
        Section {
            SettingsSubsectionLabel(title: "Maintenance")

            Button(action: onRefresh) {
                IOSSettingsRow(
                    title: "Refresh Article Pool",
                    subtitle: "Clears cached articles and fetches fresh results.",
                    systemImage: "arrow.clockwise",
                    iconColor: .regularSelectionInk
                ) {
                    maintenanceRowAccessory(
                        isLoading: false,
                        isComplete: didRefresh
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(didRefresh || isChecking)

            Button(action: onCheck) {
                IOSSettingsRow(
                    title: "Check for SDK Updates",
                    subtitle: "Downloads the latest parser rules when available.",
                    systemImage: "arrow.triangle.2.circlepath",
                    iconColor: .regularSelectionInk
                ) {
                    maintenanceRowAccessory(isLoading: isChecking)
                }
            }
            .buttonStyle(.plain)
            .disabled(isChecking)
        }
        .listRowBackground(Color.paperCream)
    }

    @ViewBuilder
    private func maintenanceRowAccessory(
        isLoading: Bool,
        isComplete: Bool = false
    ) -> some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
        } else if isComplete {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

struct SavedArticleTransferSection: View {
    let isImporting: Bool
    let isPreparingExport: Bool
    let totalSavedArticleCount: Int
    let readingListArticleCount: Int
    let onImportFromFile: () -> Void
    let onPasteArticleList: () -> Void
    let onExportAllArticles: () -> Void
    let onExportReadingList: () -> Void

    var body: some View {
        Section {
            SettingsSubsectionLabel(title: "Import")

            Button(action: onImportFromFile) {
                IOSSettingsRow(
                    title: "Import Links from File",
                    subtitle: "Use a plain-text file with one link per line.",
                    systemImage: "square.and.arrow.down",
                    iconColor: .regularSelectionInk
                ) {
                    rowAccessory(isLoading: isImporting)
                }
            }
            .buttonStyle(.plain)
            .disabled(isImporting || isPreparingExport)

            Button(action: onPasteArticleList) {
                IOSSettingsRow(
                    title: "Paste Links",
                    subtitle: "Paste any text that contains article links.",
                    systemImage: "doc.on.clipboard",
                    iconColor: .regularSelectionInk
                ) {
                    rowAccessory(isLoading: isImporting)
                }
            }
            .buttonStyle(.plain)
            .disabled(isImporting || isPreparingExport)

            SettingsSubsectionLabel(title: "Export")

            Button(action: onExportAllArticles) {
                IOSSettingsRow(
                    title: "Export Full Library",
                    subtitle: "Create a text file with every saved link.",
                    systemImage: "square.and.arrow.up",
                    iconColor: .regularSelectionInk
                ) {
                    rowAccessory(
                        isLoading: isPreparingExport,
                        countLabel: transferCountLabel(totalSavedArticleCount)
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(isImporting || isPreparingExport)

            Button(action: onExportReadingList) {
                IOSSettingsRow(
                    title: "Export Reading List",
                    subtitle: "Create a text file with links you haven't archived.",
                    systemImage: "text.badge.checkmark",
                    iconColor: .regularSelectionInk
                ) {
                    rowAccessory(
                        isLoading: isPreparingExport,
                        countLabel: transferCountLabel(readingListArticleCount)
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(isImporting || isPreparingExport)
        }
        .listRowBackground(Color.paperCream)
    }

    @ViewBuilder
    private func rowAccessory(isLoading: Bool, countLabel: String? = nil) -> some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
        } else {
            HStack(spacing: 8) {
                if let countLabel {
                    TransferCountBadge(label: countLabel)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func transferCountLabel(_ count: Int) -> String {
        count.formatted()
    }
}

private struct SettingsSubsectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
    }
}

private struct TransferCountBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.regularSelectionInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.regularSelectionInk.opacity(0.12))
            )
    }
}

struct SavedArticlePasteImportSheet: View {
    @Bindable var viewModel: SettingsViewModel

    private var canImport: Bool {
        !viewModel.pasteImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isImporting
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $viewModel.pasteImportText)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.paperCream)
                        )

                    if viewModel.pasteImportText.isEmpty {
                        Text("Paste one link per line, or any text that contains article links.")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(20)
            .background(Color.regularPanelBackground)
            .navigationTitle("Paste Links")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.dismissPasteImport()
                    }
                    .disabled(viewModel.isImporting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.importArticlesFromPasteText()
                        }
                    } label: {
                        if viewModel.isImporting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Import")
                        }
                    }
                    .disabled(!canImport)
                }
            }
        }
        .presentationDetents([.medium, .large])
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
            SettingsSubsectionLabel(title: "Sync")

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
        }
        .listRowBackground(Color.paperCream)
    }
}

struct DeveloperToolsSection: View {
    let viewModel: SettingsViewModel
    let syncStatusObserver: SyncStatusObserver?

    var body: some View {
        Section {
            SettingsSubsectionLabel(title: "Developer")

            CopyDiagnosticsButton(
                viewModel: viewModel,
                syncStatusObserver: syncStatusObserver
            )
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

struct SettingsShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

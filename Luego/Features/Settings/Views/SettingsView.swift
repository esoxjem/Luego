import SwiftUI
import CloudKit
import SwiftData

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    var syncStatusObserver: SyncStatusObserver?
    @Environment(SyncStatusObserver.self) private var envSyncStatusObserver: SyncStatusObserver?
    @Environment(\.dismiss) private var dismiss

    private var resolvedObserver: SyncStatusObserver? {
        syncStatusObserver ?? envSyncStatusObserver
    }

    var body: some View {
        #if os(macOS)
        SettingsMacLayout(
            viewModel: viewModel,
            state: resolvedObserver?.state ?? .idle,
            lastSyncTime: resolvedObserver?.lastSyncTime
        )
        #else
        Form {
            SyncStatusSection(
                state: resolvedObserver?.state ?? .idle,
                lastSyncTime: resolvedObserver?.lastSyncTime,
                isSyncing: viewModel.isForceSyncing,
                didSync: viewModel.didForceSync,
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
                CopyDiagnosticsButton()
            } header: {
                Text("Developer")
            } footer: {
                Text("Tools for monitoring and debugging.")
            }

            AppVersionSection(sdkVersionString: viewModel.sdkVersionString)
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        #endif
        .alert(
            viewModel.updateAlertTitle,
            isPresented: $viewModel.showUpdateAlert
        ) {
            Button("OK") { }
        } message: {
            Text(viewModel.updateAlertMessage)
        }
        #endif
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
    }
}

struct DiscoverySourceRow: View {
    let source: DiscoverySource
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(source.displayName)
                            .foregroundStyle(.primary)

                        if let websiteURL = source.websiteURL {
                            SourceWebsiteLinkButton(url: websiteURL, openURL: openURL)
                        }
                    }

                    Text(source.descriptionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DiscoverySettingsContent: View {
    @Binding var selectedSource: DiscoverySource
    let onSourceChanged: (DiscoverySource) -> Void

    var body: some View {
        ForEach(DiscoverySource.allCases, id: \.self) { source in
            DiscoverySourceRow(
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
                HStack {
                    Label("Refresh Article Pool", systemImage: "arrow.clockwise")

                    Spacer()

                    if didRefresh {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                    }
                }
            }
            .disabled(didRefresh)
        } footer: {
            Text("Clears the cached article pool and fetches fresh articles on next discovery.")
        }
    }
}

struct SDKUpdateSection: View {
    let isChecking: Bool
    let onCheck: () -> Void

    var body: some View {
        Section {
            Button(action: onCheck) {
                HStack {
                    Label("Check for SDK Updates", systemImage: "arrow.triangle.2.circlepath")

                    Spacer()

                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(isChecking)
        } footer: {
            Text("Downloads the latest parsing rules and parser if available.")
        }
    }
}

struct SyncStatusSection: View {
    let state: SyncState
    let lastSyncTime: Date?
    let isSyncing: Bool
    let didSync: Bool
    let onSync: () -> Void

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

    private var formattedTime: String? {
        guard let time = lastSyncTime else { return nil }
        return DateFormatters.time.string(from: time)
    }

    var body: some View {
        Section {
            HStack {
                Label("iCloud Sync", systemImage: "icloud")

                Spacer()

                Text(statusText)
                    .foregroundStyle(statusColor)
            }

            if let timeText = formattedTime {
                HStack {
                    Text("Last synced")
                    Spacer()
                    Text(timeText)
                        .foregroundStyle(.secondary)
                }
            }

            ForceReSyncButton(
                isSyncing: isSyncing,
                didSync: didSync,
                onSync: onSync
            )
        } footer: {
            Text("Articles sync automatically across your devices via iCloud.")
        }
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
            .listRowBackground(Color.clear)
        }
    }
}

#if os(macOS)
struct SettingsSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
    }
}

struct SettingsActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let showsCheckmark: Bool
    var showsProgress: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else if showsCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 6)
    }
}

struct SyncStatusContent: View {
    let statusText: String
    let statusSymbolName: String
    let statusColor: Color
    let formattedTime: String?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("iCloud Sync", systemImage: "icloud")
                    .labelStyle(.titleAndIcon)

                Spacer()

                Label(statusText, systemImage: statusSymbolName)
                    .foregroundStyle(statusColor)
                    .labelStyle(.titleOnly)
            }

            if let timeText = formattedTime {
                LabeledContent("Last synced", value: timeText)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RefreshArticlePoolAction: View {
    let didRefresh: Bool

    var body: some View {
        SettingsActionRow(
            title: "Refresh Article Pool",
            subtitle: "Clears cached articles and refetches on next discovery.",
            systemImage: "arrow.clockwise",
            showsCheckmark: didRefresh
        )
    }
}

struct SDKUpdateAction: View {
    let isChecking: Bool

    var body: some View {
        SettingsActionRow(
            title: "Check for SDK Updates",
            subtitle: "Downloads new parsing rules when available.",
            systemImage: "arrow.triangle.2.circlepath",
            showsCheckmark: false,
            showsProgress: isChecking
        )
    }
}

struct AppVersionContent: View {
    let appVersionString: String
    let sdkVersionString: String?

    var body: some View {
        VStack(spacing: 6) {
            Text(appVersionString)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let sdkVersion = sdkVersionString {
                Text("SDK \(sdkVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

#endif

#if os(macOS)
struct SettingsMacLayout: View {
    @Bindable var viewModel: SettingsViewModel
    let state: SyncState
    let lastSyncTime: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsHero(state: state)

                SettingsCard {
                    SettingsSectionHeader(
                        title: "Sync",
                        subtitle: "Articles stay consistent across devices via iCloud."
                    )
                    SettingsCardDivider()
                    SyncStatusCard(
                        state: state,
                        lastSyncTime: lastSyncTime,
                        isSyncing: viewModel.isForceSyncing,
                        didSync: viewModel.didForceSync,
                        onSync: { Task { await viewModel.forceReSync() } }
                    )
                }

                SettingsCard {
                    SettingsSectionHeader(
                        title: "Discovery",
                        subtitle: "Choose a source for finding new articles."
                    )
                    SettingsCardDivider()
                    DiscoverySettingsCardContent(
                        selectedSource: $viewModel.selectedDiscoverySource,
                        onSourceChanged: viewModel.updateDiscoverySource
                    )
                }

                SettingsCard {
                    SettingsSectionHeader(
                        title: "Content Cache",
                        subtitle: "Reset discovery results when the pool feels stale."
                    )
                    SettingsCardDivider()
                    SettingsCardActionButton(
                        isDisabled: viewModel.didRefreshPool,
                        action: viewModel.refreshArticlePool
                    ) {
                        RefreshArticlePoolAction(didRefresh: viewModel.didRefreshPool)
                    }
                }

                SettingsCard {
                    SettingsSectionHeader(
                        title: "Parsing SDK",
                        subtitle: "Stay current with the latest extraction improvements."
                    )
                    SettingsCardDivider()
                    SettingsCardActionButton(
                        isDisabled: viewModel.isCheckingForUpdates,
                        action: { Task { await viewModel.checkForSDKUpdates() } }
                    ) {
                        SDKUpdateAction(isChecking: viewModel.isCheckingForUpdates)
                    }
                }

                SettingsCard {
                    SettingsSectionHeader(
                        title: "Developer",
                        subtitle: "Tools for monitoring and debugging."
                    )
                    SettingsCardDivider()
                    VStack(spacing: 10) {
                        StreamingLogsToggle()
                        CopyDiagnosticsButton()
                    }
                }

                AppVersionCard(sdkVersionString: viewModel.sdkVersionString)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(SettingsMacBackground())
        .navigationTitle("Settings")
        .alert(
            viewModel.updateAlertTitle,
            isPresented: $viewModel.showUpdateAlert
        ) {
            Button("OK") { }
        } message: {
            Text(viewModel.updateAlertMessage)
        }
    }
}

struct SettingsMacBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.85),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            SettingsMeshBackdrop()
        }
        .ignoresSafeArea()
    }
}

struct SettingsMeshBackdrop: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.accentColor.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 420, height: 420)
                .blur(radius: 30)
                .offset(x: -180, y: -220)

            Circle()
                .fill(LinearGradient(colors: [Color.blue.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 360, height: 360)
                .blur(radius: 40)
                .offset(x: 220, y: -120)

            Circle()
                .fill(LinearGradient(colors: [Color.mint.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 380, height: 380)
                .blur(radius: 50)
                .offset(x: 40, y: 260)
        }
        .allowsHitTesting(false)
    }
}

struct SettingsHero: View {
    let state: SyncState

    private var headline: String {
        switch state {
        case .idle, .success: "Calmly in sync."
        case .syncing: "Syncing your reading list."
        case .error: "Sync needs attention."
        }
    }

    private var subheadline: String {
        "Tune discovery sources, refresh cached picks, and keep parsing up to date."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Luego")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                SettingsStatusBadge(state: state)
            }

            Text(headline)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.primary)

            Text(subheadline)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .separatorColor).opacity(0.55),
                            Color(nsColor: .separatorColor).opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

struct SettingsCardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.35))
            .frame(height: 1)
    }
}

struct SettingsStatusBadge: View {
    let state: SyncState

    private var badgeText: String {
        switch state {
        case .idle: "Up to date"
        case .syncing: "Syncing"
        case .success: "Just synced"
        case .error: "Needs attention"
        }
    }

    private var badgeSymbol: String {
        switch state {
        case .idle: "checkmark"
        case .syncing: "arrow.triangle.2.circlepath"
        case .success: "checkmark.circle"
        case .error: "exclamationmark.triangle"
        }
    }

    private var badgeColor: Color {
        switch state {
        case .idle, .success: .green
        case .syncing: .blue
        case .error: .red
        }
    }

    var body: some View {
        Label(badgeText, systemImage: badgeSymbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(badgeColor.opacity(0.16))
            )
            .overlay(
                Capsule()
                    .stroke(badgeColor.opacity(0.3))
            )
    }
}

struct SettingsCardActionButton<Label: View>: View {
    let isDisabled: Bool
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.4))
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct DiscoverySettingsCardContent: View {
    @Binding var selectedSource: DiscoverySource
    let onSourceChanged: (DiscoverySource) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(DiscoverySource.allCases.enumerated()), id: \.element) { index, source in
                DiscoverySourceRow(
                    source: source,
                    isSelected: selectedSource == source,
                    onTap: {
                        selectedSource = source
                        onSourceChanged(source)
                    }
                )

                if index != DiscoverySource.allCases.count - 1 {
                    SettingsCardDivider()
                        .opacity(0.7)
                }
            }
        }
    }
}

struct SyncStatusCard: View {
    let state: SyncState
    let lastSyncTime: Date?
    let isSyncing: Bool
    let didSync: Bool
    let onSync: () -> Void

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

    private var statusSymbolName: String {
        switch state {
        case .idle: "checkmark"
        case .syncing: "arrow.triangle.2.circlepath"
        case .success: "checkmark.circle"
        case .error: "exclamationmark.triangle"
        }
    }

    private var formattedTime: String? {
        guard let time = lastSyncTime else { return nil }
        return DateFormatters.time.string(from: time)
    }

    var body: some View {
        VStack(spacing: 10) {
            SyncStatusContent(
                statusText: statusText,
                statusSymbolName: statusSymbolName,
                statusColor: statusColor,
                formattedTime: formattedTime
            )

            ForceReSyncButton(
                isSyncing: isSyncing,
                didSync: didSync,
                onSync: onSync
            )
        }
    }
}

struct AppVersionCard: View {
    let sdkVersionString: String?

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        SettingsCard {
            AppVersionContent(
                appVersionString: appVersionString,
                sdkVersionString: sdkVersionString
            )
        }
    }
}

struct StreamingLogsToggle: View {
    @AppStorage("streaming_logs_enabled") private var isEnabled = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Streaming Logs")
                    .foregroundStyle(.primary)

                Text("Show real-time app logs in the main window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4))
        )
    }
}
#endif

struct CopyDiagnosticsButton: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showCopiedToast = false
    @State private var isLoading = false

    var body: some View {
        Button(action: {
            Task { await copyDiagnostics() }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Copy Diagnostics")
                        .foregroundStyle(.primary)

                    Text("Export device info for troubleshooting sync issues.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if showCopiedToast {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.secondary)
                }
            }
            #if os(macOS)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.4))
            )
            #endif
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private func copyDiagnostics() async {
        isLoading = true
        defer { isLoading = false }

        let diagnostics = await gatherDiagnostics()

        await MainActor.run {
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(diagnostics, forType: .string)
            #else
            UIPasteboard.general.string = diagnostics
            #endif

            showCopiedToast = true
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)

        await MainActor.run {
            showCopiedToast = false
        }
    }

    private func gatherDiagnostics() async -> String {
        var lines: [String] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        lines.append("=== Luego Diagnostics ===")
        lines.append("Generated: \(dateFormatter.string(from: Date()))")
        lines.append("")

        // App Info
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        lines.append("App Bundle ID: \(bundleID)")
        lines.append("App Version: \(version)")
        lines.append("Build Number: \(build)")
        #if os(iOS)
        lines.append("Platform: iOS \(UIDevice.current.systemVersion)")
        #elseif os(macOS)
        lines.append("Platform: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        #endif
        lines.append("")

        // CloudKit Info
        lines.append("CloudKit Container: \(AppConfiguration.cloudKitContainerIdentifier)")

        // Fetch CloudKit info in parallel
        let container = CKContainer(identifier: AppConfiguration.cloudKitContainerIdentifier)

        async let accountStatusTask = fetchAccountStatus(for: container)
        async let subscriptionsTask = fetchSubscriptions(for: container)

        let (accountStatus, subscriptions) = await (accountStatusTask, subscriptionsTask)

        lines.append("iCloud Account Status: \(accountStatus)")
        lines.append("Active CloudKit Subscriptions: \(subscriptions.count)")
        for sub in subscriptions {
            lines.append("  - \(sub.subscriptionID) (type: \(sub.subscriptionType.rawValue))")
        }
        lines.append("")

        let articleIdentityLines = await MainActor.run {
            articleIdentitySnapshotLines()
        }
        lines.append(contentsOf: articleIdentityLines)
        lines.append("")

        // Recent Logs
        let logDateFormatter = DateFormatter()
        logDateFormatter.dateFormat = "HH:mm:ss"

        lines.append("--- Recent Logs (last 500 entries) ---")
        let recentLogs = LogStream.shared.entries.suffix(500)
        if recentLogs.isEmpty {
            lines.append("No logs captured yet.")
        } else {
            for entry in recentLogs {
                let time = logDateFormatter.string(from: entry.timestamp)
                lines.append("[\(time)] [\(entry.category)] [\(entry.level.rawValue)] \(entry.message)")
            }
        }

        return lines.joined(separator: "\n")
    }

    @MainActor
    private func articleIdentitySnapshotLines() -> [String] {
        var lines: [String] = ["--- Article Identity Snapshot (id | url) ---"]

        do {
            let articles = try modelContext.fetch(FetchDescriptor<Article>())
            let sortedArticles = articles.sorted { lhs, rhs in
                let lhsURL = lhs.url.absoluteString
                let rhsURL = rhs.url.absoluteString

                if lhsURL == rhsURL {
                    return lhs.id.uuidString < rhs.id.uuidString
                }

                return lhsURL < rhsURL
            }

            lines.append("Article Identity Count: \(sortedArticles.count)")

            if sortedArticles.isEmpty {
                lines.append("No local articles.")
            } else {
                for article in sortedArticles {
                    lines.append("\(article.id.uuidString) | \(article.url.absoluteString)")
                }
            }
        } catch {
            lines.append("Failed to fetch local articles: \(error.localizedDescription)")
        }

        return lines
    }

    private func fetchAccountStatus(for container: CKContainer) async -> String {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available: return "available"
            case .noAccount: return "noAccount"
            case .restricted: return "restricted"
            case .couldNotDetermine: return "couldNotDetermine"
            case .temporarilyUnavailable: return "temporarilyUnavailable"
            @unknown default: return "unknown(\(status.rawValue))"
            }
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }

    private func fetchSubscriptions(for container: CKContainer) async -> [CKSubscription] {
        do {
            return try await container.privateCloudDatabase.allSubscriptions()
        } catch {
            return []
        }
    }
}

struct ForceReSyncButton: View {
    let isSyncing: Bool
    let didSync: Bool
    let onSync: () -> Void

    var body: some View {
        Button(action: onSync) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isSyncing ? "Syncing..." : "Force Re-sync")
                        .foregroundStyle(.primary)

                    Text("Push all local articles to iCloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSyncing {
                    ProgressView()
                        .controlSize(.regular)
                } else if didSync {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "arrow.clockwise.icloud")
                        .foregroundStyle(.secondary)
                }
            }
            #if os(macOS)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.4))
            )
            #endif
        }
        .buttonStyle(.plain)
        .disabled(isSyncing)
    }
}

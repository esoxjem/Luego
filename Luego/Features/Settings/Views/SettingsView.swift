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

struct IOSSettingsRow<TitleAccessory: View, Trailing: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var showsIcon: Bool = true
    var iconColor: Color = .accentColor
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
        iconColor: Color = .accentColor,
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
                iconColor: .accentColor
            ) {
                if let websiteURL = source.websiteURL {
                    SourceWebsiteLinkButton(url: websiteURL, openURL: openURL)
                }
            } trailing: {
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
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
            #if os(macOS)
            DiscoverySourceRow(
                source: source,
                isSelected: selectedSource == source,
                onTap: {
                    selectedSource = source
                    onSourceChanged(source)
                }
            )
            #else
            IOSDiscoverySourceRow(
                source: source,
                isSelected: selectedSource == source,
                onTap: {
                    selectedSource = source
                    onSourceChanged(source)
                }
            )
            #endif
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

    private var accessibilityStatusValue: String {
        if let timeText = formattedTime {
            return "\(statusText). Last synced at \(timeText)"
        }
        return statusText
    }

    private var statusSubtitle: String {
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

    private var accessibilityStatusValue: String {
        if let timeText = formattedTime {
            return "\(statusText). Last synced at \(timeText)"
        }
        return statusText
    }

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
                Text("Last synced at \(timeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("iCloud Sync")
        .accessibilityValue(accessibilityStatusValue)
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
            #if os(macOS)
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
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.4))
            )
            #else
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
            ArticleIdentitySnapshotFormatter.lines {
                try modelContext.fetch(FetchDescriptor<Article>())
            }
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

enum ArticleIdentitySnapshotFormatter {
    static func lines(for articles: [Article]) -> [String] {
        let sortedArticles = articles.sorted {
            let lhsURL = $0.url.absoluteString
            let rhsURL = $1.url.absoluteString

            if lhsURL == rhsURL {
                return $0.id.uuidString < $1.id.uuidString
            }

            return lhsURL < rhsURL
        }

        return articleIdentitySnapshotLines(sortedArticles)
    }

    static func lines(fetcher: () throws -> [Article]) -> [String] {
        do {
            return lines(for: try fetcher())
        } catch {
            return [
                "--- Article Identity Snapshot (id | url) ---",
                "Failed to fetch local articles: \(error.localizedDescription)"
            ]
        }
    }

    private static func articleIdentitySnapshotLines(_ sortedArticles: [Article]) -> [String] {
        var lines = ["--- Article Identity Snapshot (id | url) ---"]
        lines.append("Article Identity Count: \(sortedArticles.count)")

        if sortedArticles.isEmpty {
            lines.append("No local articles.")
            return lines
        }

        for article in sortedArticles {
            lines.append("\(article.id.uuidString) | \(article.url.absoluteString)")
        }

        return lines
    }
}

struct ForceReSyncButton: View {
    let isSyncing: Bool
    let didSync: Bool
    let onSync: () -> Void

    var body: some View {
        Button(action: onSync) {
            #if os(macOS)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isSyncing ? "Syncing..." : "Force Re-sync")
                        .foregroundStyle(.primary)

                    Text("Push local articles to iCloud")
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
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.4))
            )
            #else
            IOSSettingsRow(
                title: isSyncing ? "Syncing..." : "Force Re-sync",
                subtitle: "Push local articles to iCloud",
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
            #endif
        }
        .buttonStyle(.plain)
        .disabled(isSyncing)
    }
}

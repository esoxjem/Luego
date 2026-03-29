import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    var syncStatusObserver: SyncStatusObserver?
    @Environment(SyncStatusObserver.self) private var envSyncStatusObserver: SyncStatusObserver?
    @Environment(\.dismiss) private var dismiss

    private var resolvedObserver: SyncStatusObserver? {
        syncStatusObserver ?? envSyncStatusObserver
    }

    var body: some View {
        Group {
            #if os(macOS)
            SettingsMacLayout(
                viewModel: viewModel,
                state: resolvedObserver?.state ?? .idle,
                lastSyncTime: resolvedObserver?.lastSyncTime,
                syncStatusObserver: resolvedObserver
            )
            #else
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

struct DiscoverySourceRow: View {
    let source: DiscoverySource
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        #if os(macOS)
        Button(action: onTap) {
            SettingsControlSurface(isSelected: isSelected) {
                HStack(spacing: 14) {
                    SettingsRowGlyph(symbolName: "safari", isSelected: isSelected)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(source.displayName)
                                .font(.nunito(.subheadline, weight: .semibold))
                                .foregroundStyle(.primary)

                            if let websiteURL = source.websiteURL {
                                SourceWebsiteLinkButton(url: websiteURL, openURL: openURL)
                            }
                        }

                        Text(source.descriptionText)
                            .font(.nunito(.footnote))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.mascotPurpleInk)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        #else
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
                        .foregroundStyle(Color.regularSelectionInk)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #endif
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

#if os(macOS)
struct SettingsSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.lora(.title3, weight: .semibold))
            Text(subtitle)
                .font(.nunito(.footnote))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420, alignment: .leading)
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
            SettingsRowGlyph(symbolName: systemImage, isSelected: showsCheckmark)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.nunito(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.nunito(.footnote))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else if showsCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.mascotPurpleInk)
            } else {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SyncStatusContent: View {
    let statusText: String
    let statusSymbolName: String
    let statusColor: Color
    let formattedTime: String?
    let emphasizesGlyph: Bool

    private var accessibilityStatusValue: String {
        if let timeText = formattedTime {
            return "\(statusText). Last synced at \(timeText)"
        }
        return statusText
    }

    var body: some View {
        SettingsControlSurface {
            HStack(spacing: 14) {
                SettingsRowGlyph(symbolName: "icloud", isSelected: emphasizesGlyph)

                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud Sync")
                        .font(.nunito(.subheadline, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let timeText = formattedTime {
                        Text("Last synced at \(timeText)")
                            .font(.nunito(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: statusSymbolName)
                        .font(.system(size: 11, weight: .semibold))
                    Text(statusText)
                        .font(.nunito(.footnote, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxWidth: 180, alignment: .trailing)
                .foregroundStyle(statusColor)
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
    let syncStatusObserver: SyncStatusObserver?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
                        syncStatusObserver: syncStatusObserver,
                        isSyncing: viewModel.isForceSyncing,
                        didSync: viewModel.didForceSync,
                        repairErrorMessage: viewModel.forceSyncErrorMessage,
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
                        CopyDiagnosticsButton(
                            viewModel: viewModel,
                            syncStatusObserver: syncStatusObserver
                        )
                    }
                }

                AppVersionCard(sdkVersionString: viewModel.sdkVersionString)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(SettingsMacBackground())
        .navigationTitle("Settings")
        .tint(Color.regularSelectionInk)
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
            Color.paperCream
            MacAppMeshBackdrop()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.5),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 340, height: 340)
                .blur(radius: 28)
                .offset(x: 190, y: 120)
        }
        .ignoresSafeArea()
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                SettingsHeroGlyph()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Luego")
                        .font(.nunito(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.58))

                    HStack(alignment: .center, spacing: 10) {
                        Text("Settings")
                            .font(.lora(.title2, weight: .semibold))
                            .foregroundStyle(.primary)

                        SettingsStatusBadge(state: state)
                    }

                    Text(headline)
                        .font(.lora(.title3, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(subheadline)
                        .font(.nunito(.body))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 420, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.62),
                            Color.regularOutline.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 14)
    }
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.62),
                            Color.regularOutline.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.07), radius: 22, x: 0, y: 14)
    }
}

struct SettingsCardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.22))
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
            .font(.nunito(.caption, weight: .semibold))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(badgeColor.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(badgeColor.opacity(0.24))
            )
    }
}

struct SettingsCardActionButton<Label: View>: View {
    let isDisabled: Bool
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            SettingsControlSurface {
                label
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct SettingsControlSurface<Content: View>: View {
    var isSelected = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundStyle)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
    }

    private var backgroundStyle: some ShapeStyle {
        LinearGradient(
            colors: isSelected
                ? [Color.mascotPurple.opacity(0.28), Color.white.opacity(0.75)]
                : [Color.white.opacity(0.82), Color.mascotPurple.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderColor: Color {
        isSelected
            ? Color.mascotPurpleInk.opacity(0.22)
            : Color.regularOutline.opacity(0.65)
    }
}

struct SettingsRowGlyph: View {
    let symbolName: String
    var isSelected = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isSelected
                            ? [Color.mascotPurple.opacity(0.92), Color.mascotPurpleInk.opacity(0.78)]
                            : [Color.white.opacity(0.92), Color.mascotPurple.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.mascotPurpleInk)
        }
        .frame(width: 34, height: 34)
    }
}

struct SettingsHeroGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.mascotPurple.opacity(0.92),
                            Color.mascotPurpleInk.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 46, height: 46)
        .shadow(color: Color.mascotPurpleInk.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}

struct DiscoverySettingsCardContent: View {
    @Binding var selectedSource: DiscoverySource
    let onSourceChanged: (DiscoverySource) -> Void

    var body: some View {
        VStack(spacing: 12) {
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
                        .opacity(0.45)
                        .padding(.horizontal, 6)
                }
            }
        }
    }
}

struct SyncStatusCard: View {
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
                formattedTime: formattedTime,
                emphasizesGlyph: state != .idle
            )

            if syncStatusObserver?.cloudKitNeedsAttention == true,
               let diagnosticSummary = syncStatusObserver?.cloudKitDiagnosticSummary {
                Text(diagnosticSummary)
                    .font(.nunito(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if syncStatusObserver?.cloudKitNeedsAttention == true,
               let diagnosticHint = syncStatusObserver?.cloudKitDiagnosticHint {
                Text(diagnosticHint)
                    .font(.nunito(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForceReSyncButton(
                isSyncing: isSyncing,
                didSync: didSync,
                onSync: onSync
            )

            if let repairErrorMessage {
                Text(repairErrorMessage)
                    .font(.nunito(.footnote))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
        .opacity(0.88)
    }
}

struct StreamingLogsToggle: View {
    @AppStorage("streaming_logs_enabled") private var isEnabled = false

    var body: some View {
        SettingsControlSurface {
            HStack(spacing: 14) {
                SettingsRowGlyph(symbolName: "waveform", isSelected: isEnabled)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Streaming Logs")
                        .font(.nunito(.subheadline, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("Show real-time app logs in the main window.")
                        .font(.nunito(.footnote))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }
}
#endif

struct CopyDiagnosticsButton: View {
    let viewModel: SettingsViewModel
    let syncStatusObserver: SyncStatusObserver?
    @State private var showCopiedToast = false
    @State private var isLoading = false

    var body: some View {
        Button(action: {
            Task { await copyDiagnostics() }
        }) {
            #if os(macOS)
            SettingsControlSurface {
                HStack(spacing: 14) {
                    SettingsRowGlyph(symbolName: "doc.on.doc", isSelected: showCopiedToast)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Copy Diagnostics")
                            .font(.nunito(.subheadline, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Export device info for troubleshooting sync issues.")
                            .font(.nunito(.footnote))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else if showCopiedToast {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.mascotPurpleInk)
                    } else {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
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

        let diagnostics = await viewModel.gatherDiagnostics(syncStatusObserver: syncStatusObserver)

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
}

struct ForceReSyncButton: View {
    let isSyncing: Bool
    let didSync: Bool
    let onSync: () -> Void

    var body: some View {
        Button(action: onSync) {
            #if os(macOS)
            SettingsControlSurface {
                HStack(spacing: 14) {
                    SettingsRowGlyph(symbolName: "arrow.clockwise.icloud", isSelected: didSync || isSyncing)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isSyncing ? "Repairing Sync..." : "Repair Sync")
                            .font(.nunito(.subheadline, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Fetch from iCloud, resend local changes, and reconcile drift")
                            .font(.nunito(.footnote))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else if didSync {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.mascotPurpleInk)
                    } else {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            #else
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
            #endif
        }
        .buttonStyle(.plain)
        .disabled(isSyncing)
    }
}

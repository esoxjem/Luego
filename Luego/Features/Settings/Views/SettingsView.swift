import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            DiscoverySettingsSection(
                selectedSource: $viewModel.selectedDiscoverySource,
                onSourceChanged: viewModel.updateDiscoverySource
            )

            RefreshArticlePoolSection(
                didRefresh: viewModel.didRefreshPool,
                onRefresh: viewModel.refreshArticlePool
            )

            AppVersionSection()
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct DiscoverySettingsSection: View {
    @Binding var selectedSource: DiscoverySource
    let onSourceChanged: (DiscoverySource) -> Void

    var body: some View {
        Section {
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
        } header: {
            Text("Discovery")
        } footer: {
            Text("Choose a source to discovering new articles.")
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

struct AppVersionSection: View {
    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        Section {
            HStack {
                Spacer()
                Text(versionString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }
}

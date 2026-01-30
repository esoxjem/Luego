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

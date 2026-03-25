import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct AddArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var hasInitializedPresentation = false
    @FocusState private var isURLFieldFocused: Bool
    @Bindable var viewModel: ArticleListViewModel
    let existingArticles: [Article]

    private var trimmedURLText: String {
        urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedURLText.isEmpty && !viewModel.isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            AddArticleSurface {
                VStack(alignment: .leading, spacing: 24) {
                    AddArticleHeader()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "link")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.primary.opacity(0.48))
                                .frame(width: 16)

                            TextField("", text: $urlText)
                                .accessibilityIdentifier("addArticle.urlField")
                                .accessibilityLabel("URL")
                                .textFieldStyle(.plain)
                                .font(.nunito(.body))
                                .textContentType(.URL)
                                .focused($isURLFieldFocused)
                                #if os(iOS)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .submitLabel(.done)
                                #endif
                                .autocorrectionDisabled()
                                .onSubmit {
                                    Task {
                                        await saveArticle()
                                    }
                                }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(fieldBackground)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(fieldBorderColor, lineWidth: isURLFieldFocused ? 1.5 : 1)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            AddArticleMessageRow(
                                symbolName: "exclamationmark.circle.fill",
                                tint: Color.red.opacity(0.85),
                                message: errorMessage
                            )
                        } else if viewModel.isLoading {
                            AddArticleLoadingRow()
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .accessibilityIdentifier("addArticle.cancel")
                        .keyboardShortcut(.cancelAction)
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isLoading)

                        Spacer(minLength: 0)

                        Button {
                            Task {
                                await saveArticle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                }

                                Text(viewModel.isLoading ? "Saving…" : "Save")
                            }
                            .frame(minWidth: 96)
                        }
                        .accessibilityIdentifier("addArticle.save")
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.regularSelectionInk)
                        .disabled(!canSave)
                    }
                }
            }
            .frame(maxWidth: 500)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.regularPanelBackground)
        .accessibilityIdentifier("addArticle.sheet")
        .onAppear {
            initializePresentationIfNeeded()
        }
        .onChange(of: urlText) { _, _ in
            if viewModel.errorMessage != nil {
                viewModel.clearError()
            }
        }
    }

    private var fieldBackground: Color {
        if viewModel.errorMessage != nil {
            return Color.red.opacity(0.04)
        }

        if isURLFieldFocused {
            return Color.white.opacity(0.96)
        }

        return Color.white.opacity(0.82)
    }

    private var fieldBorderColor: Color {
        if viewModel.errorMessage != nil {
            return Color.red.opacity(0.3)
        }

        if isURLFieldFocused {
            return Color.regularSelectionInk.opacity(0.32)
        }

        return Color.regularOutline.opacity(0.9)
    }

    private func saveArticle() async {
        guard canSave else { return }

        await viewModel.addArticle(from: trimmedURLText, existingArticles: existingArticles)

        if viewModel.errorMessage == nil {
            dismiss()
        }
    }

    private func initializePresentationIfNeeded() {
        guard !hasInitializedPresentation else { return }

        hasInitializedPresentation = true
        autoPrefillURLFromClipboardIfNeeded()
        isURLFieldFocused = true
    }

    private func autoPrefillURLFromClipboardIfNeeded() {
        guard urlText.isEmpty,
              let clipboardURLText = validatedClipboardURLText() else {
            return
        }

        urlText = clipboardURLText
    }

    private func trimmedClipboardText() -> String? {
        #if os(macOS)
        let clipboardText = NSPasteboard.general.string(forType: .string)
        #elseif os(iOS)
        let clipboardText = UIPasteboard.general.string
        #endif

        guard let clipboardText else { return nil }

        let trimmedClipboardText = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedClipboardText.isEmpty ? nil : trimmedClipboardText
    }

    private func validatedClipboardURLText() -> String? {
        guard let clipboardText = trimmedClipboardText() else {
            return nil
        }

        let urlStringWithScheme: String
        if clipboardText.hasPrefix("http://") || clipboardText.hasPrefix("https://") {
            urlStringWithScheme = clipboardText
        } else {
            urlStringWithScheme = "https://" + clipboardText
        }

        guard let url = URL(string: urlStringWithScheme),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host() != nil else {
            return nil
        }

        return clipboardText
    }
}

private struct AddArticleHeader: View {
    var body: some View {
        Text("Add Article")
            .font(.lora(.title3, weight: .semibold))
    }
}

private struct AddArticleLoadingRow: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("Fetching article details…")
                .font(.nunito(.footnote))
                .foregroundStyle(Color.primary.opacity(0.62))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AddArticleMessageRow: View {
    let symbolName: String
    let tint: Color
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            Text(message)
                .font(.nunito(.footnote))
                .foregroundStyle(Color.primary.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }
}

private struct AddArticleSurface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.regularOutline.opacity(0.85), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
    }
}

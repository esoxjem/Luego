import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct AddArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
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
                VStack(alignment: .leading, spacing: 20) {
                    AddArticleHeader()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Article URL")
                            .font(.nunito(.subheadline, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.82))

                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.mascotPurpleInk)
                                .frame(width: 18)

                            TextField("https://example.com/article", text: $urlText)
                                .accessibilityIdentifier("addArticle.urlField")
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

                            Button("Paste") {
                                pasteFromClipboard()
                            }
                            .buttonStyle(.plain)
                            .font(.nunito(.subheadline, weight: .semibold))
                            .foregroundStyle(Color.mascotPurpleInk)
                            .disabled(viewModel.isLoading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(fieldBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(fieldBorderColor, lineWidth: 1)
                        }

                        Text("Paste a link and Luego will fetch the title and preview for you.")
                            .font(.nunito(.footnote))
                            .foregroundStyle(.secondary)

                        if let errorMessage = viewModel.errorMessage {
                            AddArticleMessageRow(
                                symbolName: "exclamationmark.triangle.fill",
                                tint: Color.red.opacity(0.9),
                                message: errorMessage
                            )
                        } else if viewModel.isLoading {
                            AddArticleLoadingRow()
                        }
                    }

                    Divider()
                        .opacity(0.45)

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .accessibilityIdentifier("addArticle.cancel")
                        .keyboardShortcut(.cancelAction)
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
                        .tint(Color.mascotPurple)
                        .disabled(!canSave)
                    }
                }
            }
            .frame(maxWidth: 540)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dialogBackground)
        .accessibilityIdentifier("addArticle.sheet")
        .task {
            isURLFieldFocused = true
        }
        .onChange(of: urlText) { _, _ in
            if viewModel.errorMessage != nil {
                viewModel.clearError()
            }
        }
    }

    private var fieldBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(0.92),
                Color.mascotPurple.opacity(0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fieldBorderColor: Color {
        if viewModel.errorMessage != nil {
            return Color.red.opacity(0.45)
        }

        if isURLFieldFocused {
            return Color.mascotPurpleInk.opacity(0.38)
        }

        return Color.regularOutline.opacity(0.85)
    }

    @ViewBuilder
    private var dialogBackground: some View {
        ZStack {
            Color.regularPanelBackground

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.mascotPurple.opacity(0.18),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 18)
                .offset(x: -120, y: -100)

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
                .frame(width: 320, height: 320)
                .blur(radius: 30)
                .offset(x: 150, y: 120)
        }
        .ignoresSafeArea()
    }

    private func saveArticle() async {
        guard canSave else { return }

        await viewModel.addArticle(from: trimmedURLText, existingArticles: existingArticles)

        if viewModel.errorMessage == nil {
            dismiss()
        }
    }

    private func pasteFromClipboard() {
        #if os(macOS)
        if let clipboardText = NSPasteboard.general.string(forType: .string) {
            urlText = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #elseif os(iOS)
        if let clipboardText = UIPasteboard.general.string {
            urlText = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif

        if viewModel.errorMessage != nil {
            viewModel.clearError()
        }

        isURLFieldFocused = true
    }
}

private struct AddArticleHeader: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.mascotPurple.opacity(0.9),
                                Color.mascotPurpleInk.opacity(0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                Text("Add Article")
                    .font(.lora(.title3, weight: .semibold))

                Text("Paste a link to save it to your reading list.")
                    .font(.nunito(.body))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AddArticleLoadingRow: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("Fetching article details…")
                .font(.nunito(.footnote, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.72))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.45))
        )
    }
}

private struct AddArticleMessageRow: View {
    let symbolName: String
    let tint: Color
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)

            Text(message)
                .font(.nunito(.footnote, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.76))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        }
    }
}

private struct AddArticleSurface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.regularOutline.opacity(0.9)
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

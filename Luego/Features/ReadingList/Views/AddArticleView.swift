import SwiftUI

#if os(iOS)
import UIKit
import UniformTypeIdentifiers
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

                            TextField("", text: $urlText, axis: .horizontal)
                                .accessibilityIdentifier("addArticle.urlField")
                                .accessibilityLabel("URL")
                                .textFieldStyle(.plain)
                                .font(.nunito(.body))
                                .textContentType(.URL)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
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

                            addArticlePasteControl
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

    @ViewBuilder
    private var addArticlePasteControl: some View {
        #if os(iOS)
        AddArticleInlinePasteAffordance {
            AddArticlePasteControl(onPaste: pasteClipboardText)
        }
        #else
        AddArticleInlinePasteAffordance {
            PasteButton(payloadType: String.self) { strings in
                pasteClipboardText(strings)
            }
            .accessibilityIdentifier("addArticle.paste")
            .accessibilityLabel("Paste from Clipboard")
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .controlSize(.small)
            .frame(width: 28, height: 28)
            .opacity(0.015)
        }
        #endif
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
        isURLFieldFocused = true
    }

    private func pasteClipboardText(_ strings: [String]) {
        guard let clipboardText = strings
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            return
        }

        urlText = clipboardText
        isURLFieldFocused = true
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

private struct AddArticleInlinePasteAffordance<Control: View>: View {
    @ViewBuilder let control: Control

    var body: some View {
        ZStack {
            Image(systemName: "list.clipboard")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.regularSelectionInk)
                .frame(width: 28, height: 28)

            control
        }
        .frame(width: 28, height: 28)
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

#if os(iOS)
private struct AddArticlePasteControl: UIViewRepresentable {
    let onPaste: ([String]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPaste: onPaste)
    }

    func makeUIView(context: Context) -> UIPasteControl {
        let configuration = UIPasteControl.Configuration()
        configuration.displayMode = .iconOnly
        configuration.cornerStyle = .fixed
        configuration.cornerRadius = 10
        configuration.baseForegroundColor = UIColor(Color.regularSelectionInk)
        configuration.baseBackgroundColor = .clear

        let pasteControl = UIPasteControl(configuration: configuration)
        pasteControl.target = context.coordinator
        pasteControl.accessibilityIdentifier = "addArticle.paste"
        pasteControl.accessibilityLabel = "Paste from Clipboard"
        pasteControl.backgroundColor = .clear
        pasteControl.alpha = 0.015

        return pasteControl
    }

    func updateUIView(_ uiView: UIPasteControl, context: Context) {
        context.coordinator.onPaste = onPaste
        uiView.target = context.coordinator
        uiView.alpha = 0.015
    }

    final class Coordinator: NSObject, UIPasteConfigurationSupporting {
        var onPaste: ([String]) -> Void
        var pasteConfiguration: UIPasteConfiguration?

        init(onPaste: @escaping ([String]) -> Void) {
            self.onPaste = onPaste
            self.pasteConfiguration = UIPasteConfiguration(
                acceptableTypeIdentifiers: [
                    UTType.url.identifier,
                    UTType.plainText.identifier
                ]
            )
        }

        func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
            itemProviders.contains { provider in
                provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ||
                provider.canLoadObject(ofClass: NSString.self)
            }
        }

        func paste(itemProviders: [NSItemProvider]) {
            loadFirstText(from: itemProviders)
        }

        private func loadFirstText(from itemProviders: [NSItemProvider]) {
            guard let itemProvider = itemProviders.first(where: { provider in
                provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ||
                provider.canLoadObject(ofClass: NSString.self)
            }) else {
                return
            }

            if itemProvider.canLoadObject(ofClass: NSString.self) {
                itemProvider.loadObject(ofClass: NSString.self) { string, _ in
                    guard let clipboardText = string as? NSString else { return }
                    let pastedText = clipboardText as String

                    Task { @MainActor in
                        self.onPaste([pastedText])
                    }
                }
                return
            }

            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                let clipboardText = (item as? URL)?.absoluteString ?? (item as? Data).flatMap {
                    String(data: $0, encoding: .utf8)
                }

                guard let clipboardText else { return }
                let pastedText = clipboardText

                Task { @MainActor in
                    self.onPaste([pastedText])
                }
            }
        }
    }
}
#endif

import SwiftUI

struct AddArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @Bindable var viewModel: ArticleListViewModel
    let existingArticles: [Article]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter URL", text: $urlText)
                        .accessibilityIdentifier("addArticle.urlField")
                        .textContentType(.URL)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text("Article URL")
                } footer: {
                    Text("Paste or type the URL of the article you want to save")
                }

                if viewModel.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Add Article")
            .accessibilityIdentifier("addArticle.sheet")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("addArticle.cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.addArticle(from: urlText, existingArticles: existingArticles)

                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .accessibilityIdentifier("addArticle.save")
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
}

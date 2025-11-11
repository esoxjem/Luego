//
//  AddArticleView.swift
//  Luego
//
//  Created by Claude on 2025-11-10.
//

import SwiftUI
import SwiftData

struct AddArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @Bindable var viewModel: ArticleListViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter URL", text: $urlText)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.addArticle(from: urlText)

                            // Dismiss if successful (no error)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Article.self, configurations: config)
    let viewModel = ArticleListViewModel(modelContext: container.mainContext)

    return AddArticleView(viewModel: viewModel)
}

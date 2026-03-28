//
//  ArticleListView.swift
//  Luego
//
//  Created by Claude Code on 11/12/25.
//

import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#endif

struct ArticleListView: View {
    @Environment(\.diContainer) private var diContainer
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Article.savedDate, order: .reverse) private var allArticles: [Article]
    @State private var viewModel: ArticleListViewModel?
    @State private var discoveryViewModel: DiscoveryViewModel?
    @State private var showingAddArticle = false
    @State private var showingDiscovery = false
    @State private var showingSettings = false
    let filter: ArticleFilter
    let shouldAnimateEmptyStateOnFirstAppearance: Bool
    let onEmptyStateAnimationConsumed: () -> Void

    private var filteredArticles: [Article] {
        filter.filtered(allArticles)
    }

    init(
        filter: ArticleFilter,
        shouldAnimateEmptyStateOnFirstAppearance: Bool = false,
        onEmptyStateAnimationConsumed: @escaping () -> Void = {}
    ) {
        self.filter = filter
        self.shouldAnimateEmptyStateOnFirstAppearance = shouldAnimateEmptyStateOnFirstAppearance
        self.onEmptyStateAnimationConsumed = onEmptyStateAnimationConsumed
    }

    var body: some View {
        presentingAddArticle(
            ArticleListContent(
                articles: filteredArticles,
                viewModel: viewModel,
                diContainer: diContainer,
                filter: filter,
                onDiscover: { showingDiscovery = true },
                shouldAnimateEmptyStateOnFirstAppearance: shouldAnimateEmptyStateOnFirstAppearance,
                onEmptyStateAnimationConsumed: onEmptyStateAnimationConsumed
            )
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if filter == .readingList {
                        Button {
                            showingDiscovery = true
                        } label: {
                            Image(systemName: "die.face.5")
                        }
                        .accessibilityLabel("Inspire Me")
                    }
                    Button {
                        presentAddArticle()
                    } label: {
                        Image(systemName: "plus")
                    }
                    #if os(iOS)
                    .popover(
                        isPresented: compactAddArticlePopoverBinding,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .top
                    ) {
                        compactAddArticleDestination
                    }
                    #endif
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            #if os(iOS)
            .onAppear {
                configureNavigationBarAppearance()
            }
            #endif
        )
        .sheet(isPresented: $showingSettings) {
            if let container = diContainer {
                NavigationStack {
                    SettingsView(viewModel: container.makeSettingsViewModel())
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingDiscovery) {
            if let vm = discoveryViewModel {
                DiscoveryReaderView(viewModel: vm)
            }
        }
        #else
        .sheet(isPresented: $showingDiscovery) {
            if let vm = discoveryViewModel {
                DiscoveryReaderView(viewModel: vm)
                    .frame(minWidth: 600, minHeight: 500)
            }
        }
        #endif
        .onChange(of: showingDiscovery) { _, isShowing in
            if isShowing, discoveryViewModel == nil, let container = diContainer {
                discoveryViewModel = container.makeDiscoveryViewModel()
            } else if !isShowing {
                discoveryViewModel = nil
            }
        }
        .task {
            initializeViewModelIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task {
                await handleScenePhaseChange(newPhase)
            }
        }
    }

    private func initializeViewModelIfNeeded() {
        guard viewModel == nil, let container = diContainer else { return }
        viewModel = container.makeArticleListViewModel()
    }

    private func presentAddArticle() {
        showingAddArticle = true
    }

    @ViewBuilder
    private func presentingAddArticle<Content: View>(_ content: Content) -> some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            content
        } else {
            content
                .sheet(isPresented: $showingAddArticle) {
                    addArticleDestination
                }
        }
        #else
        content
            .sheet(isPresented: $showingAddArticle) {
                addArticleDestination
            }
        #endif
    }

    @ViewBuilder
    private var addArticleDestination: some View {
        if let viewModel {
            AddArticleView(viewModel: viewModel, existingArticles: allArticles)
        }
    }

    #if os(iOS)
    private var compactAddArticlePopoverBinding: Binding<Bool> {
        Binding(
            get: {
                horizontalSizeClass == .compact && showingAddArticle
            },
            set: { newValue in
                showingAddArticle = newValue
            }
        )
    }

    @ViewBuilder
    private var compactAddArticleDestination: some View {
        addArticleDestination
            .presentationCompactAdaptation(.popover)
    }
    #endif

    private func handleScenePhaseChange(_ phase: ScenePhase) async {
        guard phase == .active, let viewModel else { return }
        await viewModel.syncSharedArticles()
    }

    private var navigationTitle: String {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            return filter.navigationTitle
        }
        #endif

        return filter.title
    }

    #if os(iOS)
    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        if horizontalSizeClass == .compact {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(red: 250 / 255, green: 248 / 255, blue: 241 / 255, alpha: 1)
        }
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [
            .font: serifBoldLargeTitleFont,
            .foregroundColor: UIColor.label
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    private var serifBoldLargeTitleFont: UIFont {
        .lora(forTextStyle: .largeTitle)
    }
    #endif
}

struct ArticleListContent: View {
    let articles: [Article]
    let viewModel: ArticleListViewModel?
    let diContainer: DIContainer?
    let filter: ArticleFilter
    let onDiscover: () -> Void
    let shouldAnimateEmptyStateOnFirstAppearance: Bool
    let onEmptyStateAnimationConsumed: () -> Void

    var body: some View {
        Group {
            if let viewModel {
                if articles.isEmpty {
                    ArticleListEmptyState(
                        onDiscover: onDiscover,
                        filter: filter,
                        shouldAnimateCopyOnFirstAppearance: filter == .readingList && shouldAnimateEmptyStateOnFirstAppearance,
                        onCopyAnimationConsumed: onEmptyStateAnimationConsumed
                    )
                } else {
                    ArticleList(articles: articles, viewModel: viewModel, diContainer: diContainer, filter: filter)
                }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paperCream)
    }
}

struct ArticleList: View {
    let articles: [Article]
    let viewModel: ArticleListViewModel
    let diContainer: DIContainer?
    let filter: ArticleFilter

    private var swipeActions: ArticleSwipeActions {
        ArticleSwipeActions(filter: filter, viewModel: viewModel)
    }

    var body: some View {
        List {
            ForEach(articles) { article in
                NavigationLink {
                    ArticleReaderDestination(article: article, diContainer: diContainer)
                } label: {
                    ArticleRowView(article: article)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    swipeActions.favoriteButton(for: article)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    swipeActions.archiveButton(for: article)
                    swipeActions.deleteButton(for: article)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct ArticleReaderDestination: View {
    let article: Article
    let diContainer: DIContainer?

    var body: some View {
        if let container = diContainer {
            let readerViewModel = container.makeReaderViewModel(article: article)
            ReaderView(viewModel: readerViewModel)
        }
    }
}

struct ArticleListEmptyState: View {
    let onDiscover: () -> Void
    let filter: ArticleFilter
    let onCopyAnimationConsumed: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var shouldAnimateCopy: Bool
    @State private var hasConsumedLaunchAnimation = false

    init(
        onDiscover: @escaping () -> Void,
        filter: ArticleFilter,
        shouldAnimateCopyOnFirstAppearance: Bool = false,
        onCopyAnimationConsumed: @escaping () -> Void = {}
    ) {
        self.onDiscover = onDiscover
        self.filter = filter
        self.onCopyAnimationConsumed = onCopyAnimationConsumed
        _shouldAnimateCopy = State(initialValue: shouldAnimateCopyOnFirstAppearance)
    }

    @ViewBuilder
    private var artwork: some View {
        if filter == .readingList {
            Image("Kike")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
        } else {
            Image(systemName: filter.emptyStateIcon)
                .font(.system(size: 64))
                .foregroundStyle(filter.emptyStateIconColor)
        }
    }

    private var verticalOffset: CGFloat {
        #if os(iOS)
        horizontalSizeClass == .compact ? -52 : 0
        #else
        0
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    artwork
                    AnimatedEmptyStateTitle(
                        text: filter.emptyStateTitle,
                        animateOnAppear: shouldAnimateCopy
                    )
                }
                .padding(.bottom, 12)

                AnimatedNarrativeText(
                    lines: filter.emptyStateLines,
                    animateOnAppear: shouldAnimateCopy
                )

                if filter == .readingList {
                    Button("Inspire Me") {
                        onDiscover()
                    }
                    .font(.nunito(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
                    #if os(iOS)
                    .buttonStyle(.glassProminent)
                    #else
                    .buttonStyle(.borderedProminent)
                    #endif
                    .buttonBorderShape(.capsule)
                    .tint(.mascotPurple)
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                    }
                    .padding(.top, 24)
                }
            }
            .frame(maxWidth: 320)
            .padding(.horizontal, 24)
        }
        .task {
            guard shouldAnimateCopy, !hasConsumedLaunchAnimation else { return }
            hasConsumedLaunchAnimation = true
            onCopyAnimationConsumed()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: verticalOffset)
        .background(Color.paperCream)
        .onDisappear {
            shouldAnimateCopy = false
        }
    }
}

struct AnimatedEmptyStateTitle: View {
    let text: String
    let animateOnAppear: Bool

    @State private var isTitleVisible = false

    var body: some View {
        Text(text)
            .font(.lora(.title2))
            .opacity(animateOnAppear ? (isTitleVisible ? 1 : 0) : 1)
            .offset(y: animateOnAppear ? (isTitleVisible ? 0 : 8) : 0)
            .animation(animateOnAppear ? .easeOut(duration: 0.7) : nil, value: isTitleVisible)
            .task(id: text) {
                guard animateOnAppear else {
                    isTitleVisible = true
                    return
                }
                isTitleVisible = false
                try? await Task.sleep(for: .milliseconds(300))
                isTitleVisible = true
            }
    }
}

struct AnimatedNarrativeText: View {
    let lines: [String]
    let animateOnAppear: Bool

    @State private var visibleLineIndices: Set<Int> = []

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(.nunito(.callout))
                    .opacity(animateOnAppear ? (visibleLineIndices.contains(index) ? 1 : 0) : 1)
                    .offset(y: animateOnAppear ? (visibleLineIndices.contains(index) ? 0 : 8) : 0)
                    .animation(
                        animateOnAppear ? .easeOut(duration: 0.7).delay(Double(index) * 0.35) : nil,
                        value: visibleLineIndices
                    )
                    .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .task(id: lines) {
            guard animateOnAppear else {
                visibleLineIndices = Set(lines.indices)
                return
            }
            visibleLineIndices = []

            try? await Task.sleep(for: .milliseconds(620))

            for index in lines.indices {
                visibleLineIndices.insert(index)
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
    }
}

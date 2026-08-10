import SwiftUI

/// Full-screen search with debounced query and grid results.
struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var requestsViewModel = RequestSearchSectionViewModel()
    @State private var navPrefs = AppNavPreferences.shared
    @Environment(AppRouter.self) private var router
    @FocusState private var isSearchFieldFocused: Bool
    /// Width the search container actually hands this screen. On tvOS the
    /// system gives roughly half of it to the keyboard panel, so the results
    /// grid can't assume the usual full-screen content column.
    @State private var containerWidth: CGFloat = 0
    private let usesTopMenuInset: Bool

    init(usesTVTopMenuInset: Bool = true) {
        self.usesTopMenuInset = usesTVTopMenuInset
    }

    var body: some View {
        // Bound once per update so the `.task(id:)` below and the work it runs
        // are guaranteed to be looking at the same search.
        let request = viewModel.request

        ScrollView {
            VStack(spacing: ContinuumTheme.padding) {
                if !request.query.isEmpty {
                    // Left-aligned with the result count and the grid's first
                    // column. The focus section spans the full row so tvOS
                    // up-moves from the grid's outer columns land here instead
                    // of skipping to the search field.
                    mediaTypeFilter
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .continuumFocusSection()
                }

                content

                // TMDB titles the library can't answer — the request
                // system's organic entry point. Renders nothing when the
                // server has requests disabled.
                RequestSearchSectionView(viewModel: requestsViewModel)
            }
            .padding(.horizontal, ContinuumTheme.padding)
            .padding(.top, ContinuumTheme.pageTopInset(underTopMenuBar: usesTopMenuInset))
        }
        // Measured on the scroll view, not its content: the container's width
        // is fixed by the presentation, so the reading can't feed back into
        // the column count it decides.
        .posterGridWidth($containerWidth)
        .continuumSearchBackground()
        .navigationTitle("Search")
        .continuumNavigationTitleDisplayMode(.inline)
        .continuumToolbarColorSchemeDark()
        .continuumNavigationBarSurfaceBackground()
        .continuumSearchable(text: $viewModel.query, prompt: searchPrompt)
        .continuumSearchFieldAutofocus($isSearchFieldFocused)
        // Query, filter, audiobook availability, and Try Again all fold into
        // one identity, so SwiftUI restarts exactly one task per change and
        // cancels whatever it superseded.
        .task(id: request) {
            await viewModel.search(request)
        }
        .task(id: request.query) {
            await requestsViewModel.search(request.query)
        }
        .onAppear {
            navPrefs.refresh()
            viewModel.audiobooksEnabled = audiobooksAvailable
        }
        .onChange(of: navPrefs.showAudiobooks) {
            viewModel.audiobooksEnabled = audiobooksAvailable
        }
    }

    /// Whether audiobooks take part in search: the user's per-platform "show
    /// audiobooks" setting, plus an audiobook library actually existing — a
    /// hidden or absent one produces neither a filter chip nor results under
    /// "All". Until the library list is cached the setting is trusted on its
    /// own, so a cold launch never silently drops audiobooks from a search.
    private var audiobooksAvailable: Bool {
        guard navPrefs.showAudiobooks else { return false }
        guard let cached: LibrariesResponse = ResponseCache.shared.get(CacheKey.userLibraries) else {
            return true
        }
        return cached.libraries.contains { $0.isAudiobookLibrary }
    }

    private var searchPrompt: String {
        viewModel.audiobooksEnabled
            ? "Search movies, series, audiobooks..."
            : "Search movies and series..."
    }

    private var promptSubtitle: String {
        viewModel.audiobooksEnabled
            ? "Find movies, series, and audiobooks"
            : "Find movies and series"
    }

    // MARK: - Shared Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .prompt:
            ContentUnavailableView(
                "Search Silo",
                systemImage: "magnifyingglass",
                description: Text(promptSubtitle)
            )
            .frame(maxWidth: .infinity, minHeight: ContinuumTheme.placeholderMinHeight)
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: ContinuumTheme.placeholderMinHeight)
        case .noResults:
            ContentUnavailableView.search(text: viewModel.query)
                .frame(maxWidth: .infinity, minHeight: ContinuumTheme.placeholderMinHeight)
        case .failed(let error):
            ErrorView(state: error, onRetry: { viewModel.retry() })
        case .results:
            resultsGrid
        }
    }

    private var resultsGrid: some View {
        VStack(alignment: .leading, spacing: ContinuumTheme.padding) {
            Text("\(viewModel.total) result\(viewModel.total == 1 ? "" : "s")")
                .font(.continuumCaption)
                .foregroundColor(.continuumSecondaryText)

#if os(tvOS)
            TVCatalogGrid(
                items: viewModel.results,
                isLoading: viewModel.isLoadingMore,
                hasMore: viewModel.hasMore,
                onItemTap: { router.navigate(to: .itemDetail(contentId: $0)) },
                onNearEnd: { _ in
                    Task { await viewModel.loadMore() }
                },
                cardWidth: resultCardWidth,
                availableWidth: resultsWidth,
                prefersDefaultFocusOnFirstItem: true
            )
#else
            CatalogGrid(
                items: viewModel.results,
                isLoading: viewModel.isLoadingMore,
                hasMore: viewModel.hasMore,
                onItemTap: { router.navigate(to: .itemDetail(contentId: $0)) },
                onLoadMore: {
                    Task { await viewModel.loadMore() }
                }
            )
#endif
        }
    }

    /// One segmented control on every platform. It replaced a hand-rolled
    /// iOS-only menu button that reimplemented selection checkmarks, capsule
    /// chrome, and accessibility traits the system already provides — and it
    /// means the filter above the results is the same control everywhere.
    private var mediaTypeFilter: some View {
        Picker("Media Type", selection: $viewModel.selectedMediaType) {
            ForEach(viewModel.availableMediaTypes) { mediaType in
                Text(mediaType.title)
                    .tag(mediaType)
            }
        }
        .pickerStyle(.segmented)
        // Left-aligned pill rather than a control stretched across a 10-foot
        // row; phones are narrower than the cap, so it's a no-op there.
        .frame(maxWidth: filterWidth)
    }

    /// Cap on the media-type control's width.
    private var filterWidth: CGFloat { 760 }

    /// Content width inside the scroll view's own horizontal padding.
    private var resultsWidth: CGFloat { containerWidth - ContinuumTheme.padding * 2 }

    /// Narrower than the full-screen `posterCardWidth` so the tvOS results
    /// column still lands five across next to the system keyboard panel.
    private var resultCardWidth: CGFloat { 200 }
}

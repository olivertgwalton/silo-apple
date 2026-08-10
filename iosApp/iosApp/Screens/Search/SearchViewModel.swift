import Foundation

enum SearchMediaType: String, CaseIterable, Identifiable {
    case all
    case movie
    case series
    case audiobook

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .movie: "Movies"
        case .series: "Series"
        case .audiobook: "Audiobooks"
        }
    }

    /// The `type` query value for this filter. `.all` is context-dependent:
    /// when audiobooks aren't part of this search it means video-only (the old
    /// "Movies & Series" filter), so hidden audiobooks never leak into
    /// unfiltered results; when they are, it sends no filter (true everything).
    func queryValue(audiobooksEnabled: Bool) -> String? {
        switch self {
        case .all: audiobooksEnabled ? nil : "video"
        case .movie: "movie"
        case .series: "series"
        case .audiobook: "audiobook"
        }
    }
}

/// Everything that identifies one search. `SearchView` feeds this to
/// `.task(id:)`, which makes SwiftUI the owner of cancellation: change the
/// query, flip the filter, or hit Try Again and the in-flight search is torn
/// down and a fresh one started. That's what replaced this screen's hand-rolled
/// `Task` handle, manual `cancel()` calls, and duplicated debounce plumbing.
struct SearchRequest: Equatable {
    /// Already trimmed — empty means "nothing to search for".
    let query: String
    let mediaType: SearchMediaType
    let audiobooksEnabled: Bool
    /// Bumped by `retry()` so re-running an unchanged query is still a new
    /// identity as far as `.task(id:)` is concerned.
    let attempt: Int
}

@Observable
@MainActor
final class SearchViewModel {
    /// The one value the results area switches on, so the view doesn't have to
    /// re-derive it from four independent flags.
    enum Content: Equatable {
        /// Nothing typed yet.
        case prompt
        /// First page in flight with nothing on screen to keep.
        case loading
        case results
        case noResults
        case failed(ErrorState)
    }

    var query = ""
    var selectedMediaType: SearchMediaType = .all

    /// Whether audiobooks participate in this search session. Drives both the
    /// offered filters (`availableMediaTypes`) and what `.all` means. On tvOS
    /// this mirrors the Audiobooks tab — an audiobook library exists and the
    /// user has opted to show it. On iOS it mirrors the local Settings toggle.
    /// macOS has no hide setting, so it stays `true`. Clamp the selection if
    /// audiobooks become unavailable; the search re-runs on its own because
    /// this is part of `request`.
    var audiobooksEnabled = true {
        didSet {
            if !audiobooksEnabled, selectedMediaType == .audiobook {
                selectedMediaType = .all
            }
        }
    }

    private(set) var results: [BrowseItem] = []
    private(set) var total = 0
    private(set) var hasMore = false
    /// True only while a *next* page is in flight — the grids use it for their
    /// footer spinner, which must not appear during a first-page search.
    private(set) var isLoadingMore = false

    private var isLoading = false
    private var error: ErrorState?
    private var hasSearched = false
    private var attempt = 0
    private var offset = 0

    private let api: ContinuumAPI
    private let pageSize = 60
    private let debounce = Duration.milliseconds(300)

    init(api: ContinuumAPI = .shared) {
        self.api = api
    }

    /// Filters offered in the picker — Audiobooks only when enabled.
    var availableMediaTypes: [SearchMediaType] {
        audiobooksEnabled ? [.all, .movie, .series, .audiobook] : [.all, .movie, .series]
    }

    var request: SearchRequest {
        SearchRequest(
            query: query.trimmingCharacters(in: .whitespaces),
            mediaType: selectedMediaType,
            audiobooksEnabled: audiobooksEnabled,
            attempt: attempt
        )
    }

    /// Results already on screen outrank both the spinner and a stale error, so
    /// a keystroke never flashes the grid empty and a failed *second* page
    /// leaves the first one alone instead of replacing it with an error screen.
    var content: Content {
        if !results.isEmpty { return .results }
        if let error { return .failed(error) }
        if isLoading { return .loading }
        return hasSearched ? .noResults : .prompt
    }

    func retry() {
        attempt += 1
    }

    /// Runs `request` after a debounce. Called from `.task(id: request)`, so
    /// every superseded call is cancelled for us: mid-debounce it returns
    /// before the network is ever touched, and mid-flight it returns without
    /// writing results a newer search has already replaced.
    func search(_ request: SearchRequest) async {
        guard !request.query.isEmpty else {
            clear()
            return
        }

        do {
            try await Task.sleep(for: debounce)
        } catch {
            return
        }

        isLoading = true
        do {
            let page = try await fetch(request, offset: 0)
            guard !Task.isCancelled else { return }
            results = page.items
            offset = page.items.count
            total = page.total ?? page.items.count
            hasMore = page.hasMore ?? false
            error = nil
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            offset = 0
            total = 0
            hasMore = false
            self.error = ErrorState(error)
        }
        hasSearched = true
        isLoading = false
    }

    /// Next page of the search already on screen, called by the grids as the
    /// user nears the end. Deliberately separate from `search` so paging never
    /// restarts the debounce or clears what's visible. A failed page is
    /// swallowed — `hasMore` stays set, so the next scroll retries.
    func loadMore() async {
        guard hasMore, !isLoading, !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        guard let page = try? await fetch(request, offset: offset), !Task.isCancelled else {
            return
        }
        let known = Set(results.map(\.contentId))
        results.append(contentsOf: page.items.filter { !known.contains($0.contentId) })
        offset += page.items.count
        total = page.total ?? results.count
        hasMore = page.hasMore ?? false
    }

    private func fetch(_ request: SearchRequest, offset: Int) async throws -> CatalogResponse {
        var parameters = [
            "source": "query",
            "q": request.query,
            "limit": String(pageSize),
            "offset": String(offset),
        ]
        // A nil filter value simply isn't sent — see `queryValue(audiobooksEnabled:)`.
        parameters["type"] = request.mediaType.queryValue(audiobooksEnabled: request.audiobooksEnabled)
        return try await api.get("/api/v1/catalog", query: parameters)
    }

    private func clear() {
        results = []
        total = 0
        offset = 0
        hasMore = false
        isLoading = false
        hasSearched = false
        error = nil
    }
}

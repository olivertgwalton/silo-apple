import SwiftUI

/// Horizontal poster rail of "More Like This" items shown at the bottom of
/// Movie / Series detail pages on every platform. Mirrors the web frontend's
/// `RecommendationGrid` flow:
///   1. Hit `/recommendations/similar/{contentId}` for scored IDs
///   2. Resolve each ID to an `ItemDetail` in parallel
///   3. Render a poster card per resolved item; selecting one opens detail
///
/// The rail self-loads its data when the parent provides a `contentId`.
/// Hidden when the request fails or returns nothing — recommendations are
/// non-essential, so a missing rail is preferable to an error placeholder.
/// The section header lives in here (not the parent) for the same reason:
/// when recommendations are disabled or empty, an orphaned "More Like This"
/// title must vanish with the cards.
struct SimilarRail: View {
    let contentId: String
    let onSelect: (String) -> Void

    @State private var items: [SimilarPosterItem] = []
    @State private var isLoading = true
    @State private var loadedFor: String? = nil
    /// Only consulted on tvOS (`MediaCard` ignores it elsewhere), but declared
    /// unconditionally so the card call site doesn't have to fork.
    @FocusState private var focusedItemId: String?

    // MARK: - Platform metrics

    #if os(tvOS)
    private let cardSpacing: CGFloat = 32
    private let railVerticalPadding: CGFloat = 24
    /// Header-to-content gap, matching the other detail sections'
    /// `VStack(spacing: 28)` so the page rhythm stays uniform.
    private let headerSpacing: CGFloat = 28
    private let visibleCardCount = 6
    #elseif os(macOS)
    private let cardSpacing: CGFloat = 12
    private let railVerticalPadding: CGFloat = 4
    private let headerSpacing: CGFloat = 14
    private let visibleCardCount = 6
    #else
    private let cardSpacing: CGFloat = 12
    private let railVerticalPadding: CGFloat = 4
    /// Matches the parents' `VStack(spacing: 14)` so the page rhythm is
    /// unchanged.
    private let headerSpacing: CGFloat = 14
    private let visibleCardCount = 3
    #endif

    var body: some View {
        Group {
            if isLoading {
                section { loadingPlaceholder }
            } else if !items.isEmpty {
                section { rail }
            }
        }
        .task(id: contentId) { await load() }
    }

    private func section(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            DetailSectionHeader(title: "More Like This")
                .padding(.horizontal, ContinuumTheme.safePadding)
            content()
        }
    }

    // MARK: - Rail

    private var rail: some View {
        let strip = ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: cardSpacing) {
                ForEach(items) { item in
                    card(for: item)
                        .containerRelativeFrame(
                            .horizontal,
                            count: visibleCardCount,
                            span: 1,
                            spacing: cardSpacing
                        )
                }
            }
            .padding(.vertical, railVerticalPadding)
        }
        .contentMargins(.horizontal, ContinuumTheme.safePadding, for: .scrollContent)

        #if os(tvOS)
        // Land d-pad entry on the first card (like the cast/episode rails)
        // instead of letting tvOS pick the geometrically-nearest middle card.
        // `.userInitiated` priority is what makes `defaultFocus` win over
        // geometric proximity. No-op while loading / empty (first id is nil).
        return strip
            .focusSection()
            .applyRailDefaultFocus(items.first?.contentId, binding: $focusedItemId)
            .scrollClipDisabled()
        #else
        return strip
        #endif
    }

    private func card(for item: SimilarPosterItem) -> some View {
        MediaCard(
            title: item.title,
            posterUrl: item.posterUrl ?? "",
            thumbhash: item.posterThumbhash,
            year: item.year,
            action: { onSelect(item.contentId) },
            focusedItemId: $focusedItemId,
            contentId: item.contentId,
            focusTreatment: .ring,
            captionLayout: .gridCentered
        )
    }

    // MARK: - Loading placeholder

    private var loadingPlaceholder: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: cardSpacing) {
                ForEach(0..<visibleCardCount, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(ContinuumTheme.posterAspectRatio, contentMode: .fit)
                        .background(Color.continuumSurfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: ContinuumTheme.cornerRadius))
                        .containerRelativeFrame(
                            .horizontal,
                            count: visibleCardCount,
                            span: 1,
                            spacing: cardSpacing
                        )
                }
            }
            .padding(.vertical, railVerticalPadding)
        }
        .contentMargins(.horizontal, ContinuumTheme.safePadding, for: .scrollContent)
        .allowsHitTesting(false)
    }

    // MARK: - Data loading

    private func load() async {
        // Bail if we already populated for this id.
        guard loadedFor != contentId else { return }
        loadedFor = contentId
        isLoading = true
        items = []

        do {
            let scored = try await ContinuumAPI.shared.recommendationsSimilar(
                contentId: contentId,
                limit: 12
            )
            // Resolve detail pages in parallel — preserve the engine's
            // ranking by zipping the resolved details back to their
            // original index. Failed resolutions are dropped silently.
            let resolved = await withTaskGroup(of: (Int, ItemDetail?).self) { group in
                for (index, ref) in scored.enumerated() {
                    group.addTask {
                        let detail = try? await ContinuumAPI.shared.itemDetail(
                            contentId: ref.mediaItemId
                        )
                        return (index, detail)
                    }
                }
                var pairs: [(Int, ItemDetail)] = []
                for await (index, detail) in group {
                    if let detail { pairs.append((index, detail)) }
                }
                return pairs.sorted(by: { $0.0 < $1.0 }).map(\.1)
            }
            items = resolved.map(SimilarPosterItem.init(detail:))
        } catch {
            items = []
            // `.task(id:)` cancels this load when the view detaches or the id
            // changes, and cancellation surfaces here as a throw. Releasing
            // the claim lets the next appearance retry; holding it would hide
            // the rail for this item until the view is recreated.
            loadedFor = nil
        }
        isLoading = false
    }
}

// MARK: - Card model

/// View-side projection of an `ItemDetail` containing only what the poster
/// card needs. Decoupled so the card never re-renders when unrelated detail
/// fields change.
struct SimilarPosterItem: Identifiable, Hashable {
    let contentId: String
    let title: String
    let posterUrl: String?
    let posterThumbhash: String?
    let year: Int?
    var id: String { contentId }

    var accessibilityDescription: String {
        [title, year.map(String.init)].compactMap { $0 }.joined(separator: ", ")
    }

    init(detail: ItemDetail) {
        self.contentId = detail.contentId
        self.title = detail.title
        self.posterUrl = detail.posterUrl
        self.posterThumbhash = detail.posterThumbhash
        self.year = detail.year
    }
}

// MARK: - Platform trim

private extension View {
    #if os(tvOS)
    /// Makes `firstItemId` the rail's default focus target on d-pad entry.
    /// No-op while the rail is empty.
    @ViewBuilder
    func applyRailDefaultFocus(
        _ firstItemId: String?,
        binding: FocusState<String?>.Binding
    ) -> some View {
        if let firstItemId {
            self.defaultFocus(binding, firstItemId, priority: .userInitiated)
        } else {
            self
        }
    }
    #endif
}

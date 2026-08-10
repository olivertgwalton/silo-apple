#if os(tvOS)
import SwiftUI

/// Flexible poster grid for tvOS. Delegates pagination + prefetch to the
/// caller via callbacks so the same view works against any paged catalog
/// source (library browse, collection detail, filter result).
///
/// - Pagination: `onNearEnd(currentIndex)` fires when a cell in the last 8
///   rows of items appears. That's a generous lead time on a 100-item page,
///   which gives
///   the network room to complete before the user reaches the bottom.
/// - Prefetch: the same callback arms Nuke to fetch posters in the next
///   window. The grid itself does not touch the image cache.
/// - Columns: caller picks `columnCount` (default 6). Drop to 5 when a
///   side-rail (alphabet jumper etc.) eats horizontal space, or the
///   fixed `posterCardWidth` cards start overlapping each other.
struct TVCatalogGrid: View {
    let items: [BrowseItem]
    let isLoading: Bool
    let hasMore: Bool
    let onItemTap: (String) -> Void
    let onNearEnd: (Int) -> Void
    var columnCount: Int = 6
    /// Per-card width. Defaults to the theme poster size; shrink when a
    /// side-rail squeezes the usable width and the default cards would
    /// overflow their grid cells.
    var cardWidth: CGFloat = ContinuumTheme.posterCardWidth
    /// Width the grid actually has to spend, when the caller knows it's less
    /// than the screen's content column — search hands half the screen to the
    /// system keyboard. `nil` keeps the full-width assumption, so the count
    /// comes from `columnCount` and the poster-size preference alone.
    var availableWidth: CGFloat?
    var prefersDefaultFocusOnFirstItem: Bool = false
    var focusRequest: Int = 0

    @Namespace private var gridFocusNamespace
    @FocusState private var focusedItemId: String?
    @State private var lastAppliedFocusRequest = 0
    @State private var uiCustomization = UICustomizationPreferences.shared
    @Environment(AppRouter.self) private var router

    private let columnSpacing = AdaptiveColumns.tvPosterColumnSpacing
    private let rowSpacing: CGFloat = 60

    /// Trigger prefetch/pagination when a cell within this many rows of
    /// the end appears. 8 rows of lead time — larger buffer means fast
    /// scrolls that skip `.onAppear` events still hit the trigger
    /// before the user reaches the bottom.
    private let prefetchRowsRemaining: Int = 8

    /// The poster-size preference picks the count; a caller-supplied width has
    /// the final say, because cards are a fixed size and a count that doesn't
    /// fit is drawn past the edge rather than shrunk.
    private var resolvedColumnCount: Int {
        let preferred = AdaptiveColumns.tvPosterCount(
            standardCount: columnCount,
            posterSize: uiCustomization.cardPresentation.posterSize
        )
        guard let availableWidth else { return preferred }
        return AdaptiveColumns.tvPosterCountThatFits(
            preferredCount: preferred,
            availableWidth: availableWidth,
            cardWidth: cardWidth,
            spacing: AdaptiveColumns.tvPosterColumnSpacing
        )
    }

    /// One display row. `id` is the index the row starts at, which each cell
    /// adds its own offset to when reporting its absolute position.
    private struct Row: Identifiable {
        let id: Int
        let items: [BrowseItem]
    }

    private var rows: [Row] {
        let count = resolvedColumnCount
        return stride(from: 0, to: items.count, by: count).map { start in
            Row(id: start, items: Array(items[start..<min(start + count, items.count)]))
        }
    }

    var body: some View {
        // Rows are explicit full-width focus sections so a D-pad move into a
        // ragged row (fewer cards than columns) still lands: the focus engine
        // resolves moves geometrically, and a partially filled LazyVGrid row
        // has no focusable under most columns. The row's full-width section
        // frame is the catchment; the engine snaps to its nearest card.
        LazyVStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: columnSpacing) {
                    ForEach(Array(row.items.enumerated()), id: \.element.id) { offset, item in
                        TVMediaCard(
                            title: item.title,
                            posterUrl: item.posterUrl ?? "",
                            thumbhash: item.posterThumbhash,
                            year: item.year,
                            userState: item.userState,
                            overlayData: OverlayData.from(item),
                            action: { onItemTap(item.contentId) },
                            playAction: playAction(for: item),
                            cardWidth: cardWidth,
                            aspect: item.isAudiobook ? .square : .poster,
                            prefersDefaultFocus: prefersDefaultFocusOnFirstItem
                                && row.id == 0 && offset == 0,
                            defaultFocusNamespace: gridFocusNamespace,
                            focusBinding: $focusedItemId,
                            focusContentId: item.contentId,
                            contentId: item.contentId
                        )
                        .frame(maxWidth: .infinity)
                        .onAppear { onCellAppear(index: row.id + offset) }
                    }
                    // Keep ragged-row cards in their column positions by
                    // filling the empty slots with equally flexible spacers.
                    ForEach(0..<(resolvedColumnCount - row.items.count), id: \.self) { _ in
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .focusSection()
            }
        }
        .focusScope(gridFocusNamespace)
        .focusSection()
        .onAppear { applyFocusRequest(focusRequest) }
        .onChange(of: focusRequest) { _, request in applyFocusRequest(request) }
        .onChange(of: items.map(\.contentId)) { _, _ in applyFocusRequest(focusRequest) }

        if isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .tint(.continuumOnSurface)
                    .padding()
                Spacer()
            }
        }
    }

    private func onCellAppear(index: Int) {
        guard hasMore else { return }
        let threshold = items.count - (prefetchRowsRemaining * resolvedColumnCount)
        if index >= threshold {
            onNearEnd(index)
        }
    }

    private func playAction(for item: BrowseItem) -> (() -> Void)? {
        guard SiloMediaType.isDirectlyPlayable(item.type) else { return nil }
        return {
            router.presentPlayer(
                contentId: item.contentId,
                posterURL: item.posterUrl,
                backdropURL: item.backdropUrl
            )
        }
    }

    private func applyFocusRequest(_ request: Int) {
        guard request > 0, request != lastAppliedFocusRequest else { return }
        guard let firstItemId = items.first?.contentId else { return }
        lastAppliedFocusRequest = request
        focusedItemId = firstItemId
    }
}

#endif

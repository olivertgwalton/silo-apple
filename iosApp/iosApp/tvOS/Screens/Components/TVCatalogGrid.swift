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
/// - Columns: caller picks `columnCount` (default 6), adjusted for the
///   poster-size preference. Cells take their width from
///   `containerRelativeFrame`, so a grid that is handed less room than the
///   full content column — search gives half the screen to the system
///   keyboard — narrows its cards instead of drawing them past the edge.
///   Nothing has to measure or be told the available width.
///
/// Rows are chunked by hand rather than left to `LazyVGrid` because they are
/// explicit focus sections: the focus engine resolves d-pad moves
/// geometrically, and a partially filled grid row has no focusable under most
/// columns, so a move into a ragged row falls through.
struct TVCatalogGrid: View {
    let items: [BrowseItem]
    let isLoading: Bool
    let hasMore: Bool
    let onItemTap: (String) -> Void
    let onNearEnd: (Int) -> Void
    var columnCount: Int = 6
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

    /// Columns come from the poster-size preference alone. The cells size
    /// themselves against whatever width the grid is actually given, so a
    /// narrower container yields narrower cards rather than an overflowing row.
    private var resolvedColumnCount: Int {
        AdaptiveColumns.tvPosterCount(
            standardCount: columnCount,
            posterSize: uiCustomization.cardPresentation.posterSize
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
                        MediaCard(
                            title: item.title,
                            posterUrl: item.posterUrl ?? "",
                            thumbhash: item.posterThumbhash,
                            year: item.year,
                            userState: item.userState,
                            overlayData: OverlayData.from(item),
                            action: { onItemTap(item.contentId) },
                            playAction: playAction(for: item),
                            focusedItemId: $focusedItemId,
                            contentId: item.contentId,
                            aspect: item.isAudiobook ? .square : .poster,
                            captionLayout: .gridCentered,
                            prefersDefaultFocus: prefersDefaultFocusOnFirstItem
                                && row.id == 0 && offset == 0,
                            defaultFocusNamespace: gridFocusNamespace
                        )
                        .containerRelativeFrame(
                            .horizontal,
                            count: resolvedColumnCount,
                            span: 1,
                            spacing: columnSpacing
                        )
                        .onAppear { onCellAppear(index: row.id + offset) }
                    }
                    // Keep ragged-row cards in their column positions by
                    // filling the empty slots with equally flexible spacers.
                    ForEach(0..<(resolvedColumnCount - row.items.count), id: \.self) { _ in
                        Color.clear
                            .frame(height: 1)
                            .containerRelativeFrame(
                                .horizontal,
                                count: resolvedColumnCount,
                                span: 1,
                                spacing: columnSpacing
                            )
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

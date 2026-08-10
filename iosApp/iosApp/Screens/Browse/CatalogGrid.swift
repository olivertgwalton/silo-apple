import SwiftUI

/// The poster grid for a paged catalog result — one entry point for every
/// platform, so screens shared across iOS, macOS, and tvOS don't fork on it.
///
/// Off tvOS the column count follows the width the grid is actually given
/// (see `AdaptiveColumns`), so a resized Mac window and iPad Split View
/// re-flow instead of stretching a fixed count. tvOS routes to
/// `TVCatalogGrid`, whose rows are explicit focus sections — the focus engine
/// resolves moves geometrically, and a partially filled `LazyVGrid` row has no
/// focusable under most columns, so a d-pad move into a ragged row falls
/// through. tvOS-only screens can still build `TVCatalogGrid` directly when
/// they need its focus-request plumbing.
struct CatalogGrid: View {
    let items: [BrowseItem]
    let isLoading: Bool
    let hasMore: Bool
    let onItemTap: (String) -> Void
    let onLoadMore: () -> Void
    /// tvOS: per-card width. Shrink it when a side rail or the system search
    /// keyboard squeezes the usable width. Ignored elsewhere, where the cards
    /// flex to the column width instead.
    var cardWidth: CGFloat = ContinuumTheme.posterCardWidth
    /// tvOS: width the grid actually has to spend, when the caller knows it's
    /// less than the screen's content column. `nil` assumes the full width.
    var availableWidth: CGFloat?
    /// tvOS: make the first card the scope's default focus target.
    var prefersDefaultFocusOnFirstItem: Bool = false

    @State private var uiCustomization = UICustomizationPreferences.shared

    #if !os(tvOS)
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var gridWidth: CGFloat = 0
    private let rowSpacing: CGFloat = 12

    private var columns: [GridItem] {
        AdaptiveColumns.posters(
            for: hSize,
            availableWidth: gridWidth,
            posterSize: uiCustomization.cardPresentation.posterSize,
            spacing: 8
        )
    }
    #endif

    var body: some View {
        #if os(tvOS)
        TVCatalogGrid(
            items: items,
            isLoading: isLoading,
            hasMore: hasMore,
            onItemTap: onItemTap,
            // Fires per cell across the last rows rather than once per page,
            // so a caller's load-more has to be re-entrant. They all guard on
            // their own `isLoading`.
            onNearEnd: { _ in onLoadMore() },
            cardWidth: cardWidth,
            availableWidth: availableWidth,
            prefersDefaultFocusOnFirstItem: prefersDefaultFocusOnFirstItem
        )
        #else
        LazyVGrid(columns: columns, spacing: rowSpacing) {
            ForEach(items) { item in
                MediaCard(
                    title: item.title,
                    posterUrl: item.posterUrl ?? "",
                    thumbhash: item.posterThumbhash,
                    year: item.year,
                    userState: item.userState,
                    overlayData: OverlayData.from(item),
                    action: { onItemTap(item.contentId) },
                    contentId: item.contentId,
                    aspect: item.isAudiobook ? .square : .poster
                )
                .frame(maxWidth: .infinity)
                .onAppear {
                    if item.id == items.suffix(6).first?.id, hasMore {
                        onLoadMore()
                    }
                }
            }
        }
        .posterGridWidth($gridWidth)

        if isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .tint(.continuumOnSurface)
                    .padding()
                Spacer()
            }
        }
        #endif
    }
}

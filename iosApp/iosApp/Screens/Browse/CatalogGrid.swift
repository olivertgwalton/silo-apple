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
    /// tvOS: make the first card the scope's default focus target.
    var prefersDefaultFocusOnFirstItem: Bool = false
    /// Fires with the index of a cell as it comes on screen, for callers that
    /// warm artwork ahead of the scroll (see `PersonDetailViewModel`). This is
    /// the hook that used to force screens onto `TVCatalogGrid` directly;
    /// exposing it here keeps them on the one cross-platform entry point.
    var onCellAppear: ((Int) -> Void)? = nil

    @State private var uiCustomization = UICustomizationPreferences.shared

    #if !os(tvOS)
    private let rowSpacing: CGFloat = 12

    private var columns: [GridItem] {
        AdaptiveColumns.posterColumns(
            uiCustomization.cardPresentation.posterSize,
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
            onNearEnd: { index in
                onCellAppear?(index)
                onLoadMore()
            },
            prefersDefaultFocusOnFirstItem: prefersDefaultFocusOnFirstItem
        )
        #else
        LazyVGrid(columns: columns, spacing: rowSpacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
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
                .onAppear {
                    onCellAppear?(index)
                    if item.id == items.suffix(6).first?.id, hasMore {
                        onLoadMore()
                    }
                }
            }
        }

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

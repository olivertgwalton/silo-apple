import SwiftUI

/// A poster grid. Off tvOS the column count follows the width the grid is
/// actually given (see `AdaptiveColumns`), so a resized Mac window and iPad
/// Split View re-flow instead of stretching a fixed count. tvOS keeps its
/// fixed 6-column layout; cards handle their own focus lift there.
struct CatalogGrid: View {
    let items: [BrowseItem]
    let isLoading: Bool
    let hasMore: Bool
    let onItemTap: (String) -> Void
    let onLoadMore: () -> Void
    @Environment(AppRouter.self) private var router
    @State private var uiCustomization = UICustomizationPreferences.shared

    @State private var gridWidth: CGFloat = 0

    #if os(tvOS)
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 40, alignment: .top),
            count: AdaptiveColumns.tvPosterCount(
                standardCount: 6,
                posterSize: uiCustomization.cardPresentation.posterSize
            )
        )
    }
    private let rowSpacing: CGFloat = 60
    #else
    @Environment(\.horizontalSizeClass) private var hSize
    private var columns: [GridItem] {
        AdaptiveColumns.posters(
            for: hSize,
            availableWidth: gridWidth,
            posterSize: uiCustomization.cardPresentation.posterSize,
            spacing: 8
        )
    }
    private let rowSpacing: CGFloat = 12
    #endif

    var body: some View {
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
                    playAction: playAction(for: item),
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
    }

    private func playAction(for item: BrowseItem) -> (() -> Void)? {
        #if os(tvOS)
        guard SiloMediaType.isDirectlyPlayable(item.type) else { return nil }
        return {
            router.presentPlayer(
                contentId: item.contentId,
                posterURL: item.posterUrl,
                backdropURL: item.backdropUrl
            )
        }
        #else
        return nil
        #endif
    }
}

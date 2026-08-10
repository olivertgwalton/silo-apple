#if !os(tvOS)
import SwiftUI

/// Expanded episode presentation for regular-width detail containers.
///
/// Same contract as the poster grids (see `AdaptiveColumns`): an `.adaptive`
/// column fits as many readable rows as the container can hold and re-flows on
/// every resize, so a portrait iPad pane, a landscape one, and a dragged Mac
/// window all just work. Nothing here measures a width or counts a column.
struct PhoneEpisodeList: View {
    let episodes: [EpisodeListItem]
    let onSelect: (String) -> Void
    var currentContentId: String? = nil

    /// Narrowest an episode row goes before the grid drops to one column: the
    /// 168pt still, its gutter, and enough room left for a two-line overview.
    private static let minimumRowWidth: CGFloat = 420
    private static let rowSpacing: CGFloat = 16

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: Self.minimumRowWidth), spacing: Self.rowSpacing)
            ],
            alignment: .leading,
            spacing: Self.rowSpacing
        ) {
            ForEach(episodes) { episode in
                PhoneEpisodeListRow(
                    episode: episode,
                    isCurrent: currentContentId == episode.contentId,
                    onSelect: { onSelect(episode.contentId) }
                )
            }
        }
        .padding(.horizontal, ContinuumTheme.safePadding)
        .padding(.vertical, 4)
    }
}
#endif

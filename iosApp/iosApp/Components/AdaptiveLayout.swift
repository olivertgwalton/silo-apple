import SwiftUI

/// Poster grid geometry.
///
/// Off tvOS there is no column *count* to compute: `GridItem(.adaptive)` fits
/// as many columns of at least `posterMinWidth` as the container can hold and
/// re-flows on every resize, so a phone, an iPad in Split View, and a dragged
/// Mac window all just work without measuring anything. All this type still
/// owns off tvOS is the minimum width the user's poster-size preference maps
/// onto. tvOS keeps an explicit count because its grid rows are focus
/// sections (see `TVCatalogGrid`).
enum AdaptiveColumns {
    /// Smallest poster the grid draws before dropping a column. Phones land
    /// on 3-up at the standard size; wider canvases simply fit more.
    static func posterMinWidth(_ posterSize: CardPosterSize = .standard) -> CGFloat {
        switch posterSize {
        case .compact: 96
        case .standard: 116
        case .large: 150
        }
    }

    /// One `.adaptive` column spec sized for `posterSize`. Call sites hand
    /// this straight to `LazyVGrid` — nothing measures, nothing counts.
    static func posterColumns(
        _ posterSize: CardPosterSize = .standard,
        spacing: CGFloat = 12
    ) -> [GridItem] {
        [GridItem(.adaptive(minimum: posterMinWidth(posterSize)), spacing: spacing)]
    }

    /// Gap between tvOS poster columns. Shared so a screen fitting a count to
    /// its own width measures against the spacing the grid lays out with.
    static let tvPosterColumnSpacing: CGFloat = 40

    /// Keeps tvOS poster grids dense enough for compact artwork while making
    /// room for large artwork and its native focus lift. Six columns is the
    /// safe upper bound inside the standard 1,760-point content width.
    static func tvPosterCount(
        standardCount: Int,
        posterSize: CardPosterSize,
        minimumCount: Int = 3
    ) -> Int {
        switch posterSize {
        case .compact:
            return min(6, standardCount + 1)
        case .standard:
            return standardCount
        case .large:
            return max(minimumCount, standardCount - 1)
        }
    }
}

extension Comparable {
    /// Pins a measured dimension inside the range a layout will accept.
    /// Reads as the intent — "a quarter of the container, between 164 and
    /// 224" — where nested `min(max(…))` reads as arithmetic.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

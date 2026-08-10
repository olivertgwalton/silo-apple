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

    /// Narrows `preferredCount` to the columns that actually fit
    /// `availableWidth`.
    ///
    /// tvOS cards keep a fixed frame — the focus lift needs a stable one — so
    /// unlike the phone grids the column *count* is the only free variable.
    /// A screen that owns the full width gets its preferred count back
    /// untouched; one the system shares with something else (search, which
    /// gives half the screen to the keyboard panel) drops columns instead of
    /// drawing the last one past the edge.
    static func tvPosterCountThatFits(
        preferredCount: Int,
        availableWidth: CGFloat,
        cardWidth: CGFloat,
        spacing: CGFloat,
        minimumCount: Int = 3
    ) -> Int {
        // Before the first layout pass reports a width, trust the preference —
        // same "never wildly wrong on frame one" rule as `posters`.
        guard availableWidth > 0, cardWidth > 0 else { return preferredCount }
        // Half a point of slack: a count that fits exactly (six standard
        // posters in the 1,760pt content column) must survive a measurement
        // that lands a hair under its own layout width.
        let fitted = Int((availableWidth + spacing + 0.5) / (cardWidth + spacing))
        return min(preferredCount, max(minimumCount, fitted))
    }
}

extension View {
    /// Caps form/content width so text fields and buttons don't stretch
    /// edge-to-edge on iPad. iPhones are already narrower than the cap, so
    /// this is a no-op on phone. The second `frame` centers the capped view.
    func continuumFormWidth(_ maxWidth: CGFloat = 600) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

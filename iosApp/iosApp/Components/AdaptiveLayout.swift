import SwiftUI

/// Width-aware poster grid columns.
///
/// Column count is derived from the width the grid actually gets, not from
/// the size class alone. The size class only picks the *target* poster width
/// — phones want dense 3-up artwork, regular-width canvases (iPad, Mac) want
/// larger posters — and the container width then decides how many of those
/// fit. This is what makes a resizable Mac window and iPad Split View behave:
/// `horizontalSizeClass` is permanently `.regular` on macOS, so a size-class
/// count alone pinned every window to five stretched columns.
///
/// Call sites pass their measured width via `posterGridWidth(_:)`; until the
/// first layout pass reports one, the size-class count is used so the very
/// first frame is never empty or wildly wrong.
enum AdaptiveColumns {
    /// Target poster width for a compact canvas (iPhone portrait, narrow
    /// Split View). Three columns across a 390pt phone.
    private static let compactIdealPosterWidth: CGFloat = 116
    /// Target poster width for a regular canvas (iPad, Mac). Five columns
    /// across a full-screen 1024pt iPad.
    private static let regularIdealPosterWidth: CGFloat = 200

    static func posters(
        for sizeClass: UserInterfaceSizeClass?,
        availableWidth: CGFloat? = nil,
        posterSize: CardPosterSize = .standard,
        spacing: CGFloat = 12
    ) -> [GridItem] {
        let count = posterCount(
            for: sizeClass,
            availableWidth: availableWidth,
            posterSize: posterSize,
            spacing: spacing
        )
        return Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: count
        )
    }

    static func posterCount(
        for sizeClass: UserInterfaceSizeClass?,
        availableWidth: CGFloat?,
        posterSize: CardPosterSize = .standard,
        spacing: CGFloat = 12,
        minimumCount: Int = 2
    ) -> Int {
        guard let availableWidth, availableWidth > 0 else {
            return sizeClassPosterCount(for: sizeClass, posterSize: posterSize)
        }
        let ideal = idealPosterWidth(for: sizeClass, posterSize: posterSize)
        // Round rather than floor: a canvas that lands just short of the next
        // whole column is better served by slightly narrower posters than by
        // stretching the previous count across the leftover width.
        let fitted = Int(((availableWidth + spacing) / (ideal + spacing)).rounded())
        return max(minimumCount, fitted)
    }

    /// Size-class-only count, used before the first width measurement lands.
    /// Preserves the original 3-up phone / 5-up regular layout.
    private static func sizeClassPosterCount(
        for sizeClass: UserInterfaceSizeClass?,
        posterSize: CardPosterSize
    ) -> Int {
        let standardCount = (sizeClass == .regular) ? 5 : 3
        switch posterSize {
        case .compact:
            return sizeClass == .regular ? standardCount + 1 : standardCount
        case .standard:
            return standardCount
        case .large:
            return max(2, standardCount - 1)
        }
    }

    private static func idealPosterWidth(
        for sizeClass: UserInterfaceSizeClass?,
        posterSize: CardPosterSize
    ) -> CGFloat {
        let base = (sizeClass == .regular)
            ? regularIdealPosterWidth
            : compactIdealPosterWidth
        switch posterSize {
        case .compact: return base * 0.82
        case .standard: return base
        case .large: return base * 1.28
        }
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
    /// Reports this view's laid-out width into `width`, for grids that size
    /// their columns from the space they were actually given.
    ///
    /// Safe to apply directly to a `LazyVGrid`: the grid fills its container's
    /// width regardless of column count, so the reported width does not change
    /// when the count does and the measurement cannot oscillate.
    func posterGridWidth(_ width: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            guard abs(newWidth - width.wrappedValue) > 0.5 else { return }
            width.wrappedValue = newWidth
        }
    }

    /// Caps form/content width so text fields and buttons don't stretch
    /// edge-to-edge on iPad. iPhones are already narrower than the cap, so
    /// this is a no-op on phone. The second `frame` centers the capped view.
    func continuumFormWidth(_ maxWidth: CGFloat = 600) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

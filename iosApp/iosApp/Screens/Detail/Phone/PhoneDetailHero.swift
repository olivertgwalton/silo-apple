#if !os(tvOS)
import SwiftUI

/// The layout constants this hero's two compositions are built from.
/// Named rather than inline so the relationships between them — the width
/// at which the poster earns its place, the width above which the columns
/// breathe — are readable without measuring the view.
private enum HeroLayout {
    /// Container width at which poster + left-aligned column beats the
    /// phone's backdrop-over-centered-column stack.
    static let expandedBreakpoint: CGFloat = 640
    /// Above this the expanded hero has room for wider gutters.
    static let roomyBreakpoint: CGFloat = 840

    static let backdropHeightCompact: CGFloat = 360
    static let backdropHeightRegular: CGFloat = 420

    /// Logo art arrives with generous internal padding, so a taller box
    /// lets a wordmark claim a third of the column and push Play toward
    /// the fold. These keep the logo dominant without crowding the
    /// actions it exists to introduce.
    static let logoHeightCompact: CGFloat = 132
    static let logoHeightRegular: CGFloat = 168
    static let logoHeightExpanded: CGFloat = 144
    /// Logo width in the expanded column, clamped so a wide wordmark
    /// can't crowd the poster and a narrow one still reads as title art.
    static let expandedLogoWidthRange: ClosedRange<CGFloat> = 220...360

    static let editorialMaxWidth: CGFloat = 620
    static let expandedMinHeight: CGFloat = 560
    /// Clears the navigation bar over the expanded backdrop.
    static let expandedTopPadding: CGFloat = 92
    /// The page adds its own hero-to-section spacing; a smaller inset here
    /// keeps the first detail section within reach on iPad.
    static let expandedBottomPadding: CGFloat = 24

    static let horizontalPaddingRoomy: CGFloat = 48
    static let horizontalPaddingTight: CGFloat = 32
    static let columnSpacingRoomy: CGFloat = 36
    static let columnSpacingTight: CGFloat = 28

    /// Poster takes a quarter of the container, floored so it stays
    /// recognizable and capped so it never dominates the column.
    static let posterWidthFraction: CGFloat = 0.25
    static let posterWidthRange: ClosedRange<CGFloat> = 164...224
}

/// Adaptive iOS detail hero. Compact containers retain the phone's
/// backdrop-first, centered editorial composition. At regular iPad detail
/// widths, poster art and a left-aligned editorial column share a single
/// backdrop-backed stage so actions and context stay above the fold.
///
/// The breakpoint is based on this view's actual container rather than the
/// device size class, so split view and resizable windows fall back cleanly.
struct PhoneDetailHero<Actions: View, BelowOverview: View>: View {
    let title: String
    let seriesTitle: String?
    let logoUrl: String?
    let posterUrl: String?
    let posterThumbhash: String?
    let backdropUrl: String?
    let backdropThumbhash: String?
    let eyebrow: String?
    let sourceTokens: [String]
    let ratingChip: String?
    let overview: String?
    let factsLine: [DetailHeroFactToken]
    @ViewBuilder let actions: () -> Actions
    /// Affordance rendered directly under the overview (e.g. the on-view
    /// description-translation control). Pass `{ EmptyView() }` when there's
    /// nothing to show.
    @ViewBuilder let belowOverview: () -> BelowOverview

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var availableWidth: CGFloat = 0

    private var backdropHeight: CGFloat {
        horizontalSizeClass == .regular
            ? HeroLayout.backdropHeightRegular
            : HeroLayout.backdropHeightCompact
    }

    var body: some View {
        Group {
            if usesExpandedLayout {
                expandedHero
            } else {
                compactHero
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            guard abs(width - availableWidth) > 1 else { return }
            availableWidth = width
        }
    }

    private var usesExpandedLayout: Bool {
        if availableWidth > 0 {
            return availableWidth >= HeroLayout.expandedBreakpoint
        }
        return horizontalSizeClass == .regular
    }

    private var compactHero: some View {
        VStack(spacing: 0) {
            backdropBlock
            editorialColumn(
                alignment: .center,
                textAlignment: .center,
                factsAlignment: .center,
                logoHeight: compactLogoHeight
            )
            .padding(.horizontal, ContinuumTheme.safePadding)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Expanded iPad hero

    private var expandedHero: some View {
        HStack(alignment: .top, spacing: expandedColumnSpacing) {
            poster
                .padding(.top, 8)

            editorialColumn(
                alignment: .leading,
                textAlignment: .leading,
                factsAlignment: .leading,
                logoHeight: HeroLayout.logoHeightExpanded
            )
            .frame(maxWidth: HeroLayout.editorialMaxWidth, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, expandedHorizontalPadding)
        .padding(.top, HeroLayout.expandedTopPadding)
        .padding(.bottom, HeroLayout.expandedBottomPadding)
        .frame(maxWidth: .infinity, minHeight: HeroLayout.expandedMinHeight, alignment: .topLeading)
        .background {
            expandedBackdrop
        }
    }

    @ViewBuilder
    private var poster: some View {
        if let posterUrl, !posterUrl.isEmpty {
            CachedAsyncImage(
                url: posterUrl,
                thumbhash: posterThumbhash,
                targetSize: CGSize(width: posterWidth, height: posterHeight),
                contentMode: .fill
            )
            .frame(width: posterWidth, height: posterHeight)
            .clipShape(RoundedRectangle(cornerRadius: ContinuumTheme.cornerRadius))
            .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
            .accessibilityHidden(true)
        }
    }

    private var expandedBackdrop: some View {
        ZStack {
            Group {
                if let url = backdropUrl, !url.isEmpty {
                    CachedAsyncImage(
                        url: url,
                        thumbhash: backdropThumbhash,
                        contentMode: .fill
                    )
                } else {
                    Color.continuumSurface
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            Color.black.opacity(0.18)

            LinearGradient(
                stops: [
                    .init(color: Color.continuumBackground.opacity(0.78), location: 0),
                    .init(color: Color.continuumBackground.opacity(0.38), location: 0.48),
                    .init(color: Color.continuumBackground.opacity(0.62), location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                stops: [
                    .init(color: Color.continuumBackground.opacity(0.18), location: 0),
                    .init(color: Color.continuumBackground.opacity(0.28), location: 0.52),
                    .init(color: Color.continuumBackground, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .backgroundExtensionEffect()
        .allowsHitTesting(false)
    }

    private var expandedHorizontalPadding: CGFloat {
        availableWidth >= HeroLayout.roomyBreakpoint
            ? HeroLayout.horizontalPaddingRoomy
            : HeroLayout.horizontalPaddingTight
    }

    private var expandedColumnSpacing: CGFloat {
        availableWidth >= HeroLayout.roomyBreakpoint
            ? HeroLayout.columnSpacingRoomy
            : HeroLayout.columnSpacingTight
    }

    private var posterWidth: CGFloat {
        (availableWidth * HeroLayout.posterWidthFraction)
            .clamped(to: HeroLayout.posterWidthRange)
    }

    private var posterHeight: CGFloat {
        posterWidth / ContinuumTheme.posterAspectRatio
    }

    // MARK: - Backdrop

    private var backdropBlock: some View {
        ZStack(alignment: .bottom) {
            backdrop
            bottomFade
        }
        .frame(height: backdropHeight)
        .frame(maxWidth: .infinity)
        // Intentionally no hard rectangle clip here. The backdrop's background
        // extension (applied below) mirrors/blurs the artwork past its frame into
        // the top safe area and the horizontal screen edges (the callers apply
        // ignoresSafeArea on the top edge). Clipping to the fixed-height rectangle
        // would defeat that edge-to-edge bleed.
    }

    private var backdrop: some View {
        Group {
            if let url = backdropUrl, !url.isEmpty {
                CachedAsyncImage(url: url, thumbhash: backdropThumbhash, contentMode: .fill)
            } else {
                Color.continuumSurface
            }
        }
        .frame(height: backdropHeight)
        .frame(maxWidth: .infinity)
        // Mirror + blur the source artwork to fill behind the status bar /
        // Dynamic Island and out to the screen edges — the Apple TV / Music
        // detail-page continuation, instead of a hard banner edge. All Apple
        // targets are at the 26 minimum, so this is unconditional.
        .backgroundExtensionEffect()
    }

    /// Soft single-direction fade — only enough to let text below sit
    /// on the background without a visible seam. The artwork stays
    /// readable across most of the hero.
    private var bottomFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.55),
                .init(color: Color.continuumBackground.opacity(0.6), location: 0.85),
                .init(color: Color.continuumBackground, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Editorial column

    private func editorialColumn(
        alignment: HorizontalAlignment,
        textAlignment: TextAlignment,
        factsAlignment: HorizontalAlignment,
        logoHeight: CGFloat
    ) -> some View {
        VStack(alignment: alignment, spacing: 14) {
            if let eyebrow, !eyebrow.isEmpty {
                HeroEyebrow(text: eyebrow)
            }
            titleBlock(textAlignment: textAlignment, logoHeight: logoHeight)
            sourceRow(textAlignment: textAlignment)
            actions()
                .padding(.top, 6)
            overviewBlock
            belowOverview()
            factsRow(alignment: factsAlignment)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func titleBlock(textAlignment: TextAlignment, logoHeight: CGFloat) -> some View {
        if let episodeSeriesTitle {
            HeroEpisodeHierarchyTitle(
                seriesTitle: episodeSeriesTitle,
                episodeTitle: title,
                textAlignment: textAlignment
            )
        } else if let logoUrl, !logoUrl.isEmpty {
            CachedAsyncImage(url: logoUrl, contentMode: .fit, placeholderStyle: .clear)
                .frame(
                    width: textAlignment == .leading ? expandedLogoWidth : nil,
                    height: logoHeight
                )
                .frame(maxWidth: .infinity, alignment: frameAlignment(for: textAlignment))
                .accessibilityLabel(title)
        } else {
            HeroTitle(title: title, textAlignment: textAlignment)
        }
    }

    private var episodeSeriesTitle: String? {
        guard let trimmed = seriesTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }

    private var compactLogoHeight: CGFloat {
        horizontalSizeClass == .regular
            ? HeroLayout.logoHeightRegular
            : HeroLayout.logoHeightCompact
    }

    @ViewBuilder
    private func sourceRow(textAlignment: TextAlignment) -> some View {
        if !sourceTokens.isEmpty || ratingChip != nil {
            HeroSourceRow(
                tokens: sourceTokens,
                ratingChip: ratingChip,
                textAlignment: textAlignment
            )
        }
    }

    private var expandedLogoWidth: CGFloat {
        let editorialWidth = availableWidth
            - (expandedHorizontalPadding * 2)
            - posterWidth
            - expandedColumnSpacing
        return editorialWidth.clamped(to: HeroLayout.expandedLogoWidthRange)
    }

    private func frameAlignment(for textAlignment: TextAlignment) -> Alignment {
        textAlignment == .leading ? .leading : .center
    }

    // MARK: - Overview

    @ViewBuilder
    private var overviewBlock: some View {
        if let overview, !overview.isEmpty {
            ExpandableSynopsis(overview: overview)
                .padding(.top, 8)
        }
    }

    // MARK: - Facts row

    @ViewBuilder
    private func factsRow(alignment: HorizontalAlignment) -> some View {
        if !factsLine.isEmpty {
            HeroFactsRow(tokens: factsLine, alignment: alignment)
                .padding(.top, 4)
        }
    }
}

#endif

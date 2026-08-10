#if os(tvOS)
import SwiftUI

/// The layout constants this hero is built from. Named rather than inline so
/// the composition — how much viewport the hero claims, how much of the next
/// rail is left peeking — is readable without measuring the view.
private enum HeroLayout {
    /// Just short of the full 1080 viewport, so the rail below peeks and the
    /// viewer instinctively drifts down rather than reaching an "end".
    static let heroHeight: CGFloat = 980
    /// Keeps the editorial column off the backdrop's bright right side.
    static let contentMaxWidth: CGFloat = 1200
    static let blockSpacing: CGFloat = 24
    /// The detail pages' outer VStack adds its own hero-to-section spacing,
    /// so a large inset here reads as a dead band under the selector row.
    static let bottomInset: CGFloat = 48
    static let actionsTopInset: CGFloat = 8

    static let logoMaxWidth: CGFloat = 620
    static let logoMaxHeight: CGFloat = 220

    static let starringMaxWidth: CGFloat = 460
    /// Floats the starring line at mid-hero, clear of the editorial column.
    static let starringHeightFraction: CGFloat = 0.45
}

/// Full-bleed cinematic hero for the tvOS item-detail screen. Modeled
/// after Apple TV's detail page: a nearly full-viewport backdrop layered
/// with a tall left-column editorial stack (eyebrow pill → title →
/// source row → overview → facts+quality → actions) and a quiet
/// right-side "Starring ..." line positioned mid-hero.
///
/// The intent is to show enough of the below-fold rail peeking at the
/// bottom that the viewer instinctively drifts down when they want
/// episodes / similar titles — rather than reaching the "end" of the
/// hero.
struct TVDetailHero<Actions: View, BelowSynopsis: View>: View {
    let title: String
    let seriesTitle: String?
    let logoUrl: String?
    let backdropUrl: String?
    /// Optional short editorial line placed in a capsule above the title
    /// (e.g. "New Episode Friday", "Continuing Series"). Hidden when nil.
    let eyebrow: String?
    /// Source/genre line shown under the title. Text items are
    /// pipe-separated; a single optional rating token is rendered as an
    /// outlined chip at the end of the row.
    let sourceTokens: [String]
    let ratingChip: String?
    /// Short description shown in the hero. Clamped to 3 lines.
    let overview: String?
    /// Inline facts row shown above the action buttons. Mixes plain text
    /// (year / runtime / maturity) and outlined quality chips
    /// (4K / HDR / ATMOS / CC).
    let factsLine: [DetailHeroFactToken]
    /// Optional "Starring A, B, C" line floated on the right of the hero
    /// at mid-height. Hidden when nil.
    let starringText: String?
    @ViewBuilder let actions: () -> Actions
    /// Affordance rendered directly under the synopsis (e.g. the on-view
    /// description-translation control). Pass `{ EmptyView() }` when there's
    /// nothing to show.
    @ViewBuilder let belowSynopsis: () -> BelowSynopsis


    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop
            leftGradient
            bottomFade
            content
        }
        .overlay(alignment: .trailing) { starringOverlay }
        .frame(height: HeroLayout.heroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        Group {
            if let url = backdropUrl, !url.isEmpty {
                CachedAsyncImage(url: url, contentMode: .fill)
            } else {
                Color.continuumSurface
            }
        }
        .frame(height: HeroLayout.heroHeight)
        .frame(maxWidth: .infinity)
    }

    /// Heavy left-side darkening → clear on the right so the backdrop
    /// imagery breathes while text stays legible.
    private var leftGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.92), location: 0.0),
                .init(color: Color.black.opacity(0.70), location: 0.22),
                .init(color: Color.black.opacity(0.35), location: 0.55),
                .init(color: .clear, location: 0.88),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Soft bottom fade into the scroll body — subtle so the seam is
    /// invisible and a hint of the next rail peeks through.
    private var bottomFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.55),
                .init(color: Color.continuumBackground.opacity(0.55), location: 0.85),
                .init(color: Color.continuumBackground, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Content column

    private var content: some View {
        VStack(alignment: .leading, spacing: HeroLayout.blockSpacing) {
            editorialColumn

            // Give the action cluster the full hero width with leading
            // content (instead of `HStack { actions(); Spacer() }`) so the
            // selector row inside can stretch its own focus section full-width
            // for Down navigation — a trailing Spacer would split the width
            // with that greedy child and leave the section too narrow.
            // Still a full-width focus destination so lower rails can move
            // "up" into this cluster even from a far-right card.
            actions()
                .padding(.top, HeroLayout.actionsTopInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusSection()
        }
        .padding(.leading, ContinuumTheme.safePadding)
        .padding(.trailing, ContinuumTheme.safePadding)
        .padding(.bottom, HeroLayout.bottomInset)
    }

    private var editorialColumn: some View {
        VStack(alignment: .leading, spacing: HeroLayout.blockSpacing) {
            if let eyebrow, !eyebrow.isEmpty {
                HeroEyebrow(text: eyebrow, floatsOverArtwork: true)
            }
            titleBlock
                .padding(.top, eyebrow == nil ? 0 : 4)
            sourceRow
            if let overview, !overview.isEmpty {
                ExpandableSynopsis(overview: overview)
            }
            belowSynopsis()
            factsRow
        }
        .frame(maxWidth: HeroLayout.contentMaxWidth, alignment: .leading)
    }

    @ViewBuilder
    private var titleBlock: some View {
        if let episodeSeriesTitle {
            HeroEpisodeHierarchyTitle(
                seriesTitle: episodeSeriesTitle,
                episodeTitle: title,
                textAlignment: .leading,
                floatsOverArtwork: true
            )
        } else if let logoUrl, !logoUrl.isEmpty {
            CachedAsyncImage(url: logoUrl, contentMode: .fit, placeholderStyle: .clear)
                .frame(
                    maxWidth: HeroLayout.logoMaxWidth,
                    maxHeight: HeroLayout.logoMaxHeight,
                    alignment: .bottomLeading
                )
                .accessibilityLabel(title)
        } else {
            HeroTitle(title: title, textAlignment: .leading, floatsOverArtwork: true)
        }
    }

    private var episodeSeriesTitle: String? {
        guard let trimmed = seriesTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }

    // MARK: - Source row (type · genre · rating-chip)

    private var sourceRow: some View {
        HeroSourceRow(
            tokens: sourceTokens,
            ratingChip: ratingChip,
            textAlignment: .leading
        )
    }

    // MARK: - Facts + quality row

    private var factsRow: some View {
        HeroFactsRow(tokens: factsLine, alignment: .leading)
    }

    // MARK: - Starring overlay (right-aligned, vertical center)

    @ViewBuilder
    private var starringOverlay: some View {
        if let starringText, !starringText.isEmpty {
            Text(starringText)
                .font(.continuumBody)
                .foregroundColor(Color.white.opacity(0.8))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .frame(maxWidth: HeroLayout.starringMaxWidth, alignment: .trailing)
                .shadow(color: .black.opacity(0.55), radius: 6, y: 2)
                .padding(.trailing, ContinuumTheme.safePadding)
                .padding(.bottom, HeroLayout.heroHeight * HeroLayout.starringHeightFraction)
        }
    }
}

#endif

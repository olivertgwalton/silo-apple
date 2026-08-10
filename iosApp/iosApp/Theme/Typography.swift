import SwiftUI

extension Font {
    #if os(tvOS)

    // tvOS is viewed from ~10 feet away, so all typography is scaled up
    // roughly 2.3x from iOS and uses Apple TV's system text design.

    /// Hero title overlaid on backdrop — massive on TV (76pt bold)
    static let continuumHeroTitle = Font.system(size: 76, weight: .heavy).leading(.tight)

    /// Large screen titles — "Discover", "TV Shows" (48pt bold)
    static let continuumTitle = Font.system(size: 48, weight: .bold)

    /// Section headlines — "Continue Watching" (36pt semibold)
    static let continuumHeadline = Font.system(size: 36, weight: .semibold)

    /// Card titles and subheadlines (28pt semibold)
    static let continuumSubheadline = Font.system(size: 28, weight: .semibold)

    /// Body text — descriptions, synopses (26pt regular)
    static let continuumBody = Font.system(size: 26)

    /// Captions and metadata (22pt regular)
    static let continuumCaption = Font.system(size: 22, weight: .regular)

    /// Smallest text — badges, episode numbers, tab labels (20pt regular)
    static let continuumSmall = Font.system(size: 20, weight: .regular)

    /// Numeric displays like PINs (64pt monospaced bold)
    static let continuumPIN = Font.system(size: 64, weight: .bold, design: .monospaced)

    /// Tracked all-caps eyebrow above a detail-page section title.
    static let continuumSectionEyebrow = Font.system(size: 20, weight: .bold)

    /// Detail-page section title — "Episodes", "Cast & Crew".
    static let continuumSectionTitle = Font.system(size: 42, weight: .semibold)

    /// Right-aligned count/context beside a section title.
    static let continuumSectionTrailing = Font.system(size: 22, weight: .medium)

    /// Actor name on a cast-rail portrait.
    static let continuumCastName = Font.system(size: 22, weight: .semibold)

    /// Character name under an actor on a cast-rail portrait.
    static let continuumCastRole = Font.system(size: 18, weight: .regular)

    /// Detail-hero synopsis body.
    static let continuumSynopsis = Font.system(size: 26, weight: .regular)

    // MARK: - Detail components
    //
    // The steps the detail hero, rails and action controls are set in. These
    // exist because the general scale above is deliberately coarse — eight
    // steps for a whole app — and collapsing the detail screens onto it put
    // several of them two to six points out, and the hero title sixteen. A
    // named step per role keeps the components free of point sizes without
    // rounding the design to the nearest general token.

    /// Detail-hero title, and the series name on an episode hero.
    static let continuumDetailTitle = Font.system(size: 92, weight: .black)
    /// Episode name under the series name on an episode hero.
    static let continuumDetailEpisodeTitle = Font.system(size: 50, weight: .semibold)
    /// Colon-split second line under either of the above.
    static let continuumDetailSubtitle = Font.system(size: 40, weight: .heavy)

    /// Title on a rail card (episode still, trailer).
    static let continuumCardTitle = Font.system(size: 26, weight: .semibold)
    /// Air date / runtime line under a rail-card title.
    static let continuumCardMetadata = Font.system(size: 20, weight: .medium)
    /// All-caps "EPISODE 4" / "TRAILER" eyebrow above a rail-card title.
    static let continuumCardEyebrow = Font.system(size: 18, weight: .bold)
    /// "NOW VIEWING" pill on the card representing the current page.
    static let continuumCardBadge = Font.system(size: 14, weight: .heavy)

    /// Outlined quality chip in a hero facts row (4K / HDR / ATMOS).
    static let continuumFactChip = Font.system(size: 16, weight: .heavy)

    /// Primary play pill in a detail hero.
    static let continuumActionPrimary = Font.system(size: 30, weight: .semibold)
    /// Its darker secondary peer, and the pre-play selector pills.
    static let continuumActionSecondary = Font.system(size: 26, weight: .semibold)

    /// Season chip label.
    static let continuumSeasonChip = Font.system(size: 22, weight: .medium)

    #elseif os(macOS)

    // A Mac is read at desk distance, so body copy stays near the iOS sizes.
    // The display sizes grow instead: a 36pt hero that anchors a phone screen
    // is lost on a window three times as wide.

    /// Hero title overlaid on backdrop (44pt bold, tight tracking)
    static let continuumHeroTitle = Font.system(size: 44, weight: .bold).leading(.tight)

    /// Large screen titles — "Discover", "TV Shows" (22pt bold)
    static let continuumTitle = Font.system(size: 22, weight: .bold)

    /// Section headlines — "Continue Watching" (18pt semibold)
    static let continuumHeadline = Font.system(size: 18, weight: .semibold)

    /// Card titles and subheadlines (15pt semibold)
    static let continuumSubheadline = Font.system(size: 15, weight: .semibold)

    /// Body text — descriptions, synopses (14pt regular)
    static let continuumBody = Font.system(size: 14)

    /// Captions and metadata (12pt regular)
    static let continuumCaption = Font.system(size: 12, weight: .regular)

    /// Smallest text — badges, episode numbers, tab labels (11pt regular)
    static let continuumSmall = Font.system(size: 11, weight: .regular)

    /// Numeric displays like PINs (40pt monospaced bold)
    static let continuumPIN = Font.system(size: 40, weight: .bold, design: .monospaced)

    /// Tracked all-caps eyebrow above a detail-page section title.
    static let continuumSectionEyebrow = Font.system(size: 12, weight: .bold)

    /// Detail-page section title — "Episodes", "Cast & Crew".
    static let continuumSectionTitle = Font.system(size: 26, weight: .semibold)

    /// Right-aligned count/context beside a section title.
    static let continuumSectionTrailing = Font.system(size: 13, weight: .medium)

    /// Actor name on a cast-rail portrait.
    static let continuumCastName = Font.system(size: 13, weight: .semibold)

    /// Character name under an actor on a cast-rail portrait.
    static let continuumCastRole = Font.system(size: 12, weight: .regular)

    /// Detail-hero synopsis body.
    static let continuumSynopsis = Font.system(size: 15, weight: .regular)

    // MARK: - Detail components
    //
    // The steps the detail hero, rails and action controls are set in. These
    // exist because the general scale above is deliberately coarse — eight
    // steps for a whole app — and collapsing the detail screens onto it put
    // several of them two to six points out, and the hero title sixteen. A
    // named step per role keeps the components free of point sizes without
    // rounding the design to the nearest general token.

    /// Detail-hero title, and the series name on an episode hero.
    static let continuumDetailTitle = Font.system(size: 30, weight: .heavy)
    /// Episode name under the series name on an episode hero.
    static let continuumDetailEpisodeTitle = Font.system(size: 22, weight: .semibold)
    /// Colon-split second line under either of the above.
    static let continuumDetailSubtitle = Font.system(size: 13, weight: .heavy)

    /// Title on a rail card (episode still, trailer).
    static let continuumCardTitle = Font.system(size: 14, weight: .semibold)
    /// Air date / runtime line under a rail-card title.
    static let continuumCardMetadata = Font.system(size: 12, weight: .medium)
    /// All-caps "EPISODE 4" / "TRAILER" eyebrow above a rail-card title.
    static let continuumCardEyebrow = Font.system(size: 10, weight: .bold)
    /// "NOW VIEWING" pill on the card representing the current page.
    static let continuumCardBadge = Font.system(size: 9, weight: .heavy)

    /// Outlined quality chip in a hero facts row (4K / HDR / ATMOS).
    static let continuumFactChip = Font.system(size: 10, weight: .heavy)

    /// Primary play pill in a detail hero.
    static let continuumActionPrimary = Font.system(size: 17, weight: .semibold)
    /// Its darker secondary peer, and the pre-play selector pills.
    static let continuumActionSecondary = Font.system(size: 17, weight: .semibold)

    /// Season chip label.
    static let continuumSeasonChip = Font.system(size: 14, weight: .medium)

    #else

    /// Hero title overlaid on backdrop (36pt bold, tight tracking)
    static let continuumHeroTitle = Font.system(size: 36, weight: .bold).leading(.tight)

    /// Large screen titles — "Discover", "TV Shows" (18pt bold)
    static let continuumTitle = Font.system(size: 18, weight: .bold)

    /// Section headlines — "Continue Watching" (16pt semibold)
    static let continuumHeadline = Font.system(size: 16, weight: .semibold)

    /// Card titles and subheadlines (14pt bold)
    static let continuumSubheadline = Font.system(size: 14, weight: .bold)

    /// Body text — descriptions, synopses (14pt regular)
    static let continuumBody = Font.system(size: 14)

    /// Captions and metadata (12pt regular)
    static let continuumCaption = Font.system(size: 12, weight: .regular)

    /// Smallest text — badges, episode numbers, tab labels (11pt regular)
    static let continuumSmall = Font.system(size: 11, weight: .regular)

    /// Numeric displays like PINs (32pt monospaced bold)
    static let continuumPIN = Font.system(size: 32, weight: .bold, design: .monospaced)

    /// Tracked all-caps eyebrow above a detail-page section title.
    static let continuumSectionEyebrow = Font.system(size: 11, weight: .bold)

    /// Detail-page section title — "Episodes", "Cast & Crew".
    static let continuumSectionTitle = Font.system(size: 22, weight: .semibold)

    /// Right-aligned count/context beside a section title.
    static let continuumSectionTrailing = Font.system(size: 13, weight: .medium)

    /// Actor name on a cast-rail portrait.
    static let continuumCastName = Font.system(size: 12, weight: .semibold)

    /// Character name under an actor on a cast-rail portrait.
    static let continuumCastRole = Font.system(size: 11, weight: .regular)

    /// Detail-hero synopsis body.
    static let continuumSynopsis = Font.system(size: 15, weight: .regular)

    // MARK: - Detail components
    //
    // The steps the detail hero, rails and action controls are set in. These
    // exist because the general scale above is deliberately coarse — eight
    // steps for a whole app — and collapsing the detail screens onto it put
    // several of them two to six points out, and the hero title sixteen. A
    // named step per role keeps the components free of point sizes without
    // rounding the design to the nearest general token.

    /// Detail-hero title, and the series name on an episode hero.
    static let continuumDetailTitle = Font.system(size: 30, weight: .heavy)
    /// Episode name under the series name on an episode hero.
    static let continuumDetailEpisodeTitle = Font.system(size: 22, weight: .semibold)
    /// Colon-split second line under either of the above.
    static let continuumDetailSubtitle = Font.system(size: 13, weight: .heavy)

    /// Title on a rail card (episode still, trailer).
    static let continuumCardTitle = Font.system(size: 14, weight: .semibold)
    /// Air date / runtime line under a rail-card title.
    static let continuumCardMetadata = Font.system(size: 12, weight: .medium)
    /// All-caps "EPISODE 4" / "TRAILER" eyebrow above a rail-card title.
    static let continuumCardEyebrow = Font.system(size: 10, weight: .bold)
    /// "NOW VIEWING" pill on the card representing the current page.
    static let continuumCardBadge = Font.system(size: 9, weight: .heavy)

    /// Outlined quality chip in a hero facts row (4K / HDR / ATMOS).
    static let continuumFactChip = Font.system(size: 10, weight: .heavy)

    /// Primary play pill in a detail hero.
    static let continuumActionPrimary = Font.system(size: 17, weight: .semibold)
    /// Its darker secondary peer, and the pre-play selector pills.
    static let continuumActionSecondary = Font.system(size: 17, weight: .semibold)

    /// Season chip label.
    static let continuumSeasonChip = Font.system(size: 14, weight: .medium)

    #endif
}

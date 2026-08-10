import SwiftUI

/// Central design token repository matching Plezy's mono theme.
///
/// Every metric below forks three ways, because the three platforms are read
/// from three distances: a phone at arm's length, a Mac at desk distance with
/// a pointer, and an Apple TV across a room. Keeping the fork here — rather
/// than at call sites — is what lets one view render correctly on all three;
/// see `Font.continuum*` for the typographic half of the same contract.
struct ContinuumTheme {

    // MARK: - Platform scale

    #if os(tvOS)
    /// Uniform scale applied to tvOS — everything is ~2x bigger than iOS.
    static let scale: CGFloat = 2.0
    #elseif os(macOS)
    /// Desk-distance viewing sits between a phone and a TV. Artwork and
    /// spacing get a modest bump; type does not (the Mac renders text at the
    /// same physical size as a phone held closer).
    static let scale: CGFloat = 1.25
    #else
    static let scale: CGFloat = 1.0
    #endif

    // MARK: - Corner Radii

    #if os(tvOS)
    /// Standard card/poster corner radius (12pt on tvOS, larger so focus rings read well)
    static let cornerRadius: CGFloat = 12
    /// Smaller elements like episode thumbnail corners
    static let smallCornerRadius: CGFloat = 8
    /// Card container radius
    static let cardCornerRadius: CGFloat = 18
    #elseif os(macOS)
    /// Slightly softer than the phone radii to match the larger artwork.
    static let cornerRadius: CGFloat = 10
    static let smallCornerRadius: CGFloat = 7
    static let cardCornerRadius: CGFloat = 16
    #else
    /// Standard card/poster corner radius (8pt — Plezy radiusSm)
    static let cornerRadius: CGFloat = 8
    /// Smaller elements like episode thumbnail corners (6pt)
    static let smallCornerRadius: CGFloat = 6
    /// Card container radius (14pt — Plezy CardTheme)
    static let cardCornerRadius: CGFloat = 14
    #endif

    // MARK: - Top Bar

    /// Tap-target frame for chrome-free top-bar icon buttons (Search / Cast).
    /// The glyph stays small; the frame keeps a comfortable 44pt hit area and
    /// sets the rhythm for the evenly spaced top-right cluster.
    static let topBarIconHitSize: CGFloat = 44
    /// Gap between top-bar action items (cast / search / profile). Tuned so the
    /// visible spacing between glyphs reads like Plex's top-right cluster.
    static let topBarIconSpacing: CGFloat = 2

    // MARK: - Spacing

    #if os(tvOS)
    /// Base spacing unit — scaled up for TV
    static let spacing: CGFloat = 24
    /// Standard content padding
    static let padding: CGFloat = 48
    /// Compact padding
    static let smallPadding: CGFloat = 16
    /// Large section spacing
    static let largePadding: CGFloat = 60
    /// Screen safe-area padding — tvOS always wants overscan
    static let safePadding: CGFloat = 80
    #elseif os(macOS)
    /// Base spacing unit
    static let spacing: CGFloat = 14
    /// Standard content padding
    static let padding: CGFloat = 20
    /// Compact padding
    static let smallPadding: CGFloat = 10
    /// Large section spacing
    static let largePadding: CGFloat = 32
    /// Window content inset. A Mac window has no bezel to hide behind, so
    /// content needs a real margin — the phone's 16pt reads as content
    /// jammed against the window frame.
    static let safePadding: CGFloat = 24
    #else
    /// Base spacing unit (12pt — Plezy space token)
    static let spacing: CGFloat = 12
    /// Standard content padding (16pt)
    static let padding: CGFloat = 16
    /// Compact padding (8pt)
    static let smallPadding: CGFloat = 8
    /// Large section spacing (24pt)
    static let largePadding: CGFloat = 24
    /// No extra overscan padding on iOS
    static let safePadding: CGFloat = 16
    #endif

    // MARK: - Detail section headers

    /// Letter tracking on the all-caps eyebrow above a section title. Scales
    /// with the eyebrow's point size so the optical spacing is constant.
    #if os(tvOS)
    static let sectionEyebrowTracking: CGFloat = 3.0
    /// Gap between the eyebrow and the section title.
    static let sectionHeaderSpacing: CGFloat = 10
    #elseif os(macOS)
    static let sectionEyebrowTracking: CGFloat = 1.8
    static let sectionHeaderSpacing: CGFloat = 5
    #else
    static let sectionEyebrowTracking: CGFloat = 1.6
    static let sectionHeaderSpacing: CGFloat = 4
    #endif

    // MARK: - Detail rails
    //
    // A landscape rail card is the one dimension the layout can't derive: a
    // grid can fit `.adaptive` columns to its container, but a free-scrolling
    // rail has no container width to divide. Everything else about these
    // cards — type, corner radius, insets — comes from the tokens above.
    // Matched across the episode and trailer rails so the two line up
    // card-for-card on a page that shows both.

    #if os(tvOS)
    /// Read from across a room: roughly three and a half cards per screen.
    static let railCardWidth: CGFloat = 460
    static let railCardSpacing: CGFloat = 36
    #elseif os(macOS)
    static let railCardWidth: CGFloat = 300
    static let railCardSpacing: CGFloat = 18
    #else
    static let railCardWidth: CGFloat = 240
    static let railCardSpacing: CGFloat = 14
    #endif

    // MARK: - Detail chips and cards
    //
    // Restored to the values the Phone*/TV* components carried before they
    // were merged. The general spacing scale above is too coarse for a chip:
    // rounding a 4pt inset to the nearest 8 doubles it.

    #if os(tvOS)
    static let chipTracking: CGFloat = 1.0
    static let chipHorizontalPadding: CGFloat = 9
    static let chipVerticalPadding: CGFloat = 4
    static let chipLabelPadding: CGFloat = 26
    static let watchedBadgeDiameter: CGFloat = 40
    static let progressBarHeight: CGFloat = 5
    static let railCardVerticalPadding: CGFloat = 32
    static let factsColumnGap: CGFloat = 64
    static let factsRowPadding: CGFloat = 22
    static let factsLabelTracking: CGFloat = 2.0
    #elseif os(macOS)
    static let chipTracking: CGFloat = 0.8
    static let chipHorizontalPadding: CGFloat = 6
    static let chipVerticalPadding: CGFloat = 2
    static let chipLabelPadding: CGFloat = 16
    static let watchedBadgeDiameter: CGFloat = 22
    static let progressBarHeight: CGFloat = 3
    static let railCardVerticalPadding: CGFloat = 4
    static let factsColumnGap: CGFloat = 16
    static let factsRowPadding: CGFloat = 12
    static let factsLabelTracking: CGFloat = 1.2
    #else
    static let chipTracking: CGFloat = 0.8
    static let chipHorizontalPadding: CGFloat = 6
    static let chipVerticalPadding: CGFloat = 2
    static let chipLabelPadding: CGFloat = 16
    static let watchedBadgeDiameter: CGFloat = 22
    static let progressBarHeight: CGFloat = 3
    static let railCardVerticalPadding: CGFloat = 4
    static let factsColumnGap: CGFloat = 16
    static let factsRowPadding: CGFloat = 12
    static let factsLabelTracking: CGFloat = 1.2
    #endif

    // MARK: - Focus
    //
    // Focus appearance, not focus behaviour — `defaultFocus` is applied
    // unconditionally and `focusGroup()` absorbs the one API that is
    // tvOS/macOS-only. These tokens say how loud the focused state looks, and
    // flatten to "no treatment" where a pointer or a finger is the input.

    #if os(tvOS)
    /// Focused cards lift, so their scroll views must not clip them.
    static let cardsLiftOnFocus = true
    static let focusScale: CGFloat = 1.04
    static let focusRingWidth: CGFloat = 3
    static let focusOutlineWidth: CGFloat = 3
    static let focusOutlineInset: CGFloat = 5
    static let cardRestingShadowRadius: CGFloat = 8
    /// Icon-only action button — a comfortable Siri Remote target.
    static let circleControlDiameter: CGFloat = 72
    #elseif os(macOS)
    static let cardsLiftOnFocus = false
    static let focusScale: CGFloat = 1.0
    static let focusRingWidth: CGFloat = 0
    static let focusOutlineWidth: CGFloat = 0
    static let focusOutlineInset: CGFloat = 0
    static let cardRestingShadowRadius: CGFloat = 0
    static let circleControlDiameter: CGFloat = 36
    #else
    static let cardsLiftOnFocus = false
    static let focusScale: CGFloat = 1.0
    static let focusRingWidth: CGFloat = 0
    static let focusOutlineWidth: CGFloat = 0
    static let focusOutlineInset: CGFloat = 0
    static let cardRestingShadowRadius: CGFloat = 0
    /// The 44pt minimum touch target.
    static let circleControlDiameter: CGFloat = 44
    #endif

    /// Ring drawn around the card representing the page you came from. Not a
    /// focus cue — it persists whether or not anything is focused.
    static let currentItemRingWidth: CGFloat = 2

    /// Louder focus treatment for a control that stands alone on a screen —
    /// the Next Up card, the player's own transport — rather than sitting in
    /// a crowded hero row where every neighbour would compete with it.
    static let focusScaleProminent: CGFloat = focusScale == 1.0 ? 1.0 : 1.085
    static let focusOutlineWidthProminent: CGFloat = focusOutlineWidth == 0 ? 0 : 4
    static let focusOutlineInsetProminent: CGFloat = focusOutlineInset == 0 ? 0 : 7

    // MARK: - Detail hero controls

    #if os(tvOS)
    /// The play pill is the one element the eye should land on first.
    static let pillHorizontalPadding: CGFloat = 54
    static let pillVerticalPadding: CGFloat = 26
    #elseif os(macOS)
    static let pillHorizontalPadding: CGFloat = 20
    static let pillVerticalPadding: CGFloat = 12
    #else
    static let pillHorizontalPadding: CGFloat = 24
    static let pillVerticalPadding: CGFloat = 15
    #endif

    /// A secondary pill sits beside the primary and gives back some of its
    /// footprint so the two read as a hierarchy rather than a pair.
    static let secondaryPillPaddingScale: CGFloat = 0.78

    #if os(tvOS)
    /// Label gutter in the Details key/value list — wide enough that the
    /// longest label ("Content Rating") sets one column, not each row.
    static let factsLabelWidth: CGFloat = 260
    /// A measured line length for long-form copy at this viewing distance.
    static let readableContentWidth: CGFloat = 1400
    #elseif os(macOS)
    static let factsLabelWidth: CGFloat = 120
    static let readableContentWidth: CGFloat = 720
    #else
    static let factsLabelWidth: CGFloat = 100
    static let readableContentWidth: CGFloat = .infinity
    #endif

    // MARK: - Media Aspect Ratios

    /// Movie/show poster (2:3.3 — Plezy uses slightly taller posters)
    static let posterAspectRatio: CGFloat = 2.0 / 3.3

    /// Episode thumbnail (16:9)
    static let thumbnailAspectRatio: CGFloat = 16.0 / 9.0

    // MARK: - Media Card Dimensions
    //
    // There are none. Cards state an aspect ratio and fill the cell their
    // grid or rail gives them (`GridItem(.adaptive)`,
    // `containerRelativeFrame`), so artwork scales with the window on macOS
    // and iPad instead of being pinned to a per-platform constant. The
    // aspect ratios above are the whole contract.

    /// Profile avatar size
    #if os(tvOS)
    static let profileAvatarSize: CGFloat = 160
    #elseif os(macOS)
    static let profileAvatarSize: CGFloat = 96
    #else
    static let profileAvatarSize: CGFloat = 80
    #endif

    /// Room a full-page placeholder (`ContentUnavailableView`, a spinner)
    /// reserves so it reads as centered in the empty area rather than pinned
    /// under whatever sits above it.
    #if os(tvOS)
    static let placeholderMinHeight: CGFloat = 520
    #elseif os(macOS)
    static let placeholderMinHeight: CGFloat = 360
    #else
    static let placeholderMinHeight: CGFloat = 280
    #endif

    /// Inset above a scrolling page's first row of content. On tvOS a page
    /// sitting under the floating top menu bar has to clear it; a page pushed
    /// onto the navigation stack (which hides the bar) does not.
    static func pageTopInset(underTopMenuBar: Bool) -> CGFloat {
        #if os(tvOS)
        underTopMenuBar ? TVTopMenuLayout.contentTopInset : padding
        #else
        smallPadding
        #endif
    }

    // MARK: - Animation Durations (Plezy mono_tokens)

    /// Fast — focus state changes, hover effects (120ms)
    static let fastDuration: Double = 0.12

    /// Normal — tab transitions, chip selection (200ms)
    static let normalDuration: Double = 0.20

    /// Slow — image crossfades, content reveals (300ms)
    static let slowDuration: Double = 0.30

    /// Standard spring animation
    static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.85)

    #if os(tvOS)
    // MARK: - Skyline chrome metrics (tvOS)

    /// Skyline navigation chrome tokens (design guide §4–§5). Values are
    /// mockup pixels at 1920×1080, which render 1:1 as points on tvOS.
    enum Skyline {
        /// Root horizontal inset for chrome and content — `safeArea.x`.
        static let safeAreaX: CGFloat = 88
        /// Top bar offset from the screen's top edge — `safeArea.top`.
        static let barTopInset: CGFloat = 56
        /// Top bar row height.
        static let barHeight: CGFloat = 64
        /// Gap between tab capsules in the bar's center cluster.
        static let tabSpacing: CGFloat = 8
        static let tabLabelSize: CGFloat = 26
        static let tabPaddingHorizontal: CGFloat = 29
        static let tabPaddingVertical: CGFloat = 12
        /// Square hit target of the search button and the profile avatar.
        static let barIconSize: CGFloat = 58
        static let wordmarkSize: CGFloat = 26
        /// Wordmark letter tracking — +0.34 em.
        static let wordmarkTracking: CGFloat = 26 * 0.34
        /// Bar opacity while focus is down in the content zone (§5.1).
        static let barDimmedOpacity: Double = 0.7
        /// Upward drift of incoming sub-pill content on a pill switch
        /// (§4.2: "200 ms crossfade + 12 px upward drift of incoming
        /// content"). Paired with the shared 200 ms `normalDuration`.
        static let pillDriftY: CGFloat = 12

        /// A–Z alphabet rail letter size when expanded (§6.4: "mono 15").
        /// Rendered monospaced; the collapsed edge peek uses a smaller frame.
        static let alphabetRailLetterSize: CGFloat = 15

        /// Top inset for library-tab content that has no hero of its own
        /// (grids, chip clouds): clears the bar and the pill row.
        static let libraryContentTopInset: CGFloat = 216
        /// Anchored dropdown panel (§5.3/§5.8).
        static let dropdownWidth: CGFloat = 460
        static let dropdownCornerRadius: CGFloat = 22
        static let dropdownPadding: CGFloat = 14
        static let dropdownRowTextSize: CGFloat = 22
        static let dropdownHeaderSize: CGFloat = 14
        /// Panel top offset — anchored just under the bar.
        static let dropdownTopInset: CGFloat = 132

        // MARK: Cascading library selector (§5.3)

        /// Focus-dwell before a library tab (or the profile avatar) opens
        /// its anchored panel. Sweeping across the bar never opens it;
        /// resting this long does. Tuned per Open-Q5/Q7 on device.
        static let cascadeDwellMilliseconds: UInt64 = 250
        /// Cascade open scale-up start (§4.2: 0.96 → 1.0).
        static let cascadeOpenScale: CGFloat = 0.96
        /// Cascade panel scale/fade duration (§4.2, 180 ms).
        static let cascadeOpenDuration: Double = 0.18
        /// Scrim fade duration behind the cascade (§4.2, 150 ms).
        static let cascadeScrimDuration: Double = 0.15
        /// Level-1 library row metrics (§5.3).
        static let cascadeRowTextSize: CGFloat = 22
        static let cascadeRowPaddingHorizontal: CGFloat = 18
        static let cascadeRowPaddingVertical: CGFloat = 16
        static let cascadeRowCornerRadius: CGFloat = 14
        static let cascadeRowIconSize: CGFloat = 30
        /// Library rows visible before the level-1 list scrolls internally.
        static let cascadeMaxVisibleRows = 6

        /// Sections flyout (§5.3, level 2).
        static let flyoutWidth: CGFloat = 300
        static let flyoutCornerRadius: CGFloat = 18
        static let flyoutPadding: CGFloat = 10
        /// Gap between the level-1 panel's right edge and the flyout.
        static let flyoutGap: CGFloat = 18
        static let flyoutRowTextSize: CGFloat = 20
        static let flyoutRowPaddingHorizontal: CGFloat = 16
        static let flyoutRowPaddingVertical: CGFloat = 13
        static let flyoutRowCornerRadius: CGFloat = 12
        static let flyoutHeaderSize: CGFloat = 13
        static let flyoutOpenDuration: Double = 0.16
        /// Rest debounce before the flyout follows focus to a new library
        /// row (§5.3) — rolling the list never thrashes the flyout.
        static let flyoutFollowDebounceMilliseconds: UInt64 = 150

        // MARK: Focus marquee (§5.4/§5.5)

        /// Marquee block bottom inset — Home scale. On a 1080p tvOS canvas,
        /// this lands the marquee's bottom edge at the midpoint so the lower
        /// half can hold the focused row plus a peek of the next row.
        static let marqueeBottomInsetHome: CGFloat = 540
        /// Marquee block bottom inset — library (compact) scale. Matched to
        /// Home so the Skyline feed keeps a consistent 50/50 marquee-to-row
        /// split across Home and library landings.
        static let marqueeBottomInsetLibrary: CGFloat = 540
        /// Marquee content block width.
        static let marqueeContentWidth: CGFloat = 880
        static let marqueeTitleSizeHome: CGFloat = 84
        static let marqueeTitleSizeLibrary: CGFloat = 66
        static let marqueeMetaSizeHome: CGFloat = 20
        static let marqueeMetaSizeLibrary: CGFloat = 19
        static let marqueeSynopsisSize: CGFloat = 22
        /// Synopsis column cap (§4.1) — narrower than the content block.
        static let marqueeSynopsisMaxWidth: CGFloat = 780
        /// Cached server logo art caps in the marquee title slot. With
        /// the row stack owning the lower half of the screen, Home affords
        /// the full §5.4 cap; the library scale stays tighter because the
        /// pill row eats into its band. While a logo is shown the synopsis
        /// drops a line, like a wrapped title.
        static let marqueeLogoMaxWidth: CGFloat = 880
        static let marqueeLogoMaxHeightHome: CGFloat = 200
        static let marqueeLogoMaxHeightLibrary: CGFloat = 150
        /// Codec/HDR badge chip label size (§4.1).
        static let marqueeBadgeSize: CGFloat = 15
        /// Focus must rest this long before the marquee swaps (§4.2) —
        /// rolling through cards never thrashes backdrops.
        static let marqueeRestDebounceMilliseconds = 150
        /// Marquee text + backdrop crossfade duration (§4.2).
        static let marqueeCrossfadeDuration: Double = 0.24

        // MARK: Row band under the marquee (§5.7, revised)

        /// Portion of the screen reserved for the row stack. The focused row
        /// sits at the top of this lower-half band and the following row peeks
        /// below it.
        static let rowBandHeightFraction: CGFloat = 0.50

        /// Bottom inset for the row band, measured from the physical bottom
        /// edge. The row layers ignore the bottom safe area (the ~86pt tvOS
        /// overscan was leaving a dead band under the rail), so this is the
        /// small margin kept below the focused row's captions.
        static let rowBandBottomInset: CGFloat = 20
        /// Vertical gap between the focused row and the passive preview of
        /// the next row.
        static let rowBandPreviewSpacing: CGFloat = 10
        /// Tighter vertical breathing room for the focused Skyline card strip.
        /// Regular rows keep the wider tvOS padding so focus lift has more
        /// space in standard scroll layouts.
        static let rowBandCardVerticalPadding: CGFloat = 14
        /// Dense poster row (§5.6) for Home + Browse. Enough columns that a
        /// full poster row (header + 2:3 poster + title/year) fits in the top
        /// of the lower-half row band while leaving a preview of the next row
        /// below it — the count replaces the old fixed 176pt card width now
        /// that cells size themselves against the row.
        static let densePosterColumnCount = 8

        // MARK: Collections poster grid (§6.3)

        /// Collections render as standard 2:3 poster tiles — the same aspect
        /// ratio the cards state for themselves — in a grid that mirrors the
        /// library Browse grid, so a collection reads as a first-class
        /// browseable card.
        /// 6 flexible columns within the safe area.
        static let collectionGridColumnCount = 6
        static let collectionGridColumnSpacing: CGFloat = 40
        static let collectionGridRowSpacing: CGFloat = 60
        /// Mono group-header size for the collections grid (§6.3, mono
        /// header style — the dropdown mono grammar at grid scale).
        static let collectionGridGroupHeaderSize: CGFloat = 22
    }
    #endif
}

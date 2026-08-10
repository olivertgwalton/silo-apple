import SwiftUI

/// Artwork shape for a `MediaCard`.
enum MediaCardAspect {
    /// 2:3 movie/series poster.
    case poster
    /// 1:1 tile for audiobook covers.
    case square
}

/// tvOS focus visual for a `MediaCard`. Ignored on iOS and macOS, which
/// have no focus engine.
enum MediaCardFocusTreatment {
    /// The system `.card` button style — focus lift, parallax, and halo.
    /// The default, and what every scrolling row uses.
    case nativeCard
    /// White ring + scale with the system halo suppressed, matching the
    /// episode and cast rails. Used by rails that sit among those cards and
    /// would otherwise read as a different component.
    case ring
}

/// Caption geometry beneath a `MediaCard`'s artwork.
///
/// The two cases exist because the app ships two poster treatments today:
/// scrolling rows caption leading-aligned at subheadline size, grids and
/// cover rails caption centered a size down. Declaring both here — rather
/// than in two separate card components — keeps the divergence visible and
/// cheap to collapse if the design settles on one.
enum MediaCardCaptionLayout {
    /// Leading-aligned, `continuumSubheadline` title over `continuumCaption`
    /// metadata. Used by `MediaRow`.
    case rowLeading
    /// Centered, one size down. Used by the tvOS catalog grid and the
    /// audiobook / recommendation cover rails.
    case gridCentered
}

func mediaCardAccessibilityLabel(
    title: String,
    episodeBadge: String?,
    year: Int?,
    isWatched: Bool
) -> String {
    var components = [title]
    if let episodeBadge, !episodeBadge.isEmpty {
        components.append(episodeBadge)
    }
    if let year {
        components.append(String(year))
    }
    if isWatched {
        components.append("Watched")
    }
    return components.joined(separator: ", ")
}

func episodeRailAccessibilityLabel(
    seasonNumber: Int,
    episodeNumber: Int,
    title: String?,
    metadata: String?,
    isCurrent: Bool,
    isPlayed: Bool
) -> String {
    let seasonLabel = seasonNumber == 0 ? "Specials" : "Season \(seasonNumber)"
    var components = ["\(seasonLabel), Episode \(episodeNumber)"]
    if let title, !title.isEmpty {
        components.append(title)
    }
    if let metadata, !metadata.isEmpty {
        components.append(metadata)
    }
    if isCurrent {
        components.append("Now viewing")
    }
    if isPlayed {
        components.append("Watched")
    }
    return components.joined(separator: ", ")
}

/// A poster-style media card with title, year, and optional progress.
/// On tvOS the card uses `.buttonStyle(.card)` which gives proper focus lift,
/// parallax, and title reveal — no manual focus effects required.
struct MediaCard: View {
    let title: String
    let posterUrl: String
    var thumbhash: String? = nil
    var year: Int? = nil
    var progress: Double? = nil
    var userState: MediaItemUserState? = nil
    /// Data for the optional overlay badges (resolution, ratings, …).
    /// `nil` skips overlay rendering on this card — callers that
    /// don't have an `OverlaySummary` available (e.g. people /
    /// collection thumbnails) leave this off.
    var overlayData: OverlayData? = nil
    let action: () -> Void
    /// tvOS-only shortcut invoked by the remote's Play/Pause button while
    /// this card owns focus. Select continues to invoke `action`.
    var playAction: (() -> Void)? = nil
    /// tvOS-only: binding to the parent row's `@FocusState` so the parent
    /// can route default focus (`defaultFocus(_:_:priority: .userInitiated)`)
    /// to a specific card. Pass `nil` for callers that don't need row-level
    /// focus targeting.
    var focusedItemId: FocusState<String?>.Binding? = nil

    var contentId: String? = nil
    var onRemoveFromContinueWatching: (() -> Void)? = nil
    var onSetWatched: ((Bool) async -> Bool)? = nil
    var aspect: MediaCardAspect = .poster
    /// "S2 · E10" badge drawn over the bottom-leading corner of the poster
    /// for episodes rendered in a poster row (e.g. "Recently Released
    /// Episodes"). `nil` for movies / series / audiobooks.
    var episodeBadge: String? = nil
    /// Fires after a favorite/watchlist toggle from the card's context
    /// menu commits server-side, with the item's new state. Favorites /
    /// Watchlist grids use it to drop the card from the list in place.
    var onUserStateChanged: ((MediaItemUserState) -> Void)? = nil
    /// Second caption line, rendered in place of the year — e.g. "Book 3" on
    /// audiobook series rails. tvOS only (off tvOS the caption shows the year).
    var subtitle: String? = nil
    /// tvOS focus visual. See `MediaCardFocusTreatment`.
    var focusTreatment: MediaCardFocusTreatment = .nativeCard
    /// tvOS caption geometry. See `MediaCardCaptionLayout`.
    var captionLayout: MediaCardCaptionLayout = .rowLeading
    /// tvOS: make this card its focus scope's default target, so d-pad entry
    /// lands here rather than on the geometrically-nearest card.
    var prefersDefaultFocus: Bool = false
    /// Namespace the `prefersDefaultFocus` request resolves in.
    var defaultFocusNamespace: Namespace.ID? = nil

    @State private var playedOverride: Bool?
    @State private var favoriteOverride: Bool?
    @State private var watchlistOverride: Bool?
    @State private var uiCustomization = UICustomizationPreferences.shared
    @EnvironmentObject private var overlayStore: OverlayPrefsStore
    /// iOS 26 zoom transition namespace, shared from `MainTabView`. When
    /// present (and `contentId` is non-nil) the poster acts as the
    /// `.matchedTransitionSource` for the zoom into item detail. `nil` on
    /// tvOS/macOS or when unset, in which case the tap falls back to a plain
    /// push. (iOS branch only — tvOS uses focus-driven `.card` style.)
    @Environment(\.zoomNamespace) private var zoomNamespace
    #if !os(tvOS)
    @Environment(AppRouter.self) private var router
    /// Stable per-placement id for the zoom source. A bare `contentId` collides
    /// when the same item is visible in two rows (e.g. Continue Watching +
    /// Recently Added), making SwiftUI pick an ambiguous source; a per-instance
    /// id keeps each card's source unique and the tapped card's id is handed to
    /// the destination via `router.pendingZoomSourceID`.
    @State private var zoomInstanceID = UUID()
    #endif

    /// Width ÷ height of the artwork. The card claims no absolute size of its
    /// own: it fills whatever cell the grid or rail hands it and derives its
    /// height from this. Column count and rail cell width are the layout's
    /// job (`GridItem(.adaptive)`, `containerRelativeFrame`), which is what
    /// lets one card serve a phone, a resizable Mac window, and a TV.
    private var aspectRatio: CGFloat {
        switch aspect {
        case .poster: ContinuumTheme.posterAspectRatio
        case .square: 1
        }
    }

    var body: some View {
        #if os(tvOS)
        // tvOS: button label is just the poster (so .card style lifts the image),
        // then a title caption lives outside the button and reacts to focus via FocusState.
        FocusableMediaCard(
            title: title,
            year: year,
            subtitle: subtitle,
            episodeBadge: episodeBadge,
            captionStyle: uiCustomization.cardPresentation.caption,
            captionLayout: captionLayout,
            focusTreatment: focusTreatment,
            prefersDefaultFocus: prefersDefaultFocus,
            defaultFocusNamespace: defaultFocusNamespace,
            action: action,
            playAction: playAction,
            focusedItemId: focusedItemId,
            itemId: contentId,
            isWatched: isPlayed,
            onRemoveFromContinueWatching: onRemoveFromContinueWatching,
            onSetWatched: onSetWatched.map { handler in
                { played in
                    playedOverride = played
                    let succeeded = await handler(played)
                    if !succeeded {
                        playedOverride = nil
                    }
                    return succeeded
                }
            },
            personalItems: hasPersonalActions ? personalMenuItems : nil
        ) {
            posterImage
        }
        .onChange(of: userState) { _, _ in
            playedOverride = nil
            favoriteOverride = nil
            watchlistOverride = nil
        }
        #else
        Group {
            if hasIOSContextActions {
                iosCardButton.contextMenu {
                    iosContextActions
                }
            } else {
                iosCardButton
            }
        }
        .onChange(of: userState) { _, _ in
            playedOverride = nil
            favoriteOverride = nil
            watchlistOverride = nil
        }
        #endif
    }

    #if !os(tvOS)
    private var iosCardButton: some View {
        Group {
            if let contentId {
                Button {
                    router.pendingZoomSourceID = zoomInstanceID.uuidString
                    router.navigate(to: .itemDetail(contentId: contentId))
                } label: {
                    cardContent
                        .zoomTransitionSource(id: zoomInstanceID.uuidString, in: zoomNamespace)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var hasIOSContextActions: Bool {
        hasPersonalActions || onSetWatched != nil || onRemoveFromContinueWatching != nil
    }

    /// Same action set (and ordering) as the tvOS `FocusableMediaCard` menu:
    /// watched toggle, favorite/watchlist, then the destructive remove.
    @ViewBuilder
    private var iosContextActions: some View {
        if let onSetWatched {
            Button {
                let played = !isPlayed
                Task { @MainActor in
                    playedOverride = played
                    let succeeded = await onSetWatched(played)
                    if !succeeded {
                        playedOverride = nil
                    }
                }
            } label: {
                Label(
                    isPlayed ? "Mark as Unwatched" : "Mark as Watched",
                    systemImage: isPlayed ? "circle" : "checkmark.circle"
                )
            }
        }

        if hasPersonalActions {
            personalMenuItems
        }

        if let onRemoveFromContinueWatching {
            Button(role: .destructive) {
                onRemoveFromContinueWatching()
            } label: {
                Label("Remove from Continue Watching", systemImage: "xmark.circle")
            }
        }
    }
    #endif

    // MARK: - Favorite / watchlist context actions

    /// Only cards backed by a catalog item (a `contentId` plus server
    /// user state) get the favorite/watchlist menu — thumbnails without
    /// user state (people, collections, discover results) don't.
    private var hasPersonalActions: Bool {
        contentId != nil && userState != nil
    }

    private var isFavorite: Bool {
        favoriteOverride ?? (userState?.isFavorite == true)
    }

    private var isInWatchlist: Bool {
        watchlistOverride ?? (userState?.inWatchlist == true)
    }

    private var personalMenuItems: PersonalListMenuItems {
        PersonalListMenuItems(
            isFavorite: isFavorite,
            inWatchlist: isInWatchlist,
            onToggleFavorite: togglePersonalFavorite,
            onToggleWatchlist: togglePersonalWatchlist
        )
    }

    private func togglePersonalFavorite() {
        guard let contentId else { return }
        let newValue = !isFavorite
        let watchlist = isInWatchlist
        favoriteOverride = newValue
        Task {
            if await PersonalListSync.setFavorite(
                contentId: contentId, isFavorite: newValue, inWatchlist: watchlist
            ) {
                onUserStateChanged?(
                    MediaItemUserState(played: isPlayed, isFavorite: newValue, inWatchlist: watchlist)
                )
            } else {
                favoriteOverride = !newValue // Revert on failure
            }
        }
    }

    private func togglePersonalWatchlist() {
        guard let contentId else { return }
        let newValue = !isInWatchlist
        let favorite = isFavorite
        watchlistOverride = newValue
        Task {
            if await PersonalListSync.setWatchlist(
                contentId: contentId, isFavorite: favorite, inWatchlist: newValue
            ) {
                onUserStateChanged?(
                    MediaItemUserState(played: isPlayed, isFavorite: favorite, inWatchlist: newValue)
                )
            } else {
                watchlistOverride = !newValue // Revert on failure
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            posterImage
            if uiCustomization.cardPresentation.caption.showsTitle {
                titleText
            }
            if uiCustomization.cardPresentation.caption.showsMetadata {
                yearText
            }
        }
    }

    // MARK: - Subviews

    private var posterImage: some View {
        // `Color.clear` + `aspectRatio` is the sizing contract: the card takes
        // the cell's width and computes its own height, so nothing downstream
        // needs a hardcoded poster dimension. Every badge is an `overlay`
        // anchored to an edge rather than a view framed to a known size.
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                CachedAsyncImage(url: posterUrl, thumbhash: thumbhash, contentMode: .fill)
            }
            // Server / user-customized overlays (resolution, HDR, ratings, …)
            // sit under the watched check + progress bar so those built-in
            // affordances always win the same corner if they conflict.
            .overlay {
                if let overlayData, overlayStore.enabled {
                    CardOverlays(data: overlayData, prefs: overlayStore.prefs)
                }
            }
            // Episode badge (e.g. "S2 · E10") for episodes shown as posters,
            // so new episodes of the same series stay distinguishable.
            .overlay(alignment: .bottomLeading) {
                if let episodeBadge {
                    Text(episodeBadge)
                        .font(.continuumCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, episodeBadgeHPadding)
                        .padding(.vertical, episodeBadgeVPadding)
                        .background(Capsule().fill(Color.black.opacity(0.65)))
                        .padding(episodeBadgeInset)
                }
            }
            .overlay(alignment: .bottom) {
                if let progress, progress > 0 {
                    ProgressBar(value: progress)
                }
            }
            // Watched indicator — white circle with check (Plezy style)
            .overlay(alignment: .topTrailing) {
                if isPlayed {
                    ZStack {
                        Circle()
                            .fill(Color.continuumOnSurface)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                        Image(systemName: "checkmark")
                            .font(.system(size: checkIconSize, weight: .bold))
                            .foregroundColor(Color.continuumBackground)
                    }
                    .frame(width: checkBadgeSize, height: checkBadgeSize)
                    .padding(checkBadgePadding)
                }
            }
            // Pins itself bottom-trailing; just needs to span the card.
            .overlay {
                #if !os(tvOS)
                DownloadedBadgeOverlay(contentId: contentId, padding: checkBadgePadding)
                #endif
            }
            .clipShape(RoundedRectangle(cornerRadius: ContinuumTheme.cornerRadius))
            .compositingGroup()
    }

    private var isPlayed: Bool {
        playedOverride ?? (userState?.played == true)
    }

    private var accessibilityDescription: String {
        mediaCardAccessibilityLabel(
            title: title,
            episodeBadge: episodeBadge,
            year: year,
            isWatched: isPlayed
        )
    }

    private var titleText: some View {
        Text(title)
            .font(.continuumSubheadline)
            .foregroundColor(.continuumOnSurface)
            // Reserve 2 lines of space so single- and multi-line titles
            // produce the same overall card height — keeps posters in a
            // row top-aligned when titles wrap.
            .lineLimit(2, reservesSpace: true)
    }

    @ViewBuilder
    private var yearText: some View {
        if let year {
            Text(String(year))
                .font(.continuumCaption)
                .foregroundColor(.continuumSecondaryText)
        }
    }

    // MARK: - Metric helpers

    private var checkBadgeSize: CGFloat {
        #if os(tvOS)
        return 40
        #else
        return 20
        #endif
    }

    private var checkIconSize: CGFloat {
        #if os(tvOS)
        return 20
        #else
        return 10
        #endif
    }

    private var checkBadgePadding: CGFloat {
        #if os(tvOS)
        return 12
        #else
        return 6
        #endif
    }

    private var episodeBadgeHPadding: CGFloat {
        #if os(tvOS)
        return 14
        #else
        return 8
        #endif
    }

    private var episodeBadgeVPadding: CGFloat {
        #if os(tvOS)
        return 7
        #else
        return 4
        #endif
    }

    private var episodeBadgeInset: CGFloat {
        #if os(tvOS)
        return 14
        #else
        return 6
        #endif
    }
}

// MARK: - Zoom transition source helper

extension View {
    /// Marks this view as the `.matchedTransitionSource` for the iOS 26
    /// poster → detail zoom, keyed on the item's `contentId`. No-ops when the
    /// namespace is `nil` (tvOS/macOS, or when the shared namespace is unset),
    /// so callers get a plain push with no crash. Shared by `MediaCard` and
    /// `EpisodeThumbCard` (both in this module).
    @ViewBuilder
    func zoomTransitionSource(id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}

// MARK: - tvOS Focusable wrapper

#if os(tvOS)
/// Wraps a poster inside a `.card` button so the image gets the native focus
/// lift/parallax, and renders a title + year below that bolds/brightens on focus.
private struct FocusableMediaCard<Content: View>: View {
    let title: String
    let year: Int?
    /// Replaces the year on the caption's second line when present.
    let subtitle: String?
    let episodeBadge: String?
    let captionStyle: CardCaptionStyle
    let captionLayout: MediaCardCaptionLayout
    let focusTreatment: MediaCardFocusTreatment
    let prefersDefaultFocus: Bool
    let defaultFocusNamespace: Namespace.ID?
    let action: () -> Void
    let playAction: (() -> Void)?
    /// Parent row's focus tracking binding. When paired with `itemId`,
    /// the button binds via `.focused(_, equals: itemId)` so the row's
    /// `defaultFocus(... priority: .userInitiated)` can land focus here
    /// on d-pad entry.
    let focusedItemId: FocusState<String?>.Binding?
    let itemId: String?
    let isWatched: Bool
    let onRemoveFromContinueWatching: (() -> Void)?
    let onSetWatched: ((Bool) async -> Bool)?
    /// Favorite / watchlist toggles, built by the owning card. `nil`
    /// when the card has no catalog identity or user state.
    let personalItems: PersonalListMenuItems?
    @ViewBuilder var content: () -> Content

    @FocusState private var isFocused: Bool

    private var captionAlignment: HorizontalAlignment {
        captionLayout == .gridCentered ? .center : .leading
    }

    private var captionFrameAlignment: Alignment {
        captionLayout == .gridCentered ? .center : .leading
    }

    /// Gap between the artwork and its caption. The centered grid caption
    /// sits tighter under the poster than the row caption, which has to clear
    /// the taller `.card` focus lift.
    private var captionSpacing: CGFloat {
        captionLayout == .gridCentered ? 16 : 22
    }

    var body: some View {
        VStack(alignment: captionAlignment, spacing: captionSpacing) {
            mediaButton

            if captionStyle.showsTitle {
                VStack(alignment: captionAlignment, spacing: 4) {
                    Text(title)
                        .font(captionLayout == .gridCentered ? .continuumCaption.weight(.semibold) : .continuumSubheadline)
                        .foregroundStyle(
                            isFocused
                                ? Color.continuumOnSurface
                                : Color.continuumOnSurface.opacity(
                                    captionLayout == .gridCentered ? 0.92 : 0.85
                                )
                        )
                        // Single line, truncated — keeps poster cards a uniform
                        // height and the row short under the bottom-anchored marquee.
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: isFocused)

                    if captionStyle.showsMetadata, let secondLine = subtitle ?? year.map(String.init) {
                        Text(secondLine)
                            .font(.continuumSmall)
                            .foregroundStyle(Color.continuumSecondaryText)
                    }
                }
                .multilineTextAlignment(captionLayout == .gridCentered ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: captionFrameAlignment)
            }
        }
    }

    @ViewBuilder
    private var mediaButton: some View {
        let button = Button(action: action) {
            content()
                // The `.ring` treatment suppresses the system halo in
                // `MediaCardRingButtonStyle`, so the poster draws its own cue.
                .overlay {
                    if focusTreatment == .ring {
                        RoundedRectangle(cornerRadius: ContinuumTheme.cornerRadius)
                            .stroke(
                                Color.white.opacity(isFocused ? 0.9 : 0),
                                lineWidth: isFocused ? 4 : 0
                            )
                            .animation(
                                .easeOut(duration: ContinuumTheme.fastDuration),
                                value: isFocused
                            )
                    }
                }
        }
        .focused($isFocused)
        .applyDefaultFocusIfNeeded(prefersDefaultFocus, namespace: defaultFocusNamespace)
        .applyRowFocus(focusedItemId, itemId: itemId)
        .applyPlayPauseAction(playAction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)

        mediaButtonWithContext(styledButton(button))
    }

    /// `.card` and the ring style have different `ButtonStyle` types, so the
    /// branch has to produce a single erased view rather than two buttons.
    @ViewBuilder
    private func styledButton<ButtonContent: View>(_ button: ButtonContent) -> some View {
        switch focusTreatment {
        case .nativeCard:
            button.buttonStyle(.card)
        case .ring:
            button.buttonStyle(MediaCardRingButtonStyle())
        }
    }

    @ViewBuilder
    private func mediaButtonWithContext<ButtonContent: View>(_ button: ButtonContent) -> some View {
        if hasContextActions {
            button.contextMenu {
                contextActions
            }
        } else {
            button
        }
    }

    private var hasContextActions: Bool {
        onSetWatched != nil || onRemoveFromContinueWatching != nil || personalItems != nil
    }

    private var accessibilityDescription: String {
        mediaCardAccessibilityLabel(
            title: title,
            episodeBadge: episodeBadge,
            year: year,
            isWatched: isWatched
        )
    }

    @ViewBuilder
    private var contextActions: some View {
        if let onSetWatched {
            Button {
                Task { @MainActor in
                    _ = await onSetWatched(!isWatched)
                }
            } label: {
                Label(
                    isWatched ? "Mark as Unwatched" : "Mark as Watched",
                    systemImage: isWatched ? "circle" : "checkmark.circle"
                )
            }
        }

        if let personalItems {
            personalItems
        }

        if let onRemoveFromContinueWatching {
            Button(role: .destructive) {
                onRemoveFromContinueWatching()
            } label: {
                Label("Remove from Continue Watching", systemImage: "xmark.circle")
            }
        }
    }
}

/// Poster focus style matching the episode/cast cards: scale + drop shadow
/// with the system halo suppressed. The white ring the card draws over its
/// artwork is the focus cue. Selected by `MediaCardFocusTreatment.ring`.
private struct MediaCardRingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MediaCardRingButtonBody(configuration: configuration)
    }
}

private struct MediaCardRingButtonBody: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .scaleEffect(scale)
            .shadow(
                color: .black.opacity(isFocused ? 0.45 : 0.0),
                radius: isFocused ? 18 : 0,
                y: isFocused ? 8 : 0
            )
            .focusEffectDisabled()
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: isFocused)
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: configuration.isPressed)
    }

    private var scale: CGFloat {
        let base: CGFloat = isFocused && !reduceMotion ? 1.05 : 1.0
        return configuration.isPressed ? base * 0.97 : base
    }
}

private extension View {
    @ViewBuilder
    func applyPlayPauseAction(_ action: (() -> Void)?) -> some View {
        if let action {
            self.onPlayPauseCommand(perform: action)
        } else {
            self
        }
    }

    /// Conditionally binds this view to the parent row's `@FocusState`
    /// so `defaultFocus(... priority: .userInitiated)` upstream can land
    /// focus on it. No-op when either argument is nil (e.g., on iOS or
    /// when this card isn't inside a row that manages focus).
    @ViewBuilder
    func applyRowFocus(
        _ binding: FocusState<String?>.Binding?,
        itemId: String?
    ) -> some View {
        if let binding, let itemId {
            self.focused(binding, equals: itemId)
        } else {
            self
        }
    }
}
#endif

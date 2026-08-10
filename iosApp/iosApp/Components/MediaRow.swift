import SwiftUI
#if os(tvOS)
import os
#endif

/// Layout mode for a horizontal media row.
/// Poster rows use tall (2:3) poster cards; thumbnail rows use wide 16:9
/// episode stills — pick thumbnail for episode-centric sections like
/// "Next Up" and resume rows like Continue Watching. Square
/// rows use 1:1 tiles for audiobook covers.
enum MediaRowLayout {
    case poster
    case thumbnail
    case square
}

/// A horizontal scrolling row of media cards with a title header.
/// Plezy style: section title with optional icon, safe-area leading padding.
struct MediaRow: View {
    let title: String
    let items: [SectionItem]
    let onItemTap: (String) -> Void
    /// tvOS-only direct-play action for focused leaf items. Container items
    /// intentionally receive no Play/Pause command and retain normal focus.
    var onItemPlay: ((SectionItem) -> Void)? = nil
    var onSeeAll: (() -> Void)? = nil
    var showProgress: Bool = false
    var icon: String? = nil
    var layout: MediaRowLayout = .poster
    /// When true (and there are items), the row's first card becomes the
    /// default focus target — on initial appearance AND on user-driven
    /// d-pad entry into the row's focus section. Implemented via
    /// `.defaultFocus($focusedItemId, firstId, priority: .userInitiated)`;
    /// see CLAUDE.md's "tvOS default focus on d-pad entry" pattern.
    var prefersDefaultFocusOnFirstItem: Bool = false
    /// Priority for the first-item default focus. `.userInitiated` (the
    /// default) also snaps d-pad entry into the row onto the first card;
    /// pass `.automatic` when only the engine's own resolutions (initial
    /// focus on cold launch) should use the preference, keeping directional
    /// entry geometric.
    var defaultFocusPriority: DefaultFocusEvaluationPriority = .userInitiated
    /// Programmatic kick: when this value changes to non-zero, focus
    /// jumps to the first item. Used by callers (e.g. PlayerView) that
    /// shift focus from an unrelated view rather than via d-pad entry —
    /// where `.userInitiated` defaultFocus alone doesn't fire because the
    /// focus engine isn't doing the moving.
    var focusRequest: Int = 0
    var onRemoveFromContinueWatching: ((SectionItem) -> Void)? = nil
    var onSetWatched: ((SectionItem, Bool) async -> Bool)? = nil
    /// tvOS-only: reports which of the row's items holds card focus —
    /// the Skyline focus marquee mirrors it. Fires on focus gain only;
    /// focus leaving the row (nil) is deliberately not reported so the
    /// marquee retains the last previewed item while focus is in chrome.
    var onItemFocus: ((SectionItem) -> Void)? = nil
    /// How many cards span the row's width. Cells derive their width from
    /// this via `containerRelativeFrame`, so the row re-flows with the window
    /// instead of drawing fixed-size cards. Skyline's dense landing rows
    /// (§5.6) raise the count to fit more, smaller posters above the fold.
    /// `nil` takes the platform default.
    var visibleCardCount: Int? = nil
    /// Optional tvOS-only vertical padding override for the card strip.
    /// Standard rows keep the default breathing room for focus lift.
    var cardVerticalPadding: CGFloat? = nil
    /// Down at the row's boundary — used by the Skyline section pager to
    /// page to the next section (there is no row geometrically below).

    @FocusState private var focusedItemId: String?
    #if os(tvOS)
    /// Each focus token is applied once. Tracked so the claim works on a
    /// freshly-mounted row too (the Skyline section pager swaps the row's
    /// identity per page, so the kick has to land on `onAppear`, not only
    /// on a `focusRequest` change).
    @State private var lastAppliedFocusRequest = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Scope the programmatic kick re-resolves focus within.
    @Namespace private var rowFocusScope
    @Environment(\.resetFocus) private var resetFocus
    private static let focusLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.continuum.app",
        category: "TVFocus"
    )
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: rowVerticalSpacing) {
            header
            scrollContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(tvOS)
        .focusSection()
        .onChange(of: focusedItemId) { _, newValue in
            guard let newValue,
                  let item = items.first(where: { $0.contentId == newValue }) else { return }
            Self.focusLogger.debug("mediaRow.focus changed")
            onItemFocus?(item)
        }
        #endif
    }

    #if os(tvOS)
    private func applyFocusRequest(_ request: Int, proxy: ScrollViewProxy) {
        guard request > 0, request != lastAppliedFocusRequest,
              let firstItem = items.first else { return }
        lastAppliedFocusRequest = request
        withAnimation(reduceMotion ? nil : .easeInOut(duration: ContinuumTheme.slowDuration)) {
            proxy.scrollTo(firstItem.id, anchor: .leading)
        }
        Self.focusLogger.debug("mediaRow.applyFocus request=\(request, privacy: .public)")
        resetFocus(in: rowFocusScope)
    }
    #endif

    // MARK: - Header

    private var header: some View {
        HStack(spacing: headerIconSpacing) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: headerIconSize, weight: .semibold))
                    .foregroundColor(.continuumOnSurface)
            }

            Text(title)
                .font(.continuumHeadline)
                .foregroundColor(.continuumOnSurface)

            Spacer()

            if let onSeeAll {
                Button("See All") {
                    onSeeAll()
                }
                .font(.continuumCaption)
                .foregroundColor(.continuumOnSurface.opacity(0.6))
            }
        }
        .padding(.horizontal, ContinuumTheme.safePadding)
    }

    // MARK: - Content

    private var scrollContent: some View {
        ScrollViewReader { rowProxy in
            scrollStrip(rowProxy)
        }
    }

    private func scrollStrip(_ rowProxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: cardSpacing) {
                ForEach(items) { item in
                    Group {
                        switch layout {
                        case .poster, .square:
                            MediaCard(
                                title: posterTitle(for: item),
                                posterUrl: item.posterUrl ?? "",
                                thumbhash: item.posterThumbhash,
                                year: item.year,
                                progress: progressValue(for: item),
                                userState: item.userState,
                                overlayData: OverlayData.from(item),
                                action: { onItemTap(item.contentId) },
                                playAction: playAction(for: item),
                                focusedItemId: rowFocusBinding,
                                contentId: item.contentId,
                                onRemoveFromContinueWatching: continueWatchingRemovalAction(for: item),
                                onSetWatched: watchedToggleAction(for: item),
                                aspect: layout == .square ? .square : .poster,
                                episodeBadge: episodeBadge(for: item)
                            )
                        case .thumbnail:
                            EpisodeThumbCard(
                                item: item,
                                showProgress: showProgress,
                                action: { onItemTap(item.contentId) },
                                playAction: playAction(for: item),
                                focusedItemId: rowFocusBinding,
                                onRemoveFromContinueWatching: continueWatchingRemovalAction(for: item),
                                onSetWatched: watchedToggleAction(for: item)
                            )
                        }
                    }
                    .containerRelativeFrame(
                        .horizontal,
                        count: resolvedCardCount,
                        span: 1,
                        spacing: cardSpacing
                    )
                }
            }
            .padding(.vertical, verticalCardPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The gutter is a content *margin*, not padding inside the scroll
        // content, for two reasons. On tvOS, programmatic
        // `scrollTo(anchor: .leading)` and the engine's scroll-to-focused both
        // align to the margin-inset viewport, so inner padding makes them
        // overshoot left by the gutter width and visibly drift back. And
        // everywhere, `containerRelativeFrame` measures the scroll view rather
        // than the inset content, so the margin is what lets the next card
        // peek past the edge — the cue that the row scrolls at all.
        .contentMargins(.horizontal, ContinuumTheme.safePadding, for: .scrollContent)
        #if os(tvOS)
        // tvOS focus lift expands cards on focus — give them breathing room
        // so they don't clip against the row above/below.
        .scrollClipDisabled()
        .applyDefaultFirstItemFocus(
            enabled: prefersDefaultFocusOnFirstItem,
            binding: $focusedItemId,
            firstItemId: items.first?.contentId,
            priority: defaultFocusPriority
        )
        // `resetFocus(in:)` re-resolves within this scope, which is what makes
        // the default-focus preference above fire for a programmatic kick.
        .focusScope(rowFocusScope)
        // The programmatic focus kick needs the scroll proxy (it scrolls the
        // strip home before claiming), so it hangs off the strip rather than
        // the row's outer stack.
        .onAppear { applyFocusRequest(focusRequest, proxy: rowProxy) }
        .onChange(of: focusRequest) { _, request in applyFocusRequest(request, proxy: rowProxy) }
        #endif
    }

    /// tvOS: bind every card to the row's @FocusState so the row can
    /// drive focus to a specific item via `defaultFocus(..)` or by
    /// setting `focusedItemId` directly (from the `focusRequest` kick).
    /// iOS doesn't have focus targets, so cards skip the binding.
    private var rowFocusBinding: FocusState<String?>.Binding? {
        #if os(tvOS)
        return $focusedItemId
        #else
        return nil
        #endif
    }

    private func progressValue(for item: SectionItem) -> Double? {
        // Watched items store position 0 server-side (the watched latch and
        // the resume point are independent), so a nonzero position is always
        // a live resume point — including a rewatch of a played item.
        guard showProgress,
              let pos = item.positionSeconds,
              let dur = item.durationSeconds,
              dur > 0, pos > 0 else { return nil }
        return pos / dur
    }

    private func playAction(for item: SectionItem) -> (() -> Void)? {
        #if os(tvOS)
        guard SiloMediaType.isDirectlyPlayable(item.type), let onItemPlay else { return nil }
        return { onItemPlay(item) }
        #else
        return nil
        #endif
    }

    private func continueWatchingRemovalAction(for item: SectionItem) -> (() -> Void)? {
        guard let onRemoveFromContinueWatching else { return nil }
        return { onRemoveFromContinueWatching(item) }
    }

    private func watchedToggleAction(for item: SectionItem) -> ((Bool) async -> Bool)? {
        guard let onSetWatched else { return nil }
        return { played in await onSetWatched(item, played) }
    }

    /// Caption for a poster card. Episodes are captioned with the series name
    /// — the bare `title` is the episode title (often "TBA" when unannounced).
    private func posterTitle(for item: SectionItem) -> String {
        item.type.lowercased() == "episode" ? (item.seriesTitle ?? item.title) : item.title
    }

    /// "S2 · E10" badge for an episode rendered as a poster, so new episodes
    /// of the same series stay distinguishable. `nil` for non-episodes.
    private func episodeBadge(for item: SectionItem) -> String? {
        guard item.type.lowercased() == "episode" else { return nil }
        return EpisodeCode.format(season: item.seasonNumber, episode: item.episodeNumber)
    }

    // MARK: - Metrics

    private var rowVerticalSpacing: CGFloat {
        #if os(tvOS)
        return 20
        #else
        return ContinuumTheme.smallPadding
        #endif
    }

    private var headerIconSize: CGFloat {
        #if os(tvOS)
        return 32
        #else
        return 16
        #endif
    }

    private var headerIconSpacing: CGFloat {
        #if os(tvOS)
        return 14
        #else
        return 6
        #endif
    }

    /// Cards visible across the row. Sizing the cells off a count rather than
    /// a fixed width is what makes the row behave on a resized Mac window and
    /// in iPad Split View; the scroll view's content margin then lets the next
    /// card peek, which is the affordance that says the row scrolls.
    private var resolvedCardCount: Int {
        if let visibleCardCount { return visibleCardCount }
        switch layout {
        case .thumbnail:
            #if os(tvOS)
            return 4
            #elseif os(macOS)
            return 4
            #else
            return 2
            #endif
        case .poster, .square:
            #if os(tvOS)
            return 6
            #elseif os(macOS)
            return 6
            #else
            return 3
            #endif
        }
    }

    private var cardSpacing: CGFloat {
        #if os(tvOS)
        return 40
        #else
        return ContinuumTheme.spacing
        #endif
    }

    /// Vertical padding on the row content so focus lift doesn't clip.
    private var verticalCardPadding: CGFloat {
        #if os(tvOS)
        if let cardVerticalPadding {
            return cardVerticalPadding
        }

        return 24
        #else
        return 0
        #endif
    }
}

#if os(tvOS)
private extension View {
    /// Routes both initial and user-initiated (d-pad) focus into the
    /// row's first card. The `.userInitiated` priority is the bit that
    /// `prefersDefaultFocus(_:in:)` lacks — it makes default focus win
    /// over geometric proximity on d-pad entry. See CLAUDE.md's "tvOS
    /// default focus on d-pad entry" pattern.
    @ViewBuilder
    func applyDefaultFirstItemFocus(
        enabled: Bool,
        binding: FocusState<String?>.Binding,
        firstItemId: String?,
        priority: DefaultFocusEvaluationPriority
    ) -> some View {
        if enabled, let firstItemId {
            self.defaultFocus(binding, firstItemId, priority: priority)
        } else {
            self
        }
    }
}
#endif

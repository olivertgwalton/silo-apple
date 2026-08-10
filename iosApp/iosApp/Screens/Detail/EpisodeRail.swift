import SwiftUI

/// Horizontal rail of episode cards used on the series, season, and episode
/// detail pages. Selecting a card navigates to that episode's detail page —
/// the rail is a browsing surface, not a direct play launcher.
///
/// One view, no platform branches, no dimensions of its own: type comes from
/// the semantic scale, spacing and radii from `ContinuumTheme`, and the card
/// width from `ContinuumTheme.railCardWidth` — matched to `TrailersRail` so
/// the two landscape rails line up card-for-card on a page showing both.
///
/// Pass `currentContentId` to highlight the episode the surrounding page
/// represents; the rail centers that card on first appearance. The watched /
/// favorite context actions appear only where the caller supplies handlers.
struct EpisodeRail: View {
    let episodes: [EpisodeListItem]
    let onSelect: (String) -> Void
    /// Reports which card holds focus, so a page can track the rail's
    /// position. Never fires where nothing can take focus.
    var onFocusedEpisodeChange: ((String?) -> Void)? = nil
    var onSetWatched: ((_ contentId: String, _ played: Bool) async -> Bool)? = nil
    var onSetFavorite: ((_ contentId: String, _ isFavorite: Bool) async -> Bool)? = nil
    var currentContentId: String? = nil
    var currentContentIsFavorite = false
    var favoriteStates: [String: Bool] = [:]
    /// Land focus on `currentContentId` when the user moves into the rail,
    /// rather than the geometrically nearest card.
    var prefersCurrentContentFocus = false

    @FocusState private var focusedCardId: String?
    @State private var uiCustomization = UICustomizationPreferences.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: ContinuumTheme.railCardSpacing) {
                    ForEach(episodes) { episode in
                        EpisodeCard(
                            episode: episode,
                            isCurrent: currentContentId == episode.contentId,
                            posterSize: uiCustomization.cardPresentation.posterSize,
                            captionStyle: uiCustomization.cardPresentation.caption,
                            onSelect: { onSelect(episode.contentId) },
                            onSetWatched: onSetWatched,
                            initialIsFavorite: currentContentId == episode.contentId
                                ? currentContentIsFavorite
                                : favoriteStates[episode.contentId] ?? false,
                            onSetFavorite: onSetFavorite
                        )
                        .id(episode.contentId)
                        .focused($focusedCardId, equals: episode.contentId)
                    }
                }
                .padding(.horizontal, ContinuumTheme.safePadding)
                .padding(.vertical, ContinuumTheme.smallPadding)
            }
            // Groups the rail for directional entry and lands it on the current
            // episode rather than the geometrically nearest card. Both are inert
            // where nothing takes focus.
            .focusGroup()
            .episodeRailDefaultFocus(
                prefersCurrentContentFocus ? currentContentId : nil,
                binding: $focusedCardId
            )
            .scrollClipDisabled(ContinuumTheme.cardsLiftOnFocus)
            .onChange(of: focusedCardId) { _, contentId in
                onFocusedEpisodeChange?(contentId)
            }
            .onDisappear { onFocusedEpisodeChange?(nil) }
            .onAppear {
                guard let id = currentContentId else { return }
                // Next tick, so the LazyHStack has instantiated the target
                // cell before we try to anchor on it.
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: ContinuumTheme.normalDuration)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Card

struct EpisodeCard: View {
    let episode: EpisodeListItem
    var isCurrent: Bool = false
    var posterSize: CardPosterSize = .standard
    var captionStyle: CardCaptionStyle = .titleMetadata
    let onSelect: () -> Void
    var onSetWatched: ((_ contentId: String, _ played: Bool) async -> Bool)? = nil
    var initialIsFavorite = false
    var onSetFavorite: ((_ contentId: String, _ isFavorite: Bool) async -> Bool)? = nil

    @State private var playedOverride: Bool?
    @State private var favoriteOverride: Bool?

    private var cardWidth: CGFloat { ContinuumTheme.railCardWidth * posterSize.scale }
    private var stillHeight: CGFloat { cardWidth / ContinuumTheme.thumbnailAspectRatio }

    var body: some View {
        let button = Button(action: onSelect) {
            EpisodeCardLabel(
                episode: episode,
                isPlayed: isPlayed,
                isCurrent: isCurrent,
                cardWidth: cardWidth,
                stillHeight: stillHeight,
                captionStyle: captionStyle
            )
        }
        .buttonStyle(DetailCardStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            EpisodeFormatting.accessibilityDescription(for: episode, isCurrent: isCurrent)
        )

        Group {
            if onSetWatched != nil || onSetFavorite != nil {
                button.contextMenu { contextActions }
            } else {
                button
            }
        }
        .onChange(of: episode.userData?.played) { _, refreshedValue in
            guard let playedOverride, refreshedValue == playedOverride else { return }
            self.playedOverride = nil
        }
        .onChange(of: initialIsFavorite) { _, refreshedValue in
            guard let favoriteOverride, refreshedValue == favoriteOverride else { return }
            self.favoriteOverride = nil
        }
    }

    private var isPlayed: Bool {
        playedOverride ?? episode.userData?.played ?? false
    }

    private var isFavorite: Bool {
        favoriteOverride ?? initialIsFavorite
    }

    @ViewBuilder
    private var contextActions: some View {
        if let onSetWatched {
            Button {
                let played = !isPlayed
                playedOverride = played
                Task {
                    if await onSetWatched(episode.contentId, played) == false {
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

        if let onSetFavorite {
            Button {
                let newValue = !isFavorite
                favoriteOverride = newValue
                Task {
                    if await onSetFavorite(episode.contentId, newValue) == false {
                        favoriteOverride = nil
                    }
                }
            } label: {
                Label(
                    isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: isFavorite ? "heart.slash" : "heart"
                )
            }
        }
    }
}

private struct EpisodeCardLabel: View {
    let episode: EpisodeListItem
    let isPlayed: Bool
    let isCurrent: Bool
    let cardWidth: CGFloat
    let stillHeight: CGFloat
    let captionStyle: CardCaptionStyle

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: ContinuumTheme.smallPadding) {
            still
            if captionStyle.showsTitle {
                caption
            }
        }
        .frame(width: cardWidth, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: ContinuumTheme.sectionHeaderSpacing) {
            HStack(spacing: ContinuumTheme.sectionHeaderSpacing) {
                Text(EpisodeFormatting.cardNumberLabel(for: episode))
                    .font(.continuumSectionEyebrow)
                    .tracking(ContinuumTheme.sectionEyebrowTracking)
                    .foregroundStyle(Color.continuumOnSurface.opacity(0.55))
                if isCurrent {
                    nowViewingTag
                }
            }

            Text(EpisodeFormatting.title(for: episode))
                .font(.continuumSubheadline)
                .foregroundStyle(titleColor)
                // Two lines for long titles, but without reserving the second:
                // a single-line title (the common case) was leaving a full
                // empty line of dead space above the description.
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if captionStyle.showsMetadata {
                if let metadataLine = EpisodeFormatting.metadataLine(for: episode) {
                    Text(metadataLine)
                        .font(.continuumCaption)
                        .foregroundStyle(Color.continuumSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.continuumCaption)
                        .foregroundStyle(Color.continuumSecondaryText)
                        .lineLimit(3, reservesSpace: true)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: isFocused)
    }

    private var titleColor: Color {
        if isCurrent { return .continuumOnSurface }
        return isFocused ? .continuumOnSurface : Color.continuumOnSurface.opacity(0.92)
    }

    private var nowViewingTag: some View {
        Text("NOW VIEWING")
            .font(.continuumSectionEyebrow)
            .fontWeight(.heavy)
            .tracking(ContinuumTheme.sectionEyebrowTracking)
            .foregroundColor(.black)
            .padding(.horizontal, ContinuumTheme.sectionHeaderSpacing)
            .padding(.vertical, ContinuumTheme.sectionHeaderSpacing / 2)
            .background(Capsule().fill(Color.white))
    }

    // MARK: - Still

    private var still: some View {
        ZStack(alignment: .bottom) {
            Color.continuumSurfaceElevated

            if let url = episode.stillUrl, !url.isEmpty {
                CachedAsyncImage(
                    url: url,
                    thumbhash: episode.stillThumbhash,
                    targetSize: CGSize(width: cardWidth, height: stillHeight),
                    contentMode: .fill
                )
                .clipped()
            } else {
                Image(systemName: "film")
                    .font(.continuumTitle)
                    .foregroundColor(.continuumSecondaryText)
            }

            if isPlayed {
                Color.black.opacity(0.32)
                watchedBadge
                    .padding(ContinuumTheme.smallPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            if let progress = EpisodeFormatting.progressFraction(for: episode) {
                progressBar(fraction: progress)
            }
        }
        .frame(width: cardWidth, height: stillHeight)
        .clipShape(RoundedRectangle(cornerRadius: ContinuumTheme.smallCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ContinuumTheme.smallCornerRadius)
                .stroke(borderColor, lineWidth: borderWidth)
        }
    }

    private var borderColor: Color {
        if isFocused { return Color.white.opacity(0.9) }
        if isCurrent { return Color.white.opacity(0.7) }
        return .clear
    }

    private var borderWidth: CGFloat {
        if isFocused { return ContinuumTheme.focusRingWidth }
        if isCurrent { return ContinuumTheme.currentItemRingWidth }
        return 0
    }

    private var watchedBadge: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(
                    width: ContinuumTheme.circleControlDiameter / 2,
                    height: ContinuumTheme.circleControlDiameter / 2
                )
                .shadow(color: .black.opacity(0.3), radius: 3)
            Image(systemName: "checkmark")
                .font(.continuumSmall)
                .fontWeight(.bold)
                .foregroundColor(.black)
        }
    }

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.black.opacity(0.6))
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geo.size.width * CGFloat(fraction))
            }
        }
        .frame(height: ContinuumTheme.currentItemRingWidth)
    }
}

// MARK: - Focus

private extension View {
    /// `.userInitiated` priority is what makes `defaultFocus` win over
    /// geometric proximity on entry. Applied only when the caller asked for
    /// the current episode to own it.
    @ViewBuilder
    func episodeRailDefaultFocus(
        _ currentContentId: String?,
        binding: FocusState<String?>.Binding
    ) -> some View {
        if let currentContentId {
            defaultFocus(binding, currentContentId, priority: .userInitiated)
        } else {
            self
        }
    }
}

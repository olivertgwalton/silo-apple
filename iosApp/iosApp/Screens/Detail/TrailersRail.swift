import SwiftUI

/// Horizontal rail of trailer / extra cards under a detail hero.
///
/// One view, no platform branches, no dimensions of its own: type comes from
/// the semantic scale, spacing and radii from `ContinuumTheme`, and the card
/// width from `ContinuumTheme.railCardWidth` — the one measurement a
/// free-scrolling rail can't derive from a container. Focus appearance lives
/// in the button style, reading `\.isFocused`, which is simply always false
/// where a finger or pointer is the input.
///
/// Pure presentation: entries arrive already shaped by the call site, which
/// also owns the YouTube-app availability probe deciding whether remote cards
/// exist at all. The section header lives in here so an item with neither
/// trailers nor extras renders nothing rather than an orphaned title — the
/// same arrangement `SimilarRail` uses.
struct TrailersRail: View {
    let entries: [TrailerRailEntry]
    let onSelect: (TrailerRailEntry) -> Void
    @FocusState private var focusedEntryId: String?

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: ContinuumTheme.spacing) {
                DetailSectionHeader(title: "Trailers & More")
                    .padding(.horizontal, ContinuumTheme.safePadding)
                rail
            }
        }
    }

    private var rail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: ContinuumTheme.railCardSpacing) {
                ForEach(entries) { entry in
                    TrailerCard(entry: entry, onSelect: { onSelect(entry) })
                    .focused($focusedEntryId, equals: entry.id)
                }
            }
            .padding(.horizontal, ContinuumTheme.safePadding)
            .padding(.vertical, ContinuumTheme.smallPadding)
        }
        // Groups the rail for directional entry and lands it on the first card
        // instead of the geometrically nearest one. Both are inert where
        // nothing takes focus.
        .focusGroup()
        .railDefaultFocus(entries.first?.id, binding: $focusedEntryId)
        .scrollClipDisabled(ContinuumTheme.cardsLiftOnFocus)
    }
}

// MARK: - Card

private struct TrailerCard: View {
    let entry: TrailerRailEntry
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            TrailerCardLabel(entry: entry)
        }
        .buttonStyle(DetailCardStyle())
        .accessibilityLabel("\(entry.title), \(ExtraKindLabels.label(for: entry.kind))")
    }
}

private struct TrailerCardLabel: View {
    let entry: TrailerRailEntry

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: ContinuumTheme.smallPadding) {
            thumbnail
            VStack(alignment: .leading, spacing: ContinuumTheme.sectionHeaderSpacing) {
                Text(kindLabel.uppercased())
                    .font(.continuumSectionEyebrow)
                    .tracking(ContinuumTheme.sectionEyebrowTracking)
                    .foregroundColor(.continuumOnSurface.opacity(0.55))

                // `TrailerRailEntry.title` already falls back to the kind
                // label when the server has no name, and in that case the
                // eyebrow alone says everything — repeating it below reads as
                // a bug.
                if entry.title != kindLabel {
                    Text(entry.title)
                        .font(.continuumSubheadline)
                        .foregroundColor(titleColor)
                        // Two lines for long provider names ("Official Trailer
                        // — Subtitled"), but without reserving the second line:
                        // most titles are one line and the reserved row reads
                        // as dead space.
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if let secondaryLine {
                    Text(secondaryLine)
                        .font(.continuumCaption)
                        .foregroundColor(.continuumSecondaryText)
                        .lineLimit(1)
                }
            }
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: isFocused)
        }
        .frame(width: ContinuumTheme.railCardWidth, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var titleColor: Color {
        isFocused ? .continuumOnSurface : Color.continuumOnSurface.opacity(0.92)
    }

    private var thumbnailHeight: CGFloat {
        ContinuumTheme.railCardWidth / ContinuumTheme.thumbnailAspectRatio
    }

    /// Remote cards say where selecting them leads, but only where that is a
    /// real departure: tvOS hands off to the YouTube app, while iOS opens an
    /// in-app web sheet and macOS the default browser.
    private var remoteProviderName: String? {
        #if os(tvOS)
        "YouTube"
        #else
        nil
        #endif
    }

    private var kindLabel: String {
        ExtraKindLabels.label(for: entry.kind)
    }

    /// Local extras are real files, so the scanner knows their runtime.
    /// Remote provider references carry no duration — they name where
    /// selecting them leads instead, where that is a real departure.
    private var secondaryLine: String? {
        switch entry {
        case .remote:
            return remoteProviderName
        case .local(let extra):
            guard let seconds = extra.durationSeconds, seconds > 0 else { return nil }
            return PlayerTimeFormatter.formatHMS(Double(seconds))
        }
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        ZStack {
            Color.continuumSurfaceElevated
            artwork
            playBadge
        }
        .frame(width: ContinuumTheme.railCardWidth, height: thumbnailHeight)
        .clipShape(RoundedRectangle(cornerRadius: ContinuumTheme.smallCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ContinuumTheme.smallCornerRadius)
                .stroke(
                    Color.white.opacity(isFocused ? 0.9 : 0),
                    lineWidth: isFocused ? ContinuumTheme.focusRingWidth : 0
                )
        }
    }

    /// YouTube stills exist for every remote video; local extras have no
    /// artwork server-side, so they keep the surface tile plus a glyph rather
    /// than an empty frame.
    @ViewBuilder
    private var artwork: some View {
        switch entry {
        case .remote(let video):
            if let url = TrailerRail.thumbnailURL(siteKey: video.siteKey)?.absoluteString {
                // YouTube's `hqdefault` still is 4:3 with letterbox bars; a
                // fill-mode crop to 16:9 removes them almost exactly.
                CachedAsyncImage(
                    url: url,
                    targetSize: CGSize(
                        width: ContinuumTheme.railCardWidth,
                        height: thumbnailHeight
                    ),
                    contentMode: .fill
                )
                .frame(width: ContinuumTheme.railCardWidth, height: thumbnailHeight)
                .clipped()
            }
        case .local:
            Image(systemName: "film")
                .font(.continuumTitle)
                .foregroundColor(.continuumSecondaryText)
        }
    }

    private var playBadge: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(isFocused ? 0.72 : 0.55))
                .frame(
                    width: ContinuumTheme.circleControlDiameter,
                    height: ContinuumTheme.circleControlDiameter
                )
            Image(systemName: "play.fill")
                .font(.continuumSubheadline)
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
    }
}

// MARK: - Focus

private extension View {
    /// `.userInitiated` priority is what makes `defaultFocus` win over
    /// geometric proximity on entry — the same mechanism as `SimilarRail` and
    /// `DetailCastRail`. It governs entry *into* this section only; the
    /// hero's Play button keeps page-entry focus through its own
    /// `defaultFocus` on the detail scroll container.
    @ViewBuilder
    func railDefaultFocus(
        _ firstEntryId: String?,
        binding: FocusState<String?>.Binding
    ) -> some View {
        if let firstEntryId {
            defaultFocus(binding, firstEntryId, priority: .userInitiated)
        } else {
            self
        }
    }
}

// MARK: - Section wrapper

/// The rail plus this platform's handling of a remote card tap.
///
/// The detail screens embed this instead of `TrailersRail` directly: a remote
/// trailer opens an in-app web sheet on iOS and the system browser on macOS,
/// and that branch would otherwise be copied into `MovieDetailContent` and
/// `SeriesDetailContent` verbatim. Local extras are ordinary playback targets,
/// so those taps continue up to the detail view that owns the player.
///
/// tvOS does not use this wrapper — it hands remote entries to the YouTube app
/// through `TVTrailerLaunch` at the call site that also probed for it.
#if !os(tvOS)
struct TrailersSection: View {
    let entries: [TrailerRailEntry]
    let onPlayExtra: (_ contentId: String) -> Void

    #if os(iOS)
    @State private var activeRemoteTrailer: RemoteTrailerPresentation?
    #else
    @Environment(\.openURL) private var openURL
    #endif

    var body: some View {
        #if os(iOS)
        TrailersRail(entries: entries, onSelect: handleSelection)
            .sheet(item: $activeRemoteTrailer) { presentation in
                TrailerWebSheet(title: presentation.title, siteKey: presentation.siteKey)
            }
        #else
        TrailersRail(entries: entries, onSelect: handleSelection)
        #endif
    }

    private func handleSelection(_ entry: TrailerRailEntry) {
        switch entry {
        case .local(let extra):
            onPlayExtra(extra.contentId)
        case .remote(let video):
            #if os(iOS)
            activeRemoteTrailer = RemoteTrailerPresentation(
                title: entry.title,
                siteKey: video.siteKey
            )
            #else
            // macOS has no WKWebView sheet of its own here; hand the public
            // watch page to the default browser instead.
            if let url = TrailerRail.youtubeWatchURL(siteKey: video.siteKey) {
                openURL(url)
            }
            #endif
        }
    }
}
#endif

#if os(iOS)
/// Identifiable box so a tapped remote entry can drive `.sheet(item:)`.
/// Keyed on the site key so re-tapping the same trailer is idempotent.
private struct RemoteTrailerPresentation: Identifiable {
    let title: String
    let siteKey: String
    var id: String { siteKey }
}
#endif

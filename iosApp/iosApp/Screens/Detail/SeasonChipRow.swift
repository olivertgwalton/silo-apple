import SwiftUI

/// Horizontal scroll of season chips for series, season, and episode detail.
///
/// One view, no platform branches, no dimensions of its own: the type comes
/// from the semantic scale, the insets and radii from `ContinuumTheme`, and
/// both already fork per platform in one place. Focus is applied
/// unconditionally: `defaultFocus` is cross-platform and inert where nothing
/// takes focus, and `focusGroup` absorbs the one API that isn't.
struct SeasonChipRow: View {
    let seasons: [Season]
    let selectedSeasonId: String?
    let onSelect: (Season) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedSeasonId: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ContinuumTheme.smallPadding) {
                    ForEach(seasons) { season in
                        SeasonChip(
                            season: season,
                            isSelected: selectedSeasonId == season.id,
                            onSelect: { onSelect(season) }
                        )
                        .id(season.id)
                        .focused($focusedSeasonId, equals: season.id)
                    }
                }
                .padding(.vertical, ContinuumTheme.smallPadding)
            }
            .contentMargins(.horizontal, ContinuumTheme.safePadding, for: .scrollContent)
            // Group the row so a directional move resolves to it as a unit,
            // and land entry on the selected chip rather than whichever is
            // geometrically nearest.
            .focusGroup()
            .seasonChipDefaultFocus(selectedSeasonId, binding: $focusedSeasonId)
            .scrollClipDisabled(ContinuumTheme.cardsLiftOnFocus)
            // Center the selection on first paint too. Without this a
            // high-numbered season opens with the row scrolled to Season 1 and
            // the selected chip clipped off-screen. The HStack is non-lazy, so
            // the target chip is already laid out — no dispatch hop needed.
            .onAppear { center(selectedSeasonId, using: proxy, animated: false) }
            .onChange(of: selectedSeasonId) { _, newId in
                center(newId, using: proxy, animated: !reduceMotion)
            }
        }
    }

    private func center(_ id: String?, using proxy: ScrollViewProxy, animated: Bool) {
        guard let id else { return }
        guard animated else { return proxy.scrollTo(id, anchor: .center) }
        withAnimation(.easeOut(duration: ContinuumTheme.fastDuration)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }
}

// MARK: - Chip

private struct SeasonChip: View {
    let season: Season
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(label)
                .font(.continuumSeasonChip)
                .fontWeight(isSelected ? .semibold : .medium)
                .padding(.horizontal, ContinuumTheme.chipLabelPadding)
                .padding(.vertical, ContinuumTheme.chipLabelPadding / 2)
        }
        .buttonStyle(SeasonChipStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var label: String {
        if let title = season.title, !title.isEmpty { return title }
        if season.seasonNumber == 0 { return "Specials" }
        return "Season \(season.seasonNumber)"
    }
}

/// Selected reads as a filled white pill; focused fades in a translucent fill;
/// idle is outline only. The style owns its focus rendering so tvOS doesn't
/// stack a system halo on top, and `\.isFocused` is simply always false where
/// a finger or pointer is the input.
private struct SeasonChipStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        SeasonChipBody(configuration: configuration, isSelected: isSelected)
    }
}

private struct SeasonChipBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .foregroundColor(isSelected ? .black : .white)
            .background(background)
            .scaleEffect(configuration.isPressed ? focusScale * 0.97 : focusScale)
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: isFocused)
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: configuration.isPressed)
    }

    private var focusScale: CGFloat {
        isFocused ? ContinuumTheme.focusScale : 1.0
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            Capsule().fill(Color.white)
        } else if isFocused {
            Capsule().fill(Color.white.opacity(0.18))
        } else {
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }
    }
}

// MARK: - Focus

private extension View {
    /// `.userInitiated` priority is what makes `defaultFocus` win over
    /// geometric proximity on entry. Applied only when there is a selection
    /// to land on.
    @ViewBuilder
    func seasonChipDefaultFocus(
        _ selectedSeasonId: String?,
        binding: FocusState<String?>.Binding
    ) -> some View {
        if let selectedSeasonId {
            defaultFocus(binding, selectedSeasonId, priority: .userInitiated)
        } else {
            self
        }
    }
}

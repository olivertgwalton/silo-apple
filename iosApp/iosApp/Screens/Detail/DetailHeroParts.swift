import SwiftUI

/// The pieces every detail hero is built from: the eyebrow pill, the title
/// treatment, the source row, and the facts row.
///
/// The compact and Apple TV heroes arrange these differently — a backdrop
/// block over a centered editorial column versus a full-bleed left-column
/// stack — and that arrangement stays in each hero. The parts themselves were
/// the same views at different sizes, written twice (and the title splitter
/// four times), so they live here once. They carry no dimensions: type comes
/// from the semantic scale and spacing from `ContinuumTheme`, both already
/// forked per platform in one place.

// MARK: - Eyebrow

/// Short editorial line above the title ("New Episode Friday").
struct HeroEyebrow: View {
    let text: String
    /// Over live artwork the pill needs its own scrim; on the page surface
    /// the elevated tone is enough.
    var floatsOverArtwork = false

    var body: some View {
        Text(text)
            .font(.continuumSectionEyebrow)
            .fontWeight(.semibold)
            .tracking(ContinuumTheme.sectionEyebrowTracking)
            .foregroundColor(.continuumOnSurface)
            .padding(.horizontal, ContinuumTheme.smallPadding)
            .padding(.vertical, ContinuumTheme.sectionHeaderSpacing)
            .background {
                if floatsOverArtwork {
                    Capsule()
                        .fill(Color.black.opacity(0.55))
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                } else {
                    Capsule().fill(Color.continuumSurfaceElevated)
                }
            }
    }
}

// MARK: - Title

/// Display title, split into a lead and a smaller underline when the source
/// title carries a colon or dash — "Monarch: Legacy of Monsters" becomes a
/// two-line composition. `DetailHeroMetadata.splitTitle` owns the split.
struct HeroTitle: View {
    let title: String
    var textAlignment: TextAlignment = .center
    /// Over live artwork the title carries a shadow and Apple TV's condensed
    /// all-caps wordmark treatment; on the page surface it stays as written.
    var floatsOverArtwork = false

    var body: some View {
        let parts = DetailHeroMetadata.splitTitle(title)
        VStack(alignment: textAlignment.horizontal, spacing: ContinuumTheme.sectionHeaderSpacing) {
            Text(floatsOverArtwork ? parts.primary.uppercased() : parts.primary)
                .font(.continuumHeroTitle.heroDisplay(floatsOverArtwork))
                .foregroundColor(.continuumOnSurface)
                .heroTitleLine(textAlignment)
                .heroTitleShadow(floatsOverArtwork)
            if let subtitle = parts.subtitle {
                Text(subtitle.uppercased())
                    .font(.continuumSubheadline.heroDisplay(floatsOverArtwork))
                    .tracking(ContinuumTheme.sectionEyebrowTracking)
                    .foregroundColor(.continuumOnSurface.opacity(0.8))
                    .heroTitleLine(textAlignment)
                    .heroTitleShadow(floatsOverArtwork)
            }
        }
        .frame(maxWidth: .infinity, alignment: textAlignment.frameAlignment)
    }
}

/// Episode title treatment: the series name leads, the episode title sits
/// under it, and a colon-split subtitle follows.
struct HeroEpisodeHierarchyTitle: View {
    let seriesTitle: String
    let episodeTitle: String
    var textAlignment: TextAlignment = .center
    var floatsOverArtwork = false

    var body: some View {
        let parts = DetailHeroMetadata.splitTitle(episodeTitle)
        VStack(alignment: textAlignment.horizontal, spacing: ContinuumTheme.sectionHeaderSpacing) {
            Text(floatsOverArtwork ? seriesTitle.uppercased() : seriesTitle)
                .font(.continuumHeroTitle.heroDisplay(floatsOverArtwork))
                .foregroundColor(.continuumOnSurface)
                .heroTitleLine(textAlignment)
                .heroTitleShadow(floatsOverArtwork)
            Text(parts.primary)
                .font(.continuumTitle.heroDisplay(floatsOverArtwork))
                .foregroundColor(.continuumOnSurface.opacity(0.92))
                .heroTitleLine(textAlignment)
                .heroTitleShadow(floatsOverArtwork)
            if let subtitle = parts.subtitle {
                Text(subtitle.uppercased())
                    .font(.continuumSubheadline.heroDisplay(floatsOverArtwork))
                    .tracking(ContinuumTheme.sectionEyebrowTracking)
                    .foregroundColor(.continuumOnSurface.opacity(0.78))
                    .heroTitleLine(textAlignment)
                    .heroTitleShadow(floatsOverArtwork)
            }
        }
        .frame(maxWidth: .infinity, alignment: textAlignment.frameAlignment)
    }
}

private extension View {
    func heroTitleLine(_ textAlignment: TextAlignment) -> some View {
        lineLimit(2)
            .multilineTextAlignment(textAlignment)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    func heroTitleShadow(_ enabled: Bool) -> some View {
        if enabled {
            shadow(color: .black.opacity(0.55), radius: 16, y: 4)
        } else {
            self
        }
    }
}

private extension TextAlignment {
    var horizontal: HorizontalAlignment { self == .leading ? .leading : .center }
    var frameAlignment: Alignment { self == .leading ? .leading : .center }
}

// MARK: - Source row

/// Type · genre line under the title, with the maturity rating as an outlined
/// chip at the end.
struct HeroSourceRow: View {
    let tokens: [String]
    let ratingChip: String?
    var textAlignment: TextAlignment = .center

    var body: some View {
        if !tokens.isEmpty || ratingChip != nil {
            HStack(spacing: ContinuumTheme.smallPadding) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                    if index > 0 {
                        HeroSeparator()
                    }
                    Text(token)
                        .font(.continuumBody)
                        .foregroundColor(.continuumOnSurface.opacity(0.88))
                        .lineLimit(1)
                }
                if let ratingChip, !ratingChip.isEmpty {
                    HeroChip(value: ratingChip)
                }
            }
            .multilineTextAlignment(textAlignment)
            .frame(
                maxWidth: .infinity,
                alignment: textAlignment == .leading ? .leading : .center
            )
        }
    }
}

// MARK: - Facts row

/// Year · runtime · quality chips, wrapping onto new lines when the tokens
/// exceed the container width. A plain `HStack` truncates instead of
/// wrapping, so this flows the chips like Apple's quality-badge row.
struct HeroFactsRow: View {
    let tokens: [DetailHeroFactToken]
    var alignment: HorizontalAlignment = .center

    var body: some View {
        if !tokens.isEmpty {
            HeroFactsFlowLayout(
                spacing: ContinuumTheme.smallPadding,
                lineSpacing: ContinuumTheme.sectionHeaderSpacing,
                alignment: alignment
            ) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                    if index > 0,
                       case .text = token,
                       case .text = tokens[index - 1] {
                        HeroSeparator()
                    }
                    factsItem(token)
                }
            }
        }
    }

    @ViewBuilder
    private func factsItem(_ token: DetailHeroFactToken) -> some View {
        switch token {
        case .text(let value):
            factText(value)
        case .rating(let value):
            HStack(spacing: ContinuumTheme.sectionHeaderSpacing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.continuumCaption)
                    .foregroundColor(.continuumSuccess.opacity(0.9))
                factText(value)
            }
        case .chip(let value):
            HeroChip(value: value)
        }
    }

    private func factText(_ value: String) -> some View {
        Text(value)
            .font(.continuumCaption)
            .foregroundColor(.continuumOnSurface.opacity(0.8))
    }
}

// MARK: - Shared row pieces

private struct HeroSeparator: View {
    var body: some View {
        Text("·")
            .font(.continuumBody)
            .foregroundColor(.continuumOnSurface.opacity(0.45))
    }
}

private struct HeroChip: View {
    let value: String

    var body: some View {
        Text(value)
            .font(.continuumSectionEyebrow)
            .fontWeight(.heavy)
            .tracking(ContinuumTheme.sectionEyebrowTracking)
            .foregroundColor(.continuumOnSurface)
            .padding(.horizontal, ContinuumTheme.sectionHeaderSpacing)
            .padding(.vertical, ContinuumTheme.sectionHeaderSpacing / 2)
            .overlay {
                RoundedRectangle(cornerRadius: ContinuumTheme.smallCornerRadius / 2)
                    .stroke(Color.continuumOnSurface.opacity(0.55), lineWidth: 1)
            }
    }
}

/// Minimal flow layout that wraps subviews onto new lines when the proposed
/// width can't fit them. Uses each subview's intrinsic width — no shrinking —
/// so every chip stays at its natural size.
private struct HeroFactsFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat
    var alignment: HorizontalAlignment

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let lines = layoutLines(maxWidth: maxWidth, subviews: subviews)
        let height = lines.reduce(0) { acc, line in acc + line.height + lineSpacing } - lineSpacing
        let width = lines.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        let lines = layoutLines(maxWidth: maxWidth, subviews: subviews)
        var y = bounds.minY
        for line in lines {
            let extra = max(0, maxWidth - line.width)
            var x = bounds.minX + (alignment == .center ? extra / 2 : 0)
            for entry in line.entries {
                entry.subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: entry.size.width, height: entry.size.height)
                )
                x += entry.size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Entry { let subview: LayoutSubview; let size: CGSize }
    private struct Line { var entries: [Entry] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func layoutLines(maxWidth: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = [Line()]
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let candidateWidth = lines[lines.count - 1].width
                + (lines[lines.count - 1].entries.isEmpty ? 0 : spacing)
                + size.width
            if candidateWidth > maxWidth, !lines[lines.count - 1].entries.isEmpty {
                lines.append(Line())
            }
            let index = lines.count - 1
            if !lines[index].entries.isEmpty { lines[index].width += spacing }
            lines[index].entries.append(Entry(subview: subview, size: size))
            lines[index].width += size.width
            lines[index].height = max(lines[index].height, size.height)
        }
        return lines
    }
}

private extension Font {
    /// Apple TV sets hero titles in a condensed face so a long wordmark holds
    /// one line at display size. Elsewhere the title is body-adjacent and
    /// stays at the system width.
    func heroDisplay(_ condensed: Bool) -> Font {
        condensed ? width(.compressed) : self
    }
}

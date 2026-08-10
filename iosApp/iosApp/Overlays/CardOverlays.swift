import SwiftUI

/// Renders all enabled overlay badges for an item, grouped into the
/// four corner stacks defined by the user's prefs. Designed to layer
/// inside a poster card's existing `ZStack` (over the artwork, under
/// any focus chrome). Adds nothing to layout when no badges are
/// visible.
///
/// Posters are the only surface that carries these badges: a 16:9
/// still (episode, resume) already spends its corners on the episode
/// code, the progress rail, and the watched check, and a detail hero
/// states the same facts in prose right below the artwork.
///
/// Usage:
/// ```
/// ZStack {
///     posterImage
///     CardOverlays(data: .from(item), prefs: prefs)
/// }
/// ```
struct CardOverlays: View {
    let data: OverlayData
    let prefs: CardOverlayPrefs

    var body: some View {
        let preset = OverlayPresets.preset(prefs.preset)
        ZStack(alignment: .topLeading) {
            cornerStack(.topLeft, preset: preset)
            cornerStack(.topRight, preset: preset)
            cornerStack(.bottomLeft, preset: preset)
            cornerStack(.bottomRight, preset: preset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func cornerStack(_ position: OverlayPosition, preset: OverlayPreset) -> some View {
        let badges = OverlayRegistry
            .enabled(at: position, in: prefs)
            .compactMap { OverlayBadgeRenderState.resolve(def: $0, data: data, prefs: prefs, preset: preset) }
        if badges.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: alignment(for: position), spacing: preset.gap) {
                ForEach(badges, id: \.id) { state in
                    OverlayBadgeView(state: state, preset: preset)
                }
            }
            .padding(insets(for: position))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: anchor(for: position))
        }
    }

    private func alignment(for position: OverlayPosition) -> HorizontalAlignment {
        switch position {
        case .topLeft, .bottomLeft:   return .leading
        case .topRight, .bottomRight: return .trailing
        }
    }

    private func anchor(for position: OverlayPosition) -> Alignment {
        switch position {
        case .topLeft:     return .topLeading
        case .topRight:    return .topTrailing
        case .bottomLeft:  return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }

    private func insets(for position: OverlayPosition) -> EdgeInsets {
        let inset: CGFloat = 8
        switch position {
        case .topLeft:
            return EdgeInsets(top: inset, leading: inset, bottom: 0, trailing: 0)
        case .topRight:
            return EdgeInsets(top: inset, leading: 0, bottom: 0, trailing: inset)
        case .bottomLeft:
            return EdgeInsets(top: 0, leading: inset, bottom: inset, trailing: 0)
        case .bottomRight:
            return EdgeInsets(top: 0, leading: 0, bottom: inset, trailing: inset)
        }
    }
}

// MARK: - Single-badge resolution + rendering

/// Resolved values needed to render one badge. Settings preview UI
/// uses `resolveForPreview` to force a chip even when sample data
/// doesn't yield a value; the live card path uses `resolve` and lets
/// the optional return value act as the "should I render?" signal.
struct OverlayBadgeRenderState: Equatable {
    let id: OverlayId
    let label: String
    let iconId: OverlayIconId?
    let iconOnly: Bool
    let accentColor: Color?

    /// Resolve the badge as it would appear on a real card. Returns
    /// `nil` when the overlay's data extractor returns no label —
    /// signalling that the badge should not render.
    static func resolve(
        def: OverlayDef,
        data: OverlayData,
        prefs: CardOverlayPrefs,
        preset: OverlayPreset
    ) -> OverlayBadgeRenderState? {
        guard let label = def.getValue(data) else { return nil }
        return build(def: def, label: label, data: data, prefs: prefs, preset: preset)
    }

    /// Force-resolve with the overlay's label as a fallback. Used by
    /// the settings UI so every row shows a chip even if the chosen
    /// sample fixture happens to not populate that overlay.
    static func resolveForPreview(
        def: OverlayDef,
        data: OverlayData,
        prefs: CardOverlayPrefs,
        preset: OverlayPreset
    ) -> OverlayBadgeRenderState {
        let label = def.getValue(data) ?? def.label.uppercased()
        return build(def: def, label: label, data: data, prefs: prefs, preset: preset)
    }

    private static func build(
        def: OverlayDef,
        label: String,
        data: OverlayData,
        prefs: CardOverlayPrefs,
        preset: OverlayPreset
    ) -> OverlayBadgeRenderState {
        let cfg = prefs.items[def.id]
        let dynamicIcon = def.getIcon?(data)
        let iconId = dynamicIcon ?? def.iconId
        let accent = cfg?.accentColor ?? def.defaultAccent
        let showIcon = (iconId != nil) && def.iconCapable && (cfg?.showIcon ?? preset.preferIcon)
        return .init(
            id: def.id,
            label: label,
            iconId: showIcon ? iconId : nil,
            iconOnly: def.iconOnly,
            accentColor: accent.flatMap { Color(hex: $0) }
        )
    }
}

/// Renders one resolved badge. Used by `CardOverlays` for live cards
/// and by the settings UI for per-row badge previews.
struct OverlayBadgeView: View {
    let state: OverlayBadgeRenderState
    let preset: OverlayPreset

    var body: some View {
        HStack(spacing: 4) {
            if let iconId = state.iconId {
                OverlayIcon(
                    iconId: iconId,
                    size: preset.iconSize,
                    tint: preset.foregroundColor(state.accentColor)
                )
            }
            if (!state.iconOnly || state.iconId == nil) && !labelRedundantWithIcon {
                badgeText
            }
        }
        .padding(.horizontal, preset.horizontalPadding)
        .padding(.vertical, preset.verticalPadding)
        .background(background)
        .overlay(border)
        .clipShape(shape)
    }

    /// A wordmark icon (HDR10, ATMOS, …) spells its text as the mark
    /// itself; when the label says the same thing, showing both reads
    /// "HDR10 HDR10". Mirrors web's `labelRedundantWithIcon`.
    private var labelRedundantWithIcon: Bool {
        guard let iconId = state.iconId, let mark = iconId.wordmarkText else { return false }
        return mark.lowercased() == state.label
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
    }

    @ViewBuilder
    private var badgeText: some View {
        let text = Text(state.label)
            .font(preset.font.weight(preset.textWeight))
            .tracking(preset.tracking)
            .foregroundColor(preset.foregroundColor(state.accentColor))
        Group {
            if let textCase = preset.textCase {
                text.textCase(textCase)
            } else {
                text
            }
        }
        .modifier(BadgeShadow(enabled: preset.textShadow))
    }

    @ViewBuilder
    private var background: some View {
        let color = preset.backgroundColor(state.accentColor)
        if let material = preset.backdropMaterial {
            shape
                .fill(material)
                .overlay(shape.fill(color))
        } else {
            shape.fill(color)
        }
    }

    @ViewBuilder
    private var border: some View {
        if let stroke = preset.borderColor(state.accentColor) {
            shape.stroke(stroke, lineWidth: 1)
        }
    }

    /// Type-erased shape so the same value can feed `fill`, `stroke`,
    /// and `clipShape` regardless of which corner style the preset
    /// chose. AnyShape (iOS 16+) carries no measurable overhead vs.
    /// the opaque alternatives.
    private var shape: AnyShape {
        switch preset.cornerStyle {
        case .capsule:
            return AnyShape(Capsule(style: .continuous))
        case .rounded(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

private struct BadgeShadow: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.shadow(color: Color.black.opacity(0.85), radius: 1, y: 1)
        } else {
            content
        }
    }
}

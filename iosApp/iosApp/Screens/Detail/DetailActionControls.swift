import SwiftUI

/// The hero action controls shared by every detail page: the primary play
/// pill, its dark secondary peer, and the icon-only circle button and menu
/// beside them.
///
/// One implementation, no platform branches, no dimensions of their own. Type
/// comes from the semantic scale, padding and radii from `ContinuumTheme`,
/// and focus appearance from the theme's focus tokens — which flatten to "no
/// treatment" where a finger or a pointer is the input, so the same styles
/// render a plain button there and a lifted, outlined one on Apple TV.

// MARK: - Pill button

/// Solid-white primary play control, or its dark secondary peer.
struct DetailPillButton: View {
    enum Kind { case primary, secondary }

    let icon: String
    let title: String
    let action: () -> Void
    var kind: Kind = .primary
    /// Expands to the container — the compact hero makes Play the dominant
    /// full-width CTA.
    var fullWidth = false
    /// Lets the owning detail view both observe and claim this button's
    /// focus. Combined with `.defaultFocus(…priority: .userInitiated)` on the
    /// scroll container, this is the reliable way to make Play win initial
    /// focus over the geometrically-higher synopsis —
    /// `prefersDefaultFocus(_:in:)` loses to geometry in practice here.
    var focused: FocusState<Bool>.Binding? = nil

    var body: some View {
        Button(action: action) {
            HStack(spacing: ContinuumTheme.smallPadding) {
                Image(systemName: icon)
                Text(title).lineLimit(1)
            }
            .font(kind == .primary ? .continuumActionPrimary : .continuumActionSecondary)
            .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(DetailPillButtonStyle(kind: kind))
        .detailActionFocus(focused)
    }
}

/// Also applied directly by screens that build their own pill labels — the
/// Next Up screen and the tvOS player controls — so focus appearance is
/// defined once for every pill in the app.
struct DetailPillButtonStyle: ButtonStyle {
    /// How loud the focused state reads. `prominent` is for a pill that owns
    /// its screen rather than sharing a row.
    enum Prominence { case standard, prominent }

    let kind: DetailPillButton.Kind
    var prominence: Prominence = .standard

    func makeBody(configuration: Configuration) -> some View {
        DetailPillButtonBody(
            configuration: configuration,
            kind: kind,
            prominence: prominence
        )
    }
}

private struct DetailPillButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: DetailPillButton.Kind
    let prominence: DetailPillButtonStyle.Prominence

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .foregroundColor(foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(shape.fill(background))
            .overlay(shape.stroke(innerBorderColor, lineWidth: innerBorderWidth))
            .overlay { focusOutline }
            .scaleEffect(scale)
            .shadow(color: .black.opacity(isFocused ? 0.24 : 0.14), radius: isFocused ? 10 : 4, y: isFocused ? 4 : 2)
            .focusEffectDisabled()
            .animation(ContinuumTheme.springAnimation, value: isFocused)
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: configuration.isPressed)
    }

    private var horizontalPadding: CGFloat {
        kind == .primary
            ? ContinuumTheme.pillHorizontalPadding
            : ContinuumTheme.pillHorizontalPadding * ContinuumTheme.secondaryPillPaddingScale
    }

    private var verticalPadding: CGFloat {
        kind == .primary
            ? ContinuumTheme.pillVerticalPadding
            : ContinuumTheme.pillVerticalPadding * ContinuumTheme.secondaryPillPaddingScale
    }

    /// A capsule where the platform draws soft controls, and Apple TV's
    /// squared tile where it doesn't — both from the same corner token.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ContinuumTheme.smallCornerRadius, style: .continuous)
    }

    @ViewBuilder
    private var focusOutline: some View {
        if isFocused, outlineWidth > 0 {
            RoundedRectangle(
                cornerRadius: ContinuumTheme.smallCornerRadius + 2,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.96), lineWidth: outlineWidth)
            .padding(-outlineInset)
        }
    }

    private var outlineWidth: CGFloat {
        prominence == .prominent
            ? ContinuumTheme.focusOutlineWidthProminent
            : ContinuumTheme.focusOutlineWidth
    }

    private var outlineInset: CGFloat {
        prominence == .prominent
            ? ContinuumTheme.focusOutlineInsetProminent
            : ContinuumTheme.focusOutlineInset
    }

    private var foreground: Color {
        switch kind {
        case .primary: .black
        case .secondary: isFocused ? .black : .white
        }
    }

    private var background: Color {
        switch kind {
        case .primary: isFocused ? .white : Color.white.opacity(0.76)
        case .secondary: isFocused ? .white : Color.black.opacity(0.52)
        }
    }

    private var innerBorderColor: Color {
        if isFocused { return Color.black.opacity(kind == .primary ? 0.18 : 0.12) }
        return Color.white.opacity(kind == .primary ? 0.12 : 0.24)
    }

    private var innerBorderWidth: CGFloat {
        if isFocused { return kind == .primary ? 1.8 : 1.5 }
        return kind == .primary ? 0.8 : 1.2
    }

    private var scale: CGFloat {
        let focused = prominence == .prominent
            ? ContinuumTheme.focusScaleProminent
            : ContinuumTheme.focusScale
        let base = isFocused ? focused : 1.0
        return configuration.isPressed ? base * 0.98 : base
    }
}

// MARK: - Circle button

/// Compact icon-only secondary action (favorite, watchlist, watched).
struct DetailCircleActionButton: View {
    let icon: String
    var iconActive: String? = nil
    var isActive = false
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? (iconActive ?? icon) : icon)
                .font(.continuumActionSecondary)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
        }
        .buttonStyle(DetailCircleButtonStyle(isActive: isActive))
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Circle button that opens a `Menu` — overflow navigation kept one tap away
/// without crowding the primary row.
struct DetailCircleMenuButton<MenuContent: View>: View {
    var icon: String = "ellipsis"
    let accessibilityLabel: String
    @ViewBuilder let menu: () -> MenuContent

    var body: some View {
        Menu {
            menu()
        } label: {
            Image(systemName: icon)
                .font(.continuumActionSecondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .menuStyle(.button)
        .buttonStyle(DetailCircleButtonStyle(isActive: false))
        .menuIndicator(.hidden)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct DetailCircleButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        DetailCircleButtonBody(configuration: configuration, isActive: isActive)
    }
}

private struct DetailCircleButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isActive: Bool

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .foregroundColor(isFocused ? .black : .white)
            .frame(
                width: ContinuumTheme.circleControlDiameter,
                height: ContinuumTheme.circleControlDiameter
            )
            .background(shape.fill(background))
            .overlay(shape.stroke(borderColor, lineWidth: isFocused ? 1.6 : 1.4))
            .overlay { focusOutline }
            .scaleEffect(scale)
            .shadow(color: .black.opacity(isFocused ? 0.34 : 0), radius: isFocused ? 16 : 0, y: isFocused ? 6 : 0)
            .focusEffectDisabled()
            .animation(ContinuumTheme.springAnimation, value: isFocused)
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: configuration.isPressed)
    }

    /// A true circle where the control is small, and Apple TV's rounded tile
    /// at its larger size — both from the same corner token.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ContinuumTheme.smallCornerRadius, style: .continuous)
    }

    @ViewBuilder
    private var focusOutline: some View {
        if isFocused, ContinuumTheme.focusOutlineWidth > 0 {
            RoundedRectangle(
                cornerRadius: ContinuumTheme.smallCornerRadius + 2,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.96), lineWidth: ContinuumTheme.focusOutlineWidth)
            .padding(-ContinuumTheme.focusOutlineInset)
        }
    }

    private var background: Color {
        if isFocused { return .white }
        return Color.white.opacity(isActive ? 0.18 : 0.10)
    }

    private var borderColor: Color {
        if isFocused { return Color.black.opacity(0.12) }
        return Color.white.opacity(isActive ? 0.55 : 0.25)
    }

    private var scale: CGFloat {
        let base = isFocused ? ContinuumTheme.focusScaleProminent : 1.0
        return configuration.isPressed ? base * 0.95 : base
    }
}

// MARK: - Card style

/// Focus treatment for the rail cards: scale and drop shadow, so tvOS doesn't
/// paint its default halo over the card — the white ring the card draws on its
/// own artwork is the cue. Flattens to a plain button where a finger or
/// pointer is the input, because every value it reads is zero there.
struct DetailCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DetailCardStyleBody(configuration: configuration)
    }
}

private struct DetailCardStyleBody: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .scaleEffect(scale)
            .shadow(
                color: .black.opacity(isFocused ? 0.45 : 0.3),
                radius: shadowRadius,
                y: isFocused ? 8 : 4
            )
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: isFocused)
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: configuration.isPressed)
    }

    private var shadowRadius: CGFloat {
        let resting = ContinuumTheme.cardRestingShadowRadius
        return isFocused ? resting * 2.25 : resting
    }

    private var scale: CGFloat {
        let base = isFocused ? ContinuumTheme.focusScale : 1.0
        return configuration.isPressed ? base * 0.97 : base
    }
}

// MARK: - Focus

private extension View {
    @ViewBuilder
    func detailActionFocus(_ binding: FocusState<Bool>.Binding?) -> some View {
        if let binding {
            focused(binding)
        } else {
            self
        }
    }
}

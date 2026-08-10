import SwiftUI

/// The detail hero's overview, clamped to three lines and expandable in place.
///
/// The state, the clamp, and the animation are shared; only the affordance
/// forks, because the two input models genuinely differ. On tvOS this is the
/// detail page's single text focus stop — reachable by pressing Up from the
/// action row — and Select toggles it, so it must be a `Button` and must never
/// feel "stuck". Off tvOS there is no focus to land, so the text itself is the
/// tap target and a trailing "MORE" pill advertises that there is more to read.
struct ExpandableSynopsis: View {
    let overview: String

    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    #if os(tvOS)
    private let maxWidth: CGFloat = 1200
    #endif

    var body: some View {
        #if os(tvOS)
        Button { expanded.toggle() } label: {
            synopsisText
                .frame(maxWidth: maxWidth, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(SynopsisButtonStyle())
        .animation(
            reduceMotion ? nil : .easeOut(duration: ContinuumTheme.normalDuration),
            value: expanded
        )
        #else
        synopsisText
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottomTrailing) {
                if !expanded, isClipped {
                    morePill
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: ContinuumTheme.normalDuration)) {
                    expanded.toggle()
                }
            }
        #endif
    }

    private var synopsisText: some View {
        Text(overview)
            .font(.continuumSynopsis)
            .foregroundColor(.continuumOnSurface.opacity(synopsisOpacity))
            .lineSpacing(synopsisLineSpacing)
            .lineLimit(expanded ? nil : 3)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    #if os(tvOS)
    private let synopsisOpacity: Double = 0.82
    private let synopsisLineSpacing: CGFloat = 8
    #else
    private let synopsisOpacity: Double = 0.78
    private let synopsisLineSpacing: CGFloat = 3

    /// Character-count heuristic for "this will clamp". Cheap, and only drives
    /// whether the MORE affordance is offered — a wrong guess costs a pill,
    /// not correctness, since tapping the text expands it either way.
    private var isClipped: Bool {
        overview.count > 140
    }

    private var morePill: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: ContinuumTheme.normalDuration)) {
                expanded = true
            }
        } label: {
            Text("MORE")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundColor(.continuumOnSurface)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.continuumSurfaceElevated))
        }
        .buttonStyle(.plain)
    }
    #endif
}

#if os(tvOS)
/// No chrome at rest; on focus a faint fill cue so the user knows it's
/// actionable. Suppresses the system halo (matches the page idiom).
private struct SynopsisButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SynopsisButtonStyleBody(configuration: configuration)
    }
}

private struct SynopsisButtonStyleBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: ContinuumTheme.smallCornerRadius, style: .continuous)
                    .fill(Color.continuumSurfaceElevated.opacity(isFocused ? 0.55 : 0))
            )
            .padding(.horizontal, -20)
            .padding(.vertical, -14)
            .focusEffectDisabled()
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: isFocused)
    }
}
#endif

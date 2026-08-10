import SwiftUI

/// Horizontal cast rail for the detail page on every platform. Round portrait
/// thumbnails with the actor's name and character beneath.
///
/// The three platforms differ only in scale and in whether there is a focus
/// engine to satisfy: tvOS wraps each portrait in a focus-liftable button and
/// routes d-pad entry to the first person, while iOS and macOS use a plain
/// tap target. Both share this file's layout, data, and entry cap.
struct DetailCastRail: View {
    let cast: [CastMember]
    let onTap: (String) -> Void

    private let maxEntries = 24

    /// Only consulted on tvOS; declared unconditionally so the card call site
    /// doesn't have to fork.
    @FocusState private var focusedCastId: String?

    // MARK: - Platform metrics

    #if os(tvOS)
    private let cardSpacing: CGFloat = 44
    private let railVerticalPadding: CGFloat = 24
    private let visibleCardCount = 8
    #elseif os(macOS)
    private let cardSpacing: CGFloat = 18
    private let railVerticalPadding: CGFloat = 6
    private let visibleCardCount = 8
    #else
    private let cardSpacing: CGFloat = 14
    private let railVerticalPadding: CGFloat = 4
    private let visibleCardCount = 4
    #endif

    private var entries: [CastMember] {
        Array(cast.prefix(maxEntries))
    }

    var body: some View {
        let strip = ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: cardSpacing) {
                ForEach(entries) { member in
                    CastCard(member: member, onTap: onTap)
                        .focused($focusedCastId, equals: member.id)
                        .containerRelativeFrame(
                            .horizontal,
                            count: visibleCardCount,
                            span: 1,
                            spacing: cardSpacing
                        )
                }
            }
            .padding(.vertical, railVerticalPadding)
        }
        .contentMargins(.horizontal, ContinuumTheme.safePadding, for: .scrollContent)

        #if os(tvOS)
        // When focus enters the cast/crew rail, land on the first person
        // rather than letting tvOS choose a geometrically-nearest card.
        return strip
            .focusSection()
            .applyCastRailDefaultFocus(entries.first?.id, binding: $focusedCastId)
            .scrollClipDisabled()
        #else
        return strip
        #endif
    }
}

// MARK: - Card

/// One portrait. On tvOS the focus treatment (scale, shadow, ring, and the
/// name brightening) is driven by `@Environment(\.isFocused)` from the button
/// style's context; elsewhere the card is a plain tap target.
private struct CastCard: View {
    let member: CastMember
    let onTap: (String) -> Void

    var body: some View {
        let button = Button {
            if let personId = member.personId { onTap(personId) }
        } label: {
            CastCardLabel(member: member)
        }

        #if os(tvOS)
        return button.buttonStyle(CastCardStyle())
        #else
        return button.buttonStyle(.plain)
        #endif
    }
}

private struct CastCardLabel: View {
    let member: CastMember

    @Environment(\.isFocused) private var isFocused

    #if os(tvOS)
    private let stackSpacing: CGFloat = 16
    private let nameSpacing: CGFloat = 4
    #else
    private let stackSpacing: CGFloat = 8
    private let nameSpacing: CGFloat = 2
    #endif

    var body: some View {
        VStack(spacing: stackSpacing) {
            photo
            VStack(spacing: nameSpacing) {
                Text(member.name)
                    .font(.continuumCastName)
                    .foregroundColor(
                        isFocused ? .continuumOnSurface : .continuumOnSurface.opacity(0.88)
                    )
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
                if let character = member.character, !character.isEmpty {
                    Text(character)
                        .font(.continuumCastRole)
                        .foregroundColor(.continuumSecondaryText)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
            }
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: isFocused)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var photo: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let url = member.photoUrl, !url.isEmpty {
                    CachedAsyncImage(url: url, contentMode: .fill)
                } else {
                    Color.continuumSurfaceElevated
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundColor(.continuumSecondaryText)
                        }
                }
            }
            .clipShape(Circle())
            .overlay(
                Circle().stroke(
                    Color.white.opacity(isFocused ? 0.85 : 0.10),
                    lineWidth: isFocused ? 2 : 1
                )
            )
    }
}

#if os(tvOS)
/// Custom style so the system doesn't paint its default focus halo on top.
/// Scale + shadow only — the portrait ring handles the focus cue.
private struct CastCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CastCardBody(configuration: configuration)
    }
}

private struct CastCardBody: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .scaleEffect(scale)
            .shadow(
                color: .black.opacity(isFocused ? 0.35 : 0.0),
                radius: isFocused ? 14 : 0,
                y: isFocused ? 6 : 0
            )
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: isFocused)
            .animation(.easeOut(duration: ContinuumTheme.fastDuration), value: configuration.isPressed)
    }

    private var scale: CGFloat {
        let base: CGFloat = isFocused ? 1.05 : 1.0
        return configuration.isPressed ? base * 0.97 : base
    }
}
#endif

// MARK: - Platform trim

private extension View {
    #if os(tvOS)
    @ViewBuilder
    func applyCastRailDefaultFocus(
        _ firstCastId: String?,
        binding: FocusState<String?>.Binding
    ) -> some View {
        if let firstCastId {
            self.defaultFocus(binding, firstCastId, priority: .userInitiated)
        } else {
            self
        }
    }
    #endif
}

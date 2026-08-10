import SwiftUI

/// Editorial section header used below the detail hero on every platform.
///
/// No underline or chrome — a display title, with an optional small tracked
/// all-caps "eyebrow" above it used only when the eyebrow carries context the
/// title doesn't (e.g. "This Season" over "Episodes"), and an optional
/// right-aligned count.
///
/// This is one view rather than a per-platform pair: the phone, Mac, and TV
/// treatments differ only in type size, tracking, and the eyebrow gap, all of
/// which `Font.continuumSection*` and `ContinuumTheme.sectionHeaderSpacing`
/// already resolve per platform.
struct DetailSectionHeader: View {
    var label: String? = nil
    let title: String
    var trailingText: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: ContinuumTheme.sectionHeaderSpacing) {
                if let label, !label.isEmpty {
                    Text(label.uppercased())
                        .font(.continuumSectionEyebrow)
                        .tracking(ContinuumTheme.sectionEyebrowTracking)
                        .foregroundColor(.continuumOnSurface.opacity(0.55))
                }

                Text(title)
                    .font(.continuumSectionTitle)
                    .foregroundColor(.continuumOnSurface)
            }

            // Unconditional, so a header with no trailing text still spans
            // its container and stays left-aligned rather than shrinking to
            // fit — the behaviour every existing call site was laid out for.
            Spacer(minLength: 8)

            if let trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(.continuumSectionTrailing)
                    .foregroundColor(.continuumSecondaryText)
            }
        }
    }
}

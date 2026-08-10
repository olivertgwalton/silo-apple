import SwiftUI

/// The "Details" key/value list under a detail hero.
///
/// One view for every platform. The phone and Apple TV versions were
/// structurally identical — same rows, same dividers, same alignment — and
/// the numbers that differed now come from the semantic type scale and
/// `ContinuumTheme`, both already forked per platform in one place.
struct DetailFactsSection: View {
    let detail: ItemDetail

    var body: some View {
        let facts = DetailFacts.assemble(from: detail)
        if !facts.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(facts.enumerated()), id: \.element.label) { index, fact in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                    }
                    HStack(alignment: .top, spacing: ContinuumTheme.factsColumnGap) {
                        Text(fact.label.uppercased())
                            .font(.continuumCardEyebrow)
                            .tracking(ContinuumTheme.factsLabelTracking)
                            .foregroundColor(.continuumOnSurface.opacity(0.5))
                            .frame(width: ContinuumTheme.factsLabelWidth, alignment: .leading)
                        Text(fact.value)
                            .font(.continuumCaption)
                            .foregroundColor(.continuumOnSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, ContinuumTheme.factsRowPadding)
                }
            }
            .frame(maxWidth: ContinuumTheme.readableContentWidth, alignment: .leading)
        }
    }
}

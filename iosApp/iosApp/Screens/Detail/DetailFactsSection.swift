import SwiftUI

/// The "Details" key/value list under a detail hero.
///
/// One view for every platform. The phone and Apple TV versions were
/// structurally identical — same rows, same dividers, same alignment — and
/// differed only in the seven numbers below, so those are a parameter rather
/// than a second copy of the layout.
struct DetailFactsSection: View {
    let detail: ItemDetail
    var metrics: Metrics = .compact

    struct Metrics {
        let columnGap: CGFloat
        let labelSize: CGFloat
        let labelTracking: CGFloat
        let labelWidth: CGFloat
        let valueSize: CGFloat
        let rowPadding: CGFloat
        let maxWidth: CGFloat

        /// Phone and Mac.
        static let compact = Metrics(
            columnGap: 16,
            labelSize: 11,
            labelTracking: 1.2,
            labelWidth: 100,
            valueSize: 14,
            rowPadding: 12,
            maxWidth: .infinity
        )

        /// Apple TV, read from across a room.
        static let television = Metrics(
            columnGap: 64,
            labelSize: 18,
            labelTracking: 2.0,
            labelWidth: 260,
            valueSize: 22,
            rowPadding: 22,
            maxWidth: 1400
        )
    }

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
                    HStack(alignment: .top, spacing: metrics.columnGap) {
                        Text(fact.label.uppercased())
                            .font(.system(size: metrics.labelSize, weight: .bold))
                            .tracking(metrics.labelTracking)
                            .foregroundColor(.continuumOnSurface.opacity(0.5))
                            .frame(width: metrics.labelWidth, alignment: .leading)
                        Text(fact.value)
                            .font(.system(size: metrics.valueSize, weight: .regular))
                            .foregroundColor(.continuumOnSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, metrics.rowPadding)
                }
            }
            .frame(maxWidth: metrics.maxWidth, alignment: .leading)
        }
    }
}

import Foundation

/// The label/value rows shown in a detail page's facts section — director,
/// writer, studio, network, country and the air/release dates.
///
/// One builder for every platform. The phone lists these as a two-column
/// grid and Apple TV as a focusable row, but which facts an item has and how
/// their values read is the same question everywhere.
enum DetailFacts {
    struct Fact: Hashable {
        let label: String
        let value: String
    }

    /// Credits are capped so a long crew list cannot push the rest of the
    /// section off screen; the overflow is marked with an ellipsis.
    static let maxCreditNames = 3

    static func assemble(from detail: ItemDetail) -> [Fact] {
        var facts: [Fact] = []

        if let directors = creditNames(in: detail, forJobs: ["Director"]), !directors.isEmpty {
            facts.append(Fact(label: "Director", value: directors))
        }
        if let writers = creditNames(in: detail, forJobs: ["Writer", "Screenplay", "Story"]), !writers.isEmpty {
            facts.append(Fact(label: writerLabel(for: detail), value: writers))
        }

        if let studios = detail.studios, !studios.isEmpty {
            facts.append(Fact(label: "Studio", value: studios.prefix(3).joined(separator: ", ")))
        }
        if let networks = detail.networks, !networks.isEmpty {
            facts.append(Fact(label: "Network", value: networks.prefix(3).joined(separator: ", ")))
        }
        if let countries = detail.countries, !countries.isEmpty {
            facts.append(Fact(label: "Country", value: countries.prefix(3).joined(separator: ", ")))
        }
        if let airDate = DetailDateFormatting.longDate(detail.airDate) {
            facts.append(Fact(label: "Aired", value: airDate))
        }
        if let releaseDate = DetailDateFormatting.longDate(detail.releaseDate) {
            facts.append(Fact(label: "Released", value: releaseDate))
        }
        if let firstAired = DetailDateFormatting.longDate(detail.firstAirDate) {
            facts.append(Fact(label: "First Aired", value: firstAired))
        }
        if let lastAired = DetailDateFormatting.longDate(detail.lastAirDate) {
            facts.append(Fact(label: "Last Aired", value: lastAired))
        }
        return facts
    }

    /// "Writer" reads wrong when the credit is specifically a screenplay, so
    /// the label follows whichever job the crew actually carries.
    static func writerLabel(for detail: ItemDetail) -> String {
        let hasScreenplay = detail.crew?.contains { $0.job?.lowercased() == "screenplay" } ?? false
        return hasScreenplay ? "Screenplay" : "Writer"
    }

    static func creditNames(in detail: ItemDetail, forJobs jobs: [String]) -> String? {
        guard let crew = detail.crew else { return nil }
        let lowered = jobs.map { $0.lowercased() }
        let names = crew
            .filter { member in
                guard let job = member.job?.lowercased() else { return false }
                return lowered.contains(job)
            }
            .map(\.name)
        if names.isEmpty { return nil }
        let trimmed = Array(Set(names)).sorted()
        let joined = trimmed.prefix(maxCreditNames).joined(separator: ", ")
        return trimmed.count > maxCreditNames ? "\(joined), …" : joined
    }
}

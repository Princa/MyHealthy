import Foundation

/// One row in medication search results.
struct DrugSearchResult: Identifiable, Hashable {
    enum Source: Hashable {
        case library
        case rxNorm(rxcui: String)
    }

    var id: String
    var name: String
    var subtitle: String
    var tag: String
    var source: Source
    /// Present for library results; online results load their details on demand.
    var info: DrugInfo?

    var isOnline: Bool {
        if case .rxNorm = source { return true }
        return false
    }

    static func fromLibrary(_ info: DrugInfo) -> DrugSearchResult {
        DrugSearchResult(
            id: "lib-" + info.name.lowercased(),
            name: info.name,
            subtitle: [info.brandNames.joined(separator: ", "), info.form].filter { !$0.isEmpty }.joined(separator: " · "),
            tag: info.drugClass,
            source: .library,
            info: info
        )
    }
}

enum DrugInfoError: LocalizedError {
    case offline
    case notFound

    var errorDescription: String? {
        switch self {
        case .offline: return "Couldn’t reach the medication database. Check your connection and try again."
        case .notFound: return "No reference information was found for this medication."
        }
    }
}

/// Looks up medications: first in the built-in library, then online using
/// NLM RxNorm (names), MedlinePlus Connect (plain-language summary and link)
/// and the U.S. FDA drug label via openFDA (dosing, strengths, side effects).
/// None of these services need an API key.
final class DrugInfoService {
    static let shared = DrugInfoService()

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: Search

    /// Built-in library matches only; instant and offline.
    func libraryResults(_ term: String) -> [DrugSearchResult] {
        MedicationLibrary.search(term).map(DrugSearchResult.fromLibrary)
    }

    /// Library matches first, then online RxNorm matches not already covered.
    func search(_ term: String) async -> [DrugSearchResult] {
        let query = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }

        let library = libraryResults(query)
        let online = (try? await rxNormCandidates(query)) ?? []
        let known = Set(library.map { $0.name.lowercased() })
        let onlineResults = online
            .filter { !known.contains($0.name.lowercased()) }
            .map { candidate in
                DrugSearchResult(
                    id: "rx-" + candidate.rxcui + "-" + candidate.name.lowercased(),
                    name: candidate.name,
                    subtitle: "RxNorm",
                    tag: "",
                    source: .rxNorm(rxcui: candidate.rxcui),
                    info: nil
                )
            }
        return library + onlineResults
    }

    struct RxCandidate: Hashable {
        var rxcui: String
        var name: String
    }

    private struct ApproximateTermResponse: Decodable {
        struct Group: Decodable {
            let candidate: [Candidate]?
        }
        struct Candidate: Decodable {
            let rxcui: String
            let name: String?
            let source: String?
        }
        let approximateGroup: Group
    }

    func rxNormCandidates(_ term: String, limit: Int = 8) async throws -> [RxCandidate] {
        var components = URLComponents(string: "https://rxnav.nlm.nih.gov/REST/approximateTerm.json")!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "maxEntries", value: "25")
        ]
        let response: ApproximateTermResponse = try await get(components.url!)
        var seen = Set<String>()
        var results: [RxCandidate] = []
        for candidate in response.approximateGroup.candidate ?? [] {
            guard candidate.source == "RXNORM", let rawName = candidate.name else { continue }
            let name = DrugText.displayName(rawName)
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            results.append(RxCandidate(rxcui: candidate.rxcui, name: name))
            if results.count == limit { break }
        }
        return results
    }

    // MARK: Details

    func details(for result: DrugSearchResult) async throws -> DrugInfo {
        if let info = result.info { return info }
        guard case let .rxNorm(rxcui) = result.source else { throw DrugInfoError.notFound }

        async let medline = try? medlinePlusSummary(rxcui: rxcui)
        async let label = try? fdaLabel(name: result.name)
        let summary = await medline
        let fda = await label

        if summary == nil && fda == nil {
            throw DrugInfoError.offline
        }

        var info = DrugInfo(name: result.name)
        info.retrievedAt = Date()

        if let summary {
            let sentences = DrugText.firstSentences(summary.text, count: 4)
            info.whatItsFor = DrugText.firstSentences(sentences, count: 1)
            let rest = sentences.dropFirst(info.whatItsFor.count).trimmingCharacters(in: .whitespaces)
            info.howItWorks = rest
            info.sourceURL = summary.link
        }

        if let fda {
            if info.whatItsFor.isEmpty {
                info.whatItsFor = DrugText.firstSentences(fda.indications, count: 2)
            }
            info.doseNote = DrugText.firstSentences(fda.dosage, count: 2)
            info.sideEffectsNote = DrugText.firstSentences(fda.adverseReactions, count: 2)
            info.strengths = DrugText.strengths(from: fda.dosageForms)
            info.brandNames = fda.brandNames.filter { $0.lowercased() != result.name.lowercased() }
            info.drugClass = fda.pharmClass
            let forms = fda.dosageForms.lowercased()
            info.form = forms.contains("capsule") ? "capsule" : (forms.contains("solution") ? "liquid" : "tablet")
        }

        info.howToTake = [DrugText.missedDose]
        switch (summary != nil, fda != nil) {
        case (true, true): info.sourceName = "MedlinePlus & U.S. FDA drug label"
        case (true, false): info.sourceName = "MedlinePlus"
        default: info.sourceName = "U.S. FDA drug label (openFDA)"
        }
        if info.sourceURL == nil {
            info.sourceURL = MedicationLibrary.medlinePlusSearchURL(result.name)
        }
        return info
    }

    struct MedlineSummary {
        var title: String
        var text: String
        var link: String?
    }

    private struct MedlineResponse: Decodable {
        struct Feed: Decodable { let entry: [Entry]? }
        struct Entry: Decodable {
            let title: TextValue?
            let summary: TextValue?
            let link: [Link]?
        }
        struct TextValue: Decodable {
            let value: String?
            enum CodingKeys: String, CodingKey { case value = "_value" }
        }
        struct Link: Decodable { let href: String? }
        let feed: Feed
    }

    func medlinePlusSummary(rxcui: String) async throws -> MedlineSummary? {
        var components = URLComponents(string: "https://connect.medlineplus.gov/service")!
        components.queryItems = [
            URLQueryItem(name: "mainSearchCriteria.v.cs", value: "2.16.840.1.113883.6.88"),
            URLQueryItem(name: "mainSearchCriteria.v.c", value: rxcui),
            URLQueryItem(name: "knowledgeResponseType", value: "application/json"),
            URLQueryItem(name: "informationRecipient.languageCode.c", value: "en")
        ]
        let response: MedlineResponse = try await get(components.url!)
        guard let entry = response.feed.entry?.first, let raw = entry.summary?.value else { return nil }
        let text = DrugText.stripHTML(raw)
        guard !text.isEmpty else { return nil }
        let link = entry.link?.first?.href.map { href in
            href.components(separatedBy: "?utm_").first ?? href
        }
        return MedlineSummary(title: entry.title?.value ?? "", text: text, link: link)
    }

    struct FDALabel {
        var indications: String
        var dosage: String
        var adverseReactions: String
        var dosageForms: String
        var brandNames: [String]
        var pharmClass: String
    }

    private struct FDAResponse: Decodable {
        struct Result: Decodable {
            let indications_and_usage: [String]?
            let dosage_and_administration: [String]?
            let adverse_reactions: [String]?
            let dosage_forms_and_strengths: [String]?
            let openfda: OpenFDA?
        }
        struct OpenFDA: Decodable {
            let brand_name: [String]?
            let generic_name: [String]?
            let pharm_class_epc: [String]?
        }
        let results: [Result]?
    }

    func fdaLabel(name: String) async throws -> FDALabel? {
        let cleaned = name.replacingOccurrences(of: "\"", with: "")
        for field in ["openfda.generic_name", "openfda.brand_name"] {
            var components = URLComponents(string: "https://api.fda.gov/drug/label.json")!
            components.queryItems = [
                URLQueryItem(name: "search", value: "\(field):\"\(cleaned)\""),
                URLQueryItem(name: "limit", value: "1")
            ]
            guard let url = components.url else { continue }
            guard let response: FDAResponse = try? await get(url), let result = response.results?.first else { continue }
            let pharmClass = (result.openfda?.pharm_class_epc?.first ?? "")
                .replacingOccurrences(of: " [EPC]", with: "")
            let brands = (result.openfda?.brand_name ?? []).map(DrugText.displayName)
            return FDALabel(
                indications: DrugText.cleanLabelSection(result.indications_and_usage?.first ?? ""),
                dosage: DrugText.cleanLabelSection(result.dosage_and_administration?.first ?? ""),
                adverseReactions: DrugText.cleanLabelSection(result.adverse_reactions?.first ?? ""),
                dosageForms: DrugText.cleanLabelSection(result.dosage_forms_and_strengths?.first ?? ""),
                brandNames: Array(Set(brands)).sorted(),
                pharmClass: pharmClass
            )
        }
        return nil
    }

    // MARK: Networking

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DrugInfoError.notFound
        }
        return try decoder.decode(T.self, from: data)
    }
}

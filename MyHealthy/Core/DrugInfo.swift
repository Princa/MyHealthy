import Foundation

struct DoseLine: Codable, Hashable {
    var label: String
    var value: String
}

/// Reference information about a medication, shown on the medication info screen
/// and stored with each medication a profile takes.
struct DrugInfo: Codable, Hashable {
    var name: String
    var brandNames: [String] = []
    var drugClass: String = ""
    /// Short purpose tag such as "Blood pressure" or "Cholesterol".
    var purpose: String = ""
    var whatItsFor: String = ""
    var howItWorks: String = ""
    var doseLines: [DoseLine] = []
    /// Free-text dosing note (used for label text fetched from the web).
    var doseNote: String = ""
    var howToTake: [String] = []
    var commonSideEffects: [String] = []
    /// Free-text side effect note (used for label text fetched from the web).
    var sideEffectsNote: String = ""
    var urgentWarning: String = ""
    var strengths: [String] = []
    var form: String = "tablet"
    var sourceName: String = ""
    var sourceURL: String?
    var retrievedAt: Date?
    var isCurated: Bool = false

    var brandLine: String {
        if brandNames.isEmpty { return "" }
        return "Brand: " + brandNames.joined(separator: ", ")
    }

    var hasReferenceText: Bool {
        !whatItsFor.isEmpty || !howItWorks.isEmpty || !doseLines.isEmpty || !doseNote.isEmpty
    }

    static func manual(name: String) -> DrugInfo {
        DrugInfo(name: name, sourceName: "Added manually")
    }
}

enum DrugText {
    static let missedDose = "Missed a dose? Take it when you remember. If it’s almost time for the next one, skip it — never take two at once."

    /// Removes HTML tags and decodes the handful of entities that appear in summaries.
    static func stripHTML(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#39;": "'", "&apos;": "'", "&nbsp;": " ", "&rsquo;": "’", "&lsquo;": "‘",
            "&ldquo;": "“", "&rdquo;": "”", "&mdash;": "—", "&ndash;": "–"
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return collapseWhitespace(text)
    }

    static func collapseWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cleans an FDA label section: drops the leading "1 INDICATIONS AND USAGE" style
    /// heading, cross-reference markers like "( 2.1 )", and bullet glyphs.
    static func cleanLabelSection(_ raw: String) -> String {
        var text = collapseWhitespace(raw)
        // Leading section number + ALL CAPS heading.
        text = text.replacingOccurrences(
            of: "^[0-9.]*\\s*[A-Z][A-Z &,/-]{3,}\\s+",
            with: "",
            options: .regularExpression
        )
        // Cross references: ( 2.1 ), (5.2, 5.3), [see Warnings (5.1)]
        text = text.replacingOccurrences(of: "\\[see [^\\]]*\\]", with: "", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "\\(\\s*[0-9]+(\\.[0-9]+)?(\\s*,\\s*[0-9]+(\\.[0-9]+)?)*\\s*\\)", with: "", options: .regularExpression)
        // Bullets and odd list glyphs.
        for glyph in ["•", "о ", "◦", "▪"] {
            text = text.replacingOccurrences(of: glyph, with: " ")
        }
        return collapseWhitespace(text)
            .replacingOccurrences(of: " .", with: ".")
            .replacingOccurrences(of: " ,", with: ",")
    }

    /// Returns up to `count` sentences from the start of `text`.
    static func firstSentences(_ text: String, count: Int) -> String {
        guard count > 0, !text.isEmpty else { return "" }
        var sentences: [String] = []
        var current = ""
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            current.append(character)
            let isTerminator = character == "." || character == "!" || character == "?"
            let nextIsSpace = index + 1 >= characters.count || characters[index + 1] == " "
            // Avoid splitting decimals like "2.5 mg" (next char is a digit, so nextIsSpace is false).
            if isTerminator && nextIsSpace {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if trimmed.count > 3 { sentences.append(trimmed) }
                current = ""
                if sentences.count == count { break }
            }
        }
        if sentences.count < count {
            let rest = current.trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty { sentences.append(rest) }
        }
        return sentences.prefix(count).joined(separator: " ")
    }

    /// Pulls "2.5 mg", "5 mg", "10 mg" style strengths out of label text, sorted by amount.
    static func strengths(from text: String, limit: Int = 6) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "([0-9]+(?:\\.[0-9]+)?)\\s?mg\\b", options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var amounts: [Double] = []
        for match in regex.matches(in: text, options: [], range: range) {
            guard let numberRange = Range(match.range(at: 1), in: text),
                  let amount = Double(text[numberRange]) else { continue }
            if !amounts.contains(amount) { amounts.append(amount) }
        }
        return amounts.sorted().prefix(limit).map { amount in
            let rounded = amount.rounded()
            let number = rounded == amount ? String(Int(rounded)) : String(amount)
            return "\(number) mg"
        }
    }

    /// "AMLODIPINE BESYLATE" -> "Amlodipine besylate"; keeps mixed-case names as they are.
    static func displayName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let isAllCaps = trimmed == trimmed.uppercased()
        let isAllLower = trimmed == trimmed.lowercased()
        guard isAllCaps || isAllLower else { return trimmed }
        let lower = trimmed.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }
}

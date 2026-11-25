import Foundation

/// Sift's own reading, with no model: keywords for the check, patterns for dates and amounts,
/// the letterhead line for a company. Always available, nothing leaves the Mac.
public struct SiftJudge: FileJudge {
    public init() {}

    public var displayName: String { "Sift" }
    public var staysOnDevice: Bool { true }

    public func judge(_ request: FileJudgementRequest) async throws -> FileJudgement {
        Self.judgeNow(request)
    }

    static func judgeNow(_ request: FileJudgementRequest) -> FileJudgement {
        let text = String(request.text.prefix(JudgementPrompt.textLimit))
        let haystack = Self.fold(request.fileName + "\n" + text)
        var matches: Bool?
        var reason = ""
        if let check = request.check, !check.isEmpty {
            let keywords = Self.keywords(for: check)
            let hits = keywords.filter { haystack.contains($0) }
            matches = !hits.isEmpty
            if let first = hits.first {
                reason = tr("Mentions “\(first)”", "Mentionne « \(first) »")
            } else if text.isEmpty {
                reason = tr("No readable text to check", "Aucun texte lisible à vérifier")
            } else {
                reason = tr("No sign of \(check)", "Rien n’indique \(check)")
            }
        }
        var fields: [String: String] = [:]
        for field in request.fields {
            let key = JudgementPrompt.fieldKey(field)
            let value: String?
            switch Self.role(of: key) {
            case .date: value = LocalExtraction.firstDate(in: text)
            case .amount: value = LocalExtraction.totalAmount(in: text)
            case .company: value = LocalExtraction.company(in: text, fileName: request.fileName)
            case .other: value = nil
            }
            if let value, !value.isEmpty { fields[key] = value }
        }
        if reason.isEmpty, matches == nil {
            reason = fields.isEmpty ? tr("Read by Sift", "Lu par Sift") : tr("Values read by Sift", "Valeurs lues par Sift")
        }
        return FileJudgement(matches: matches, reason: reason, fields: fields, answeredBy: "Sift")
    }

    enum FieldRole { case date, amount, company, other }

    static func role(of key: String) -> FieldRole {
        let dateWords = ["date", "day", "issued", "jour", "emission"]
        let amountWords = ["amount", "total", "price", "sum", "montant", "prix", "cost"]
        let companyWords = ["vendor", "company", "merchant", "supplier", "seller", "store", "from", "issuer", "fournisseur", "societe", "vendeur", "client"]
        if dateWords.contains(where: key.contains) { return .date }
        if amountWords.contains(where: key.contains) { return .amount }
        if companyWords.contains(where: key.contains) { return .company }
        return .other
    }

    /// Words that betray a kind of document, in English and French. Other checks use their own words.
    static func keywords(for check: String) -> [String] {
        let folded = fold(check)
        var words: [String] = []
        let families: [(triggers: [String], words: [String])] = [
            (["invoice", "facture", "bill"], ["invoice", "facture", "amount due", "montant du", "total ttc", "vat", "tva", "bill to", "invoice number", "n° de facture"]),
            (["receipt", "recu", "ticket"], ["receipt", "recu", "ticket de caisse", "paid", "payment received", "paiement", "total"]),
            (["contract", "contrat", "agreement", "lease", "bail"], ["agreement", "contract", "contrat", "lease", "bail", "between the parties", "entre les soussignes"]),
            (["payslip", "salary", "fiche de paie", "bulletin"], ["payslip", "pay slip", "bulletin de salaire", "fiche de paie", "net pay", "net a payer"]),
            (["statement", "releve"], ["statement", "releve de compte", "account summary", "opening balance", "solde"]),
            (["resume", "cv", "curriculum"], ["curriculum", "experience", "education", "competences", "skills"]),
        ]
        for family in families where family.triggers.contains(where: folded.contains) {
            words.append(contentsOf: family.words)
        }
        let stop: Set<String> = ["a", "an", "the", "or", "and", "of", "un", "une", "le", "la", "les", "ou", "et", "de", "des", "du", "file", "document"]
        let own = folded.split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 4 && !stop.contains($0) }
        words.append(contentsOf: own)
        var seen = Set<String>()
        return words.filter { seen.insert($0).inserted }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

/// Patterns for the values most rules ask for. Kept separate so tests can pin them down.
public enum LocalExtraction {
    private static let monthNames: [String: Int] = [
        "jan": 1, "january": 1, "janvier": 1, "janv": 1,
        "feb": 2, "february": 2, "fevrier": 2, "fevr": 2, "fev": 2,
        "mar": 3, "march": 3, "mars": 3,
        "apr": 4, "april": 4, "avril": 4, "avr": 4,
        "may": 5, "mai": 5,
        "jun": 6, "june": 6, "juin": 6,
        "jul": 7, "july": 7, "juillet": 7, "juil": 7,
        "aug": 8, "august": 8, "aout": 8,
        "sep": 9, "sept": 9, "september": 9, "septembre": 9,
        "oct": 10, "october": 10, "octobre": 10,
        "nov": 11, "november": 11, "novembre": 11,
        "dec": 12, "december": 12, "decembre": 12,
    ]

    /// The first plausible date, as YYYY-MM-DD. Numeric dates are read day-first unless the region is the US.
    public static func firstDate(in text: String, monthFirst: Bool = Locale.current.region?.identifier == "US") -> String? {
        let folded = SiftJudge.fold(text)
        var best: (offset: Int, value: String)?
        func consider(_ offset: Int, _ year: Int, _ month: Int, _ day: Int) {
            guard (1900...2100).contains(year), (1...12).contains(month), (1...31).contains(day) else { return }
            let value = String(format: "%04d-%02d-%02d", year, month, day)
            if best == nil || offset < best!.offset { best = (offset, value) }
        }
        for match in matches(#"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"#, in: folded) {
            consider(match.offset, Int(match.groups[0]) ?? 0, Int(match.groups[1]) ?? 0, Int(match.groups[2]) ?? 0)
        }
        for match in matches(#"\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})\b"#, in: folded) {
            let a = Int(match.groups[0]) ?? 0
            let b = Int(match.groups[1]) ?? 0
            var year = Int(match.groups[2]) ?? 0
            if year < 100 { year += 2000 }
            let (month, day) = (a > 12) ? (b, a) : (b > 12 ? (a, b) : (monthFirst ? (a, b) : (b, a)))
            consider(match.offset, year, month, day)
        }
        // "3 March 2026", "3 mars 2026", "March 3, 2026"
        for match in matches(#"\b(\d{1,2})(?:st|nd|rd|th|er)?\s+([a-z]{3,9})\.?,?\s+(\d{4})\b"#, in: folded) {
            if let month = monthNames[match.groups[1]] {
                consider(match.offset, Int(match.groups[2]) ?? 0, month, Int(match.groups[0]) ?? 0)
            }
        }
        for match in matches(#"\b([a-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b"#, in: folded) {
            if let month = monthNames[match.groups[0]] {
                consider(match.offset, Int(match.groups[2]) ?? 0, month, Int(match.groups[1]) ?? 0)
            }
        }
        return best?.value
    }

    /// The amount on a "total" line, else the largest amount with a currency. "129.00 EUR" style.
    public static func totalAmount(in text: String) -> String? {
        let pattern = #"(€|\$|£|eur|usd|gbp|chf|cad)?\s?(\d{1,3}(?:[ .,\x{00A0}\x{202F}]\d{3})*(?:[.,]\d{2})|\d+[.,]\d{2})\s?(€|\$|£|eur|usd|gbp|chf|cad)?"#
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        let totalWords = ["total", "amount due", "montant", "net a payer", "a payer", "grand total", "balance due", "ttc"]
        var candidates: [(value: Double, text: String, onTotalLine: Bool)] = []
        for line in lines {
            let folded = SiftJudge.fold(line)
            let onTotal = totalWords.contains(where: folded.contains) && !folded.contains("subtotal") && !folded.contains("sous-total")
            for match in matches(pattern, in: folded) {
                let currency = match.groups[0].isEmpty ? match.groups[2] : match.groups[0]
                guard !currency.isEmpty || onTotal else { continue }
                guard let value = number(from: match.groups[1]) else { continue }
                candidates.append((value, format(value, currency: currency), onTotal))
            }
        }
        if let total = candidates.filter(\.onTotalLine).max(by: { $0.value < $1.value }) {
            return total.text
        }
        return candidates.max(by: { $0.value < $1.value })?.text
    }

    /// The letterhead: the first short line that reads like a name, not like a title or a field.
    public static func company(in text: String, fileName: String) -> String? {
        let skip = ["invoice", "facture", "receipt", "recu", "page", "date", "total", "bill to", "ship to", "devis", "quote", "statement", "tax", "tva", "vat", "n°", "no.", "number", "client", "customer", "@", "http", "www."]
        for raw in text.split(whereSeparator: \.isNewline).prefix(12) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (2...40).contains(line.count) else { continue }
            let folded = SiftJudge.fold(line)
            guard !skip.contains(where: folded.contains) else { continue }
            let letters = line.filter(\.isLetter).count
            guard letters >= 2, Double(letters) / Double(line.count) > 0.6 else { continue }
            return line.split(separator: " ").prefix(4).joined(separator: " ")
        }
        return nil
    }

    // MARK: helpers

    struct Match { let offset: Int; let groups: [String] }

    static func matches(_ pattern: String, in text: String) -> [Match] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { result in
            var groups: [String] = []
            for index in 1..<result.numberOfRanges {
                if let slice = Range(result.range(at: index), in: text) {
                    groups.append(String(text[slice]))
                } else {
                    groups.append("")
                }
            }
            return Match(offset: result.range.location, groups: groups)
        }
    }

    static func number(from raw: String) -> Double? {
        var digits = raw.replacingOccurrences(of: "\u{00A0}", with: "").replacingOccurrences(of: "\u{202F}", with: "").replacingOccurrences(of: " ", with: "")
        // The last separator followed by exactly two digits is the decimal mark.
        if let last = digits.lastIndex(where: { $0 == "," || $0 == "." }),
           digits.distance(from: last, to: digits.endIndex) == 3 {
            let whole = digits[..<last].filter(\.isNumber)
            let cents = digits[digits.index(after: last)...]
            digits = "\(whole).\(cents)"
        } else {
            digits = digits.filter(\.isNumber)
        }
        return Double(digits)
    }

    static func format(_ value: Double, currency: String) -> String {
        let code: String
        switch currency.lowercased() {
        case "€", "eur": code = "EUR"
        case "$", "usd": code = "USD"
        case "£", "gbp": code = "GBP"
        case "chf": code = "CHF"
        case "cad": code = "CAD"
        default: code = ""
        }
        let number = String(format: "%.2f", value)
        return code.isEmpty ? number : "\(number) \(code)"
    }
}

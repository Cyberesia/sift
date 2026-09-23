import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

/// Text documents added beside photos, video, and audio. Code files are not included.
public enum DocumentFormats {
    public static let ordered = ["docx", "xlsx", "pptx", "pdf", "csv", "md", "mdx", "txt", "rtf"]
    public static let extensions = Set(ordered)

    public static func isDocument(url: URL, allowed: Set<String> = extensions) -> Bool {
        allowed.contains(url.pathExtension.lowercased())
    }
}

public struct DocumentUnit: Sendable, Equatable {
    public let title: String
    public let text: String

    public init(title: String, text: String) {
        self.title = title
        self.text = text
    }
}

/// One file, split on the structure it already has: headings, slides, or sheets.
public struct DocumentReading: Sendable, Equatable {
    public let category: String
    public let units: [DocumentUnit]
    public let excerpt: String
    /// Sheet column names, separate from the cell values.
    public let columns: [String]

    public init(category: String, units: [DocumentUnit], excerpt: String, columns: [String] = []) {
        self.category = category
        self.units = units
        self.excerpt = excerpt
        self.columns = columns
    }
}

/// Kind tags plus labels taken from the file: headings, the opening line, sheet names, and column headers.
public enum DocumentTags {
    public static func isTag(_ value: String) -> Bool {
        allowed.contains(value)
    }

    public static func make(
        category: String,
        fileName: String,
        units: [DocumentUnit],
        columns: [String] = []
    ) -> [String] {
        let sample = units.prefix(12).map { "\($0.title) \($0.text)" }.joined(separator: " ")
        let kinds = assemble(
            category: category,
            fileName: fileName,
            unitCount: units.count,
            sample: String(sample.prefix(6_000))
        )
        return unique(subjectLabels(category: category, units: units, columns: columns) + kinds)
    }

    /// Keeps kind tags and short subject labels. A stored excerpt longer than a label is dropped.
    public static func sanitized(fileName: String, stored: [String]) -> [String] {
        _ = fileName
        let subjects = stored.filter { !isTag($0) && isUsefulLabel($0) }
        let kinds = stored.filter(isTag)
        return unique(subjects + kinds)
    }

    /// Headings, the first sentence, sheet names, and column headers. Generic placeholders are left out.
    public static func subjectLabels(category: String, units: [DocumentUnit], columns: [String]) -> [String] {
        var labels: [String] = []
        for unit in units.prefix(12) {
            let title = cleaned(unit.title)
            if category == "spreadsheet" {
                if isUsefulLabel(title) { labels.append(title) }
            } else if title.lowercased().hasPrefix("slide ") {
                if let line = firstLine(unit.text), isUsefulLabel(line) { labels.append(line) }
            } else if isUsefulLabel(title) {
                labels.append(title)
            }
        }
        if category != "spreadsheet", let opening = units.first.flatMap({ openingSentence($0.text) }) {
            labels.append(opening)
        }
        for column in columns {
            let name = cleaned(column)
            if isUsefulLabel(name) { labels.append(name) }
        }
        return unique(labels).prefix(16).map { $0 }
    }

    public static func isUsefulLabel(_ value: String) -> Bool {
        let label = cleaned(value)
        guard label.count >= 2, label.count <= 80, label.contains(where: \.isLetter) else { return false }
        let folded = fold(label)
        if genericTitles.contains(folded) { return false }
        if folded.range(of: #"^(slide|sheet|feuil|column|col)\s*\d+$"#, options: .regularExpression) != nil {
            return false
        }
        return true
    }

    private static func assemble(category: String, fileName: String, unitCount: Int, sample: String) -> [String] {
        let kind = category == "spreadsheet" || category == "slides" || category == "notes" || category == "prose"
            ? category
            : kind(forFileName: fileName)
        var tags = [kind]
        switch kind {
        case "spreadsheet":
            tags.append(unitCount > 1 ? "multi-sheet" : "single-sheet")
        case "slides":
            tags.append(unitCount > 8 ? "long-deck" : "short-deck")
        default:
            if unitCount > 1 { tags.append("sectioned") }
        }
        let words = tokens(in: "\(fileName) \(sample)")
        let rules = kind == "spreadsheet" ? spreadsheetRules : (kind == "slides" ? slideRules : proseRules)
        for rule in rules where rule.phrases.contains(where: { phrase($0, isIn: words) }) {
            tags.append(rule.tag)
        }
        var seen = Set<String>()
        return tags.filter { allowed.contains($0) && seen.insert($0).inserted }
    }

    private static func kind(forFileName fileName: String) -> String {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "xlsx", "csv": return "spreadsheet"
        case "pptx": return "slides"
        case "md", "mdx": return "notes"
        default: return "prose"
        }
    }

    private static func tokens(in text: String) -> [String] {
        let folded = text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX")).lowercased()
        return folded.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    private static let genericTitles: Set<String> = [
        "document", "notes", "note", "section", "slide", "sheet", "sheets",
        "untitled", "sans titre", "worksheet", "introduction", "overview",
    ]

    private static func unique(_ labels: [String]) -> [String] {
        var seen = Set<String>()
        return labels.filter { seen.insert(fold($0)).inserted }
    }

    private static func cleaned(_ value: String) -> String {
        value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fold(_ value: String) -> String {
        cleaned(value).folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX")).lowercased()
    }

    private static func firstLine(_ text: String) -> String? {
        text.split(whereSeparator: \.isNewline)
            .map { cleaned(String($0)) }
            .first { !$0.isEmpty }
    }

    private static func openingSentence(_ text: String) -> String? {
        guard let line = firstLine(text), line.count >= 12 else { return nil }
        let end = line.firstIndex { ".!?".contains($0) }
        var sentence = end.map { String(line[...$0]) } ?? line
        sentence = cleaned(sentence)
        if sentence.count > 80, let space = sentence.prefix(80).lastIndex(of: " ") {
            sentence = cleaned(String(sentence[..<space]))
        }
        return isUsefulLabel(sentence) ? sentence : nil
    }

    private static func phrase(_ phrase: String, isIn words: [String]) -> Bool {
        let parts = tokens(in: phrase)
        guard !parts.isEmpty, parts.count <= words.count else { return false }
        if parts.count == 1 { return words.contains(parts[0]) }
        for index in 0...(words.count - parts.count) where words[index] == parts[0] {
            if Array(words[index..<(index + parts.count)]) == parts { return true }
        }
        return false
    }

    private struct Rule {
        let tag: String
        let phrases: [String]
    }

    private static let proseRules = [
        Rule(tag: "meeting", phrases: ["meeting", "reunion"]),
        Rule(tag: "minutes", phrases: ["minutes", "compte rendu"]),
        Rule(tag: "report", phrases: ["report", "rapport"]),
        Rule(tag: "letter", phrases: ["letter", "lettre"]),
        Rule(tag: "invoice", phrases: ["invoice", "facture"]),
        Rule(tag: "contract", phrases: ["contract", "contrat"]),
        Rule(tag: "resume", phrases: ["resume", "cv"]),
        Rule(tag: "agenda", phrases: ["agenda", "ordre du jour"]),
        Rule(tag: "proposal", phrases: ["proposal", "devis", "proposition"]),
        Rule(tag: "memo", phrases: ["memo"]),
    ]

    private static let spreadsheetRules = [
        Rule(tag: "budget", phrases: ["budget"]),
        Rule(tag: "inventory", phrases: ["inventory", "inventaire"]),
        Rule(tag: "schedule", phrases: ["schedule", "planning"]),
        Rule(tag: "contacts", phrases: ["contacts", "annuaire"]),
        Rule(tag: "expenses", phrases: ["expenses", "depenses"]),
        Rule(tag: "ledger", phrases: ["ledger"]),
        Rule(tag: "timesheet", phrases: ["timesheet"]),
        Rule(tag: "forecast", phrases: ["forecast", "prevision"]),
    ]

    private static let slideRules = [
        Rule(tag: "pitch", phrases: ["pitch"]),
        Rule(tag: "lecture", phrases: ["lecture", "cours"]),
        Rule(tag: "training", phrases: ["training", "formation"]),
        Rule(tag: "briefing", phrases: ["briefing"]),
        Rule(tag: "report", phrases: ["report", "rapport"]),
    ]

    private static let allowed: Set<String> = [
        "prose", "notes", "spreadsheet", "slides",
        "sectioned", "single-sheet", "multi-sheet", "short-deck", "long-deck",
        "meeting", "minutes", "report", "letter", "invoice", "contract", "resume", "agenda", "proposal", "memo",
        "budget", "inventory", "schedule", "contacts", "expenses", "ledger", "timesheet", "forecast",
        "pitch", "lecture", "training", "briefing",
    ]
}

public enum DocumentReader {
    private static let excerptLimit = 4_000
    private static let unitLimit = 40

    public static func read(url: URL) -> DocumentReading {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "md", "mdx":
            return markdown(readPlain(url))
        case "csv":
            return csv(url)
        case "pdf":
            return pdf(url)
        case "txt":
            return single("prose", title: url.deletingPathExtension().lastPathComponent, text: readPlain(url))
        case "rtf":
            return single("prose", title: url.deletingPathExtension().lastPathComponent, text: stripRTF(readPlain(url)))
        case "docx":
            return office(url: url, entry: "word/document.xml", category: "prose", splitHeadings: true)
        case "pptx":
            return slides(url)
        case "xlsx":
            return sheets(url)
        default:
            return single("prose", title: url.lastPathComponent, text: "")
        }
    }

    private static func markdown(_ raw: String) -> DocumentReading {
        var body = raw
        if body.hasPrefix("---") {
            let rest = body.dropFirst(3)
            if let end = rest.range(of: "\n---") {
                body = String(rest[end.upperBound...])
            }
        }
        var units: [DocumentUnit] = []
        var title = "Notes"
        var lines: [String] = []
        func flush() {
            let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            lines = []
            guard !text.isEmpty else { return }
            units.append(DocumentUnit(title: title, text: String(text.prefix(1_500))))
        }
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("#") {
                flush()
                title = line.drop { $0 == "#" || $0 == " " }.description
                if title.isEmpty { title = "Section" }
            } else {
                lines.append(String(line))
            }
        }
        flush()
        if units.isEmpty {
            units = [DocumentUnit(title: "Notes", text: String(body.prefix(1_500)))]
        }
        return finish("notes", units: units)
    }

    private static func office(url: URL, entry: String, category: String, splitHeadings: Bool) -> DocumentReading {
        guard let xml = ZipText.extract(entry, from: url) else {
            return single(category, title: url.deletingPathExtension().lastPathComponent, text: "")
        }
        if splitHeadings {
            return finish(category, units: docxUnits(xml))
        }
        return single(category, title: url.deletingPathExtension().lastPathComponent, text: plainXML(xml))
    }

    private static func docxUnits(_ xml: String) -> [DocumentUnit] {
        let paragraphs = xml.components(separatedBy: "<w:p ").dropFirst()
        var units: [DocumentUnit] = []
        var title = "Document"
        var lines: [String] = []
        func flush() {
            let text = lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            units.append(DocumentUnit(title: title, text: String(text.prefix(1_500))))
            lines = []
        }
        for paragraph in paragraphs {
            let text = plainXML(paragraph)
            guard !text.isEmpty else { continue }
            let heading = paragraph.contains("Heading") || paragraph.contains("heading")
            if heading {
                flush()
                title = text
            } else {
                lines.append(text)
            }
            if units.count >= unitLimit { break }
        }
        flush()
        if units.isEmpty {
            units = [DocumentUnit(title: "Document", text: String(plainXML(xml).prefix(1_500)))]
        }
        return units
    }

    private static func slides(_ url: URL) -> DocumentReading {
        let packed = ZipText.slideXML(from: url)
        let chunks = packed.components(separatedBy: "inflating:").dropFirst()
        var units: [DocumentUnit] = []
        for (index, chunk) in chunks.prefix(unitLimit).enumerated() {
            let xml = chunk.split(separator: "\n", maxSplits: 1).dropFirst().joined(separator: "\n")
            let text = plainXML(xml)
            guard !text.isEmpty else { continue }
            units.append(DocumentUnit(title: "Slide \(index + 1)", text: String(text.prefix(1_500))))
        }
        if units.isEmpty {
            units = [DocumentUnit(title: url.deletingPathExtension().lastPathComponent, text: "")]
        }
        return finish("slides", units: units)
    }

    private static func csv(_ url: URL) -> DocumentReading {
        let raw = readPlain(url, maxBytes: 80_000)
        let header = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let columns = csvFields(header)
        let stem = url.deletingPathExtension().lastPathComponent
        return finish(
            "spreadsheet",
            units: [DocumentUnit(title: stem, text: columns.joined(separator: ", "))],
            columns: columns
        )
    }

    private static func pdf(_ url: URL) -> DocumentReading {
        let stem = url.deletingPathExtension().lastPathComponent
        #if canImport(PDFKit)
        guard let document = PDFDocument(url: url), document.pageCount > 0 else {
            return single("prose", title: stem, text: "")
        }
        var text = ""
        for index in 0..<min(document.pageCount, 2) {
            guard let page = document.page(at: index)?.string else { continue }
            text += page
            text += "\n"
            if text.count > 4_000 { break }
        }
        let lines = text.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let title = lines.first.flatMap { $0.count <= 80 ? $0 : nil } ?? stem
        let body = lines.dropFirst().joined(separator: " ")
        let opening = body.isEmpty ? (lines.first ?? "") : body
        return single("prose", title: title, text: String(opening.prefix(1_500)))
        #else
        return single("prose", title: stem, text: "")
        #endif
    }

    private static func sheets(_ url: URL) -> DocumentReading {
        let workbook = ZipText.extract("xl/workbook.xml", from: url) ?? ""
        var titles = matches(in: workbook, pattern: "name=\"([^\"]+)\"")
        if titles.isEmpty { titles = [url.deletingPathExtension().lastPathComponent] }
        let shared = sharedStringList(ZipText.extract("xl/sharedStrings.xml", from: url) ?? "")
        var units: [DocumentUnit] = []
        var columns: [String] = []
        for (index, title) in titles.prefix(unitLimit).enumerated() {
            let sheet = ZipText.extract("xl/worksheets/sheet\(index + 1).xml", from: url) ?? ""
            let headers = firstRowValues(sheet, shared: shared)
            columns.append(contentsOf: headers)
            units.append(DocumentUnit(title: title, text: headers.joined(separator: ", ")))
        }
        if units.isEmpty {
            units = [DocumentUnit(title: url.deletingPathExtension().lastPathComponent, text: "")]
        }
        return finish("spreadsheet", units: units, columns: columns)
    }

    private static func csvFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for character in line {
            if character == "\"" {
                inQuotes.toggle()
                continue
            }
            if character == "," && !inQuotes {
                let field = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !field.isEmpty { fields.append(field) }
                current = ""
                continue
            }
            current.append(character)
        }
        let field = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !field.isEmpty { fields.append(field) }
        return fields
    }

    private static func sharedStringList(_ xml: String) -> [String] {
        xml.components(separatedBy: "<si").dropFirst().map {
            plainXML(String($0.prefix(500))).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func firstRowValues(_ sheet: String, shared: [String]) -> [String] {
        guard let start = sheet.range(of: "<row") else { return [] }
        let tail = sheet[start.lowerBound...]
        let row: String
        if let end = tail.range(of: "</row>") {
            row = String(tail[..<end.upperBound])
        } else {
            row = String(tail.prefix(4_000))
        }
        var values: [String] = []
        for piece in row.components(separatedBy: "<c ").dropFirst() {
            let cell = String(piece.prefix(800))
            if cell.contains("t=\"s\"") || cell.contains("t='s'") {
                guard let raw = matches(in: cell, pattern: "<v>([^<]*)</v>").first,
                      let index = Int(raw),
                      shared.indices.contains(index) else { continue }
                values.append(shared[index])
            } else if cell.contains("inlineStr") {
                let text = plainXML(cell).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { values.append(text) }
            }
        }
        return values
    }

    private static func single(_ category: String, title: String, text: String) -> DocumentReading {
        finish(category, units: [DocumentUnit(title: title, text: String(text.prefix(1_500)))])
    }

    private static func finish(_ category: String, units: [DocumentUnit], columns: [String] = []) -> DocumentReading {
        let kept = Array(units.prefix(unitLimit))
        let header = columns.isEmpty ? "" : "Columns: \(columns.joined(separator: ", "))\n\n"
        let excerpt = String((header + kept.map { "\($0.title)\n\($0.text)" }.joined(separator: "\n\n")).prefix(excerptLimit))
        return DocumentReading(category: category, units: kept, excerpt: excerpt, columns: columns)
    }

    private static func readPlain(_ url: URL, maxBytes: Int = 200_000) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let data = try? handle.read(upToCount: maxBytes)
        return String(data: data ?? Data(), encoding: .utf8) ?? ""
    }

    private static func stripRTF(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: "\\par", with: "\n")
        text = text.replacingOccurrences(of: "\\\\", with: "")
        return plainXML(text.replacingOccurrences(of: "{", with: " ").replacingOccurrences(of: "}", with: " "))
    }

    private static func plainXML(_ xml: String) -> String {
        var output = ""
        var dropping = false
        for character in xml {
            if character == "<" { dropping = true; continue }
            if character == ">" { dropping = false; if !output.hasSuffix(" ") { output.append(" ") }; continue }
            if !dropping { output.append(character) }
        }
        return output.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let slice = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[slice])
        }
    }
}

enum ZipText {
    /// Enough XML for headings, a sheet list, or the first slides. The rest of a large file is not read.
    private static let maxBytes = 180_000

    static func extract(_ entry: String, from url: URL) -> String? {
        let output = run(["-p", url.path, entry])
        return output.isEmpty ? nil : output
    }

    static func slideXML(from url: URL) -> String {
        run(["-c", url.path, "ppt/slides/slide*.xml"])
    }

    /// Reads unzip's output while it runs. Waiting first fills the pipe and the process never exits.
    private static func run(_ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let handle = pipe.fileHandleForReading
        var data = Data()
        while data.count < maxBytes {
            let chunk = handle.readData(ofLength: 32_768)
            if chunk.isEmpty { break }
            let room = maxBytes - data.count
            if chunk.count > room {
                data.append(chunk.prefix(room))
                break
            }
            data.append(chunk)
        }
        if process.isRunning {
            try? handle.close()
            process.terminate()
        }
        process.waitUntilExit()
        try? handle.close()
        return String(decoding: data, as: UTF8.self)
    }
}

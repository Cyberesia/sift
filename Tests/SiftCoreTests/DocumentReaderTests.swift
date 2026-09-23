import SiftCore
import Foundation
import Testing

@Test func markdownNotesSplitOnHeadings() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("sift-notes-\(UUID().uuidString).md")
    try """
    ---
    title: ignore
    ---
    # Garden
    Orbit notes
    # Review
    Duplicate notes
    """.write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    let reading = DocumentReader.read(url: url)
    #expect(reading.category == "notes")
    #expect(reading.units.map(\.title) == ["Garden", "Review"])
    #expect(reading.units[0].text.contains("Orbit"))
}

@Test func csvIsOneSpreadsheet() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("sift-\(UUID().uuidString).csv")
    try "name,count\ncat,1\n".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    let reading = DocumentReader.read(url: url)
    #expect(reading.category == "spreadsheet")
    #expect(reading.units.count == 1)
    #expect(DocumentFormats.isDocument(url: url))
    #expect(!DocumentFormats.isDocument(url: URL(fileURLWithPath: "/tmp/App.swift")))
    #expect(!DocumentFormats.isDocument(url: url, allowed: ["md"]))
    #expect(DocumentFormats.isDocument(url: URL(fileURLWithPath: "/tmp/notes.md"), allowed: ["md"]))
}

@Test func largeDocxIsReadFromAShortSample() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sift-docx-\(UUID().uuidString)", isDirectory: true)
    let word = dir.appendingPathComponent("word", isDirectory: true)
    try FileManager.default.createDirectory(at: word, withIntermediateDirectories: true)
    let paragraph = "<w:p><w:r><w:t>garden note</w:t></w:r></w:p>"
    try Array(repeating: paragraph, count: 4_000).joined().write(to: word.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)
    let docx = FileManager.default.temporaryDirectory.appendingPathComponent("sift-\(UUID().uuidString).docx")
    let zip = Process()
    zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    zip.arguments = ["-q", "-r", docx.path, "word"]
    zip.currentDirectoryURL = dir
    try zip.run()
    zip.waitUntilExit()
    defer {
        try? FileManager.default.removeItem(at: docx)
        try? FileManager.default.removeItem(at: dir)
    }

    let reading = DocumentReader.read(url: docx)
    #expect(reading.category == "prose")
    #expect(reading.excerpt.contains("garden note"))
}

@Test func documentTagsAreTypedAndNeverQuoteTheFile() {
    let prose = DocumentTags.make(
        category: "prose",
        fileName: "compte-rendu-2026.docx",
        units: [
            DocumentUnit(title: "Ordre du jour", text: "The confidential merger discussion stays on this Mac."),
            DocumentUnit(title: "Décisions", text: "Approve the private budget line."),
        ]
    )
    #expect(prose.contains("prose"))
    #expect(prose.contains("sectioned"))
    #expect(prose.contains("minutes"))
    #expect(prose.contains("agenda"))
    #expect(!prose.contains("budget"))
    #expect(prose.allSatisfy { !($0.contains("merger") || $0.contains("confidential")) })
    #expect(prose.allSatisfy(DocumentTags.isTag))

    let sheet = DocumentTags.make(
        category: "spreadsheet",
        fileName: "depenses.xlsx",
        units: [
            DocumentUnit(title: "Q1", text: "secret figures"),
            DocumentUnit(title: "Q2", text: ""),
        ]
    )
    #expect(sheet.contains("spreadsheet"))
    #expect(sheet.contains("multi-sheet"))
    #expect(sheet.contains("expenses"))
    #expect(!sheet.contains { $0.contains("secret") })

    let deck = DocumentTags.make(
        category: "slides",
        fileName: "pitch-formation.pptx",
        units: (1...3).map { DocumentUnit(title: "Slide \($0)", text: "client names") }
    )
    #expect(deck.contains("slides"))
    #expect(deck.contains("short-deck"))
    #expect(deck.contains("pitch"))
    #expect(deck.contains("training"))

    let cleaned = DocumentTags.sanitized(
        fileName: "notes.docx",
        stored: ["prose", "Confidential merger plan"]
    )
    #expect(cleaned == ["prose"])
    #expect(DocumentTags.sanitized(fileName: "a.docx", stored: ["prose", "minutes"]) == ["prose", "minutes"])
}

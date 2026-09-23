import SiftCore
import Foundation
import Testing
#if os(macOS)
import CoreGraphics
import CoreText
#endif

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
    #expect(reading.columns == ["name", "count"])
    let tags = DocumentTags.make(
        category: reading.category,
        fileName: url.lastPathComponent,
        units: reading.units,
        columns: reading.columns
    )
    #expect(tags.contains("name"))
    #expect(tags.contains("count"))
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
    #expect(prose.contains("Ordre du jour"))
    #expect(prose.contains("Décisions"))
    #expect(prose.contains { $0.localizedCaseInsensitiveContains("merger") })
    #expect(!prose.contains("budget"))
    #expect(!prose.contains { $0.contains("private budget") })

    let sheet = DocumentTags.make(
        category: "spreadsheet",
        fileName: "depenses.xlsx",
        units: [
            DocumentUnit(title: "Q1", text: "secret figures"),
            DocumentUnit(title: "Sheet1", text: ""),
        ],
        columns: ["Date", "Client", "Amount"]
    )
    #expect(sheet.contains("spreadsheet"))
    #expect(sheet.contains("multi-sheet"))
    #expect(sheet.contains("expenses"))
    #expect(sheet.contains("Q1"))
    #expect(sheet.contains("Date"))
    #expect(sheet.contains("Client"))
    #expect(sheet.contains("Amount"))
    #expect(!sheet.contains("Sheet1"))
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
    #expect(deck.contains("client names"))
    #expect(!deck.contains("Slide 1"))

    let cleaned = DocumentTags.sanitized(
        fileName: "notes.docx",
        stored: ["prose", "Confidential merger plan", String(repeating: "x", count: 200)]
    )
    #expect(cleaned == ["Confidential merger plan", "prose"])
    #expect(DocumentTags.sanitized(fileName: "a.docx", stored: ["prose", "minutes"]) == ["prose", "minutes"])
}

@Test func spreadsheetColumnsComeFromTheHeaderRow() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sift-xlsx-\(UUID().uuidString)", isDirectory: true)
    let xl = dir.appendingPathComponent("xl", isDirectory: true)
    let sheets = xl.appendingPathComponent("worksheets", isDirectory: true)
    try FileManager.default.createDirectory(at: sheets, withIntermediateDirectories: true)
    try """
    <workbook><sheets><sheet name="Invoices" sheetId="1" r:id="rId1"/></sheets></workbook>
    """.write(to: xl.appendingPathComponent("workbook.xml"), atomically: true, encoding: .utf8)
    try """
    <sst><si><t>Date</t></si><si><t>Client</t></si><si><t>Amount</t></si></sst>
    """.write(to: xl.appendingPathComponent("sharedStrings.xml"), atomically: true, encoding: .utf8)
    try """
    <worksheet><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c></row><row r="2"><c r="A2"><v>99</v></c></row></sheetData></worksheet>
    """.write(to: sheets.appendingPathComponent("sheet1.xml"), atomically: true, encoding: .utf8)
    let xlsx = FileManager.default.temporaryDirectory.appendingPathComponent("sift-\(UUID().uuidString).xlsx")
    let zip = Process()
    zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    zip.arguments = ["-q", "-r", xlsx.path, "xl"]
    zip.currentDirectoryURL = dir
    try zip.run()
    zip.waitUntilExit()
    defer {
        try? FileManager.default.removeItem(at: xlsx)
        try? FileManager.default.removeItem(at: dir)
    }

    let reading = DocumentReader.read(url: xlsx)
    #expect(reading.columns == ["Date", "Client", "Amount"])
    #expect(reading.units.first?.title == "Invoices")
    let tags = DocumentTags.make(
        category: reading.category,
        fileName: "invoices.xlsx",
        units: reading.units,
        columns: reading.columns
    )
    #expect(tags.contains("Invoices"))
    #expect(tags.contains("Date"))
    #expect(tags.contains("Client"))
    #expect(!tags.contains { $0 == "99" })
}

#if os(macOS)
@Test func pdfOpeningBecomesALabel() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("sift-\(UUID().uuidString).pdf")
    var box = CGRect(x: 0, y: 0, width: 400, height: 400)
    guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else {
        Issue.record("Could not create a PDF")
        return
    }
    context.beginPDFPage(nil)
    func draw(_ text: String, at point: CGPoint, size: CGFloat) {
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: text,
            attributes: [.font: font]
        ))
        context.textMatrix = .identity
        context.textPosition = point
        CTLineDraw(line, context)
    }
    draw("Coastal erosion", at: CGPoint(x: 40, y: 340), size: 18)
    draw("This report examines coastal erosion along the Brittany coast.", at: CGPoint(x: 40, y: 300), size: 12)
    context.endPDFPage()
    context.closePDF()
    defer { try? FileManager.default.removeItem(at: url) }

    let reading = DocumentReader.read(url: url)
    #expect(reading.excerpt.localizedCaseInsensitiveContains("coastal"))
    let tags = DocumentTags.make(
        category: reading.category,
        fileName: url.lastPathComponent,
        units: reading.units,
        columns: reading.columns
    )
    #expect(tags.contains { $0.localizedCaseInsensitiveContains("coastal") })
}
#endif

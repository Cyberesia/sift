@testable import SiftCore
import Foundation
import SwiftData
import Testing

private func facts(_ name: String, size: Int64 = 40_000, kind: MediaKind? = .document, created: Date? = nil) -> RuleFileFacts {
    RuleFileFacts(
        url: URL(fileURLWithPath: "/Users/me/Downloads/\(name)"),
        size: size,
        kind: kind,
        createdAt: created,
        modifiedAt: created,
        isCloudOnly: false
    )
}

private let invoiceRule = FolderRuleTemplate.invoices.make(watchedFolderID: "downloads", destinationID: "documents")

// MARK: - Cheap checks

@Test func extensionConditionKeepsOnlyPDFs() {
    #expect(RulePlanner.failedCondition(invoiceRule, facts: facts("Invoice_88231.pdf")) == nil)
    #expect(RulePlanner.failedCondition(invoiceRule, facts: facts("IMG_4471.heic", kind: .image)) == RuleCondition.extensions(["pdf"]).failureReason)
    #expect(RulePlanner.failedCondition(invoiceRule, facts: facts("Figma-124.2.dmg", kind: nil)) == RuleCondition.extensions(["pdf"]).failureReason)
}

@Test func nameAndSizeConditions() {
    var rule = FolderRule(name: "Shots", conditions: [.nameContains("screenshot"), .nameExcludes("draft"), .largerThan(1_000)])
    rule.destinationID = "x"
    #expect(RulePlanner.failedCondition(rule, facts: facts("Screenshot 2026-11-22.png", size: 5_000, kind: .image)) == nil)
    #expect(RulePlanner.failedCondition(rule, facts: facts("Screenshot draft.png", size: 5_000, kind: .image)) != nil)
    #expect(RulePlanner.failedCondition(rule, facts: facts("Screenshot tiny.png", size: 10, kind: .image)) == RuleCondition.largerThan(1_000).failureReason)
    #expect(RulePlanner.failedCondition(rule, facts: facts("photo.png", size: 5_000, kind: .image)) != nil)
}

@Test func partialDownloadsAreNotTouched() {
    #expect(RulePlanner.isStillArriving(URL(fileURLWithPath: "/d/report.pdf.crdownload")))
    #expect(RulePlanner.isStillArriving(URL(fileURLWithPath: "/d/report.pdf.download")))
    #expect(RulePlanner.isStillArriving(URL(fileURLWithPath: "/d/.report.pdf.part")))
    #expect(!RulePlanner.isStillArriving(URL(fileURLWithPath: "/d/report.pdf")))
}

// MARK: - Templates and plans

@Test func planRenamesAndFilesByYearFromTheInvoiceDate() {
    let judgement = FileJudgement(
        matches: true,
        reason: "An invoice from Acme Corp",
        fields: ["vendor": "Acme Corp", "date": "2026-11-03", "amount": "129.00 EUR"],
        answeredBy: "Test"
    )
    let plan = RulePlanner.plan(rule: invoiceRule, facts: facts("Invoice_88231.pdf"), judgement: judgement, destinationName: "Documents")
    #expect(plan.newName == "Acme Corp 2026-11-03.pdf")
    #expect(plan.subfolders == [tr("Invoices", "Factures"), "2026"])
    #expect(plan.destinationLabel == "Documents › \(tr("Invoices", "Factures")) › 2026")
}

@Test func missingValuesLeaveNoGapAndEmptyNamesFallBack() {
    let values = ["vendor": "Uber"]
    #expect(RulePlanner.render("{vendor} {date}", values: values, fallback: "receipt-0412") == "Uber")
    #expect(RulePlanner.render("{vendor} - {date}", values: values, fallback: "x") == "Uber")
    #expect(RulePlanner.render("{vendor} {date}", values: [:], fallback: "receipt-0412") == "receipt-0412")
}

@Test func renderedNamesCannotEscapeTheDestination() {
    let values = ["vendor": "../../etc/passwd", "year": ".."]
    #expect(!RulePlanner.render("{vendor}", values: values, fallback: "x").contains("/"))
    #expect(RulePlanner.subfolders("Invoices/{year}/../{vendor}", values: values).allSatisfy { $0 != ".." && !$0.contains("/") })
    #expect(!RulePlanner.sanitizeComponent("a:b/c\u{0}d").contains(where: { ":/\u{0}".contains($0) }))
}

@Test func yearFallsBackToTheFileDateWithoutAReadDate() {
    var components = DateComponents()
    components.year = 2025
    components.month = 7
    components.day = 14
    let created = Calendar(identifier: .gregorian).date(from: components)
    let values = RulePlanner.templateValues(facts: facts("scan.pdf", created: created), fields: [:])
    #expect(values["year"] == "2025")
    #expect(values["month"] == "07")
    #expect(values["name"] == "scan")
}

@Test func uniqueNamesNeverOverwrite() {
    let taken: Set<String> = ["/d/Acme.pdf", "/d/Acme 2.pdf"]
    let url = RulePlanner.uniqueURL(in: URL(fileURLWithPath: "/d"), name: "Acme.pdf") { taken.contains($0) }
    #expect(url.lastPathComponent == "Acme 3.pdf")
}

@Test func moveCreatesFoldersAndKeepsBothFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("sift-rule-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = root.appendingPathComponent("a.pdf")
    let second = root.appendingPathComponent("b.pdf")
    try Data("one".utf8).write(to: first)
    try Data("two".utf8).write(to: second)
    let target = root.appendingPathComponent("Invoices/2026", isDirectory: true)
    let movedFirst = try FolderRuleEngine.move(first, into: target, name: "Acme.pdf")
    let movedSecond = try FolderRuleEngine.move(second, into: target, name: "Acme.pdf")
    #expect(movedFirst.lastPathComponent == "Acme.pdf")
    #expect(movedSecond.lastPathComponent == "Acme 2.pdf")
    #expect(try String(contentsOf: movedFirst, encoding: .utf8) == "one")
    #expect(!FileManager.default.fileExists(atPath: first.path))
}

@Test func rulesRoundTripThroughJSON() throws {
    let data = try JSONEncoder().encode([invoiceRule])
    let decoded = try JSONDecoder().decode([FolderRule].self, from: data)
    #expect(decoded == [invoiceRule])
    #expect(decoded[0].isEnabled == false)
}

// MARK: - Sift's own reading

@Test func siftJudgeRecognizesAnInvoiceAndItsValues() async throws {
    let text = """
    Acme Corp
    12 Market Street
    INVOICE No. 88231
    Date: 03/11/2026
    Subtotal 107.50 €
    Total TTC 129,00 €
    """
    let request = FileJudgementRequest(fileName: "Invoice_88231.pdf", text: text, check: "an invoice or receipt", fields: ["vendor", "date", "amount"])
    let result = try await SiftJudge().judge(request)
    #expect(result.matches == true)
    #expect(result.fields["vendor"] == "Acme Corp")
    #expect(result.fields["date"] == "2026-11-03")
    #expect(result.fields["amount"] == "129.00 EUR")
}

@Test func siftJudgeSaysALeaseIsNotAnInvoice() async throws {
    let text = "Residential lease agreement between the parties. The tenant agrees to rent the flat."
    let request = FileJudgementRequest(fileName: "Lease renewal.pdf", text: text, check: "an invoice or receipt", fields: [])
    let result = try await SiftJudge().judge(request)
    #expect(result.matches == false)
}

@Test func datesInWordsAndUSOrder() {
    #expect(LocalExtraction.firstDate(in: "Issued on March 3, 2026") == "2026-03-03")
    #expect(LocalExtraction.firstDate(in: "Le 29 octobre 2026") == "2026-10-29")
    #expect(LocalExtraction.firstDate(in: "10/29/2026", monthFirst: true) == "2026-10-29")
    #expect(LocalExtraction.firstDate(in: "29/10/2026", monthFirst: true) == "2026-10-29")
    #expect(LocalExtraction.firstDate(in: "nothing here") == nil)
}

@Test func amountsPreferTheTotalLine() {
    #expect(LocalExtraction.totalAmount(in: "Item $12.00\nItem $40.00\nTotal $52.00") == "52.00 USD")
    #expect(LocalExtraction.totalAmount(in: "Montant à payer : 1 234,56 €") == "1234.56 EUR")
    #expect(LocalExtraction.totalAmount(in: "no money") == nil)
}

// MARK: - Model replies

@Test func judgementParsesJSONWrappedInChatter() throws {
    let request = FileJudgementRequest(fileName: "x.pdf", text: "", check: "an invoice", fields: ["Vendor", "date"])
    let reply = """
    Sure! ```json
    {"matches": false, "reason": "A lease agreement, not an invoice", "fields": {"vendor": "", "date": "2026-01-02"}}
    ```
    """
    let result = try JudgementPrompt.parse(reply, request: request, answeredBy: "Test")
    #expect(result.matches == false)
    #expect(result.reason == "A lease agreement, not an invoice")
    #expect(result.fields == ["date": "2026-01-02"])
}

@Test func schemaRequiresEveryFieldAndNothingElse() {
    let schema = JudgementPrompt.schema(fields: ["vendor", "Due date"])
    let fields = (schema["properties"] as? [String: Any])?["fields"] as? [String: Any]
    #expect(fields?["required"] as? [String] == ["vendor", "due_date"])
    #expect(fields?["additionalProperties"] as? Bool == false)
    #expect(schema["additionalProperties"] as? Bool == false)
}

@Test func claudeRequestUsesStructuredOutputAndFallbacks() throws {
    let judge = ClaudeJudge(model: "claude-opus-5-5", apiKey: "test")
    let body = judge.requestBody(system: "s", user: "u", schema: ["type": "object"])
    let output = body["output_config"] as? [String: Any]
    #expect(body["model"] as? String == "claude-opus-5-5")
    #expect((output?["format"] as? [String: Any])?["type"] as? String == "json_schema")
    #expect(output?["effort"] as? String == "low")
    #expect(body["fallbacks"] as? String == "default")
    #expect(body["thinking"] == nil)

    let haiku = ClaudeJudge(model: "claude-haiku-5-5", apiKey: "test").requestBody(system: "s", user: "u", schema: [:])
    #expect(haiku["fallbacks"] == nil)
}

@Test func claudeRepliesAreReadAndRefusalsAreNot() throws {
    let ok = Data(#"{"stop_reason":"end_turn","content":[{"type":"thinking","thinking":""},{"type":"text","text":"{\"matches\":true}"}]}"#.utf8)
    #expect(try ClaudeJudge.replyText(ok) == #"{"matches":true}"#)
    let refused = Data(#"{"stop_reason":"refusal","content":[]}"#.utf8)
    #expect(throws: IntelligenceError.refused) { try ClaudeJudge.replyText(refused) }
}

@Test func localServerRepliesAreRead() throws {
    let data = Data(#"{"choices":[{"message":{"role":"assistant","content":"{\"matches\":true}"}}]}"#.utf8)
    #expect(try LocalServerJudge.replyText(data) == #"{"matches":true}"#)
}

@Test func localServerOnThisMacIsDetected() {
    #expect(IntelligenceSettings(localServerURL: "http://localhost:11434/v1").localServerIsOnThisMac)
    #expect(IntelligenceSettings(localServerURL: "http://127.0.0.1:1234/v1").localServerIsOnThisMac)
    #expect(!IntelligenceSettings(localServerURL: "http://gpu-box.lan:11434/v1").localServerIsOnThisMac)
}

@MainActor @Test func heuristicDraftUnderstandsInvoicePDFs() {
    let base = FolderRule(name: "x")
    let rule = FolderRuleEngine.heuristicDraft("Put invoice PDFs from Downloads into Invoices by year", base: base)
    #expect(rule.conditions == [.extensions(["pdf"])])
    #expect(rule.check == tr("an invoice or receipt", "une facture ou un reçu"))
    #expect(rule.renameTemplate == "{vendor} {date}")
}

// MARK: - Priority, saved rules, new actions

@MainActor @Test func rulesCanBeReordered() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("sift-rules-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let engine = FolderRuleEngine(
        bookmarkStore: BookmarkStore(),
        destinationStore: DestinationStore(),
        indexStore: MediaIndexStore(container: try ModelContainer(for: StratumSchema.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])),
        journal: TransferJournal(store: MediaIndexStore(container: try ModelContainer(for: StratumSchema.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))),
        intelligence: IntelligenceCenter(defaults: UserDefaults(suiteName: "sift.tests.\(UUID().uuidString)")!),
        storageDirectory: folder
    )
    let first = engine.addRule(FolderRule(name: "A"))
    let second = engine.addRule(FolderRule(name: "B"))
    engine.moveRule(id: second.id, by: -1)
    #expect(engine.rules.map(\.name) == ["B", "A"])
    engine.moveRule(id: first.id, by: -5)
    #expect(engine.rules.map(\.name) == ["A", "B"])
}

@Test func rulesSavedBeforeTagsStillLoad() throws {
    let json = #"[{"id":"r1","name":"Old","isEnabled":true,"createdAt":0,"includeSubfolders":false,"conditions":[],"fields":[],"destinationSubpath":"","mode":"askFirst"}]"#
    let rules = try JSONDecoder().decode([FolderRule].self, from: Data(json.utf8))
    #expect(rules.first?.tags == [])
    #expect(rules.first?.freeUpSpace == false)
    #expect(rules.first?.isEnabled == true)
}

@Test func tagsAloneCountAsAnAction() {
    var rule = FolderRule(name: "Tag only")
    #expect(!rule.hasAction)
    rule.tags = ["Project X"]
    #expect(rule.hasAction)
}

@Test func siftJudgeRecognizesALeaseAsAContract() async throws {
    let text = "Residential lease agreement between the parties. The tenant agrees to rent the flat."
    let check = FolderRuleTemplate.contracts.make(watchedFolderID: nil, destinationID: nil).check
    let result = try await SiftJudge().judge(FileJudgementRequest(fileName: "Lease renewal.pdf", text: text, check: check, fields: []))
    #expect(result.matches == true)
}

@Test func finderTagsAreAddedWithoutDroppingExistingOnes() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("sift-tag-\(UUID().uuidString).txt")
    try Data("x".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    try (file as NSURL).setResourceValue(["Keep"], forKey: .tagNamesKey)
    FolderRuleEngine.addTags(["Invoices", "Keep"], to: file)
    let tags = try URL(fileURLWithPath: file.path).resourceValues(forKeys: [.tagNamesKey]).tagNames ?? []
    #expect(Set(tags) == ["Keep", "Invoices"])
    #expect(!FolderRuleEngine.isInICloud(file))
}

import Foundation
import os.log

/// One file in a rule's "Right now in Downloads" list.
public struct RulePreviewRow: Identifiable, Sendable, Equatable {
    public enum Status: Sendable, Equatable {
        case fits(RulePlan)
        case doesNotFit(String)
        case waitingToRead
        case reading
        case cloudOnly
        case stillArriving
        case failed(String)
    }

    public var id: String { path }
    public var path: String
    public var name: String
    public var kind: MediaKind?
    public var status: Status

    public var fits: Bool { if case .fits = status { return true } else { return false } }
}

public struct RulePreview: Sendable, Equatable {
    public var folderName: String
    /// Files that fit, need reading, or could not be read, first; then those that do not fit.
    public var rows: [RulePreviewRow]
    public var isLoading: Bool
    public var problem: String?

    public var fitCount: Int { rows.filter(\.fits).count }
    public var unreadCount: Int { rows.filter { $0.status == .waitingToRead }.count }

    public static let empty = RulePreview(folderName: "", rows: [], isLoading: false, problem: nil)
}

/// A file that fits an Ask-first rule, waiting for the person to press File.
public struct PendingFiling: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var ruleID: String
    public var ruleName: String
    public var plan: RulePlan
    public var arrivedAt: Date
    public var answeredBy: String

    public var fileName: String { (plan.sourcePath as NSString).lastPathComponent }
}

/// What a rule did, with what is needed to undo it.
public struct RuleActivity: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var date: Date
    public var ruleID: String
    public var ruleName: String
    public var fromPath: String
    public var toPath: String?
    public var transferRecordID: String?
    public var answeredBy: String
    public var note: String
    public var isUndone: Bool

    public var fileName: String { (fromPath as NSString).lastPathComponent }
    public var newName: String? { toPath.map { ($0 as NSString).lastPathComponent } }
}

public enum FolderRuleError: Error, LocalizedError {
    case noWatchedFolder
    case noDestination
    case sourceGone
    case cloudOnly
    case undoUnavailable

    public var errorDescription: String? {
        switch self {
        case .noWatchedFolder: tr("Pick the folder this rule watches.", "Choisissez le dossier que cette règle surveille.")
        case .noDestination: tr("The destination folder is no longer saved. Pick it again.", "Le dossier de destination n’est plus enregistré. Choisissez-le à nouveau.")
        case .sourceGone: tr("The file is no longer where it was.", "Le fichier n’est plus à sa place.")
        case .cloudOnly: tr("The file is in iCloud only. Download it first; Sift will not do it on its own.", "Le fichier n’est que dans iCloud. Téléchargez-le d’abord ; Sift ne le fera pas tout seul.")
        case .undoUnavailable: tr("This move can no longer be undone.", "Ce déplacement ne peut plus être annulé.")
        }
    }
}

/// Runs folder rules: previews what would happen, files new arrivals, keeps an undoable log.
///
/// Work is sequential and paced by `ResourceGovernor`, so a burst of 300 downloads never turns into
/// 300 parallel reads. Only files that pass the cheap checks (name, type, size) are ever opened,
/// cloud placeholders never are, and nothing moves unless a rule is on.
@MainActor
public final class FolderRuleEngine: ObservableObject {
    private static let log = Logger(subsystem: "ai.cyclones.sift", category: "Rules")

    @Published public private(set) var rules: [FolderRule] = []
    @Published public private(set) var previews: [String: RulePreview] = [:]
    @Published public private(set) var pending: [PendingFiling] = []
    @Published public private(set) var activity: [RuleActivity] = []
    @Published public private(set) var busyRuleIDs: Set<String> = []
    @Published public var lastError: String?

    /// Called when files start waiting for the person, with how many.
    public var onFilesWaiting: ((Int, String) -> Void)?
    /// Called after a file moved, so the library can refresh.
    public var onFilesMoved: (() -> Void)?

    public let intelligence: IntelligenceCenter
    private let bookmarkStore: BookmarkStore
    private let destinationStore: DestinationStore
    private let indexStore: MediaIndexStore
    private let journal: TransferJournal
    private let storageURL: URL
    private let governor = ResourceGovernor.shared

    /// How many files a preview reads on its own. "Read more" reads the next ones.
    public var previewReadLimit = 8
    private let previewListLimit = 400

    private var previewTasks: [String: Task<Void, Never>] = [:]
    private var arrivalQueue: [String] = []
    private var queuedArrivalKeys: Set<String> = []
    private var arrivalWorker: Task<Void, Never>?
    /// Files Sift just moved or renamed: their own FSEvents must not trigger the rule again.
    private var recentlyMoved: [String: Date] = [:]
    /// Files the person dismissed from the waiting list, by path and modification date.
    private var dismissed: Set<String> = []

    public init(
        bookmarkStore: BookmarkStore,
        destinationStore: DestinationStore,
        indexStore: MediaIndexStore,
        journal: TransferJournal,
        intelligence: IntelligenceCenter,
        storageDirectory: URL? = nil
    ) {
        self.bookmarkStore = bookmarkStore
        self.destinationStore = destinationStore
        self.indexStore = indexStore
        self.journal = journal
        self.intelligence = intelligence
        let directory = storageDirectory ?? SiftRuntime.supportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.storageURL = directory.appendingPathComponent("folder-rules.json")
        load()
    }

    // MARK: - Persistence

    private struct Saved: Codable {
        var rules: [FolderRule]
        var pending: [PendingFiling]
        var activity: [RuleActivity]
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        rules = saved.rules
        pending = saved.pending
        activity = saved.activity
    }

    private func save() {
        let saved = Saved(rules: rules, pending: pending, activity: Array(activity.prefix(300)))
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    // MARK: - Editing

    public var enabledCount: Int { rules.filter(\.isEnabled).count }

    public func rule(id: String) -> FolderRule? { rules.first { $0.id == id } }

    @discardableResult
    public func addRule(from template: FolderRuleTemplate) -> FolderRule {
        let watched = bookmarkStore.folders.first { $0.displayName.caseInsensitiveCompare("Downloads") == .orderedSame }
            ?? bookmarkStore.folders.first
        let rule = template.make(watchedFolderID: watched?.id, destinationID: destinationStore.activeDestination?.id)
        rules.append(rule)
        save()
        refreshPreview(ruleID: rule.id)
        return rule
    }

    @discardableResult
    public func addRule(_ rule: FolderRule) -> FolderRule {
        rules.append(rule)
        save()
        refreshPreview(ruleID: rule.id)
        return rule
    }

    public func update(_ rule: FolderRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        let previous = rules[index]
        rules[index] = rule
        save()
        if previous.withoutToggle != rule.withoutToggle {
            refreshPreview(ruleID: rule.id)
        }
    }

    public func setEnabled(_ enabled: Bool, ruleID: String) {
        guard var rule = rule(id: ruleID) else { return }
        rule.isEnabled = enabled
        update(rule)
    }

    public func duplicate(ruleID: String) {
        guard var copy = rule(id: ruleID) else { return }
        copy.id = UUID().uuidString
        copy.name += " copy"
        copy.isEnabled = false
        copy.createdAt = .now
        addRule(copy)
    }

    public func delete(ruleID: String) {
        previewTasks[ruleID]?.cancel()
        previewTasks[ruleID] = nil
        rules.removeAll { $0.id == ruleID }
        pending.removeAll { $0.ruleID == ruleID }
        previews[ruleID] = nil
        save()
    }

    public func folderName(for rule: FolderRule) -> String? {
        rule.watchedFolderID.flatMap { bookmarkStore.bookmark(id: $0)?.displayName }
    }

    public func destinationName(for rule: FolderRule) -> String? {
        rule.destinationID.flatMap { destinationStore.destination(id: $0)?.displayName }
    }

    // MARK: - Drafting from a description

    /// Asks the chosen model to turn a sentence into a rule. Falls back to the invoice template's shape
    /// when no model can draft, so the person always gets something to edit.
    public func draftRule(from description: String) async -> FolderRule {
        let folders = bookmarkStore.folders
        let destinations = destinationStore.destinations
        var rule = FolderRuleTemplate.blank.make(
            watchedFolderID: folders.first { description.localizedCaseInsensitiveContains($0.displayName) }?.id ?? folders.first?.id,
            destinationID: destinationStore.activeDestination?.id
        )
        rule.name = String(description.prefix(40))
        let judge = intelligence.currentJudge()
        guard let data = try? await judge.draftRule(
            description: description,
            folderNames: folders.map(\.displayName),
            destinationNames: destinations.map(\.displayName)
        ), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return Self.heuristicDraft(description, base: rule)
        }
        if let name = object["name"] as? String, !name.isEmpty { rule.name = name }
        if let folder = object["watched_folder"] as? String,
           let match = folders.first(where: { $0.displayName.caseInsensitiveCompare(folder) == .orderedSame }) {
            rule.watchedFolderID = match.id
        }
        if let extensions = object["extensions"] as? [String], !extensions.isEmpty {
            rule.conditions = [.extensions(extensions.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ")) })]
        }
        if let check = object["check"] as? String, !check.isEmpty { rule.check = check }
        if let fields = object["fields"] as? [String] { rule.fields = fields.filter { !$0.isEmpty } }
        if let rename = object["rename"] as? String, !rename.isEmpty { rule.renameTemplate = rename }
        if let destination = object["destination"] as? String,
           let match = destinations.first(where: { $0.displayName.caseInsensitiveCompare(destination) == .orderedSame }) {
            rule.destinationID = match.id
        }
        if let subfolder = object["subfolder"] as? String { rule.destinationSubpath = subfolder }
        return rule
    }

    static func heuristicDraft(_ description: String, base: FolderRule) -> FolderRule {
        var rule = base
        let folded = SiftJudge.fold(description)
        let knownExtensions = ["pdf", "dmg", "pkg", "zip", "docx", "xlsx", "pptx", "csv", "png", "jpg", "heic", "mov", "mp4"]
        let found = knownExtensions.filter { folded.range(of: "\\b\($0)s?\\b", options: .regularExpression) != nil }
        if !found.isEmpty { rule.conditions = [.extensions(found)] }
        if folded.contains("screenshot") || folded.contains("capture d") {
            rule.conditions.append(.nameContains("Screenshot"))
        }
        if ["invoice", "facture", "receipt", "recu"].contains(where: folded.contains) {
            rule.check = tr("an invoice or receipt", "une facture ou un reçu")
            rule.fields = ["vendor", "date", "amount"]
            rule.renameTemplate = "{vendor} {date}"
            rule.destinationSubpath = tr("Invoices", "Factures") + "/{year}"
        }
        return rule
    }

    // MARK: - Preview

    /// Lists the watched folder, runs the cheap checks, then reads the first few candidates.
    public func refreshPreview(ruleID: String) {
        previewTasks[ruleID]?.cancel()
        guard let rule = rule(id: ruleID) else { return }
        guard let bookmarkID = rule.watchedFolderID, let bookmark = bookmarkStore.bookmark(id: bookmarkID) else {
            previews[ruleID] = RulePreview(folderName: "", rows: [], isLoading: false, problem: FolderRuleError.noWatchedFolder.localizedDescription)
            return
        }
        previews[ruleID] = RulePreview(folderName: bookmark.displayName, rows: previews[ruleID]?.rows ?? [], isLoading: true, problem: nil)
        previewTasks[ruleID] = Task { [weak self] in
            guard let self else { return }
            let listing: [RuleFileFacts]
            do {
                listing = try self.bookmarkStore.withSecurityScopedAccess(bookmark) { root in
                    Self.listFiles(in: root, includeSubfolders: rule.includeSubfolders, limit: self.previewListLimit)
                }
            } catch {
                self.previews[ruleID] = RulePreview(folderName: bookmark.displayName, rows: [], isLoading: false, problem: error.localizedDescription)
                return
            }
            var rows: [RulePreviewRow] = listing.map { facts in
                let status: RulePreviewRow.Status
                if RulePlanner.isStillArriving(facts.url) {
                    status = .stillArriving
                } else if let failure = RulePlanner.failedCondition(rule, facts: facts) {
                    status = .doesNotFit(failure)
                } else if facts.isCloudOnly && rule.needsReading {
                    status = .cloudOnly
                } else if rule.needsReading {
                    status = .waitingToRead
                } else {
                    status = .fits(RulePlanner.plan(rule: rule, facts: facts, judgement: nil, destinationName: self.destinationName(for: rule)))
                }
                return RulePreviewRow(path: facts.url.path, name: facts.name, kind: facts.kind, status: status)
            }
            rows.sort { Self.order($0.status) < Self.order($1.status) }
            self.previews[ruleID] = RulePreview(folderName: bookmark.displayName, rows: rows, isLoading: false, problem: nil)
            await self.readWaitingRows(ruleID: ruleID, limit: self.previewReadLimit)
        }
    }

    /// Reads the next files that need reading.
    public func readMore(ruleID: String) {
        guard previewTasks[ruleID] == nil || previewTasks[ruleID]?.isCancelled == true || !(previews[ruleID]?.isLoading ?? false) else { return }
        previewTasks[ruleID] = Task { [weak self] in
            guard let self else { return }
            await self.readWaitingRows(ruleID: ruleID, limit: self.previewReadLimit)
        }
    }

    private func readWaitingRows(ruleID: String, limit: Int) async {
        guard let rule = rule(id: ruleID),
              let bookmark = rule.watchedFolderID.flatMap({ bookmarkStore.bookmark(id: $0) }) else { return }
        busyRuleIDs.insert(ruleID)
        defer { busyRuleIDs.remove(ruleID) }
        var read = 0
        while read < limit, !Task.isCancelled {
            guard var preview = previews[ruleID],
                  let index = preview.rows.firstIndex(where: { $0.status == .waitingToRead }) else { break }
            preview.rows[index].status = .reading
            previews[ruleID] = preview
            let path = preview.rows[index].path
            let status: RulePreviewRow.Status
            do {
                try await governor.waitWhileHeld()
                let outcome = try await bookmarkStore.withSecurityScopedAccessAsync(bookmark) { _ in
                    try await self.evaluate(rule: rule, url: URL(fileURLWithPath: path))
                }
                switch outcome {
                case .fits(let plan, _): status = .fits(plan)
                case .doesNotFit(let reason): status = .doesNotFit(reason)
                case .cloudOnly: status = .cloudOnly
                }
            } catch is CancellationError {
                return
            } catch {
                status = .failed(error.localizedDescription)
            }
            if var latest = previews[ruleID], let row = latest.rows.firstIndex(where: { $0.path == path }) {
                latest.rows[row].status = status
                previews[ruleID] = latest
            }
            read += 1
        }
        if var latest = previews[ruleID] {
            latest.rows.sort { Self.order($0.status) < Self.order($1.status) }
            previews[ruleID] = latest
        }
    }

    private static func order(_ status: RulePreviewRow.Status) -> Int {
        switch status {
        case .fits: 0
        case .reading: 1
        case .waitingToRead: 2
        case .failed: 3
        case .cloudOnly: 4
        case .stillArriving: 5
        case .doesNotFit: 6
        }
    }

    nonisolated static func listFiles(in root: URL, includeSubfolders: Bool, limit: Int) -> [RuleFileFacts] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentTypeKey, .creationDateKey, .contentModificationDateKey]
        var urls: [URL] = []
        if includeSubfolders {
            let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants])
            while let url = enumerator?.nextObject() as? URL, urls.count < limit * 2 {
                urls.append(url)
            }
        } else {
            urls = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        }
        let facts = urls.compactMap(RuleFileFacts.read)
        // Newest first: what just landed is what the person is looking for.
        return Array(facts.sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }.prefix(limit))
    }

    // MARK: - Evaluation

    enum Outcome {
        case fits(RulePlan, answeredBy: String)
        case doesNotFit(String)
        case cloudOnly
    }

    /// Cheap checks, then (only if they pass) one read and one question. Caller holds folder access.
    func evaluate(rule: FolderRule, url: URL) async throws -> Outcome {
        guard let facts = RuleFileFacts.read(url) else { throw FolderRuleError.sourceGone }
        if let failure = RulePlanner.failedCondition(rule, facts: facts) { return .doesNotFit(failure) }
        guard rule.needsReading else {
            return .fits(RulePlanner.plan(rule: rule, facts: facts, judgement: nil, destinationName: destinationName(for: rule)), answeredBy: "")
        }
        if facts.isCloudOnly { return .cloudOnly }

        let text = await readText(facts)
        let request = FileJudgementRequest(fileName: facts.name, text: text, check: rule.check, fields: rule.fields)
        let judge = intelligence.currentJudge()
        var judgement: FileJudgement
        do {
            judgement = try await judge.judge(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // The chosen model is down or refused: Sift's own reading answers, and says so.
            Self.log.error("\(judge.displayName, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            judgement = try await SiftJudge().judge(request)
            judgement.answeredBy = "Sift (\(judge.displayName) unavailable)"
            if !judgement.reason.isEmpty { judgement.reason += " · \(judge.displayName) unavailable" }
        }
        if judgement.matches == false {
            let reason = judgement.reason.isEmpty ? "Not \(rule.check ?? "a match")" : judgement.reason
            return .doesNotFit("\(judgement.answeredBy.split(separator: " ").first ?? "Sift") : \(reason)".replacingOccurrences(of: " : ", with: SiftLanguage.isFrench ? " : " : ": "))
        }
        let plan = RulePlanner.plan(rule: rule, facts: facts, judgement: judgement, destinationName: destinationName(for: rule))
        return .fits(plan, answeredBy: judgement.answeredBy)
    }

    /// The start of a document's text, read off the main thread, within the memory budget, never from iCloud.
    private func readText(_ facts: RuleFileFacts) async -> String {
        guard facts.kind == .document, !facts.isCloudOnly,
              governor.admitsRead(kind: .document, fileSize: facts.size, fileExtension: facts.fileExtension) else {
            return ""
        }
        let url = facts.url
        return await Task.detached(priority: governor.analysisPriority) {
            let reading = DocumentReader.read(url: url)
            return reading.excerpt
        }.value
    }

    // MARK: - Arrivals

    /// Called with FSEvents paths from watched folders. Only enabled rules react.
    public func handleArrivals(bookmarks: [FolderBookmark], paths: [String]) {
        let ids = Set(bookmarks.map(\.id))
        let active = rules.filter { $0.isEnabled && $0.hasAction && ($0.watchedFolderID.map(ids.contains) ?? false) }
        guard !active.isEmpty else { return }
        let now = Date()
        recentlyMoved = recentlyMoved.filter { now.timeIntervalSince($0.value) < 30 }
        for path in Set(paths) {
            let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
            guard recentlyMoved[standardized] == nil, !queuedArrivalKeys.contains(standardized) else { continue }
            guard active.contains(where: { watches($0, path: standardized) }) else { continue }
            queuedArrivalKeys.insert(standardized)
            arrivalQueue.append(standardized)
        }
        startArrivalWorker()
    }

    /// True when the rule's folder holds this path (directly, or below it when subfolders count).
    private func watches(_ rule: FolderRule, path: String) -> Bool {
        guard let bookmark = rule.watchedFolderID.flatMap({ bookmarkStore.bookmark(id: $0) }),
              let root = try? bookmarkStore.resolve(bookmark).standardizedFileURL.path,
              path.hasPrefix(root + "/") else { return false }
        return rule.includeSubfolders || (path as NSString).deletingLastPathComponent == root
    }

    private func startArrivalWorker() {
        guard arrivalWorker == nil, !arrivalQueue.isEmpty else { return }
        arrivalWorker = Task { [weak self] in
            while let self, !self.arrivalQueue.isEmpty, !Task.isCancelled {
                let path = self.arrivalQueue.removeFirst()
                await self.processArrival(path: path)
                self.queuedArrivalKeys.remove(path)
            }
            self?.arrivalWorker = nil
        }
    }

    /// Rules are tried from the top of the list down. The first one that fits acts; the others leave the file alone.
    private func processArrival(path: String) async {
        let url = URL(fileURLWithPath: path)
        if RulePlanner.isStillArriving(url) { return } // its final name will send its own event
        guard await waitUntilSettled(url) else { return }
        if let facts = RuleFileFacts.read(url), dismissed.contains(Self.dismissKey(facts)) { return }
        if pending.contains(where: { $0.plan.sourcePath == path }) { return }
        for rule in rules where rule.isEnabled && rule.hasAction && watches(rule, path: path) {
            guard let bookmark = rule.watchedFolderID.flatMap({ bookmarkStore.bookmark(id: $0) }) else { continue }
            do {
                try await governor.waitWhileHeld()
                let outcome = try await bookmarkStore.withSecurityScopedAccessAsync(bookmark) { _ in
                    try await self.evaluate(rule: rule, url: url)
                }
                guard case .fits(let plan, let answeredBy) = outcome else { continue }
                let fellBack = answeredBy.contains("unavailable")
                if rule.mode == .automatic, !fellBack {
                    try file(plan: plan, rule: rule, answeredBy: answeredBy)
                } else {
                    pending.append(PendingFiling(id: UUID().uuidString, ruleID: rule.id, ruleName: rule.name, plan: plan, arrivedAt: .now, answeredBy: answeredBy))
                    save()
                    onFilesWaiting?(pending.count, rule.name)
                }
                if previews[rule.id] != nil { refreshPreview(ruleID: rule.id) }
                return
            } catch is CancellationError {
                return
            } catch {
                lastError = "\(rule.name): \(error.localizedDescription)"
                return
            }
        }
    }

    /// Moves a rule up or down the list. Higher rules get the first look at each new file.
    public func moveRule(id: String, by offset: Int) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(index + offset, 0), rules.count - 1)
        guard target != index else { return }
        let rule = rules.remove(at: index)
        rules.insert(rule, at: target)
        save()
    }

    /// A download is done when its size stops changing. Waits at most ten minutes.
    private func waitUntilSettled(_ url: URL) async -> Bool {
        var lastSize: Int64 = -1
        var stableChecks = 0
        for _ in 0..<300 {
            guard let facts = RuleFileFacts.read(url) else { return false }
            if facts.isCloudOnly { return true } // evaluate reports it; nothing to wait for
            if facts.size == lastSize, facts.size > 0 {
                stableChecks += 1
                if stableChecks >= 2 { return true }
            } else {
                stableChecks = 0
                lastSize = facts.size
            }
            do { try await Task.sleep(for: .seconds(2)) } catch { return false }
        }
        return false
    }

    private static func dismissKey(_ facts: RuleFileFacts) -> String {
        "\(facts.url.path)|\(facts.modifiedAt?.timeIntervalSince1970 ?? 0)"
    }

    // MARK: - Filing

    /// "File 2 already here": files every row the preview found fitting.
    public func fileFittingRows(ruleID: String) {
        guard let rule = rule(id: ruleID), let preview = previews[ruleID] else { return }
        var moved = 0
        for row in preview.rows {
            guard case .fits(let plan) = row.status else { continue }
            do {
                try file(plan: plan, rule: rule, answeredBy: intelligence.status.readerName)
                moved += 1
            } catch {
                lastError = "\(row.name): \(error.localizedDescription)"
            }
        }
        if moved > 0 { refreshPreview(ruleID: ruleID) }
    }

    public func filePending(_ ids: Set<String>? = nil) {
        let chosen = pending.filter { ids?.contains($0.id) ?? true }
        for item in chosen {
            guard let rule = rule(id: item.ruleID) else { continue }
            do {
                try file(plan: item.plan, rule: rule, answeredBy: item.answeredBy)
                pending.removeAll { $0.id == item.id }
            } catch {
                lastError = "\(item.fileName): \(error.localizedDescription)"
                if case FolderRuleError.sourceGone = error { pending.removeAll { $0.id == item.id } }
            }
        }
        save()
    }

    public func dismissPending(_ id: String) {
        guard let item = pending.first(where: { $0.id == id }) else { return }
        if let facts = RuleFileFacts.read(URL(fileURLWithPath: item.plan.sourcePath)) {
            dismissed.insert(Self.dismissKey(facts))
        }
        pending.removeAll { $0.id == id }
        save()
    }

    /// Asks iCloud to download a placeholder. Its arrival on disk triggers the rule again.
    public func requestDownload(path: String) {
        CloudMaterializationPolicy.requestDownload(of: URL(fileURLWithPath: path))
    }

    /// Moves (and renames) one file as planned, journals it, and points the catalog at the new path.
    func file(plan: RulePlan, rule: FolderRule, answeredBy: String) throws {
        guard let bookmark = rule.watchedFolderID.flatMap({ bookmarkStore.bookmark(id: $0) }) else {
            throw FolderRuleError.noWatchedFolder
        }
        let source = URL(fileURLWithPath: plan.sourcePath)
        let target: URL = try bookmarkStore.withSecurityScopedAccess(bookmark) { _ in
            guard FileManager.default.fileExists(atPath: source.path) else { throw FolderRuleError.sourceGone }
            if CloudFileState.isDataless(source) && plan.destinationID != nil {
                // Moving a placeholder across volumes would download it. Within iCloud Drive it is a rename,
                // but Sift cannot tell which, so it leaves the choice to the person.
                throw FolderRuleError.cloudOnly
            }
            if let destinationID = plan.destinationID {
                guard let destination = destinationStore.destination(id: destinationID) else { throw FolderRuleError.noDestination }
                return try destinationStore.withSecurityScopedAccess(destination) { root in
                    try Self.move(source, into: plan.subfolders.reduce(root) { $0.appendingPathComponent($1, isDirectory: true) }, name: plan.newName)
                }
            }
            return try Self.move(source, into: source.deletingLastPathComponent(), name: plan.newName)
        }
        recentlyMoved[target.standardizedFileURL.path] = .now
        recentlyMoved[source.standardizedFileURL.path] = .now
        if !rule.tags.isEmpty {
            Self.addTags(rule.tags, to: target)
        }
        if rule.freeUpSpace, Self.isInICloud(target) {
            scheduleEviction(of: target)
        }
        let record = try journal.record(assetID: "file:" + source.path, sourcePath: source.path, destinationPath: target.path, mode: .move)
        try? indexStore.updateAssetPath(assetID: "file:" + source.path, newURL: target)
        let note = plan.reason.isEmpty ? "" : plan.reason
        activity.insert(RuleActivity(
            id: UUID().uuidString,
            date: .now,
            ruleID: rule.id,
            ruleName: rule.name,
            fromPath: source.path,
            toPath: target.path,
            transferRecordID: record.id,
            answeredBy: answeredBy,
            note: note,
            isUndone: false
        ), at: 0)
        save()
        onFilesMoved?()
    }

    /// Adds Finder tags, keeping the ones the file already has.
    nonisolated static func addTags(_ tags: [String], to url: URL) {
        let existing = (try? url.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
        let merged = existing + tags.filter { !existing.contains($0) }
        try? (url as NSURL).setResourceValue(merged, forKey: .tagNamesKey)
    }

    /// True when the URL is inside iCloud Drive (or another folder macOS syncs and can evict).
    public nonisolated static func isInICloud(_ url: URL) -> Bool {
        var probe = url
        if !FileManager.default.fileExists(atPath: probe.path) { probe = url.deletingLastPathComponent() }
        return (try? probe.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true
    }

    /// Once iCloud has the file, macOS may drop the local copy. It stays visible and downloads again on open.
    private func scheduleEviction(of url: URL) {
        Task.detached(priority: .background) {
            for _ in 0..<120 { // up to an hour
                let uploaded = (try? url.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey]).ubiquitousItemIsUploaded) == true
                if uploaded {
                    try? FileManager.default.evictUbiquitousItem(at: url)
                    return
                }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    nonisolated static func move(_ source: URL, into directory: URL, name: String) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        if directory.standardizedFileURL.appendingPathComponent(name).path == source.standardizedFileURL.path {
            return source
        }
        let target = RulePlanner.uniqueURL(in: directory, name: name)
        try manager.moveItem(at: source, to: target)
        return target
    }

    /// Puts the file back where it was, under its old name.
    public func undo(activityID: String) {
        guard let index = activity.firstIndex(where: { $0.id == activityID }) else { return }
        let entry = activity[index]
        guard let recordID = entry.transferRecordID, let record = journal.record(id: recordID) else {
            lastError = FolderRuleError.undoUnavailable.localizedDescription
            return
        }
        // A deleted rule leaves no folder access to borrow; outside the sandbox the undo still works.
        let rule = self.rule(id: entry.ruleID) ?? FolderRule(name: entry.ruleName)
        do {
            try withAccess(rule: rule) {
                try journal.undo(record: record)
            }
            activity[index].isUndone = true
            recentlyMoved[entry.fromPath] = .now
            save()
            onFilesMoved?()
            if previews[entry.ruleID] != nil { refreshPreview(ruleID: entry.ruleID) }
        } catch {
            lastError = "Undo: \(error.localizedDescription)"
        }
    }

    /// Opens the sandbox for the rule's watched folder and destination, when they are still saved.
    private func withAccess(rule: FolderRule, _ body: () throws -> Void) throws {
        let watched = rule.watchedFolderID.flatMap { bookmarkStore.bookmark(id: $0) }
        let destination = rule.destinationID.flatMap { destinationStore.destination(id: $0) }
        switch (watched, destination) {
        case let (watched?, destination?):
            try bookmarkStore.withSecurityScopedAccess(watched) { _ in
                try destinationStore.withSecurityScopedAccess(destination) { _ in try body() }
            }
        case let (watched?, nil):
            try bookmarkStore.withSecurityScopedAccess(watched) { _ in try body() }
        case let (nil, destination?):
            try destinationStore.withSecurityScopedAccess(destination) { _ in try body() }
        case (nil, nil):
            try body()
        }
    }
}

private extension FolderRule {
    /// The rule minus the switch: toggling on or off does not need a new preview.
    var withoutToggle: FolderRule {
        var copy = self
        copy.isEnabled = false
        copy.mode = .askFirst
        copy.name = ""
        return copy
    }
}

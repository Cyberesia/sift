import Foundation

/// "When a file lands in Downloads and it's a PDF, read it, confirm it's an invoice, note the vendor,
/// date and amount, rename it {vendor} {date} and move it to Documents › Invoices › {year}."
public struct FolderRule: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var name: String
    /// Off by default. A rule only acts once the person turns it on.
    public var isEnabled: Bool
    public var createdAt: Date

    /// A saved source folder (`FolderBookmark.id`), so the sandbox already allows reading it.
    public var watchedFolderID: String?
    /// Files in subfolders of the watched folder count too.
    public var includeSubfolders: Bool
    /// Cheap checks on name, type and size. All must pass before anything is read.
    public var conditions: [RuleCondition]

    /// What the file must be, in plain words: "an invoice or receipt". Nil: no reading for a check.
    public var check: String?
    /// Values to note from the text: "vendor", "date", "amount".
    public var fields: [String]

    /// New name without the extension: "{vendor} {date}". Nil keeps the name.
    public var renameTemplate: String?
    /// A saved destination (`DestinationBookmark.id`). Nil: rename in place.
    public var destinationID: String?
    /// Path inside the destination, "/" separated, with tokens: "Invoices/{year}".
    public var destinationSubpath: String

    /// Finder tags added to the file.
    public var tags: [String]
    /// After moving into iCloud Drive, let macOS remove the local copy once it is uploaded.
    public var freeUpSpace: Bool

    public var mode: RunMode

    public enum RunMode: String, Codable, Sendable, CaseIterable {
        /// Matching files wait in a list until the person presses File.
        case askFirst
        /// Matching files are filed as soon as they finish arriving. Every move can be undone.
        case automatic

        public var label: String {
            switch self {
            case .askFirst: tr("Ask me before filing", "Me demander avant de ranger")
            case .automatic: tr("File them on their own", "Les ranger seuls")
            }
        }
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        isEnabled: Bool = false,
        createdAt: Date = .now,
        watchedFolderID: String? = nil,
        includeSubfolders: Bool = false,
        conditions: [RuleCondition] = [],
        check: String? = nil,
        fields: [String] = [],
        renameTemplate: String? = nil,
        destinationID: String? = nil,
        destinationSubpath: String = "",
        tags: [String] = [],
        freeUpSpace: Bool = false,
        mode: RunMode = .askFirst
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.watchedFolderID = watchedFolderID
        self.includeSubfolders = includeSubfolders
        self.conditions = conditions
        self.check = check
        self.fields = fields
        self.renameTemplate = renameTemplate
        self.destinationID = destinationID
        self.destinationSubpath = destinationSubpath
        self.tags = tags
        self.freeUpSpace = freeUpSpace
        self.mode = mode
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isEnabled, createdAt, watchedFolderID, includeSubfolders, conditions, check, fields
        case renameTemplate, destinationID, destinationSubpath, tags, freeUpSpace, mode
    }

    /// Fields added later decode with defaults, so saved rules keep working.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        watchedFolderID = try c.decodeIfPresent(String.self, forKey: .watchedFolderID)
        includeSubfolders = try c.decodeIfPresent(Bool.self, forKey: .includeSubfolders) ?? false
        conditions = try c.decodeIfPresent([RuleCondition].self, forKey: .conditions) ?? []
        check = try c.decodeIfPresent(String.self, forKey: .check)
        fields = try c.decodeIfPresent([String].self, forKey: .fields) ?? []
        renameTemplate = try c.decodeIfPresent(String.self, forKey: .renameTemplate)
        destinationID = try c.decodeIfPresent(String.self, forKey: .destinationID)
        destinationSubpath = try c.decodeIfPresent(String.self, forKey: .destinationSubpath) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        freeUpSpace = try c.decodeIfPresent(Bool.self, forKey: .freeUpSpace) ?? false
        mode = try c.decodeIfPresent(RunMode.self, forKey: .mode) ?? .askFirst
    }

    /// True when the rule needs a file's text: a check, or values for the name or the folder.
    public var needsReading: Bool {
        if let check, !check.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return !fields.isEmpty
    }

    /// True when the rule would change something.
    public var hasAction: Bool {
        destinationID != nil || !(renameTemplate ?? "").trimmingCharacters(in: .whitespaces).isEmpty || !tags.isEmpty
    }
}

public enum RuleCondition: Codable, Sendable, Hashable, Identifiable {
    case extensions([String])
    case kind(MediaKind)
    case nameContains(String)
    case nameExcludes(String)
    case largerThan(Int64)
    case smallerThan(Int64)

    public var id: String {
        switch self {
        case .extensions(let list): "ext:" + list.joined(separator: ",")
        case .kind(let kind): "kind:" + kind.rawValue
        case .nameContains(let text): "has:" + text
        case .nameExcludes(let text): "not:" + text
        case .largerThan(let bytes): "gt:\(bytes)"
        case .smallerThan(let bytes): "lt:\(bytes)"
        }
    }

    /// The words in the rule sentence: "it's a PDF", "the name has “scan”".
    public var phrase: String {
        switch self {
        case .extensions(let list):
            let names = list.map { $0.uppercased() }
            if names.count == 1 { return tr("it’s a \(names[0])", "c’est un \(names[0])") }
            return tr("it’s a ", "c’est un ") + names.dropLast().joined(separator: ", ") + tr(" or ", " ou ") + (names.last ?? "")
        case .kind(let kind):
            switch kind {
            case .image: return tr("it’s a photo", "c’est une photo")
            case .video: return tr("it’s a video", "c’est une vidéo")
            case .audio: return tr("it’s audio", "c’est de l’audio")
            case .document: return tr("it’s a document", "c’est un document")
            }
        case .nameContains(let text): return tr("the name has “\(text)”", "le nom contient « \(text) »")
        case .nameExcludes(let text): return tr("the name lacks “\(text)”", "le nom ne contient pas « \(text) »")
        case .largerThan(let bytes): return tr("it’s over ", "il dépasse ") + ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        case .smallerThan(let bytes): return tr("it’s under ", "il fait moins de ") + ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
    }

    /// The reason shown when a file fails this condition: "Not a PDF".
    public var failureReason: String {
        switch self {
        case .extensions(let list):
            return tr("Not a ", "Pas un ") + list.map { $0.uppercased() }.joined(separator: tr(" or ", " ou "))
        case .kind(let kind):
            return tr("Not a \(kind.rawValue)", "Pas le bon genre (\(kind.rawValue))")
        case .nameContains(let text): return tr("Name lacks “\(text)”", "Le nom ne contient pas « \(text) »")
        case .nameExcludes(let text): return tr("Name has “\(text)”", "Le nom contient « \(text) »")
        case .largerThan: return tr("Too small", "Trop petit")
        case .smallerThan: return tr("Too large", "Trop grand")
        }
    }
}

/// Ready-made rules for the New rule menu. Starting points: every part can be changed afterwards.
public enum FolderRuleTemplate: String, CaseIterable, Identifiable, Sendable {
    case invoices
    case contracts
    case payslips
    case statements
    case screenshots
    case installers
    case largeVideos
    case blank

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .invoices: tr("Invoices and receipts", "Factures et reçus")
        case .contracts: tr("Contracts and agreements", "Contrats et accords")
        case .payslips: tr("Payslips", "Fiches de paie")
        case .statements: tr("Bank statements", "Relevés bancaires")
        case .screenshots: tr("Screenshots by month", "Captures par mois")
        case .installers: tr("Tidy installers", "Ranger les installeurs")
        case .largeVideos: tr("Large videos to iCloud", "Grosses vidéos vers iCloud")
        case .blank: tr("Empty rule", "Règle vide")
        }
    }

    public var icon: String {
        switch self {
        case .invoices: "doc.text.magnifyingglass"
        case .contracts: "signature"
        case .payslips: "banknote"
        case .statements: "building.columns"
        case .screenshots: "camera.viewfinder"
        case .installers: "shippingbox"
        case .largeVideos: "film.stack"
        case .blank: "square.dashed"
        }
    }

    /// Templates that read documents, grouped in the New rule menu.
    public static let documents: [FolderRuleTemplate] = [.invoices, .contracts, .payslips, .statements]
    public static let files: [FolderRuleTemplate] = [.screenshots, .installers, .largeVideos]

    public func make(watchedFolderID: String?, destinationID: String?) -> FolderRule {
        let base = FolderRule(name: title, watchedFolderID: watchedFolderID, destinationID: destinationID)
        var rule = base
        switch self {
        case .invoices:
            rule.conditions = [.extensions(["pdf"])]
            rule.check = tr("an invoice or receipt", "une facture ou un reçu")
            rule.fields = ["vendor", "date", "amount"]
            rule.renameTemplate = "{vendor} {date}"
            rule.destinationSubpath = tr("Invoices", "Factures") + "/{year}"
        case .contracts:
            rule.conditions = [.extensions(["pdf", "docx"])]
            rule.check = tr("a contract, lease or agreement", "un contrat, un bail ou un accord")
            rule.fields = ["company", "date"]
            rule.renameTemplate = "{company} {date}"
            rule.destinationSubpath = tr("Contracts", "Contrats") + "/{year}"
        case .payslips:
            rule.conditions = [.extensions(["pdf"])]
            rule.check = tr("a payslip", "une fiche de paie")
            rule.fields = ["company", "date"]
            rule.renameTemplate = tr("Payslip", "Fiche de paie") + " {year}-{month}"
            rule.destinationSubpath = tr("Payslips", "Fiches de paie") + "/{year}"
        case .statements:
            rule.conditions = [.extensions(["pdf", "csv"])]
            rule.check = tr("a bank statement", "un relevé bancaire")
            rule.fields = ["company", "date"]
            rule.renameTemplate = "{company} {year}-{month}"
            rule.destinationSubpath = tr("Statements", "Relevés") + "/{year}"
        case .screenshots:
            rule.conditions = [.kind(.image), .nameContains("Screenshot")]
            rule.destinationSubpath = tr("Screenshots", "Captures") + "/{year}-{month}"
        case .installers:
            rule.conditions = [.extensions(["dmg", "pkg", "zip"])]
            rule.destinationSubpath = tr("Installers", "Installeurs")
        case .largeVideos:
            rule.conditions = [.kind(.video), .largerThan(1 << 30)]
            rule.destinationID = nil // pick a folder in iCloud Drive
            rule.destinationSubpath = tr("Videos", "Vidéos") + "/{year}"
            rule.freeUpSpace = true
        case .blank:
            rule.name = tr("New rule", "Nouvelle règle")
        }
        return rule
    }
}

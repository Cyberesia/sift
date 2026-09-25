import Foundation

/// What a sentence typed in the assistant asks for. Bounded: Jev and the offline classifier choose among these only.
public enum AssistantIntent: String, CaseIterable, Sendable, Codable {
    case find
    case scan
    case slice
    case organizeByType
    case organizeByDate
    case organizeByContent
    case leaveInPlace
    case review
    case none

    public static var cards: [AssistantIntent] { allCases.filter { $0 != .none } }

    public var isPlan: Bool {
        self == .organizeByType || self == .organizeByDate || self == .organizeByContent
    }

    /// Criteria sent to Jev. Self-contained and non-overlapping, with `none` as the escape.
    public var criterion: String {
        switch self {
        case .find: "Finding files already in the catalog by what they show, their text, or their name, such as pictures with dogs or the invoice from March"
        case .scan: "Adding this Mac, a disk, or a folder to the catalog so its files can be found later"
        case .slice: "Narrowing which already cataloged files to look at, such as only some file types or one folder, without saying where they go"
        case .organizeByType: "Putting cataloged files into destination folders by file type or media kind"
        case .organizeByDate: "Putting cataloged files into folders by year, month, or date"
        case .organizeByContent: "Putting cataloged files into folders by what they show or contain, such as screenshots, people, or documents about a subject"
        case .leaveInPlace: "Keeping files where they are and moving nothing"
        case .review: "Reviewing duplicates, faces, or uncertain suggestions before deciding"
        case .none: "Too short, unclear, or unrelated to finding or organizing files"
        }
    }
}

public enum AssistantGrouping: String, Sendable, Equatable {
    case year
    case month
}

/// Values read from the sentence by code. Jev never extracts these.
public struct AssistantCommand: Sendable, Equatable {
    public var included: Set<String> = []
    public var excluded: Set<String> = []
    public var kinds: Set<MediaKind> = []
    public var sourceLabel: String?
    public var folder: String?
    public var grouping: AssistantGrouping?
    public var mode: FileTransferMode?
    public var scansWholeMac = false
    /// What to look for once command words, kinds, extensions, and folder names are removed. "find pictures with dogs" gives ["dogs"].
    public var searchTerms: [String] = []

    public init() {}

    public var searchQuery: String { searchTerms.joined(separator: " ") }

    public var slice: CatalogSlice {
        CatalogSlice(sourceLabel: sourceLabel, includedExtensions: included, excludedExtensions: excluded, kinds: kinds)
    }

    public var hasSliceWords: Bool {
        !included.isEmpty || !excluded.isEmpty || !kinds.isEmpty || sourceLabel != nil
    }
}

/// What the command field found in the catalog. There is always something to show: matches, look-alikes, or why nothing came back.
public struct AssistantFindResult: Sendable, Equatable {
    public enum Match: Sendable, Equatable {
        /// Labels, recognized text, or file names contain the words.
        case labeled
        /// Nothing is labeled that way; these are the closest-looking files.
        case lookalike
        case nothing
    }

    public var query: String
    public var hits: [MediaAssetSummary]
    public var labeledCount: Int
    public var searchedCount: Int
    public var searching: Bool
    public var visualSearchReady: Bool

    public init(query: String, hits: [MediaAssetSummary] = [], labeledCount: Int = 0, searchedCount: Int = 0, searching: Bool = true, visualSearchReady: Bool = false) {
        self.query = query
        self.hits = hits
        self.labeledCount = labeledCount
        self.searchedCount = searchedCount
        self.searching = searching
        self.visualSearchReady = visualSearchReady
    }

    public var match: Match {
        if labeledCount > 0 { return .labeled }
        return hits.isEmpty ? .nothing : .lookalike
    }

    /// Spellings to try against stored labels, which Vision keeps singular ("dog", not "dogs").
    public static func variants(of term: String) -> [String] {
        var forms = [term]
        if term.count > 3, term.hasSuffix("ies") { forms.append(String(term.dropLast(3)) + "y") }
        if term.count > 3, term.hasSuffix("es") { forms.append(String(term.dropLast(2))) }
        if term.count > 2, term.hasSuffix("s") || term.hasSuffix("x") { forms.append(String(term.dropLast())) }
        var seen = Set<String>()
        return forms.filter { seen.insert($0).inserted }
    }
}

/// The same shape whether the answer came from Jev or from the offline classifier.
public struct AssistantResult: Sendable, Equatable {
    public var probabilities: [AssistantIntent: Double]
    public var readiness: Double
    public var engine: String

    public init(probabilities: [AssistantIntent: Double], readiness: Double = 0.5, engine: String = "offline") {
        self.probabilities = probabilities
        self.readiness = readiness
        self.engine = engine
    }

    public var ranked: [(AssistantIntent, Double)] {
        probabilities.map { ($0.key, $0.value) }.sorted {
            $0.1 == $1.1 ? $0.0.rawValue < $1.0.rawValue : $0.1 > $1.1
        }
    }

    public var value: AssistantIntent { ranked.first?.0 ?? .none }
    public var confidence: Double { ranked.first?.1 ?? 0 }
}

/// Reads extensions, kinds, folder, grouping, and move or copy from a sentence, in French or English.
public enum AssistantParser {
    public static let commonExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tif", "tiff", "webp", "bmp", "raw", "dng", "cr2", "cr3", "nef", "arw", "raf", "rw2", "orf",
        "mov", "mp4", "m4v", "avi", "mkv", "mts",
        "mp3", "m4a", "wav", "aiff", "aif", "flac", "aac", "ogg",
        "pdf", "docx", "xlsx", "pptx", "csv", "md", "mdx", "txt", "rtf",
    ]

    private static let exclusionCues: Set<String> = [
        "pas", "sauf", "hors", "sans", "except", "excluding", "without", "not", "no", "leave", "laisse", "laisser", "ignore", "ignorer", "skip",
    ]
    private static let kindWords: [(Set<String>, MediaKind)] = [
        (["photo", "photos", "image", "images", "picture", "pictures"], .image),
        (["video", "videos", "vidéo", "vidéos", "film", "films"], .video),
        (["audio", "audios", "music", "musique", "musiques", "son", "sons", "song", "songs"], .audio),
        (["document", "documents", "doc", "docs"], .document),
    ]
    private static let folderCues: Set<String> = ["dans", "into", "to", "vers", "in", "en"]

    public static func parse(
        _ text: String,
        knownExtensions: Set<String> = [],
        sources: [String] = [],
        folders: [String] = []
    ) -> AssistantCommand {
        var command = AssistantCommand()
        let lowered = fold(text)
        var remaining = lowered

        if let folder = folderName(in: lowered, folders: folders) {
            command.folder = folder
            remaining = remaining.replacingOccurrences(of: fold(folder), with: " ")
        }

        command.sourceLabel = sources
            .sorted { $0.count > $1.count }
            .first { !$0.isEmpty && lowered.contains(fold($0)) }
        if let source = command.sourceLabel {
            remaining = remaining.replacingOccurrences(of: fold(source), with: " ")
        }

        let extensions = knownExtensions.union(commonExtensions)
        for clause in clauses(remaining) {
            let words = tokens(clause)
            let excluding = words.contains(where: exclusionCues.contains)
            for word in words {
                guard let ext = extensionToken(word, known: extensions) else { continue }
                if excluding {
                    command.excluded.insert(ext)
                } else {
                    command.included.insert(ext)
                }
            }
            if !excluding {
                for (set, kind) in kindWords where words.contains(where: set.contains) {
                    command.kinds.insert(kind)
                }
            }
        }
        command.included.subtract(command.excluded)

        let words = tokens(lowered)
        if phrase(["par mois", "by month", "monthly", "par date", "by date", "mensuel"], in: lowered) {
            command.grouping = .month
        } else if phrase(["par an", "par annee", "par année", "by year", "yearly", "annuel"], in: lowered) {
            command.grouping = .year
        }
        if words.contains(where: { ["copie", "copier", "copy", "duplique"].contains($0) }) {
            command.mode = .copy
        } else if words.contains(where: { ["deplace", "déplace", "deplacer", "déplacer", "move"].contains($0) }) {
            command.mode = .move
        }
        command.scansWholeMac = phrase(["ce mac", "this mac", "mon mac", "my mac", "tout le mac", "whole mac", "entire mac"], in: lowered)
        let kindTokens = kindWords.reduce(into: Set<String>()) { $0.formUnion($1.0) }
        command.searchTerms = tokens(remaining).filter { word in
            word.count >= 2
                && !commandWords.contains(word)
                && !kindTokens.contains(word)
                && extensionToken(word, known: extensions) == nil
        }
        return command
    }

    /// Verbs and fillers that never describe what a file shows.
    static let commandWords: Set<String> = [
        "find", "search", "look", "looking", "show", "where", "which", "any", "all", "every", "my", "me", "the", "a", "an", "of", "with", "that",
        "have", "has", "got", "is", "are", "there", "for", "from", "on", "in", "into", "to", "and", "or", "some", "please", "can", "you", "i", "see", "get",
        "cherche", "chercher", "trouve", "trouver", "montre", "montrer", "affiche", "afficher", "voir", "ou", "quelles", "quels", "quel", "quelle",
        "les", "le", "la", "l", "des", "de", "du", "d", "un", "une", "avec", "mes", "mon", "ma", "tous", "toutes", "tout", "qui", "que", "il", "y",
        "moi", "stp", "svp", "et", "dans", "en", "sur", "pour", "est", "sont",
        "only", "just", "seulement", "juste", "uniquement", "not", "no", "without", "sans", "pas", "sauf", "except",
        "scan", "scanne", "scanner", "index", "indexe", "add", "ajoute", "ajouter", "mac", "this", "ce", "disk", "disque", "folder", "folders", "dossier", "dossiers",
        "organize", "organise", "organiser", "range", "ranger", "trie", "trier", "classe", "classer", "sort", "file", "put", "mets", "mettre",
        "move", "deplace", "deplacer", "copy", "copie", "copier", "by", "par", "date", "month", "year", "mois", "annee",
        "review", "revoir", "leave", "laisse", "keep", "garde",
    ]

    static func extensionToken(_ word: String, known: Set<String>) -> String? {
        var value = word
        if value.hasPrefix(".") { value.removeFirst() }
        if known.contains(value) { return CatalogSlice.normalized(value) }
        if value.hasSuffix("s"), known.contains(String(value.dropLast())) {
            return CatalogSlice.normalized(String(value.dropLast()))
        }
        return nil
    }

    private static func folderName(in lowered: String, folders: [String]) -> String? {
        for folder in folders.sorted(by: { $0.count > $1.count }) where !folder.isEmpty {
            let name = fold(folder)
            for cue in folderCues where lowered.contains("\(cue) \(name)") || lowered.contains("\(cue) le dossier \(name)") {
                return folder
            }
        }
        return nil
    }

    static func clauses(_ text: String) -> [String] {
        var parts: [String] = [text]
        for separator in [",", ";", " mais ", " but ", " et laisse", " and leave", " sauf ", " except "] {
            parts = parts.flatMap { part -> [String] in
                let pieces = part.components(separatedBy: separator)
                guard pieces.count > 1 else { return [part] }
                let cue = separator.trimmingCharacters(in: .whitespaces)
                return [pieces[0]] + pieces.dropFirst().map { cue.hasPrefix("et") || cue.hasPrefix("and") || cue == "sauf" || cue == "except" ? "\(cue) \($0)" : $0 }
            }
        }
        return parts
    }

    static func tokens(_ text: String) -> [String] {
        text.split { !$0.isLetter && !$0.isNumber && $0 != "." && $0 != "'" }
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: ".'")) }
            .filter { !$0.isEmpty }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
    }

    static func phrase(_ phrases: [String], in text: String) -> Bool {
        phrases.contains { text.contains(fold($0)) }
    }
}

/// Keyword classifier with the same output shape as Jev. Used without a key and whenever Jev fails.
public enum AssistantOfflineClassifier {
    public static func classify(_ text: String, command: AssistantCommand) -> AssistantResult {
        let lowered = AssistantParser.fold(text)
        let words = Set(AssistantParser.tokens(lowered))
        var weights: [AssistantIntent: Double] = [:]
        func hit(_ intent: AssistantIntent, _ amount: Double) { weights[intent, default: 0] += amount }

        let scanWords: Set<String> = ["scan", "scanne", "scanner", "index", "indexe", "indexer", "add", "ajoute", "ajouter", "import", "importe", "disk", "disque", "drive", "folder", "folders", "dossier", "dossiers"]
        let findWords: Set<String> = ["find", "search", "look", "looking", "show", "where", "which", "any", "cherche", "chercher", "trouve", "trouver", "montre", "montrer", "affiche", "afficher", "voir", "see", "ou", "quelles", "quels"]
        let organizeWords: Set<String> = ["range", "ranger", "trie", "trier", "classe", "classer", "organise", "organiser", "organize", "sort", "file", "mets", "mettre", "put", "move", "deplace", "deplacer", "copie", "copier", "copy", "ventile"]
        let reviewWords: Set<String> = ["revoir", "review", "doublon", "doublons", "duplicate", "duplicates", "visage", "visages", "faces", "verifier", "check"]
        let sliceWords: Set<String> = ["seulement", "only", "juste", "just", "uniquement", "filtre", "filter", "garde", "keep"]
        let contentWords: Set<String> = ["contenu", "content", "sujet", "subject", "captures", "screenshots", "personnes", "people", "theme", "montrent", "show"]

        let organizes = !words.isDisjoint(with: organizeWords)
        let hasSubject = !command.searchTerms.isEmpty
        let asksToFind = !words.isDisjoint(with: findWords)
        let scans = !words.isDisjoint(with: scanWords) || command.scansWholeMac
        if scans { hit(.scan, command.hasSliceWords && organizes ? 0.4 : 1.2) }
        if command.scansWholeMac { hit(.scan, 0.8) }
        if !organizes, !scans {
            if asksToFind, hasSubject {
                hit(.find, 1.5)
            } else if asksToFind {
                hit(.find, 0.5)
            }
        }
        if !words.isDisjoint(with: reviewWords) { hit(.review, 1.2) }
        if AssistantParser.phrase(["laisse tout", "ne touche", "ne bouge", "leave everything", "don't move", "dont move", "move nothing", "rien ne bouge", "touche a rien"], in: lowered) {
            hit(.leaveInPlace, 1.6)
        }
        if organizes {
            if command.grouping != nil || AssistantParser.phrase(["date", "mois", "annee", "year", "month"], in: lowered) {
                hit(.organizeByDate, 1.4)
            } else if !words.isDisjoint(with: contentWords) {
                hit(.organizeByContent, 1.2)
            } else {
                hit(.organizeByType, command.folder != nil || command.hasSliceWords ? 1.4 : 0.9)
            }
        }
        if command.grouping != nil, !organizes { hit(.organizeByDate, 0.6) }
        if !words.isDisjoint(with: sliceWords) || (command.hasSliceWords && !organizes && !(asksToFind && hasSubject)) {
            hit(.slice, organizes ? 0.3 : 1.1)
        }

        var total = weights.values.reduce(0, +)
        if total == 0, command.searchQuery.count >= 3 {
            hit(.find, 0.9)
            total = 0.9
        }
        guard total > 0 else {
            return AssistantResult(probabilities: [.none: 0.8], readiness: 0.1)
        }
        let base = 0.35
        var probabilities: [AssistantIntent: Double] = [:]
        for (intent, weight) in weights {
            probabilities[intent] = weight / (total + base)
        }
        probabilities[.none] = base / (total + base) / 2
        let readiness: Double = {
            let top = probabilities.max { $0.value < $1.value }?.key ?? .none
            if top.isPlan { return command.folder != nil || command.grouping != nil ? 0.9 : 0.55 }
            if top == .slice { return command.hasSliceWords ? 0.85 : 0.3 }
            if top == .find { return command.searchTerms.isEmpty ? 0.3 : 0.9 }
            return 0.7
        }()
        return AssistantResult(probabilities: probabilities, readiness: readiness)
    }
}

/// Calm UI states for the assistant field, ported from Shapeshift's decide.ts.
public enum AssistantUIState: Sendable, Equatable {
    case input
    case ghost(AssistantIntent)
    case choose(AssistantIntent, AssistantIntent)
    case committed(AssistantIntent, forced: Bool)

    public var activeIntent: AssistantIntent? {
        switch self {
        case .ghost(let intent), .committed(let intent, _): intent
        default: nil
        }
    }
}

public struct AssistantMemory: Sendable, Equatable {
    public var ui: AssistantUIState = .input
    public var challenger: (intent: AssistantIntent, wins: Int)?
    public var forcedText: String?

    public init() {}

    public static func == (lhs: AssistantMemory, rhs: AssistantMemory) -> Bool {
        lhs.ui == rhs.ui && lhs.forcedText == rhs.forcedText
            && lhs.challenger?.intent == rhs.challenger?.intent && lhs.challenger?.wins == rhs.challenger?.wins
    }
}

public enum AssistantDecide {
    public static let inputBelow = 0.4
    public static let commitAt = 0.7
    public static let chooseGap = 0.15
    public static let chooseFloor = 0.25
    public static let challengerOverride = 0.85
    public static let challengerWins = 2
    public static let dropBelow = 0.3
    public static let forcedChangeRatio = 0.3

    public static func rawState(_ result: AssistantResult) -> AssistantUIState {
        let ranked = result.ranked.filter { $0.0 != .none }
        if ranked.count >= 2 {
            let (a, pa) = ranked[0]
            let (b, pb) = ranked[1]
            if pa > chooseFloor, pb > chooseFloor, pa - pb < chooseGap {
                return .choose(a, b)
            }
        }
        let top = result.value
        let confidence = result.confidence
        if top == .none || confidence < inputBelow { return .input }
        if confidence < commitAt { return .ghost(top) }
        return .committed(top, forced: false)
    }

    public static func decide(_ memory: AssistantMemory, result: AssistantResult, text: String) -> AssistantMemory {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return AssistantMemory() }
        if case .committed(_, true) = memory.ui, let forcedText = memory.forcedText,
           !changedSubstantially(from: forcedText, to: text) {
            return memory
        }
        let raw = rawState(result)
        var next = AssistantMemory()
        guard case .committed(let current, false) = memory.ui else {
            next.ui = raw
            return next
        }
        let top = result.value
        let topConfidence = result.confidence
        let currentP = result.probabilities[current] ?? 0
        if top == current {
            next.ui = memory.ui
            return next
        }
        if top == .none {
            if currentP < dropBelow { return next }
            var kept = memory
            kept.challenger = nil
            return kept
        }
        if topConfidence >= challengerOverride || (current.isPlan && top.isPlan && topConfidence >= inputBelow) {
            next.ui = .committed(top, forced: false)
            return next
        }
        let wins = memory.challenger?.intent == top ? (memory.challenger?.wins ?? 0) + 1 : 1
        if wins >= challengerWins, topConfidence >= inputBelow {
            next.ui = raw
            return next
        }
        if currentP < dropBelow, topConfidence < inputBelow {
            return next
        }
        next.ui = memory.ui
        next.challenger = (top, wins)
        return next
    }

    public static func force(_ intent: AssistantIntent, text: String) -> AssistantMemory {
        var memory = AssistantMemory()
        memory.ui = .committed(intent, forced: true)
        memory.forcedText = text
        return memory
    }

    public static func changedSubstantially(from: String, to: String) -> Bool {
        let length = max(from.count, to.count, 1)
        return Double(levenshtein(Array(from), Array(to))) > forcedChangeRatio * Double(length)
    }

    static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a == b { return 0 }
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i]
            for j in 1...b.count {
                current.append(min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)))
            }
            previous = current
        }
        return previous[b.count]
    }
}

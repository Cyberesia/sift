import Foundation

/// A screen Jev may open. Search is the fallback and is never applied as navigation.
public enum JevSurface: String, Sendable {
    case search
    case library
    case garden
    case sources
    case inbox
    case organize
    case review
    case duplicates
}

public struct JevCandidate: Sendable, Equatable {
    public let id: String
    public let fileName: String
    public let labels: [String]

    public init(id: String, fileName: String, labels: [String]) {
        self.id = id
        self.fileName = fileName
        self.labels = labels
    }
}

/// Applies Jev only when a key exists and the answer is confident and inside the allowed set.
/// Anything else leaves the local result untouched.
public enum JevAdvisor {
    public static let routeConfidence = 0.72
    public static let rerankConfidence = 0.66
    public static let folderConfidence = 0.70
    public static let folders = ["Photos", "Videos", "Music & Audio", "Screenshots & Documents"]
    /// A large local group is not retargeted by one remote guess.
    public static let maxGroupSize = 40

    /// Opens a known screen without calling Jev. Picture searches stay nil.
    public static func localSurface(for query: String) -> JevSurface? {
        let words = query.lowercased().split { !$0.isLetter && $0 != "'" }.map(String.init)
        if words.contains(where: { ["doublon", "doublons", "duplicate", "duplicates", "dupes", "dupe"].contains($0) }) {
            return .duplicates
        }
        guard looksLikeCommand(query) else { return nil }
        if words.contains(where: { ["garden", "jardin"].contains($0) }) { return .garden }
        if words.contains(where: { ["review", "revue"].contains($0) }) { return .review }
        if words.contains(where: { ["organize", "organise", "organiser"].contains($0) }) { return .organize }
        if words.contains("inbox") { return .inbox }
        if words.contains(where: { ["source", "sources", "discover"].contains($0) }) { return .sources }
        if words.contains(where: { ["library", "bibliotheque", "bibliothèque", "galerie", "gallery"].contains($0) }) {
            return .library
        }
        return nil
    }

    public static func routeTitle(for surface: JevSurface) -> String {
        switch surface {
        case .search: "Press Return to search"
        case .library: "Press Return to open the library"
        case .garden: "Press Return to open the garden"
        case .sources: "Press Return to open discovery"
        case .inbox: "Press Return to open the inbox"
        case .organize: "Press Return to open organize"
        case .review: "Press Return to open review"
        case .duplicates: "Press Return to open duplicates"
        }
    }

    public static func looksLikeCommand(_ query: String) -> Bool {
        let words = query.lowercased().split { !$0.isLetter && $0 != "'" }.map(String.init)
        let cues: Set<String> = [
            "open", "show", "go", "organize", "organise",
            "ouvre", "ouvrir", "montre", "affiche", "organiser",
        ]
        return words.contains { cues.contains($0) }
    }

    public static func acceptedRoute(_ choice: JevChoice) -> JevSurface? {
        guard choice.confidence >= routeConfidence,
              let surface = JevSurface(rawValue: choice.value),
              surface != .search else { return nil }
        return surface
    }

    /// Moves the chosen id to the front when it is already in the list. Otherwise the order stays.
    public static func promotedOrder(ids: [String], choice: JevChoice) -> [String] {
        guard choice.confidence >= rerankConfidence,
              let index = ids.firstIndex(of: choice.value),
              index > 0 else { return ids }
        var copy = ids
        let id = copy.remove(at: index)
        copy.insert(id, at: 0)
        return copy
    }

    public static func acceptedFolder(_ choice: JevChoice, allowed: [String] = folders) -> String? {
        guard choice.confidence >= folderConfidence, allowed.contains(choice.value) else { return nil }
        return choice.value
    }

    public static func route(query: String) async -> JevSurface? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeCommand(trimmed), JevCredential.isConfigured else { return nil }
        do {
            guard let choice = try await JevClient.ask(
                state: "User command: \(trimmed). Navigation only. No file contents.",
                instructions: "Which screen should open? Choose search when the user is looking for pictures or media.",
                choices: [
                    "search": "Find pictures or other media matching the words",
                    "library": "Open the library grid",
                    "garden": "Open the spatial garden",
                    "sources": "Open discovery and folder sources",
                    "inbox": "Open new unsorted files",
                    "organize": "Open the organize view",
                    "review": "Open people and suggestion review",
                    "duplicates": "Open duplicate review",
                ]
            ) else { return nil }
            return acceptedRoute(choice)
        } catch {
            return nil
        }
    }

    /// Picks one id from a short text list. Returns nil when the choice should not change the CLIP order.
    public static func promotedID(query: String, candidates: [JevCandidate]) async -> String? {
        let slice = Array(candidates.prefix(8))
        guard slice.count >= 2, JevCredential.isConfigured else { return nil }
        var criteria: [String: String] = [:]
        for item in slice {
            let labels = item.labels.prefix(6).joined(separator: ", ")
            let fact = labels.isEmpty ? item.fileName : "\(item.fileName); \(labels)"
            criteria[item.id] = String(fact.prefix(180))
        }
        do {
            guard let choice = try await JevClient.ask(
                state: "Search query: \(query). Candidates are filenames and tags. Document text is not included.",
                instructions: "Which candidate best matches the query? Answer with one of the given ids.",
                choices: criteria
            ) else { return nil }
            let order = promotedOrder(ids: slice.map(\.id), choice: choice)
            guard order.first != slice.first?.id else { return nil }
            return order.first
        } catch {
            return nil
        }
    }

    public static func proposeFolder(localFolder: String, sampleNames: [String]) async -> String? {
        guard JevCredential.isConfigured, folders.contains(localFolder) else { return nil }
        let names = sampleNames.prefix(5).joined(separator: ", ")
        do {
            guard let choice = try await JevClient.ask(
                state: "Local folder: \(localFolder). Example filenames: \(names). Choose one existing folder.",
                instructions: "Which existing destination folder fits this group? Do not invent a path.",
                choices: Dictionary(uniqueKeysWithValues: folders.map { ($0, "Put the files in \($0)") })
            ) else { return nil }
            guard let folder = acceptedFolder(choice), folder != localFolder else { return nil }
            return folder
        } catch {
            return nil
        }
    }
}

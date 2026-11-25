import Foundation
import UniformTypeIdentifiers

/// What Sift knows about a file without opening it.
public struct RuleFileFacts: Sendable, Hashable {
    public var url: URL
    public var size: Int64
    public var kind: MediaKind?
    public var createdAt: Date?
    public var modifiedAt: Date?
    public var isCloudOnly: Bool

    public var name: String { url.lastPathComponent }
    public var stem: String { url.deletingPathExtension().lastPathComponent }
    public var fileExtension: String { url.pathExtension.lowercased() }

    public init(url: URL, size: Int64, kind: MediaKind?, createdAt: Date?, modifiedAt: Date?, isCloudOnly: Bool) {
        self.url = url
        self.size = size
        self.kind = kind
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isCloudOnly = isCloudOnly
    }

    /// Metadata only: no read, so no iCloud download.
    public static func read(_ url: URL) -> RuleFileFacts? {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentTypeKey, .creationDateKey, .contentModificationDateKey]
        guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { return nil }
        return RuleFileFacts(
            url: url,
            size: Int64(values.fileSize ?? 0),
            kind: RulePlanner.kind(for: url, contentType: values.contentType),
            createdAt: values.creationDate,
            modifiedAt: values.contentModificationDate,
            isCloudOnly: CloudFileState.isDataless(url)
        )
    }
}

/// Where a file will go. Built before anything moves, shown in the preview, then executed as is.
public struct RulePlan: Sendable, Hashable, Codable {
    public var sourcePath: String
    /// The new file name with its extension.
    public var newName: String
    /// Folders inside the destination, already rendered: ["Invoices", "2026"].
    public var subfolders: [String]
    public var destinationID: String?
    /// For display: "Documents › Invoices › 2026".
    public var destinationLabel: String
    public var reason: String
    public var values: [String: String]

    public init(sourcePath: String, newName: String, subfolders: [String], destinationID: String?, destinationLabel: String, reason: String, values: [String: String]) {
        self.sourcePath = sourcePath
        self.newName = newName
        self.subfolders = subfolders
        self.destinationID = destinationID
        self.destinationLabel = destinationLabel
        self.reason = reason
        self.values = values
    }

    public var changesName: Bool { newName != (sourcePath as NSString).lastPathComponent }
}

public enum RulePlanner {
    /// Extensions browsers and copy tools use while a file is still arriving.
    public static let partialExtensions: Set<String> = ["download", "crdownload", "part", "partial", "opdownload", "tmp", "temp", "!ut", "aria2"]

    /// Cheap checks only. Returns the reason the file does not fit, or nil when it fits so far.
    public static func failedCondition(_ rule: FolderRule, facts: RuleFileFacts) -> String? {
        for condition in rule.conditions {
            switch condition {
            case .extensions(let list):
                let allowed = Set(list.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ")) })
                if !allowed.isEmpty, !allowed.contains(facts.fileExtension) { return condition.failureReason }
            case .kind(let kind):
                if facts.kind != kind { return condition.failureReason }
            case .nameContains(let text):
                if !text.isEmpty, facts.name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
                    return condition.failureReason
                }
            case .nameExcludes(let text):
                if !text.isEmpty, facts.name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                    return condition.failureReason
                }
            case .largerThan(let bytes):
                if facts.size <= bytes { return condition.failureReason }
            case .smallerThan(let bytes):
                if facts.size >= bytes { return condition.failureReason }
            }
        }
        return nil
    }

    /// True while a file is still being written: a browser's partial name, or a hidden temp file.
    public static func isStillArriving(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") || name.hasPrefix("~$") { return true }
        return partialExtensions.contains(url.pathExtension.lowercased())
    }

    /// Values a template can use: the judged fields plus date parts and the original name.
    public static func templateValues(facts: RuleFileFacts, fields: [String: String], now: Date = .now) -> [String: String] {
        var values: [String: String] = [:]
        for (key, value) in fields { values[key] = value }
        let dateSource: Date = fields.first(where: { $0.key.contains("date") })
            .flatMap { parseISODate($0.value) } ?? facts.createdAt ?? facts.modifiedAt ?? now
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: dateSource)
        values["year"] = values["year"] ?? String(format: "%04d", parts.year ?? 2000)
        values["month"] = values["month"] ?? String(format: "%02d", parts.month ?? 1)
        values["day"] = values["day"] ?? String(format: "%02d", parts.day ?? 1)
        values["name"] = facts.stem
        values["ext"] = facts.fileExtension
        return values
    }

    /// "{vendor} {date}" with the values filled in. Missing values leave no gap; an empty result keeps the old name.
    public static func render(_ template: String, values: [String: String], fallback: String) -> String {
        var output = ""
        var token = ""
        var inToken = false
        for character in template {
            if character == "{" { inToken = true; token = ""; continue }
            if character == "}", inToken {
                inToken = false
                let key = JudgementPrompt.fieldKey(token)
                output += values[key] ?? values[token] ?? ""
                continue
            }
            if inToken { token.append(character) } else { output.append(character) }
        }
        let cleaned = sanitizeComponent(output)
        return cleaned.isEmpty ? sanitizeComponent(fallback) : cleaned
    }

    /// Safe as one file or folder name: no slashes, colons or control characters, no leading dot,
    /// no dangling separators left by an empty token.
    public static func sanitizeComponent(_ raw: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\\0").union(.controlCharacters).union(.newlines)
        var text = raw.unicodeScalars.map { forbidden.contains($0) ? " " : String($0) }.joined()
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s*([-_.,])(\\s*[-_.,])+", with: "$1", options: .regularExpression)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " -_.,"))
        while text.hasPrefix(".") { text.removeFirst() }
        if text == ".." { return "" }
        return String(text.prefix(180))
    }

    /// "Invoices/{year}" → ["Invoices", "2026"]. Never climbs out of the destination.
    public static func subfolders(_ template: String, values: [String: String]) -> [String] {
        template.split(separator: "/").compactMap { part in
            let rendered = render(String(part), values: values, fallback: "")
            return rendered.isEmpty || rendered == "." || rendered == ".." ? nil : rendered
        }
    }

    public static func plan(
        rule: FolderRule,
        facts: RuleFileFacts,
        judgement: FileJudgement?,
        destinationName: String?,
        now: Date = .now
    ) -> RulePlan {
        let values = templateValues(facts: facts, fields: judgement?.fields ?? [:], now: now)
        var newName = facts.name
        if let template = rule.renameTemplate, !template.trimmingCharacters(in: .whitespaces).isEmpty {
            let stem = render(template, values: values, fallback: facts.stem)
            newName = facts.fileExtension.isEmpty ? stem : "\(stem).\(facts.fileExtension)"
        }
        let folders = rule.destinationID == nil ? [] : subfolders(rule.destinationSubpath, values: values)
        let label: String
        if rule.destinationID != nil {
            label = ([destinationName ?? "Destination"] + folders).joined(separator: " › ")
        } else {
            label = facts.url.deletingLastPathComponent().lastPathComponent
        }
        return RulePlan(
            sourcePath: facts.url.path,
            newName: newName,
            subfolders: folders,
            destinationID: rule.destinationID,
            destinationLabel: label,
            reason: judgement?.reason ?? "",
            values: judgement?.fields ?? [:]
        )
    }

    /// "Acme 2026-11-03.pdf", then "Acme 2026-11-03 2.pdf" if that is taken.
    public static func uniqueURL(in directory: URL, name: String, exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> URL {
        let candidate = directory.appendingPathComponent(name)
        if !exists(candidate.path) { return candidate }
        let stem = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        for index in 2...999 {
            let next = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
            let url = directory.appendingPathComponent(next)
            if !exists(url.path) { return url }
        }
        return directory.appendingPathComponent(ext.isEmpty ? "\(stem) \(UUID().uuidString.prefix(6))" : "\(stem) \(UUID().uuidString.prefix(6)).\(ext)")
    }

    static func parseISODate(_ text: String) -> Date? {
        guard let match = text.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: String(text[match]))
    }

    public static func kind(for url: URL, contentType: UTType?) -> MediaKind? {
        if let contentType {
            if contentType.conforms(to: .image) { return .image }
            if contentType.conforms(to: .movie) || contentType.conforms(to: .video) { return .video }
            if contentType.conforms(to: .audio) { return .audio }
        }
        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tif", "tiff", "bmp", "dng", "cr2", "nef", "arw"].contains(ext) { return .image }
        if ["mov", "mp4", "m4v", "avi", "mkv", "webm"].contains(ext) { return .video }
        if ["mp3", "m4a", "aac", "wav", "aiff", "aif", "flac"].contains(ext) { return .audio }
        if DocumentFormats.isDocument(url: url) { return .document }
        return nil
    }
}

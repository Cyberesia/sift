import Foundation

/// One catalog row reduced to what counting and slicing need.
public struct CompositionFile: Sendable, Equatable {
    public let id: String
    public let sourceLabel: String
    public let fileExtension: String
    public let kind: MediaKind
    public let fileSize: Int64
    public let date: Date?
    public let isAnalyzed: Bool

    public init(
        id: String,
        sourceLabel: String,
        fileExtension: String,
        kind: MediaKind,
        fileSize: Int64 = 0,
        date: Date? = nil,
        isAnalyzed: Bool = true
    ) {
        self.id = id
        self.sourceLabel = sourceLabel
        self.fileExtension = fileExtension
        self.kind = kind
        self.fileSize = fileSize
        self.date = date
        self.isAnalyzed = isAnalyzed
    }

    public init(record: MediaAssetRecord) {
        self.init(
            id: record.id,
            sourceLabel: record.sourceLabel,
            fileExtension: record.fileExtension ?? EvidenceCard.fileExtension(of: record.fileURL),
            kind: record.kind,
            fileSize: record.fileSize ?? 0,
            date: record.captureDate ?? record.modifiedAt,
            isAnalyzed: record.isAnalyzed
        )
    }
}

/// What one source folder already holds in the catalog. Counted by code, never by Jev.
public struct CatalogComposition: Sendable, Equatable {
    public struct ExtensionCount: Sendable, Equatable, Identifiable {
        public let fileExtension: String
        public let kind: MediaKind
        public let count: Int
        public let bytes: Int64
        public var id: String { fileExtension }
    }

    public let sourceLabel: String
    public let total: Int
    public let totalBytes: Int64
    /// Most common first. An empty string is a file without an extension.
    public let extensions: [ExtensionCount]
    public let kinds: [MediaKind: Int]
    public let earliest: Date?
    public let latest: Date?
    public let unanalyzed: Int

    public static func make(sourceLabel: String, files: [CompositionFile]) -> CatalogComposition {
        let byExtension: [String: [CompositionFile]] = Dictionary(grouping: files, by: \.fileExtension)
        var extensions: [ExtensionCount] = []
        for (ext, items) in byExtension {
            let bytes: Int64 = items.reduce(Int64(0)) { $0 + $1.fileSize }
            extensions.append(ExtensionCount(
                fileExtension: ext,
                kind: items.first?.kind ?? .image,
                count: items.count,
                bytes: bytes
            ))
        }
        extensions.sort { lhs, rhs in
            lhs.count == rhs.count ? lhs.fileExtension < rhs.fileExtension : lhs.count > rhs.count
        }
        let dates: [Date] = files.compactMap(\.date)
        return CatalogComposition(
            sourceLabel: sourceLabel,
            total: files.count,
            totalBytes: files.reduce(Int64(0)) { $0 + $1.fileSize },
            extensions: extensions,
            kinds: Dictionary(grouping: files, by: \.kind).mapValues(\.count),
            earliest: dates.min(),
            latest: dates.max(),
            unanalyzed: files.filter { !$0.isAnalyzed }.count
        )
    }
}

/// The part of the catalog a decision applies to: one folder, some extensions, some kinds, a date range.
public struct CatalogSlice: Sendable, Equatable, Hashable {
    public var sourceLabel: String?
    /// Empty means every extension that is not excluded.
    public var includedExtensions: Set<String>
    public var excludedExtensions: Set<String>
    /// Empty means every kind.
    public var kinds: Set<MediaKind>
    public var from: Date?
    public var until: Date?

    public init(
        sourceLabel: String? = nil,
        includedExtensions: Set<String> = [],
        excludedExtensions: Set<String> = [],
        kinds: Set<MediaKind> = [],
        from: Date? = nil,
        until: Date? = nil
    ) {
        self.sourceLabel = sourceLabel
        self.includedExtensions = Set(includedExtensions.map(Self.normalized))
        self.excludedExtensions = Set(excludedExtensions.map(Self.normalized))
        self.kinds = kinds
        self.from = from
        self.until = until
    }

    public static let everything = CatalogSlice()

    public var isEverything: Bool { self == .everything }

    public func contains(_ file: CompositionFile) -> Bool {
        if let sourceLabel, file.sourceLabel != sourceLabel { return false }
        let ext = Self.normalized(file.fileExtension)
        if excludedExtensions.contains(ext) { return false }
        if !includedExtensions.isEmpty, !includedExtensions.contains(ext) { return false }
        if !kinds.isEmpty, !kinds.contains(file.kind) { return false }
        if let from, let date = file.date, date < from { return false }
        if let until, let date = file.date, date > until { return false }
        return true
    }

    /// Counts what the slice keeps in a composition, extension by extension.
    public func kept(in composition: CatalogComposition) -> [CatalogComposition.ExtensionCount] {
        composition.extensions.filter { item in
            let probe = CompositionFile(
                id: "",
                sourceLabel: composition.sourceLabel,
                fileExtension: item.fileExtension,
                kind: item.kind
            )
            return contains(probe)
        }
    }

    public static func normalized(_ ext: String) -> String {
        var value = ext.lowercased().trimmingCharacters(in: .whitespaces)
        if value.hasPrefix(".") { value.removeFirst() }
        if value == "jpeg" { return "jpg" }
        return value
    }
}

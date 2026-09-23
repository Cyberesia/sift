import CoreGraphics
@preconcurrency import CoreML
import Foundation
import Tokenizers

public enum ClipModelStatus: String, Sendable {
    case missing
    case loading
    case ready
    case failed
}

public struct ClipWeightProgress: Sendable, Equatable {
    public var fileIndex: Int
    public var fileCount: Int
    public var completedBytes: Int64
    public var totalBytes: Int64

    public var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(completedBytes) / Double(totalBytes)))
    }

    public var statusLine: String {
        "File \(fileIndex) of \(fileCount) · \(Self.megabytes(completedBytes)) of \(Self.megabytes(totalBytes)) MB"
    }

    public static let starting = ClipWeightProgress(
        fileIndex: 1,
        fileCount: 2,
        completedBytes: 0,
        totalBytes: 302_514_176
    )

    public init(fileIndex: Int, fileCount: Int, completedBytes: Int64, totalBytes: Int64) {
        self.fileIndex = fileIndex
        self.fileCount = fileCount
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
    }

    private static func megabytes(_ bytes: Int64) -> String {
        String(format: "%.0f", Double(bytes) / 1_048_576)
    }
}

public enum ClipEmbeddingError: Error, LocalizedError {
    case missingResource(String)
    case invalidOutput

    public var errorDescription: String? {
        switch self {
        case .missingResource(let name): "Bundled CLIP resource is missing: \(name)"
        case .invalidOutput: "The bundled CLIP model returned an invalid embedding."
        }
    }
}

/// On-device Core ML CLIP. The tokenizer ships with the app. Each weight file is
/// larger than GitHub allows, so the first launch downloads it once into Application Support.
public actor ClipEmbeddingStore {
    public static let shared = ClipEmbeddingStore()
    public static let modelVersion = "datacomp-vit-b-32-coreml-2026-01"
    public static let vectorDimension = 512
    private static let weightNames = ["CLIP_ImageEncoder", "CLIP_TextEncoder"]
    private static let weightSource = "https://huggingface.co/InspiratioNULL/CLIP-VIT-B-32-DataComp.XL-CoreML/resolve/main"
    /// Both published weight files are larger than this. A smaller file is a partial download.
    private static let minimumWeightBytes = 100_000_000
    /// Image tower is about 167.5MB, text tower about 121MB.
    private static let expectedBytes: [String: Int64] = [
        "CLIP_ImageEncoder": 175_636_480,
        "CLIP_TextEncoder": 126_877_696,
    ]

    private var imageModel: MLModel?
    private var textModel: MLModel?
    private var tokenizer: Tokenizer?
    private var loadError: Error?

    public static var status: ClipModelStatus {
        guard Bundle.module.url(forResource: "tokenizer", withExtension: "json", subdirectory: "CLIP") != nil,
              weightNames.allSatisfy({ bundledPackage($0) != nil }) else {
            return .missing
        }
        return weightNames.allSatisfy({ loadablePackage($0) != nil }) ? .ready : .missing
    }

    /// Downloads the two weight files when this Mac does not have them yet.
    public func ensureWeights(onProgress: (@Sendable (ClipWeightProgress) -> Void)? = nil) async throws {
        let total = Self.expectedBytes.values.reduce(Int64(0), +)
        var prior: Int64 = 0
        for (index, name) in Self.weightNames.enumerated() {
            let budget = Self.expectedBytes[name] ?? 0
            if Self.loadablePackage(name) != nil {
                prior += budget
                onProgress?(ClipWeightProgress(
                    fileIndex: index + 1,
                    fileCount: Self.weightNames.count,
                    completedBytes: prior,
                    totalBytes: total
                ))
                continue
            }
            let completedBefore = prior
            try await installWeight(named: name) { written, expected in
                let span = expected > 0 ? expected : max(budget, 1)
                let current = min(budget, Int64((Double(written) / Double(span) * Double(budget)).rounded()))
                onProgress?(ClipWeightProgress(
                    fileIndex: index + 1,
                    fileCount: Self.weightNames.count,
                    completedBytes: completedBefore + current,
                    totalBytes: total
                ))
            }
            prior += budget
        }
        onProgress?(ClipWeightProgress(
            fileIndex: Self.weightNames.count,
            fileCount: Self.weightNames.count,
            completedBytes: total,
            totalBytes: total
        ))
    }

    public func embedText(_ text: String) async throws -> [Float] {
        try await loadIfNeeded()
        guard let textModel, let tokenizer else {
            throw loadError ?? ClipEmbeddingError.missingResource("text encoder")
        }

        var ids = tokenizer.encode(text: text)
        ids = Array(ids.prefix(77))
        if ids.count < 77 {
            ids.append(contentsOf: repeatElement(49_407, count: 77 - ids.count))
        }
        let input = try MLMultiArray(shape: [1, 77], dataType: .int32)
        for (index, id) in ids.enumerated() {
            input[index] = NSNumber(value: Int32(id))
        }
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "text": MLFeatureValue(multiArray: input),
        ])
        let output = try await textModel.prediction(from: provider)
        return try normalizedVector(from: output)
    }

    public func embedImage(_ image: CGImage) async throws -> [Float] {
        try await loadIfNeeded()
        guard let imageModel else {
            throw loadError ?? ClipEmbeddingError.missingResource("image encoder")
        }
        let imageValue = try MLFeatureValue(
            cgImage: image,
            pixelsWide: 224,
            pixelsHigh: 224,
            pixelFormatType: kCVPixelFormatType_32BGRA,
            options: nil
        )
        let provider = try MLDictionaryFeatureProvider(dictionary: ["image": imageValue])
        let output = try await imageModel.prediction(from: provider)
        return try normalizedVector(from: output)
    }

    private func loadIfNeeded() async throws {
        if imageModel != nil, textModel != nil, tokenizer != nil { return }
        if let loadError { throw loadError }
        do {
            try await ensureWeights()
            guard let imageURL = Self.loadablePackage("CLIP_ImageEncoder") else {
                throw ClipEmbeddingError.missingResource("CLIP_ImageEncoder.mlmodelc")
            }
            guard let textURL = Self.loadablePackage("CLIP_TextEncoder") else {
                throw ClipEmbeddingError.missingResource("CLIP_TextEncoder.mlmodelc")
            }
            guard let resourceRoot = Bundle.module.resourceURL else {
                throw ClipEmbeddingError.missingResource("tokenizer.json")
            }
            let tokenizerFolder = resourceRoot.appendingPathComponent("CLIP", isDirectory: true)

            let imageConfiguration = MLModelConfiguration()
            imageConfiguration.computeUnits = .all
            let textConfiguration = MLModelConfiguration()
            textConfiguration.computeUnits = .all
            imageModel = try MLModel(contentsOf: imageURL, configuration: imageConfiguration)
            textModel = try MLModel(contentsOf: textURL, configuration: textConfiguration)
            tokenizer = try await AutoTokenizer.from(modelFolder: tokenizerFolder, strict: false)
        } catch {
            loadError = error
            throw error
        }
    }

    private func normalizedVector(from provider: MLFeatureProvider) throws -> [Float] {
        guard let array = provider.featureNames
            .compactMap({ provider.featureValue(for: $0)?.multiArrayValue })
            .first,
              array.count == Self.vectorDimension else {
            throw ClipEmbeddingError.invalidOutput
        }
        var vector = (0..<array.count).map { Float(truncating: array[$0]) }
        let magnitude = sqrt(vector.reduce(Float.zero) { $0 + $1 * $1 })
        guard magnitude > 0 else { throw ClipEmbeddingError.invalidOutput }
        for index in vector.indices {
            vector[index] /= magnitude
        }
        return vector
    }

    private func installWeight(
        named name: String,
        onBytes: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        if Self.loadablePackage(name) != nil { return }
        guard let bundled = Self.bundledPackage(name) else {
            throw ClipEmbeddingError.missingResource("\(name).mlmodelc")
        }
        let destination = Self.cachedPackage(name)
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: bundled, to: destination)
        }
        let weightsFolder = destination.appendingPathComponent("weights", isDirectory: true)
        try fileManager.createDirectory(at: weightsFolder, withIntermediateDirectories: true)
        let target = weightsFolder.appendingPathComponent("weight.bin")
        guard let remote = URL(string: "\(Self.weightSource)/\(name).mlmodelc/weights/weight.bin") else {
            throw ClipEmbeddingError.missingResource(name)
        }
        let downloader = ClipWeightDownloader(onBytes: onBytes)
        let temporary = try await downloader.file(from: remote)
        if fileManager.fileExists(atPath: target.path) {
            try fileManager.removeItem(at: target)
        }
        try fileManager.moveItem(at: temporary, to: target)
        guard Self.weightFileIsComplete(target) else {
            try? fileManager.removeItem(at: target)
            throw ClipEmbeddingError.missingResource("\(name) weights")
        }
    }

    private static func bundledPackage(_ name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "mlmodelc", subdirectory: "CLIP")
    }

    private static func cachedPackage(_ name: String) -> URL {
        clipSupportDirectory().appendingPathComponent("\(name).mlmodelc", isDirectory: true)
    }

    private static func loadablePackage(_ name: String) -> URL? {
        for candidate in [bundledPackage(name), cachedPackage(name)] {
            guard let candidate else { continue }
            let weight = candidate.appendingPathComponent("weights/weight.bin")
            if weightFileIsComplete(weight) {
                return candidate
            }
        }
        return nil
    }

    private static func weightFileIsComplete(_ url: URL) -> Bool {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return size >= minimumWeightBytes
    }

    private static func clipSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("Sift/CLIP", isDirectory: true)
    }
}

private final class ClipWeightDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onBytes: @Sendable (Int64, Int64) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?
    private var lastReport = Date.distantPast

    init(onBytes: @escaping @Sendable (Int64, Int64) -> Void) {
        self.onBytes = onBytes
    }

    func file(from remote: URL) async throws -> URL {
        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.downloadTask(with: remote).resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let now = Date()
        let finished = totalBytesExpectedToWrite > 0 && totalBytesWritten >= totalBytesExpectedToWrite
        guard finished || now.timeIntervalSince(lastReport) >= 0.12 else { return }
        lastReport = now
        onBytes(totalBytesWritten, max(totalBytesExpectedToWrite, totalBytesWritten))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("sift-clip-\(UUID().uuidString).bin")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            resume(.success(destination))
        } catch {
            resume(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            resume(.failure(error))
        }
    }

    private func resume(_ result: Result<URL, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

extension SemanticRanker {
    /// Exact name matches stay ahead of cosine neighbors.
    public static let minimumVisualScore = 0.23

    public static func blend(
        keywordIDs: [String],
        semantic: [SemanticHit],
        limit: Int = 100,
        semanticFirst: Bool = false,
        documentIDs: Set<String> = []
    ) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        let visual = semantic.filter { $0.score >= minimumVisualScore }.map(\.id)
        let documents = keywordIDs.filter { documentIDs.contains($0) }
        let leadWithDocuments = documentIDs.contains(keywordIDs.first ?? "")
        let primary: [String]
        let secondary: [String]
        if semanticFirst && leadWithDocuments {
            primary = documents
            secondary = visual + keywordIDs
        } else if semanticFirst {
            primary = visual
            secondary = documents + keywordIDs
        } else {
            primary = keywordIDs
            secondary = visual
        }
        func append(_ ids: [String]) {
            for id in ids where seen.insert(id).inserted {
                ordered.append(id)
                if ordered.count == limit { return }
            }
        }
        append(primary)
        if ordered.count < limit { append(secondary) }
        let missing = documents.filter { !seen.contains($0) }
        guard semanticFirst, !leadWithDocuments, !missing.isEmpty else { return ordered }
        let keep = max(0, min(ordered.count, limit) - missing.count)
        return Array(ordered.prefix(keep)) + Array(missing.prefix(limit - keep))
    }
}

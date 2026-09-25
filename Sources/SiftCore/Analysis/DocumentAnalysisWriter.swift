import Foundation
import SwiftData

struct AnalysisJob: Sendable {
    let id: String
    let fileURL: URL
    let kind: MediaKind
    let fileName: String
}

/// Reads the catalog without pinning those rows in the interface context.
enum AnalysisJobQueue {
    static func unanalyzed(limit: Int) throws -> [AnalysisJob] {
        let context = ModelContext(StratumSchema.modelContainer)
        context.autosaveEnabled = false
        var descriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { !$0.isAnalyzed }
        )
        descriptor.fetchLimit = max(1, limit)
        return try context.fetch(descriptor).map {
            AnalysisJob(
                id: $0.id,
                fileURL: $0.fileURL,
                kind: $0.kind,
                fileName: $0.fileURL.lastPathComponent
            )
        }
    }
}

/// Saves a document's tags off the interface thread. The file text never waits on a click.
enum DocumentAnalysisWriter {
    static func readAndSave(id: String, url: URL) async throws {
        let reading = DocumentReader.read(url: url)
        let lines = reading.excerpt.split(separator: "\n").map(String.init)
        let fileName = url.lastPathComponent
        let drafted = DocumentTags.make(
            category: reading.category,
            fileName: fileName,
            units: reading.units,
            columns: reading.columns
        )
        let kinds = drafted.filter(DocumentTags.isTag)
        let subjects = drafted.filter { !DocumentTags.isTag($0) }
        let judged = await JevAdvisor.keepDocumentLabels(
            fileName: fileName,
            kind: reading.category,
            opening: reading.excerpt,
            labels: subjects
        )
        let kept = judged ?? subjects
        let tags = DocumentTags.sanitized(fileName: fileName, stored: kept + kinds)
        let keptSet = Set(tags)
        let scores = kinds.filter(keptSet.contains).map { LabelScore(label: $0, score: 1, source: .documentKind) }
            + kept.filter(keptSet.contains).map { LabelScore(label: $0, score: 1, source: .documentSubject) }
        let result = PhotoAnalysisResult(
            isScreenshotOrDocument: false,
            textLineCount: lines.count,
            topCategories: tags,
            recognizedText: Array(lines.prefix(40)),
            labelScores: scores
        )
        let context = ModelContext(StratumSchema.modelContainer)
        context.autosaveEnabled = false
        let assetID = id
        var descriptor = FetchDescriptor<MediaAssetRecord>(
            predicate: #Predicate { $0.id == assetID }
        )
        descriptor.fetchLimit = 1
        guard let record = try context.fetch(descriptor).first else { return }
        record.isAnalyzed = true
        record.isScreenshotOrDocument = result.isScreenshotOrDocument
        record.textLineCount = result.textLineCount
        record.topCategories = result.topCategories
        record.detectedAnimals = result.detectedAnimals
        record.faceCount = result.faceCount
        record.featurePrintData = result.featurePrintData
        record.recognizedTextLines = result.recognizedText
        record.pipeline = .documents
        record.applyEvidence(from: result)
        if context.hasChanges {
            try context.save()
        }
    }
}

import CoreGraphics
import Foundation
import Vision

public actor PhotoAnalyzer {
    public init() {}

    public func analyzeImage(
        _ cgImage: CGImage,
        metadata: AssetMetadata
    ) async throws -> PhotoAnalysisResult {
        async let textLines = recognizeText(cgImage)
        async let categories = classifyScene(cgImage)
        async let animals = recognizeAnimals(cgImage)
        async let faces = detectFaces(cgImage)
        async let featurePrint = LegacyVisionBridge.generateFeaturePrint(from: cgImage)

        let (texts, classes, animalLabels, faceCount, printData) = try await (
            textLines,
            categories,
            animals,
            faces,
            featurePrint
        )

        let lineCount = texts.count
        let isClutter = PipelineClassifier.isArtifact(
            analysis: PhotoAnalysisResult(
                isScreenshotOrDocument: lineCount > 5,
                textLineCount: lineCount,
                topCategories: classes,
                detectedAnimals: animalLabels,
                faceCount: faceCount
            ),
            metadata: metadata
        )

        return PhotoAnalysisResult(
            isScreenshotOrDocument: isClutter,
            textLineCount: lineCount,
            topCategories: classes,
            detectedAnimals: animalLabels,
            faceCount: faceCount,
            featurePrintData: printData,
            recognizedText: texts
        )
    }

    private func recognizeText(_ cgImage: CGImage) async throws -> [String] {
        if #available(macOS 15.0, iOS 18.0, *) {
            return try await recognizeTextModern(cgImage)
        }
        return try await recognizeTextLegacy(cgImage)
    }

    @available(macOS 15.0, iOS 18.0, *)
    private func recognizeTextModern(_ cgImage: CGImage) async throws -> [String] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let observations = try await request.perform(on: cgImage)
        return observations.compactMap { $0.topCandidates(1).first?.string }
    }

    private func recognizeTextLegacy(_ cgImage: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func classifyScene(_ cgImage: CGImage) async throws -> [String] {
        if #available(macOS 15.0, iOS 18.0, *) {
            return try await classifyModern(cgImage)
        }
        return try await classifyLegacy(cgImage)
    }

    @available(macOS 15.0, iOS 18.0, *)
    private func classifyModern(_ cgImage: CGImage) async throws -> [String] {
        let request = ClassifyImageRequest()
        let observations = try await request.perform(on: cgImage)
        return observations
            .sorted { $0.confidence > $1.confidence }
            .prefix(5)
            .map(\.identifier)
    }

    private func classifyLegacy(_ cgImage: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNClassificationObservation] ?? []
                let labels = observations
                    .sorted { $0.confidence > $1.confidence }
                    .prefix(5)
                    .map(\.identifier)
                continuation.resume(returning: labels)
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func recognizeAnimals(_ cgImage: CGImage) async throws -> [String] {
        if #available(macOS 15.0, iOS 18.0, *) {
            return try await animalsModern(cgImage)
        }
        return []
    }

    @available(macOS 15.0, iOS 18.0, *)
    private func animalsModern(_ cgImage: CGImage) async throws -> [String] {
        let request = RecognizeAnimalsRequest()
        let observations = try await request.perform(on: cgImage)
        return observations.compactMap { observation in
            observation.labels.first?.identifier
        }
    }

    private func detectFaces(_ cgImage: CGImage) async throws -> Int {
        if #available(macOS 15.0, iOS 18.0, *) {
            let request = DetectFaceRectanglesRequest()
            let results = try await request.perform(on: cgImage)
            return results.count
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let count = request.results?.count ?? 0
                continuation.resume(returning: count)
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

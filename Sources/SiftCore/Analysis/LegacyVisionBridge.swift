import CoreGraphics
import Foundation
import Vision

/// Legacy Vision APIs not yet exposed as Swift-only requests (feature prints).
public enum LegacyVisionBridge: Sendable {
    public static func generateFeaturePrint(from cgImage: CGImage) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observation = request.results?.first as? VNFeaturePrintObservation else {
                    continuation.resume(returning: nil)
                    return
                }
                do {
                    let archived = try NSKeyedArchiver.archivedData(
                        withRootObject: observation,
                        requiringSecureCoding: true
                    )
                    continuation.resume(returning: archived)
                } catch {
                    continuation.resume(returning: observation.data)
                }
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    public static func distanceBetween(_ a: Data, _ b: Data) -> Float? {
        guard let printA = unarchiveObservation(a),
              let printB = unarchiveObservation(b) else { return nil }
        var distance: Float = 0
        do {
            try printA.computeDistance(&distance, to: printB)
            return distance
        } catch {
            return nil
        }
    }

    private static func unarchiveObservation(_ data: Data) -> VNFeaturePrintObservation? {
        if let observation = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self,
            from: data
        ) {
            return observation
        }
        return nil
    }
}

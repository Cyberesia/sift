import CoreGraphics
import Foundation
import ImageIO

#if canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#endif

public enum ThumbnailCache {
    private static let queue = DispatchQueue(
        label: "sift.thumbnails",
        qos: .utility,
        attributes: .concurrent
    )

    public static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Sift/thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static func thumbnailPath(for assetID: String) -> URL {
        let safe = assetID
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cacheDirectory.appendingPathComponent("\(safe).jpg")
    }

    public static func generateThumbnail(
        for fileURL: URL,
        assetID: String,
        maxPixelSize: Int = 320
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let dest = thumbnailPath(for: assetID)
                    if FileManager.default.fileExists(atPath: dest.path) {
                        continuation.resume(returning: dest)
                        return
                    }
                    let cgImage: CGImage
                    if VideoThumbnailGenerator.isVideoFile(fileURL) {
                        guard let videoFrame = VideoThumbnailGenerator.generatePosterSync(
                            for: fileURL,
                            maxPixelSize: maxPixelSize
                        ) else {
                            throw ThumbnailError.decodeFailed
                        }
                        cgImage = videoFrame
                    } else {
                        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
                            throw ThumbnailError.decodeFailed
                        }
                        let options: [CFString: Any] = [
                            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                        ]
                        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                            throw ThumbnailError.decodeFailed
                        }
                        cgImage = thumb
                    }
                    #if canImport(AppKit)
                    let rep = NSBitmapImageRep(cgImage: cgImage)
                    guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
                        throw ThumbnailError.encodeFailed
                    }
                    #else
                    let uiImage = UIImage(cgImage: cgImage)
                    guard let data = uiImage.jpegData(compressionQuality: 0.82) else {
                        throw ThumbnailError.encodeFailed
                    }
                    #endif
                    try data.write(to: dest, options: .atomic)
                    continuation.resume(returning: dest)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public enum ThumbnailError: Error {
        case decodeFailed
        case encodeFailed
    }

}

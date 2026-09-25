import AVFoundation
import Foundation
import ImageIO

/// File facts that do not need Vision: pixel size and capture date from image headers, and audio tags.
public enum FileEvidenceReader {
    public struct ImageHeader: Sendable, Equatable {
        public let pixelWidth: Int?
        public let pixelHeight: Int?
        public let captureDate: Date?
    }

    public static func imageHeader(at url: URL) -> ImageHeader? {
        guard url.isFileURL,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        let width = properties[kCGImagePropertyPixelWidth] as? Int
        let height = properties[kCGImagePropertyPixelHeight] as? Int
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let raw = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
            ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String)
        return ImageHeader(pixelWidth: width, pixelHeight: height, captureDate: raw.flatMap(exifDate))
    }

    /// EXIF dates are local time without a zone, written `yyyy:MM:dd HH:mm:ss`.
    public static func exifDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: value.trimmingCharacters(in: .whitespaces))
    }

    /// Duration plus title, artist, and album when the file carries them.
    public static func audio(at url: URL) async -> PhotoAnalysisResult {
        let asset = AVURLAsset(url: url)
        var result = PhotoAnalysisResult()
        if let duration = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite, seconds > 0 { result.durationSeconds = seconds }
        }
        var labels: [LabelScore] = []
        if let items = try? await asset.load(.commonMetadata) {
            let wanted: [(AVMetadataKey, String)] = [
                (.commonKeyTitle, "title"),
                (.commonKeyArtist, "artist"),
                (.commonKeyAlbumName, "album"),
            ]
            for (key, name) in wanted {
                guard let item = AVMetadataItem.metadataItems(from: items, withKey: key, keySpace: .common).first,
                      let value = try? await item.load(.stringValue)?
                          .trimmingCharacters(in: .whitespacesAndNewlines),
                      !value.isEmpty else { continue }
                labels.append(LabelScore(label: "\(name): \(value)", score: 1, source: .audio))
            }
        }
        result.labelScores = labels
        result.topCategories = labels.map(\.label)
        return result
    }
}

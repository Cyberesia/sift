import CoreGraphics
import Foundation
import Photos

public enum PhotoAssetImageLoader {
    public static func loadCGImage(localIdentifier: String, targetSize: CGSize = CGSize(width: 1024, height: 1024)) async -> CGImage? {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetch.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = false
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                #if canImport(AppKit)
                continuation.resume(returning: image?.cgImage(forProposedRect: nil, context: nil, hints: nil))
                #else
                continuation.resume(returning: image?.cgImage)
                #endif
            }
        }
    }

    public static func fileURLForExport(localIdentifier: String) async -> URL? {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetch.firstObject else { return nil }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else { return nil }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("img")

        return await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false
            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: temp,
                options: options
            ) { error in
                continuation.resume(returning: error == nil ? temp : nil)
            }
        }
    }
}

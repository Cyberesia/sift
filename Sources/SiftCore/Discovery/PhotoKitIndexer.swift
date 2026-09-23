import Foundation
import Photos

public final class PhotoKitIndexer: @unchecked Sendable {
    public init() {}

    public var isAuthorized: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status == .authorized || status == .limited)
            }
        }
    }

    public func fetchAllAssets() async throws -> [DiscoveredMedia] {
        guard isAuthorized else { return [] }

        return await withCheckedContinuation { continuation in
            var results: [DiscoveredMedia] = []
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let imageFetch = PHAsset.fetchAssets(with: .image, options: options)
            let videoFetch = PHAsset.fetchAssets(with: .video, options: options)

            imageFetch.enumerateObjects { asset, _, _ in
                results.append(self.makeDiscovered(asset: asset, kind: .image))
            }
            videoFetch.enumerateObjects { asset, _, _ in
                results.append(self.makeDiscovered(asset: asset, kind: .video))
            }
            continuation.resume(returning: results)
        }
    }

    private func makeDiscovered(asset: PHAsset, kind: MediaKind) -> DiscoveredMedia {
        let url = PhotoAssetURL.make(localIdentifier: asset.localIdentifier)
        return DiscoveredMedia(
            id: "photos:\(asset.localIdentifier)",
            url: url,
            kind: kind,
            sourceKind: .photoLibrary,
            sourceLabel: "Photos Library",
            fileSize: nil,
            contentHash: "\(asset.localIdentifier)|\(asset.modificationDate?.timeIntervalSince1970 ?? 0)",
            createdAt: asset.creationDate,
            modifiedAt: asset.modificationDate
        )
    }
}

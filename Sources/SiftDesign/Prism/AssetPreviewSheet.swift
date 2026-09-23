import SiftCore
import SwiftUI

#if os(macOS)
import AppKit
#endif

#if os(macOS)
public enum PreviewImageLoader {
    public static func load(url: URL, maxPixelSize: Int) -> NSImage? {
        guard let cgImage = SafeImageLoader.loadForPreview(from: url, maxPixelSize: maxPixelSize) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
#endif

/// Single-asset entry point; library grid uses `AssetPreviewCarousel` directly.
public struct AssetPreviewOverlay: View {
    let asset: MediaAssetSummary
    let panelSize: CGSize
    let onClose: () -> Void

    @State private var index = 0
    @State private var isFullscreen = false

    public init(asset: MediaAssetSummary, panelSize: CGSize, onClose: @escaping () -> Void) {
        self.asset = asset
        self.panelSize = panelSize
        self.onClose = onClose
    }

    public var body: some View {
        AssetPreviewCarousel(
            assets: [asset],
            selectionIndex: $index,
            isFullscreen: $isFullscreen,
            panelSize: panelSize,
            windowSize: panelSize,
            mediaAccessRoot: { _ in nil },
            onClose: onClose,
            onRevealInFinder: PreviewActions.revealInFinder,
            onCopyPath: PreviewActions.copyPath
        )
    }
}

public typealias AssetPreviewSheet = AssetPreviewOverlay

#if os(macOS)
public enum PreviewActions {
    public static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public static func copyPath(_ path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }
}
#endif

import SiftCore
import SwiftUI

#if os(macOS)
import AVFoundation
import AppKit
import Quartz
#endif

public enum GalleryMark {
    public static func symbol(for kind: MediaKind) -> String {
        switch kind {
        case .audio: "waveform"
        case .video: "film"
        case .document: "doc.richtext"
        case .image: "photo"
        }
    }

    public static func tint(for kind: MediaKind) -> [Color] {
        switch kind {
        case .audio:
            [Color(red: 0.45, green: 0.18, blue: 0.42), PrismTheme.accent]
        case .document:
            [Color(red: 0.16, green: 0.22, blue: 0.34), Color(red: 0.35, green: 0.48, blue: 0.72)]
        case .video:
            [Color(red: 0.12, green: 0.14, blue: 0.22), Color(red: 0.28, green: 0.32, blue: 0.48)]
        case .image:
            [PrismTheme.surfaceMuted, PrismTheme.surface]
        }
    }
}

/// Artwork stand-in for files that are not pictures.
public struct MediaMark: View {
    let asset: MediaAssetSummary
    var showsName: Bool

    public init(asset: MediaAssetSummary, showsName: Bool) {
        self.asset = asset
        self.showsName = showsName
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: GalleryMark.tint(for: asset.kind),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: showsName ? 8 : 0) {
                Image(systemName: GalleryMark.symbol(for: asset.kind))
                    .font(showsName ? .title2.weight(.semibold) : .body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                if showsName {
                    Text(asset.fileName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                    Text(asset.fileURL.pathExtension.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                    if GalleryDateLabel.showsAddedDate(for: asset.kind) {
                        Text(GalleryDateLabel.added(asset.addedAt))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
        }
    }
}

#if os(macOS)
public struct PrismAudioPlayer: View {
    let url: URL
    var showsTitle: Bool = false
    var title: String = ""

    @State private var model = AudioPlayerModel()

    public init(url: URL, showsTitle: Bool = false, title: String = "") {
        self.url = url
        self.showsTitle = showsTitle
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTitle {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
            }
            HStack(spacing: 12) {
                Button {
                    model.toggle()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.body.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(PrismTheme.accent))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .prismClickable()

                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.16))
                            Capsule()
                                .fill(PrismTheme.accentGradient)
                                .frame(width: max(4, geo.size.width * model.fraction))
                        }
                    }
                    .frame(height: 5)
                    HStack {
                        Text(model.elapsedLabel)
                        Spacer()
                        Text(model.durationLabel)
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { model.load(url) }
        .onChange(of: url) { _, newURL in model.load(newURL) }
        .onDisappear { model.stop() }
    }
}

@MainActor
@Observable
private final class AudioPlayerModel {
    var isPlaying = false
    var fraction: Double = 0
    var elapsedLabel = "0:00"
    var durationLabel = "0:00"

    private var player: AVAudioPlayer?
    private var ticker: Timer?

    func load(_ url: URL) {
        stop()
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            durationLabel = "—"
            return
        }
        player.prepareToPlay()
        self.player = player
        durationLabel = Self.format(player.duration)
        elapsedLabel = "0:00"
        fraction = 0
    }

    func toggle() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            ticker?.invalidate()
        } else {
            player.play()
            isPlaying = true
            startTicker()
        }
    }

    func stop() {
        player?.stop()
        ticker?.invalidate()
        ticker = nil
        player = nil
        isPlaying = false
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let player else { return }
        let duration = player.duration
        fraction = duration > 0 ? min(1, player.currentTime / duration) : 0
        elapsedLabel = Self.format(player.currentTime)
        if !player.isPlaying {
            isPlaying = false
            ticker?.invalidate()
        }
    }

    private static func format(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

public struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.autostarts = true
        view.previewItem = url as NSURL
        return view
    }

    public func updateNSView(_ nsView: QLPreviewView, context: Context) {
        let current = (nsView.previewItem as? NSURL)?.path
        guard current != url.path else { return }
        nsView.previewItem = url as NSURL
        nsView.refreshPreviewItem()
    }
}
#endif

/// Player or document page shown in the gallery card and in the full viewer.
public struct GalleryInlinePreview: View {
    let asset: MediaAssetSummary
    var expanded: Bool = false

    public init(asset: MediaAssetSummary, expanded: Bool = false) {
        self.asset = asset
        self.expanded = expanded
    }

    public var body: some View {
        Group {
            switch asset.kind {
            case .audio:
                audioBody
            case .video:
                videoBody
            case .document:
                documentBody
            case .image:
                imageBody
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: expanded ? nil : previewHeight)
        .frame(maxHeight: expanded ? .infinity : previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var previewHeight: CGFloat {
        switch asset.kind {
        case .audio: 148
        case .video, .document: 180
        case .image: 150
        }
    }

    private var audioBody: some View {
        ZStack {
            MediaMark(asset: asset, showsName: false)
            VStack {
                Spacer()
                #if os(macOS)
                PrismAudioPlayer(url: asset.fileURL, showsTitle: true, title: asset.fileName)
                    .padding(12)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(10)
                #else
                Text(asset.fileName)
                    .font(.headline)
                    .padding(12)
                #endif
            }
        }
    }

    private var videoBody: some View {
        #if os(macOS)
        PrismVideoPlayer(url: asset.fileURL, isPlaying: .constant(false), managesPlayback: false)
        #else
        MediaMark(asset: asset, showsName: true)
        #endif
    }

    private var documentBody: some View {
        #if os(macOS)
        QuickLookPreview(url: asset.fileURL)
            .background(Color.white.opacity(0.04))
        #else
        MediaMark(asset: asset, showsName: true)
        #endif
    }

    private var imageBody: some View {
        ThumbnailImageView(
            path: asset.thumbnailPath,
            fallbackURL: asset.fileURL,
            contentMode: .fit,
            allowOriginalFallback: true
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.25))
    }
}

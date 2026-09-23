import AVKit
import SwiftUI

#if os(macOS)
/// Native AVPlayer surface for carousel video preview.
public struct PrismVideoPlayer: NSViewRepresentable {
    let url: URL
    @Binding var isPlaying: Bool
    /// When false, the player view's own controls start and stop playback.
    var managesPlayback: Bool

    public init(url: URL, isPlaying: Binding<Bool>, managesPlayback: Bool = true) {
        self.url = url
        _isPlaying = isPlaying
        self.managesPlayback = managesPlayback
    }

    public func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = false
        view.showsSharingServiceButton = false
        view.videoGravity = .resizeAspect
        context.coordinator.configure(view: view, url: url)
        return view
    }

    public func updateNSView(_ nsView: AVPlayerView, context: Context) {
        context.coordinator.update(view: nsView, url: url, isPlaying: isPlaying, managesPlayback: managesPlayback)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    public final class Coordinator {
        private var currentURL: URL?
        private var player: AVPlayer?

        func configure(view: AVPlayerView, url: URL) {
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            self.player = player
            self.currentURL = url
            view.player = player
        }

        func update(view: AVPlayerView, url: URL, isPlaying: Bool, managesPlayback: Bool) {
            if currentURL != url {
                configure(view: view, url: url)
            }
            guard managesPlayback else { return }
            if isPlaying {
                view.player?.play()
            } else {
                view.player?.pause()
            }
        }
    }
}
#endif

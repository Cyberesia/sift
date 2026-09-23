#if os(macOS)
import Foundation
import Sparkle

/// Sparkle auto-update controller (direct distribution).
@MainActor
final class SiftUpdaterController: NSObject, SPUUpdaterDelegate {
    static let shared = SiftUpdaterController()

    private let controller: SPUStandardUpdaterController

    private override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
#endif

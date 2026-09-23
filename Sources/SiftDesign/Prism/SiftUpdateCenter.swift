import Foundation
import SiftCore
#if os(macOS)
import AppKit
#endif

/// Checks GitHub for a newer Sift release and offers the DMG.
@MainActor
public final class SiftUpdateCenter: ObservableObject {
    public static let shared = SiftUpdateCenter()

    @Published public private(set) var latestRelease: SiftGitHubRelease?
    @Published public private(set) var isChecking = false
    @Published public private(set) var lastError: String?
    @Published public private(set) var updateAvailable = false
    @Published public private(set) var noReleaseYet = false

    private let lastCheckKey = "sift.update.lastCheck"
    private let dismissedVersionKey = "sift.update.dismissedVersion"
    private let checkInterval: TimeInterval = 86_400

    public init() {}

    public var installedVersion: String { SiftAppVersion.current }

    public var statusText: String {
        if isChecking { return Self.text("Checking for updates…", "Recherche de mises à jour…") }
        if updateAvailable, let release = latestRelease {
            return Self.text("Sift \(release.version) is available.", "Sift \(release.version) est disponible.")
        }
        if noReleaseYet {
            return Self.text("No release published yet.", "Aucune version publiée pour l’instant.")
        }
        if let lastError, !lastError.isEmpty { return lastError }
        return Self.text("You’re on the latest release.", "Vous utilisez la dernière version.")
    }

    /// Once a day, unless a check is already in memory from this launch.
    public func checkIfNeeded() async {
        if isChecking { return }
        if let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < checkInterval,
           latestRelease != nil {
            refreshAvailability()
            return
        }
        await check(force: false)
    }

    public func check(force: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        lastError = nil
        noReleaseYet = false
        defer { isChecking = false }

        do {
            let release = try await SiftGitHubReleaseAPI.fetchLatest()
            latestRelease = release
            refreshAvailability()
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            if updateAvailable {
                presentUpdateAlert(for: release, evenIfDismissed: force)
            }
        } catch {
            noReleaseYet = (error as? SiftReleaseCheckError) == .noRelease
            lastError = noReleaseYet ? nil : Self.localized(error)
            if force || latestRelease == nil {
                updateAvailable = false
            }
        }
    }

    public func openDownload() {
        #if os(macOS)
        guard let url = latestRelease?.preferredDownloadURL else { return }
        NSWorkspace.shared.open(url)
        #endif
    }

    public func dismissCurrentUpdate() {
        guard let version = latestRelease?.version else { return }
        UserDefaults.standard.set(version, forKey: dismissedVersionKey)
    }

    private func refreshAvailability() {
        guard let release = latestRelease else {
            updateAvailable = false
            return
        }
        updateAvailable = SiftVersionCompare.isRemoteNewer(
            remote: release.version,
            local: installedVersion
        )
    }

    private func presentUpdateAlert(for release: SiftGitHubRelease, evenIfDismissed: Bool) {
        #if os(macOS)
        let dismissed = UserDefaults.standard.string(forKey: dismissedVersionKey)
        if !evenIfDismissed, release.version == dismissed { return }

        let alert = NSAlert()
        alert.messageText = Self.text("Update available", "Mise à jour disponible")
        alert.informativeText = Self.text(
            "Sift \(release.version) is available on GitHub. Download the latest DMG to update.",
            "Sift \(release.version) est disponible sur GitHub. Téléchargez le dernier DMG pour mettre à jour."
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: Self.text("Download update", "Télécharger la mise à jour"))
        alert.addButton(withTitle: Self.text("Later", "Plus tard"))
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openDownload()
        } else {
            dismissCurrentUpdate()
        }
        #endif
    }

    private static func localized(_ error: Error) -> String {
        if let check = error as? SiftReleaseCheckError {
            switch check {
            case .invalidResponse:
                return text("Invalid update check response.", "Réponse de mise à jour illisible.")
            case .noRelease:
                return text("No release published yet.", "Aucune version publiée pour l’instant.")
            case .httpStatus(let code):
                return text("Update check failed (HTTP \(code)).", "La recherche a échoué (HTTP \(code)).")
            case .decodingFailed:
                return text("Could not read the latest release.", "Impossible de lire la dernière version.")
            }
        }
        return error.localizedDescription
    }

    static func text(_ en: String, _ fr: String) -> String {
        Locale.current.language.languageCode?.identifier == "fr" ? fr : en
    }
}

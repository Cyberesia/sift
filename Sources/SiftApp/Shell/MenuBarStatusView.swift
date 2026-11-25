#if os(macOS)
import SiftCore
import SiftDesign
import SwiftUI

struct MenuBarStatusView: View {
    @ObservedObject var session: SiftRootSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Section {
                Text(session.jobCenter.progress.title)
                    .font(.headline)
                Text(session.jobCenter.progress.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            Section {
                let rulesOn = session.folderRules.enabledCount
                Text(rulesOn == 0 ? tr("All rules paused", "Toutes les règles en pause") : tr("\(rulesOn) active rule(s) · read by \(session.intelligence.status.readerName)", "\(rulesOn) règle(s) active(s) · lu par \(session.intelligence.status.readerName)"))
                    .font(.caption)
                if !session.folderRules.pending.isEmpty {
                    Button(tr("Apply \(session.folderRules.pending.count) to review", "Appliquer les \(session.folderRules.pending.count) à valider")) {
                        session.folderRules.filePending()
                    }
                    Button(tr("Open To review…", "Ouvrir À valider…")) {
                        session.appMode = .rules
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }
            Divider()
            Button("Open Sift") {
                NSApp.activate(ignoringOtherApps: true)
            }
            if session.indexingCoordinator.showsTransportControls {
                Button("Pause") { session.pauseIndexing() }
                Button("Resume") { session.resumeIndexing() }
                Button("Stop") { session.stopIndexing() }
            } else if session.indexingCoordinator.showsRecoveryControls {
                Button("Continue indexing") { session.continueIndexing() }
                Button("Reset AI tags") { session.resetAIProcessing() }
                Button("Clear status") { session.dismissIndexingStatus() }
            }
            Divider()
            Button(tr("Settings…", "Réglages…")) {
                session.openSettings()
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(8)
    }
}
#endif

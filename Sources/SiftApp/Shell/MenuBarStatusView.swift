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
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(8)
    }
}
#endif

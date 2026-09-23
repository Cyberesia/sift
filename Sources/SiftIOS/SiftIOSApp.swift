import SiftCore
import SiftDesign
import SwiftUI

#if os(iOS)
@main
struct SiftIOSApplication: App {
    @StateObject private var session = SiftRootSession()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                PrismShellView(session: session)
            }
            .preferredColorScheme(.dark)
            // iOS: read-only library browse; organize, transfers, and folder watch are macOS-only for now.
        }
    }
}
#endif

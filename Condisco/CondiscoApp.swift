import SwiftUI

@main
struct CondiscoApp: App {
    @ObservedObject private var a11y = A11ySettings.shared

    init() {
        #if DEBUG
        // UI tests opt in to a blank local profile. Normal launches never
        // remove learner data, and Release builds exclude this path.
        if ProcessInfo.processInfo.arguments.contains("--condisco-ui-test-reset") {
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }
            if let documents = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask).first {
                for suffix in ["", "-wal", "-shm"] {
                    let database = documents.appendingPathComponent("verbalibera.sqlite\(suffix)")
                    try? FileManager.default.removeItem(at: database)
                }
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // The Comfort toggle is a real promise: while it's on,
                // every animation in the app goes quiet.
                .transaction { transaction in
                    if a11y.reduceMotion {
                        transaction.disablesAnimations = true
                    }
                }
        }
    }
}

import SwiftUI
#if DEBUG
import os
#endif

// MARK: - Performance instrumentation (DEBUG only)
//
// Minimal signpost-based timing helpers for Instruments (Time Profiler and
// Points of Interest). Everything that does real work lives behind `#if
// DEBUG`; in Release builds this enum compiles down to `@inline(__always)`
// no-ops with a zero-size `Token`, so nothing is logged, measured, or
// allocated. Guarding the whole helper keeps the call sites dependency-free:
// `PerfSignpost.begin(...)` is safe to call (and optimizes away) in any
// configuration.
enum PerfSignpost {
#if DEBUG
    private static let log = OSLog(
        subsystem: "com.sleuthysloth.condisco",
        category: "Performance"
    )

    /// A single timed, signposted measurement.
    struct Measurement {
        let id: OSSignpostID
        let start: Double // seconds since boot (ProcessInfo.systemUptime)
    }

    // MARK: Launch → first content

    private static let launchID = OSSignpostID(log: log)
    private static var launchDidEnd = false

    /// Fire from `CondiscoApp.init()` — the earliest app-code point.
    static func launchBegin() {
        os_signpost(.begin, log: log, name: "LaunchToFirstContent", signpostID: launchID)
        os_log("LaunchToFirstContent: begin", log: log, type: .debug)
    }

    /// Fire from the root view's first `onAppear` (see `CondiscoApp.body`).
    /// Guarded so only the first interval of the process is closed; later
    /// appearances (background/foreground, scene re-creation) are ignored.
    static func launchEnd() {
        guard !launchDidEnd else { return }
        launchDidEnd = true
        os_signpost(.end, log: log, name: "LaunchToFirstContent", signpostID: launchID)
    }

    // MARK: Scoped timed measurements (pack load, …)

    /// Begin a timed signpost; pass the returned value to `end`.
    static func begin(_ name: StaticString) -> Measurement {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return Measurement(id: id, start: ProcessInfo.processInfo.systemUptime)
    }

    /// End a timed signpost and print its duration to the DEBUG console.
    static func end(_ name: StaticString, _ measurement: Measurement) {
        os_signpost(.end, log: log, name: name, signpostID: measurement.id)
        let ms = (ProcessInfo.processInfo.systemUptime - measurement.start) * 1000
        os_log("%{public}s finished in %.1f ms", log: log, type: .debug, "\(name)", ms)
    }
#else
    // Release twin: zero-cost no-ops. `Token` is an empty, zero-size struct
    // and every body is empty, so the optimizer inlines these calls away.
    struct Token {
        @inline(__always) init() {}
    }

    @inline(__always) static func launchBegin() {}
    @inline(__always) static func launchEnd() {}

    @inline(__always) static func begin(_ name: StaticString) -> Token { Token() }
    @inline(__always) static func end(_ name: StaticString, _ token: Token) {}
#endif
}

@main
struct CondiscoApp: App {
    @ObservedObject private var a11y = A11ySettings.shared

    init() {
        PerfSignpost.launchBegin()
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
                // DEBUG-only: closes the LaunchToFirstContent signpost at the
                // first frame the root content appears. (Release no-op.)
                .onAppear { PerfSignpost.launchEnd() }
        }
    }
}

import Foundation

// MARK: - PackLoader
//
// Loads the bundled course packs from the Content folder resource.
// The Xcode target copies `Condisco/Content` into the app bundle as a
// folder reference, so the on-disk layout mirrors the web repo's public/:
//
//   Content/packs/french.json … (5 files)
//   Content/audio/<lang>/…      (referenced from packs as "audio/…")
//   Content/images/…            (referenced from packs as "images/…")
//
// Audio/image URLs keep their web-style relative form ("audio/french/…")
// and are resolved to bundle URLs by MediaResolver in StimulusViews.

enum PackLoadError: Error, LocalizedError {
    case missingContentFolder
    case noPacksLoaded([String])

    var errorDescription: String? {
        switch self {
        case .missingContentFolder:
            return "The Content folder is missing from the app bundle."
        case .noPacksLoaded(let failures):
            return "No course packs could be loaded:\n" + failures.joined(separator: "\n")
        }
    }
}

enum PackLoader {
    /// Pack basenames in the order the Courses tab lists them.
    static let packFilenames = ["french", "italian", "german", "portuguese", "spanish"]

    static func contentDirectory() -> URL? {
        Bundle.main.url(forResource: "Content", withExtension: nil)
    }

    // MARK: Caching
    //
    // `cached` holds the result of the *first* pack load and is reused on
    // every subsequent call. Decoding + validating the five bundled packs is
    // ~4 MB of JSON I/O per call, and the loader is invoked from 15 sites
    // (Home, Review, Listen, Courses, You, DeepLink, Spotlight, Intents,
    // Onboarding, Phrasebook, WidgetSnapshotWriter…), usually on the main
    // actor. The bundle content is immutable at runtime, so caching the
    // outcome — success or failure — is safe: a failed pack would
    // deterministically fail again on retry.
    //
    // Thread safety: a static stored property's lazy initializer runs exactly
    // once per process under the runtime's `swift_once`, so concurrent first
    // access from the main actor and `Task.detached` (ListenView) performs
    // exactly one decode with no locking.
    private static let cached: Result<[CoursePack], Error> = Result {
        try loadPacksUncached()
    }

    /// Decode and validate every bundled pack. Packs that fail validation
    /// are skipped (with the reason collected); the load only throws when
    /// nothing usable remains. The heavy work happens once per process; the
    /// result (including a `PackLoadError` describing per-file failures) is
    /// cached and returned on all subsequent calls.
    static func loadPacks() throws -> [CoursePack] {
        try cached.get()
    }

    private static func loadPacksUncached() throws -> [CoursePack] {
        // DEBUG-only timing: Instruments reads the "PackLoad" signpost
        // (I/O + JSON decode + validation across all five packs). In Release
        // PerfSignpost compiles to inline no-ops, so this is zero-cost.
#if DEBUG
        // Guarded so the standalone content validator (`tools/check_packs.sh`),
        // which compiles this file with swiftc outside the app target, never
        // needs `PerfSignpost` (defined in CondiscoApp.swift).
        let measurement = PerfSignpost.begin("PackLoad")
        defer { PerfSignpost.end("PackLoad", measurement) }
#endif
        guard let content = contentDirectory() else {
            throw PackLoadError.missingContentFolder
        }
        let packsDir = content.appendingPathComponent("packs", isDirectory: true)
        let decoder = JSONDecoder()
        var packs: [CoursePack] = []
        var failures: [String] = []
        for name in packFilenames {
            let url = packsDir.appendingPathComponent(name).appendingPathExtension("json")
            do {
                let data = try Data(contentsOf: url)
                let pack = try decoder.decode(CoursePack.self, from: data)
                try PackValidator.validate(pack)
                packs.append(pack)
            } catch {
                failures.append("\(name).json: \(error.localizedDescription)")
            }
        }
        guard !packs.isEmpty else {
            throw PackLoadError.noPacksLoaded(failures)
        }
        return packs
    }
}

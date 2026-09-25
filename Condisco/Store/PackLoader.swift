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

    /// Decode and validate every bundled pack. Packs that fail validation
    /// are skipped (with the reason collected); the load only throws when
    /// nothing usable remains.
    static func loadPacks() throws -> [CoursePack] {
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

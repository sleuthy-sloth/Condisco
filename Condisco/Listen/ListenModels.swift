import Foundation

// MARK: - Listen track models
//
// Audio-only Thinking Method tracks: a teacher guide plus target-language
// reveals, synthesized at author time and bundled with the app. Each track is
// a static JSON transcript (Content/listen-tracks/<course>.json, copied from
// the web repo's src/features/listen/generated/) paired with its mp3 under
// Content/audio/<course>-foundations/.

// JSON shapes mirror src/features/listen/tracks.ts in the web repo.
struct ListenTarget: Codable, Hashable {
    let text: String
    let meaning: String
}

struct ListenSection: Codable, Hashable {
    let heading: String
    let teacher: String
    let target: ListenTarget?
    /// Section start in seconds, for "jump to section" seeking. Written by
    /// the track builder; absent in older transcripts, where headings stay
    /// plain text instead of seek buttons.
    let startS: Double?
}

struct ListenTrack: Codable, Identifiable {
    let lessonId: String
    let courseSlug: String
    let lessonTitle: String
    let audioUrl: String
    let durationS: Double
    let reviewPending: Bool?
    let sections: [ListenSection]

    var id: String { lessonId }
}

enum ListenCourse {
    /// Pack filenames and JSON basenames, in Courses-tab order. Derived from
    /// PackLoader so the course list has a single source of truth.
    static let courseSlugs = PackLoader.packFilenames

    /// Display name resolved through the registry; a foreign slug falls back
    /// to its own capitalization, never an English country name.
    static func displayName(for slug: String) -> String {
        CourseRegistry.displayName(for: slug)
    }
}

enum ListenCatalog {
    /// Decode every bundled track transcript. A track is listed only when its
    /// transcript decodes and its audio file is present in the bundle — a
    /// track without audio renders nothing rather than a dead player.
    static func loadTracks() -> [ListenTrack] {
        guard let content = Bundle.main.url(forResource: "Content", withExtension: nil) else {
            return []
        }
        let dir = content.appendingPathComponent("listen-tracks", isDirectory: true)
        let decoder = JSONDecoder()
        var tracks: [ListenTrack] = []
        for slug in ListenCourse.courseSlugs {
            let url = dir.appendingPathComponent(slug).appendingPathExtension("json")
            guard let data = try? Data(contentsOf: url),
                  let track = try? decoder.decode(ListenTrack.self, from: data),
                  MediaResolver.bundleURL(for: track.audioUrl) != nil else {
                continue
            }
            tracks.append(track)
        }
        return tracks
    }
}

// MARK: - Position + listened history
//
// Mirrors src/features/listen/position.ts and listened.ts. The web keeps
// this browser-local; here it lives in the SQLite listen_state table so
// resume points and listened marks sync between devices. The honesty rules
// travel with it:
//
// - a position under MIN_RESUME_SECONDS is a stray tap, not a resume point;
// - a position within COMPLETE_WITHIN_SECONDS of the end is a finished track,
//   so it is cleared instead of resuming into the last seconds;
// - marking a track "listened" records that it was heard, with a timestamp.
//   It never claims mastery.

@MainActor
struct ListenHistory {
    static let minResumeSeconds = 5.0
    static let completeWithinSeconds = 10.0

    private static let migratedKey = "condisco.listen.migratedFromDefaults.v1"
    private static let legacyPositionPrefix = "verbalibera_listen_position:"
    private static let legacyListenedDictKey = "verbalibera_listened"

    let store: LearningStore

    /// Opens the store-backed history, running the one-time UserDefaults
    /// migration first. Nil when the database cannot be opened.
    @MainActor
    static func open() -> ListenHistory? {
        guard let store = try? LearningStore.inDocuments() else { return nil }
        migrateFromUserDefaultsIfNeeded(store: store)
        return ListenHistory(store: store)
    }

    /// The stored resume point, or nil when there is none worth offering.
    func readPosition(lessonId: String) -> Double? {
        guard let seconds = try? store.listenPosition(trackId: lessonId),
              seconds >= Self.minResumeSeconds else { return nil }
        return seconds
    }

    /// Records where the learner stopped. Returns the resume point to offer
    /// back, or nil when the track is effectively finished (which also clears
    /// the stored value) or the position is too small to be real.
    @discardableResult
    func savePosition(lessonId: String, seconds: Double, duration: Double) -> Double? {
        guard seconds.isFinite, seconds >= Self.minResumeSeconds else { return nil }
        if duration.isFinite, duration > 0, seconds >= duration - Self.completeWithinSeconds {
            try? store.clearListenPosition(trackId: lessonId)
            return nil
        }
        let rounded = floor(seconds)
        try? store.saveListenPosition(trackId: lessonId, seconds: rounded)
        return rounded
    }

    func clearPosition(lessonId: String) {
        try? store.clearListenPosition(trackId: lessonId)
    }

    func listenedAt(lessonId: String) -> Date? {
        try? store.listenedAt(trackId: lessonId)
    }

    @discardableResult
    func markListened(lessonId: String, at date: Date = Date()) -> Date {
        try? store.markListened(trackId: lessonId, at: date)
        return date
    }

    /// One-time move of the pre-SQLite UserDefaults listen state into the
    /// store. Idempotent; safe to call on every launch.
    static func migrateFromUserDefaultsIfNeeded(store: LearningStore) {
        guard (try? store.kvGet(migratedKey)) == nil else { return }
        let defaults = UserDefaults.standard
        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.hasPrefix(legacyPositionPrefix),
                  let seconds = value as? Double, seconds.isFinite
            else { continue }
            let trackId = String(key.dropFirst(legacyPositionPrefix.count))
            // Ancient write: any real position save wins over it.
            try? store.saveListenPosition(
                trackId: trackId, seconds: seconds,
                at: Date(timeIntervalSince1970: 0))
            defaults.removeObject(forKey: key)
        }
        if let listened = defaults.dictionary(
            forKey: legacyListenedDictKey) as? [String: Double] {
            for (trackId, timestamp) in listened {
                try? store.markListened(
                    trackId: trackId,
                    at: Date(timeIntervalSince1970: timestamp))
            }
            defaults.removeObject(forKey: legacyListenedDictKey)
        }
        try? store.kvSet(migratedKey, "1")
    }
}

// MARK: - Formatting

/// `183.4` → `3:03`. Used for the resume state and the transport readout.
func formatListenPosition(_ seconds: Double) -> String {
    let whole = max(0, Int(floor(seconds)))
    return "\(whole / 60):\(String(format: "%02d", whole % 60))"
}

/// `617` → `10:17`.
func formatListenDuration(_ seconds: Double) -> String {
    formatListenPosition(seconds)
}

// MARK: - Scenario loop (P3.2 pure core)
//
// The listen–respond–compare loop, as a *pure, side-effect-free* core:
// section eligibility, per-section timing, and the step machine. There is
// deliberately no audio, no view, and no scoring here — the sheet UI and
// playback land in a later task, and the loop carries no score/accuracy
// state by design.

enum ListenScenario {
    /// The sections a scenario can play, in track order: only sections
    /// with a reveal (`target`) and a known start time (`startS`). Older
    /// transcripts may omit either, so the filter stays defensive.
    static func scenarioSections(track: ListenTrack) -> [ListenSection] {
        track.sections.filter { $0.target != nil && $0.startS != nil }
    }

    /// End time for the `index`-th scenario section (`index` is an index
    /// into `scenarioSections(track:)`). The next timed transcript section
    /// bounds playback, even if that section has no target. The final
    /// section runs to the track's declared duration.
    static func sectionEnd(for index: Int, in track: ListenTrack) -> TimeInterval {
        let eligibleIndices = track.sections.indices.filter {
            track.sections[$0].target != nil && track.sections[$0].startS != nil
        }
        guard eligibleIndices.indices.contains(index) else { return 0 }
        let sectionIndex = eligibleIndices[index]
        let start = track.sections[sectionIndex].startS ?? 0
        let nextStart = track.sections.dropFirst(sectionIndex + 1)
            .compactMap(\.startS)
            .first(where: { $0 > start })
        let candidate = nextStart ?? track.durationS
        // Defensive: degenerate transcripts must never yield an empty or
        // backwards section window.
        return max(candidate, start + 1)
    }
}

/// Pure step machine for one listen scenario run. Holds only the loop
/// position — the current section, the total section count, and the step —
/// plus the mic availability flag that shapes the transition table. There
/// is intentionally NO score/accuracy/grade state of any kind.
struct ScenarioLoopState: Equatable {
    enum Step: Equatable {
        case line
        case choose
        case speak
        case model
        case done
    }

    /// How many sections the scenario covers.
    let total: Int
    /// Current section within the scenario (0-based).
    private(set) var index: Int
    /// Current step in the section loop.
    private(set) var step: Step
    /// When true (no microphone), the `.speak` step is skipped.
    private let micUnavailable: Bool

    /// Enters the first section at `.line`. An empty scenario (total 0)
    /// starts directly at `.done` — there is nothing to play.
    init(total: Int, micUnavailable: Bool) {
        self.total = max(0, total)
        self.micUnavailable = micUnavailable
        self.index = 0
        self.step = self.total == 0 ? .done : .line
    }

    var currentSectionIndex: Int { index }
    var currentStep: Step { step }
    var isDone: Bool { step == .done }

    /// The transition table:
    ///   `line` → `choose` → `speak` → `model` → (next section) `line` | `done`
    ///   `choose` → `model` directly when `micUnavailable` (speak skipped)
    ///   `done` is terminal: advancing is a no-op.
    mutating func advance() {
        switch step {
        case .line:
            step = .choose
        case .choose:
            step = micUnavailable ? .model : .speak
        case .speak:
            step = .model
        case .model:
            if index + 1 < total {
                index += 1
                step = .line
            } else {
                step = .done
            }
        case .done:
            break
        }
    }
}

/// The playback rate for one scenario step, pinned by tests: the compare
/// (`.model`) step replays its line at the slow rate (0.75×, the same
/// constant as `ListenPlayerModel.slowRate`), every other step at normal
/// speed. Pure, so the practice sheet's window playback stays honest and
/// testable without touching audio.
func scenarioStepRate(for step: ScenarioLoopState.Step) -> Float {
    step == .model ? 0.75 : 1
}

import Foundation

// MARK: - You tab model
//
// Everything the profile screen shows, derived from the local event log:
// phrases the learner has actually produced, practice stats, per-course
// progress, and comfort preferences. Signing in does not change what is
// shown — it only marks the progress as belonging to the learner's account
// so sync can carry it to their other devices.

@MainActor
final class YouModel: ObservableObject {
    struct CourseStat: Identifiable {
        let id: String
        let title: String
        let languageName: String
        let done: Int
        let total: Int

        var percent: Int {
            guard total > 0 else { return 0 }
            return Int(
                (Double(done) / Double(total) * 100).rounded())
        }
    }

    struct SayablePhrase: Identifiable {
        let id: String
        let text: String
        let context: String
    }

    @Published var phrases: [SayablePhrase] = []
    @Published var daysPractised = 0
    @Published var dueCount = 0
    @Published var courses: [CourseStat] = []
    @Published var isLoading = true
    @Published var loadError: String?

    @Published var largeText = A11ySettings.shared.largeText {
        didSet { A11ySettings.shared.largeText = largeText }
    }
    @Published var reduceMotion = A11ySettings.shared.reduceMotion {
        didSet { A11ySettings.shared.reduceMotion = reduceMotion }
    }

    func load() async {
        do {
            let store = try LearningStore.inDocuments()
            let packs = try PackLoader.loadPacks()
            var courses: [CourseStat] = []
            var due = 0
            var phrases: [SayablePhrase] = []
            for pack in packs {
                let progress = try store.project(pack: pack)
                courses.append(CourseStat(
                    id: pack.id,
                    title: pack.title,
                    languageName: pack.language.displayName,
                    done: progress.finishedLessons.count,
                    total: pack.lessons.count))
                due += try ReviewCatalog.loadDue(
                    packs: [pack], store: store).due.count
                phrases.append(contentsOf: sayablePhrases(
                    pack: pack, progress: progress,
                    limit: 12 - phrases.count))
            }
            self.courses = courses
            self.dueCount = due
            self.phrases = phrases
            self.daysPractised = try store.practiceDays()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        isLoading = true
        loadError = nil
        await load()
    }

    /// Builds the data-export file, or nil when it cannot be produced.
    func exportData() -> URL? {
        guard let store = try? LearningStore.inDocuments() else { return nil }
        return try? DataExport.buildFile(store: store)
    }

    // MARK: - What you can say

    /// Target-language strings the learner has produced correctly at least
    /// once, in course order. Mirrors the web's "What you can say", derived
    /// from evidence instead of the curriculum concept graph.
    private func sayablePhrases(
        pack: CoursePack, progress: PackProgress, limit: Int
    ) -> [SayablePhrase] {
        guard limit > 0 else { return [] }
        var lessonTitleByActivity: [String: String] = [:]
        for lesson in pack.lessons {
            for step in lesson.steps {
                lessonTitleByActivity[step.activityId] = lesson.title
            }
        }
        var out: [SayablePhrase] = []
        for activity in pack.activities {
            guard out.count < limit,
                  let key = activity.evidenceKey,
                  let record = progress.evidence[key],
                  record.successes > 0,
                  let text = Self.sayableText(for: activity),
                  !text.isEmpty
            else { continue }
            out.append(SayablePhrase(
                id: "\(pack.id):\(key)",
                text: text,
                context: lessonTitleByActivity[activity.id]
                    ?? pack.language.displayName))
        }
        return out
    }

    /// The canonical target-language answer for an activity, or nil when the
    /// kind has no plain-text answer worth quoting.
    private static func sayableText(for activity: Activity) -> String? {
        switch activity {
        case .text(let a):
            return a.answer.answers.joined(separator: " · ")
        case .selection(let a):
            return a.options
                .filter { a.acceptedIds.contains($0.id) }
                .map(\.text).joined(separator: " · ")
        case .ordering(let a):
            let tokensById = Dictionary(
                uniqueKeysWithValues: a.tokens.map { ($0.id, $0.text) })
            guard let order = a.acceptedOrders.first else { return nil }
            let text = order.compactMap { tokensById[$0] }
                .joined(separator: " ")
            return text.isEmpty ? nil : text
        case .matching(let a):
            let leftById = Dictionary(
                uniqueKeysWithValues: a.left.map { ($0.id, $0.text) })
            let rightById = Dictionary(
                uniqueKeysWithValues: a.right.map { ($0.id, $0.text) })
            let text = a.acceptedPairs.map { pair in
                let left = leftById[pair.leftId] ?? pair.leftId
                let right = rightById[pair.rightId] ?? pair.rightId
                return "\(left) → \(right)"
            }.joined(separator: " · ")
            return text.isEmpty ? nil : text
        case .cloze(let a):
            let text = a.segments.map { segment -> String in
                switch segment {
                case .text(let t): return t
                case .blank(let name, _):
                    let answer = a.blanks[name]?.answers.first ?? "…"
                    return "«\(answer)»"
                }
            }.joined()
            return text.isEmpty ? nil : text
        case .dialogueChoice(let a):
            let text = a.options
                .filter { a.acceptedIds.contains($0.id) }
                .map(\.text).joined(separator: " · ")
            return text.isEmpty ? nil : text
        case .legacy, .sceneSelection, .information, .selfCompare:
            return nil
        }
    }
}

// MARK: - Data export
//
// The learner's data, portable. Events are the source of truth — SRS state,
// completion, and stats all project from them — and checkpoints plus listen
// state ride along so nothing is lost in the move.

/// Everything the app knows about the learner, as JSON.
struct ExportedLearningData: Codable {
    var app: String
    var exportedAt: Date
    var events: [LearningEvent]
    var checkpoints: [StoredCheckpoint]
    var listenState: [ListenStateRow]
}

enum DataExport {
    /// Builds the export file in a temporary directory, ready for a
    /// ShareLink. Throws when the store cannot be read or the file cannot
    /// be written.
    @MainActor
    static func buildFile(store: LearningStore) throws -> URL {
        let payload = ExportedLearningData(
            app: "Condisco",
            exportedAt: Date(),
            events: try store.allEvents(),
            checkpoints: try store.allCheckpoints(),
            listenState: try store.allListenState())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let stamp = ISO8601DateFormatter()
            .string(from: payload.exportedAt)
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("condisco-export-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }
}

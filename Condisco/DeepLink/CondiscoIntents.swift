import AppIntents
import Foundation
import UIKit

// MARK: - Siri Shortcuts + Spotlight intents
//
// The intents below are thin launchers: they open a `condisco://` deep link and
// let `DeepLinkRouter` (owned by the app root) do the routing, so Siri,
// Shortcuts, and Spotlight all share the app's single URL-handling path.
//
// `openAppWhenRun` foregrounds Condisco first; the `UIApplication.shared.open`
// call then runs in the app process, where the existing `.onOpenURL`
// handling picks it up.

// MARK: - Language

/// The five course languages, as Siri hears them.
///
/// AppIntents keeps its own enum rather than consuming `CourseLanguage`
/// directly: a `@Parameter` of AppEnum type serializes its persisted value
/// by the enum's rawValue, which stays the stable slug ("french", …) here —
/// `CourseLanguage`'s rawValues are the pack JSON codes ("fr", …), so
/// switching would change persisted Shortcut parameter values. The display
/// strings below are additionally forced inline by the AppIntents metadata
/// processor (it extracts literal titles at build time). Drift is pinned by
/// `CourseRegistryTests.testAppIntentsLessonLanguageIsRegistryBacked`:
/// adding a language is one registry row + one enum case + one display
/// line here (the residual framework cost).
enum LessonLanguage: String, AppEnum {
    case french
    case italian
    case german
    case portuguese
    case spanish

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Language"

    // AppIntents forces this to be a stored dictionary of LITERAL strings:
    // the build-time metadata processor statically extracts the titles and
    // rejects computed values or function calls (attempted registry lookups
    // as of plan 9.1 — the processor reports nil titles). The enum's case
    // order and the display strings therefore stay spelled out here;
    // `CourseRegistryTests.testAppIntentsLessonLanguageIsRegistryBacked`
    // pins that every case ↔ registry row ↔ order without drift. Adding a
    // language = one `CourseLanguage`/`CourseRegistry` row + one enum case
    // + one literal line here (the residual AppIntents framework cost).
    static var caseDisplayRepresentations: [LessonLanguage: DisplayRepresentation] = [
        .french: "French",
        .italian: "Italian",
        .german: "German",
        .portuguese: "Portuguese",
        .spanish: "Spanish",
    ]
}

// MARK: - Lesson catalog

/// One row of the lesson catalog, shared by the dynamic and generated paths.
struct LessonCatalogEntry: Hashable {
    let packId: String
    let lessonId: String
    let title: String
    let languageName: String
    let unitTitle: String

    init(packId: String, lessonId: String, title: String, languageName: String, unitTitle: String) {
        self.packId = packId
        self.lessonId = lessonId
        self.title = title
        self.languageName = languageName
        self.unitTitle = unitTitle
    }

    init(pack: CoursePack, lesson: Lesson) {
        let unitTitle = pack.units.first { $0.id == lesson.unitId }?.title ?? ""
        self.init(
            packId: pack.id,
            lessonId: lesson.id,
            title: lesson.title,
            languageName: pack.language.displayName,
            unitTitle: unitTitle
        )
    }
}

/// A lesson Siri can resolve by name, e.g. "Start the café mission lesson".
struct LessonEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Lesson"
    static var defaultQuery = LessonEntityQuery()

    /// "<packId>/<lessonId>" — stable across pack edits.
    let id: String
    let packId: String
    let lessonId: String
    let title: String
    let languageName: String
    let unitTitle: String

    init(entry: LessonCatalogEntry) {
        self.id = "\(entry.packId)/\(entry.lessonId)"
        self.packId = entry.packId
        self.lessonId = entry.lessonId
        self.title = entry.title
        self.languageName = entry.languageName
        self.unitTitle = entry.unitTitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(languageName) · \(unitTitle)"
        )
    }
}

struct LessonEntityQuery: EntityQuery, EntityStringQuery {
    /// The full catalog, keyed by stable id.
    ///
    /// Prefers the live bundled packs so new content needs no code change;
    /// falls back to the generated snapshot for host processes whose bundle
    /// does not carry the Content folder (e.g. the Shortcuts app).
    private static func catalogById() -> [String: LessonCatalogEntry] {
        let entries: [LessonCatalogEntry]
        if let packs = try? PackLoader.loadPacks(), !packs.isEmpty {
            entries = packs.flatMap { pack in
                pack.lessons.map { LessonCatalogEntry(pack: pack, lesson: $0) }
            }
        } else {
            entries = GeneratedLessonCatalog.entries
        }
        return Dictionary(uniqueKeysWithValues: entries.map { ("\($0.packId)/\($0.lessonId)", $0) })
    }

    private static func allEntities() -> [LessonEntity] {
        catalogById().values
            .sorted { "\($0.languageName)\($0.title)" < "\($1.languageName)\($1.title)" }
            .map(LessonEntity.init)
    }

    func entities(for identifiers: [LessonEntity.ID]) async throws -> [LessonEntity] {
        let catalog = Self.catalogById()
        return identifiers.compactMap { catalog[$0] }.map(LessonEntity.init)
    }

    func suggestedEntities() async throws -> [LessonEntity] {
        Self.allEntities()
    }

    func entities(matching string: String) async throws -> [LessonEntity] {
        let needle = string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return Self.allEntities().filter { entity in
            [entity.title, entity.unitTitle, entity.languageName].contains {
                $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .contains(needle)
            }
        }
    }
}

// MARK: - Intents

/// "Continue learning in Condisco" — opens the focus language's next lesson.
struct ContinueLearningIntent: AppIntent {
    static var title: LocalizedStringResource = "Continue learning"
    static var description = IntentDescription("Open Condisco at your next lesson.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        guard let url = URL(string: "condisco://continue") else {
            return .result()
        }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
        return .result()
    }
}

/// "Start a French lesson in Condisco" — opens the chosen lesson.
struct StartLessonIntent: AppIntent {
    static var title: LocalizedStringResource = "Start lesson"
    static var description = IntentDescription("Open a specific Condisco lesson.")
    static var openAppWhenRun = true

    @Parameter(title: "Language")
    var language: LessonLanguage

    @Parameter(title: "Lesson")
    var lesson: LessonEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$lesson) in \(\.$language)")
    }

    func perform() async throws -> some IntentResult {
        guard let url = URL(string: "condisco://lesson/\(lesson.packId)/\(lesson.lessonId)") else {
            return .result()
        }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
        return .result()
    }
}

/// "Start my review in Condisco" — opens the Review tab.
struct StartReviewIntent: AppIntent {
    static var title: LocalizedStringResource = "Start review"
    static var description = IntentDescription("Open Condisco at your Review queue.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        guard let url = URL(string: "condisco://review") else {
            return .result()
        }
        await MainActor.run {
            UIApplication.shared.open(url)
        }
        return .result()
    }
}

// MARK: - App Shortcuts

struct CondiscoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ContinueLearningIntent(),
            phrases: [
                "Continue learning in \(.applicationName)",
                "Continue my lesson in \(.applicationName)",
                "Resume learning in \(.applicationName)",
            ],
            shortTitle: "Continue Learning",
            systemImageName: "book.fill"
        )
        AppShortcut(
            intent: StartLessonIntent(),
            phrases: [
                "Start a lesson in \(.applicationName)",
                "Open a lesson in \(.applicationName)",
                "Start learning in \(.applicationName)",
            ],
            shortTitle: "Start Lesson",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: StartReviewIntent(),
            phrases: [
                "Start my review in \(.applicationName)",
                "Review my phrases in \(.applicationName)",
                "Start reviewing in \(.applicationName)",
            ],
            shortTitle: "Start Review",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}

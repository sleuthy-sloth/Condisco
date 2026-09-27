import XCTest
@testable import Condisco

// MARK: - Course registry coherence (plan 9.1)
//
// `CourseRegistry` is the single source of truth for every slug ↔ display
// name ↔ BCP-47 mapping in the app shell. These tests pin that the five
// courses are the same five everywhere (packs, Listen tracks, voice
// pickers, the AppIntents language enum, the display-name helpers) and
// that an unknown slug can never produce English speech.

final class CourseRegistryTests: XCTestCase {

    /// The five bundled packs, in Courses-tab order.
    private var packs: [CoursePack] {
        (try? PackLoader.loadPacks()) ?? []
    }

    /// The registry's order equals the pack load order, which is the
    /// Courses-tab sort and the Listen catalog iteration order.
    func testRegistryOrderIsThePackLoadOrder() {
        XCTAssertEqual(CourseRegistry.slugs, PackLoader.packFilenames)
        XCTAssertEqual(
            CourseRegistry.slugs,
            ["french", "italian", "german", "portuguese", "spanish"])
        XCTAssertEqual(CourseRegistry.order.map(\.slug), CourseRegistry.slugs)
    }

    /// Every registry entry carries a non-empty display name and a
    /// well-formed BCP-47 tag whose language prefix matches the pack JSON
    /// language code (the enum's rawValue).
    func testEveryRegistryEntryHasDisplayNameAndBCP47() {
        XCTAssertFalse(CourseRegistry.order.isEmpty)
        XCTAssertEqual(
            Set(CourseRegistry.order.map(\.slug)).count, CourseRegistry.order.count,
            "registry slugs must be unique")
        for course in CourseRegistry.order {
            XCTAssertFalse(course.displayName.isEmpty)
            XCTAssertFalse(course.slug.isEmpty)
            XCTAssertEqual(course.slug, CourseRegistry.language(slug: course.slug)?.slug)
            XCTAssertNotNil(
                course.bcp47.range(of: #"^[a-z]{2}-[A-Z]{2}$"#, options: .regularExpression),
                "\(course.slug) has malformed BCP-47 \(course.bcp47)")
            XCTAssertEqual(
                String(course.bcp47.prefix(2)), course.rawValue,
                "\(course.slug) BCP-47 prefix must match the pack JSON code \(course.rawValue)")
        }
    }

    /// Every bundled pack's language resolves through the registry with a
    /// non-empty display name and the registry's BCP-47 tag.
    func testEveryBundledPackResolvesThroughRegistry() {
        let loaded = packs
        XCTAssertEqual(loaded.count, 5, "all five bundled packs must load")
        for pack in loaded {
            let registry = CourseRegistry.language(slug: pack.language.slug)
            XCTAssertNotNil(
                registry,
                "pack \(pack.id) language slug \(pack.language.slug) is missing from the registry")
            XCTAssertEqual(pack.language.displayName, registry?.displayName)
            XCTAssertFalse(pack.language.displayName.isEmpty)
            XCTAssertEqual(pack.language.bcp47, registry?.bcp47)
        }
    }

    /// Every bundled Listen track's course slug resolves through the
    /// registry, and its display name comes from the registry.
    func testEveryListenTrackResolvesThroughRegistry() {
        let tracks = ListenCatalog.loadTracks()
        XCTAssertFalse(tracks.isEmpty, "bundled Listen catalog unavailable in this test host")
        XCTAssertLessThanOrEqual(tracks.count, CourseRegistry.order.count)
        for track in tracks {
            let registry = CourseRegistry.language(slug: track.courseSlug)
            XCTAssertNotNil(
                registry,
                "Listen track \(track.lessonId) slug \(track.courseSlug) is missing from the registry")
            XCTAssertEqual(
                ListenCourse.displayName(for: track.courseSlug), registry?.displayName)
            XCTAssertFalse(registry?.displayName.isEmpty ?? true)
        }
    }

    /// Every voice-picker row is exactly one registry course, in registry
    /// order, with the registry's BCP-47 strings — these strings key the
    /// `condisco.voice.<bcp47>` UserDefaults, so they must never drift.
    func testVoicePickerEntriesResolveThroughRegistryAndKeepBCP47() {
        let entries = VoiceStore.courses
        XCTAssertEqual(entries.count, CourseRegistry.order.count)
        for (course, entry) in zip(CourseRegistry.order, entries) {
            XCTAssertEqual(entry.slug, course.slug)
            XCTAssertEqual(entry.name, course.displayName)
            XCTAssertEqual(entry.bcp47, course.bcp47)
            XCTAssertFalse(entry.bcp47.isEmpty)
        }
        XCTAssertEqual(
            entries.map(\.bcp47), CourseRegistry.order.map(\.bcp47),
            "voice-picker BCP-47 strings must match the registry exactly")
    }

    /// Shadow speech resolves every known slug through the registry and
    /// returns nil — never "en-US" — for an unknown slug: the
    /// silent-English fallback is gone.
    func testShadowVoiceNeverFallsBackToEnglish() {
        for slug in CourseRegistry.slugs {
            XCTAssertEqual(
                ShadowVoice.languageCode(for: slug),
                CourseRegistry.bcp47(for: slug))
            XCTAssertNotEqual(
                ShadowVoice.languageCode(for: slug), "en-US")
        }
        XCTAssertNil(ShadowVoice.languageCode(for: "klingon"))
        XCTAssertNil(ShadowVoice.languageCode(for: ""))
        XCTAssertNotEqual(ShadowVoice.languageCode(for: "klingon"), "en-US")
    }

    /// The display-name helpers used by the Library, Listen, and Courses
    /// surfaces all resolve through the registry, and a foreign slug never
    /// reads as an English country name.
    func testDisplayNameHelpersResolveThroughRegistry() {
        for slug in CourseRegistry.slugs {
            XCTAssertEqual(
                LibraryLanguage.displayName(for: slug),
                CourseRegistry.displayName(for: slug))
            XCTAssertEqual(
                ListenCourse.displayName(for: slug),
                CourseRegistry.displayName(for: slug))
            XCTAssertEqual(
                CourseRegistry.language(slug: slug)?.displayName,
                CourseRegistry.displayName(for: slug))
        }
        let foreign = CourseRegistry.displayName(for: "klingon")
        XCTAssertNotEqual(foreign, "French")
        XCTAssertEqual(foreign, "klingon".capitalized)
        XCTAssertEqual(LibraryLanguage.displayName(for: "klingon"), "klingon".capitalized)
    }

    /// AppIntents keeps its own `LessonLanguage` enum (its rawValue — the
    /// stable slug — is what Shortcuts persists, and the metadata processor
    /// forces inline display strings). Every case must resolve to a registry
    /// course with a non-empty display name, and the case order must match
    /// the registry order.
    func testAppIntentsLessonLanguageIsRegistryBacked() {
        let languages = LessonLanguage.allCases
        XCTAssertEqual(languages.count, CourseRegistry.order.count)
        XCTAssertEqual(
            languages.map(\.rawValue), CourseRegistry.slugs,
            "AppIntents case order must match the registry order")
        for language in languages {
            let registry = CourseRegistry.language(slug: language.rawValue)
            XCTAssertNotNil(
                registry,
                "AppIntents language \(language.rawValue) is missing from the registry")
            XCTAssertFalse(registry?.displayName.isEmpty ?? true)
            let display = LessonLanguage.caseDisplayRepresentations[language]
            XCTAssertNotNil(display, "AppIntents language \(language.rawValue) has no display title")
        }
    }
}

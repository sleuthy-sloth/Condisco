import XCTest
@testable import Condisco

// MARK: - Course levels (course-path mapping and counts)
//
// `CoursePath` + `coursePath(of:)` are the single level mapping shared by
// the Courses-tab level cards, the level pages, scoped lesson lists, and
// search. These tests pin that mapping against the bundled packs and
// verify the per-level lesson/completion counts that the level card and
// the level course row display, using a synthetic fixture for exact
// control over mixed levels and empty levels.

final class CoursePathTests: XCTestCase {

    // MARK: - Level mapping (A1 / untagged / A2 / B1 / B2)

    /// Every bundled lesson resolves to exactly the mapping's path:
    /// A2 → Developing, A1/untagged → Foundation, anything else (B1/B2) →
    /// Independent. One mapping must never drift from the authored tags.
    func testLessonLevelMappingMatchesAuthoredTags() throws {
        let packs = try PackLoader.loadPacks()
        XCTAssertFalse(packs.isEmpty)
        for pack in packs {
            for lesson in pack.lessons {
                let expected: CoursePath
                switch lesson.cefr {
                case "A2": expected = .developing
                case "A1", nil: expected = .foundation
                default: expected = .independent
                }
                XCTAssertEqual(
                    coursePath(of: lesson), expected,
                    "\(pack.id)/\(lesson.id) with cefr \(lesson.cefr ?? "nil")")
            }
        }
    }

    /// The mapping covers the five levels named by the plan, including
    /// Spanish's B1 and B2 lessons that populate the Independent level.
    func testLevelMappingForA1UntaggedA2B1AndB2() throws {
        let spanish = try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language.slug == "spanish" })
        let byTag = Dictionary(grouping: spanish.lessons, by: { $0.cefr })
        XCTAssertNotNil(byTag["A1"])
        XCTAssertNotNil(byTag["A2"])
        XCTAssertNotNil(byTag["B1"])
        XCTAssertNotNil(byTag["B2"])
        XCTAssertNotNil(byTag[nil], "Spanish ships untagged foundation lessons")

        XCTAssertEqual(coursePath(of: byTag["A1"]!.first!), .foundation)
        XCTAssertEqual(coursePath(of: byTag[nil]!.first!), .foundation)
        XCTAssertEqual(coursePath(of: byTag["A2"]!.first!), .developing)
        XCTAssertEqual(coursePath(of: byTag["B1"]!.first!), .independent)
        XCTAssertEqual(coursePath(of: byTag["B2"]!.first!), .independent)
    }

    /// The progression order stays Foundation → Developing → Independent
    /// everywhere the level cards iterate.
    func testCoursePathOrderIsProgressionOrder() {
        XCTAssertEqual(
            CoursePath.allCases,
            [.foundation, .developing, .independent])
    }

    /// A unit's path is its first lesson's path; every unit today is
    /// uniform within one path.
    func testUnitLevelMappingUsesFirstLesson() throws {
        let pack = try makeFixture(lessons: [
            ("l1", "u1", "A1"),
            ("l2", "u1", "A2"),
            ("l3", "u2", "B1"),
        ])
        let u1 = try XCTUnwrap(pack.units.first { $0.id == "u1" })
        let u2 = try XCTUnwrap(pack.units.first { $0.id == "u2" })
        XCTAssertEqual(coursePath(of: u1, in: pack), .foundation)
        XCTAssertEqual(coursePath(of: u2, in: pack), .independent)
    }

    // MARK: - Empty-level behavior

    /// A level with no matching lessons reports zero lessons and zero
    /// completed, and contributes no course row (the level card renders
    /// plain text instead of a link).
    func testEmptyLevelHasNoLessonsOrCourses() throws {
        let pack = try makeFixture(lessons: [
            ("l1", "u1", "A1"),
            ("l2", "u2", "A2"),
        ])
        XCTAssertTrue(CoursePath.independent.lessons(in: pack).isEmpty)
        XCTAssertEqual(
            CoursePath.independent.completedCount(in: pack, finished: ["l1", "l2"]), 0)
        XCTAssertTrue(
            [pack].filter { !CoursePath.independent.lessons(in: $0).isEmpty }.isEmpty)
    }

    // MARK: - Matching / completed counts on a mixed-level course

    /// A course spanning all three levels reports, per level, only that
    /// level's lessons (in pack order) and only that level's completed
    /// lessons — a finished lesson at one level never counts for another.
    func testMixedLevelCourseCountsMatchPerLevel() throws {
        // Foundation: l1 (untagged), l2 (A1), l3 (A1); Developing: l4 (A2);
        // Independent: l5 (B1), l6 (B2). Finished: l2 + l4 + l6.
        let pack = try makeFixture(lessons: [
            ("l1", "u1", nil),
            ("l2", "u1", "A1"),
            ("l3", "u2", "A1"),
            ("l4", "u3", "A2"),
            ("l5", "u4", "B1"),
            ("l6", "u5", "B2"),
        ])
        let finished: Set<String> = ["l2", "l4", "l6"]

        XCTAssertEqual(
            CoursePath.foundation.lessons(in: pack).map(\.id), ["l1", "l2", "l3"])
        XCTAssertEqual(
            CoursePath.foundation.completedCount(in: pack, finished: finished), 1)

        XCTAssertEqual(
            CoursePath.developing.lessons(in: pack).map(\.id), ["l4"])
        XCTAssertEqual(
            CoursePath.developing.completedCount(in: pack, finished: finished), 1)

        XCTAssertEqual(
            CoursePath.independent.lessons(in: pack).map(\.id), ["l5", "l6"])
        XCTAssertEqual(
            CoursePath.independent.completedCount(in: pack, finished: finished), 1)

        // The per-level counts never exceed the matching lessons.
        for path in CoursePath.allCases {
            let matching = path.lessons(in: pack).count
            XCTAssertLessThanOrEqual(
                path.completedCount(in: pack, finished: finished), matching)
        }
    }

    /// The Spanish pack is the live mixed-level course: every level has
    /// lessons, in authored order, and the Independent set is exactly the
    /// B1/B2 lessons it ships.
    func testSpanishReachesAllLevelsWithAuthoredOrder() throws {
        let spanish = try XCTUnwrap(
            PackLoader.loadPacks().first { $0.language.slug == "spanish" })
        XCTAssertFalse(CoursePath.foundation.lessons(in: spanish).isEmpty)
        XCTAssertFalse(CoursePath.developing.lessons(in: spanish).isEmpty)
        let independent = CoursePath.independent.lessons(in: spanish)
        XCTAssertEqual(
            independent.map(\.id),
            spanish.lessons.filter { $0.cefr == "B1" || $0.cefr == "B2" }.map(\.id),
            "Independent must be exactly the B1/B2 lessons, in pack order")
        XCTAssertEqual(
            independent.first?.cefr, "B1",
            "Spanish's Independent path begins with a B1 lesson")
    }

    // MARK: - Scoped search

    /// The lesson list's search runs over the scoped `visibleLessons`, so
    /// results are always a subset of the selected level — including while
    /// searching (acceptance: a scoped course never shows another level).
    func testScopedSearchNeverEscapesTheLevel() throws {
        let pack = try makeFixture(lessons: [
            ("l1", "u1", nil),
            ("l2", "u1", "A1"),
            ("l3", "u2", "A2"),
            ("l4", "u3", "B1"),
            ("l5", "u4", "B2"),
        ])
        // "Lesson" matches every fixture title; results must still only be
        // the lessons the level actually contains.
        let foundationHits = lessonSearchResults(
            CoursePath.foundation.lessons(in: pack), query: "Lesson")
        XCTAssertEqual(Set(foundationHits.map(\.id)), ["l1", "l2"])
        let developingHits = lessonSearchResults(
            CoursePath.developing.lessons(in: pack), query: "Lesson")
        XCTAssertEqual(Set(developingHits.map(\.id)), ["l3"])
        let independentHits = lessonSearchResults(
            CoursePath.independent.lessons(in: pack), query: "Lesson")
        XCTAssertEqual(Set(independentHits.map(\.id)), ["l4", "l5"])
        // A scoped search can never suggest a lesson outside its level.
        let allIds = Set(pack.lessons.map(\.id))
        for hits in [foundationHits, developingHits, independentHits] {
            XCTAssertTrue(
                hits.allSatisfy { allIds.contains($0.id) }
                    && Set(hits.map(\.id)).count == hits.count)
        }
    }

    /// The search predicate is case-insensitive over title and objective,
    /// preserves input order, and returns nothing for a blank or unmatched
    /// query.
    func testLessonSearchMatchesTitleObjectiveAndPreservesOrder() throws {
        let pack = try makeFixture(lessons: [
            ("l1", "u1", "A1"),
            ("l2", "u1", "A1"),
            ("l3", "u2", "A1"),
            ("l4", "u3", "A2"),
        ])
        let all = pack.lessons
        XCTAssertEqual(lessonSearchResults(all, query: "Lesson").map(\.id),
                       ["l1", "l2", "l3", "l4"],
                       "case-insensitive title match must keep pack order")
        XCTAssertEqual(lessonSearchResults(all, query: "objective").map(\.id),
                       ["l1", "l2", "l3", "l4"],
                       "objective match must be included")
        XCTAssertEqual(lessonSearchResults(all, query: "LESSON L2").map(\.id), ["l2"])
        XCTAssertEqual(lessonSearchResults(all, query: "missing").map(\.id), [])
        XCTAssertEqual(lessonSearchResults(all, query: "   ").map(\.id), [])
        XCTAssertEqual(lessonSearchResults([], query: "Lesson").map(\.id), [])
    }

    // MARK: - Synthetic fixture

    /// A schema-valid pack with exactly the given lessons and one unit per
    /// distinct unitId, in first-appearance order — the same JSON shape
    /// other suites' fixtures use.
    private func makeFixture(
        lessons: [(id: String, unitId: String, cefr: String?)]
    ) throws -> CoursePack {
        var unitIds: [String] = []
        for lesson in lessons where !unitIds.contains(lesson.unitId) {
            unitIds.append(lesson.unitId)
        }
        let units = unitIds.enumerated().map { index, id in
            """
            {"id":"\(id)","title":"Unit \(index + 1)","objective":"Objective \(index + 1)"}
            """
        }.joined(separator: ",")
        let lessonJSON = lessons.map { spec in
            let cefr = spec.cefr.map { ",\"cefr\":\"\($0)\"" } ?? ""
            return """
            {"id":"\(spec.id)","unitId":"\(spec.unitId)","title":"Lesson \(spec.id)","objective":"Objective","family":"discovery","revision":1,"estimatedMinutes":5,"entryStepId":"s\(spec.id)","steps":[],"completionPolicy":{"kind":"participation"},"prerequisites":[],"conceptIds":[],"vocabulary":[],"legacyExercises":[]\(cefr)}
            """
        }.joined(separator: ",")
        let json = """
        {"schemaVersion":2,"id":"course-path-fixture","version":"1.0.0","language":"es","status":"active","title":"Fixture","sourceLanguage":"en","description":"d","attribution":"a",
        "units":[\(units)],
        "concepts":[],"vocabulary":[],"media":[],"stimuli":[],
        "activities":[],
        "lessons":[\(lessonJSON)],
        "dialogues":[]}
        """
        return try JSONDecoder().decode(CoursePack.self, from: Data(json.utf8))
    }
}
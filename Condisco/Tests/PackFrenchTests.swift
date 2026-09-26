import XCTest
@testable import Condisco

/// Per-pack editorial regression tests for the French pack.
///
/// Owned by the French editorial lane: add targeted answer/evaluation
/// tests here for content fixes (resolved high-confidence errors,
/// narrowed accepted-answer sets, authored error feedback). Do not put
/// other packs' tests in this file.
final class PackFrenchTests: XCTestCase {
    func testFrenchPackLoadsAndValidates() throws {
        let packs = try PackLoader.loadPacks()
        let pack = try XCTUnwrap(packs.first { $0.language.slug == "french" })
        XCTAssertFalse(pack.lessons.isEmpty, "French pack must ship lessons")
        XCTAssertNoThrow(try PackValidator.validate(pack), pack.id)
    }
}

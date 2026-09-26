import XCTest
@testable import Condisco

/// Per-pack editorial regression tests for the Portuguese pack.
///
/// Owned by the Portuguese editorial lane: add targeted answer/evaluation
/// tests here for content fixes (resolved high-confidence errors,
/// narrowed accepted-answer sets, authored error feedback). Do not put
/// other packs' tests in this file.
final class PackPortugueseTests: XCTestCase {
    func testPortuguesePackLoadsAndValidates() throws {
        let packs = try PackLoader.loadPacks()
        let pack = try XCTUnwrap(packs.first { $0.language.slug == "portuguese" })
        XCTAssertFalse(pack.lessons.isEmpty, "Portuguese pack must ship lessons")
        XCTAssertNoThrow(try PackValidator.validate(pack), pack.id)
    }
}

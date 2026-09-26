import XCTest
@testable import Condisco

/// Per-pack editorial regression tests for the Spanish pack.
///
/// Owned by the Spanish editorial lane: add targeted answer/evaluation
/// tests here for content fixes (resolved high-confidence errors,
/// narrowed accepted-answer sets, authored error feedback). Do not put
/// other packs' tests in this file.
final class PackSpanishTests: XCTestCase {
    func testSpanishPackLoadsAndValidates() throws {
        let packs = try PackLoader.loadPacks()
        let pack = try XCTUnwrap(packs.first { $0.language.slug == "spanish" })
        XCTAssertFalse(pack.lessons.isEmpty, "Spanish pack must ship lessons")
        XCTAssertNoThrow(try PackValidator.validate(pack), pack.id)
    }
}

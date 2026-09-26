import XCTest
@testable import Condisco

/// Per-pack editorial regression tests for the German pack.
///
/// Owned by the German editorial lane: add targeted answer/evaluation
/// tests here for content fixes (resolved high-confidence errors,
/// narrowed accepted-answer sets, authored error feedback). Do not put
/// other packs' tests in this file.
final class PackGermanTests: XCTestCase {
    func testGermanPackLoadsAndValidates() throws {
        let packs = try PackLoader.loadPacks()
        let pack = try XCTUnwrap(packs.first { $0.language.slug == "german" })
        XCTAssertFalse(pack.lessons.isEmpty, "German pack must ship lessons")
        XCTAssertNoThrow(try PackValidator.validate(pack), pack.id)
    }
}

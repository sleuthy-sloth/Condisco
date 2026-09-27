import Foundation

// MARK: - Library import validation (8.2 §5)
//
// Pure, side-effect-free validation of raw UTF-8 text BEFORE it is written
// to the store. The imported text is untrusted input: it may be binary, a
// non-text file that slipped past the picker, oversized, or empty. Every
// check runs on the `Data` alone — no store, no UserDefaults, no file I/O —
// so a failed validation can guarantee zero writes by construction: the
// caller has nothing to write.
//
// The type is new and parallel to `ImportValidator` (which validates
// exports): same discipline — plain-language errors for direct display, a
// named pinned size constant — but a different contract, raw text in, not
// a JSON document.

/// Why an imported text was rejected. Messages are written plainly so
/// they can be shown to the learner as-is.
enum LibraryImportError: Error, CustomStringConvertible, Equatable {
    /// The text exceeds the document size cap.
    case tooLarge(actualBytes: Int, limitBytes: Int)
    /// The data is not decodable UTF-8 text (binary, garbage, or a
    /// non-text file that slipped past the picker).
    case notUTF8
    /// The text is empty once whitespace is trimmed.
    case empty

    var description: String {
        switch self {
        case .tooLarge:
            return "This text is too long to import (the limit is 1 MB)."
        case .notUTF8:
            return "This file isn't readable as UTF-8 text. Nothing was imported."
        case .empty:
            return "There's no text here to import."
        }
    }
}

enum LibraryImportValidator {
    /// Hard cap on a single reading document. Named and pinned so the
    /// bound is auditable, like `ImportValidator.maxImportSizeBytes`:
    /// 1 MB of UTF-8 is on the order of 300k+ words — far beyond a
    /// realistic reading passage — while staying comfortably below any
    /// SQLite row-size concern.
    static let maxDocumentBytes = 1 * 1024 * 1024   // 1 MB

    /// Validates raw imported text.
    ///
    /// - Returns: `.success(text)` with the decoded text as-is (whitespace
    ///   preserved — only the emptiness check trims), or `.failure` naming
    ///   the first problem. On failure nothing has been written — this
    ///   function has no side effects at all.
    static func validate(_ data: Data) -> Result<String, LibraryImportError> {
        // 1. Size cap before any decoding.
        guard data.count <= maxDocumentBytes else {
            return .failure(.tooLarge(
                actualBytes: data.count, limitBytes: maxDocumentBytes))
        }

        // 2. Must decode as UTF-8. This is the safe rejection for
        //    undecodable/binary/garbage input.
        guard let text = String(data: data, encoding: .utf8) else {
            return .failure(.notUTF8)
        }

        // 3. Trimmed content must be non-empty.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }

        return .success(text)
    }
}

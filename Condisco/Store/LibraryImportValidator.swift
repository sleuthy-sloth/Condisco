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
    case notReadableText
    /// The text is empty once whitespace is trimmed.
    case empty

    var description: String {
        switch self {
        case .tooLarge:
            return "This text is too long to import (the limit is 1 MB)."
        case .notUTF8:
            return "This file isn't readable as UTF-8 text. Nothing was imported."
        case .notReadableText:
            return "This file contains binary characters. Choose a plain text file. Nothing was imported."
        case .empty:
            return "There's no text here to import."
        }
    }
}

enum LibraryImportValidator {
    /// Reads no more than the limit plus one sentinel byte. The caller owns
    /// security-scoped access and runs this synchronous I/O off the UI actor.
    static func readFile(_ url: URL) throws -> Data {
        try Task.checkCancellation()
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= maxDocumentBytes {
            try Task.checkCancellation()
            let remaining = maxDocumentBytes + 1 - data.count
            let chunk = try handle.read(upToCount: min(16_384, remaining)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
        }
        try Task.checkCancellation()
        guard data.count <= maxDocumentBytes else {
            throw LibraryImportError.tooLarge(
                actualBytes: data.count, limitBytes: maxDocumentBytes)
        }
        return data
    }

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
        guard var text = String(data: data, encoding: .utf8) else {
            return .failure(.notUTF8)
        }

        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        guard !text.unicodeScalars.contains(where: {
            let value = $0.value
            return (value < 32 && value != 9 && value != 10 && value != 13)
                || (127...159).contains(value)
        }) else { return .failure(.notReadableText) }

        // 3. Trimmed content must be non-empty.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }

        return .success(text)
    }
}

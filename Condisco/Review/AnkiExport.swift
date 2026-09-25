import CryptoKit
import Foundation
import SQLite3
import SwiftUI

// MARK: - Anki export
//
// Builds a genuine .apkg package from the learner's phrasebook: one
// "Condisco::<Language>" deck per language, basic Front → Back cards.
// Anki desktop and AnkiMobile import .apkg straight from the share
// sheet. The package is a zip using stored (uncompressed) entries —
// written by hand below so the app needs no third-party dependency —
// containing collection.anki2 (SQLite, minimal valid Anki schema) and
// the media manifest.

enum AnkiExporter {
    struct ExportError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Writes "Condisco Flashcards.apkg" into a fresh temp folder and
    /// returns its URL. Throws ExportError when there is nothing to
    /// export or the package cannot be built.
    static func export(phrases: [SavedPhrase]) throws -> URL {
        let clean = phrases.filter {
            !$0.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !clean.isEmpty else {
            throw ExportError(message: "No saved phrases to export yet.")
        }
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "condisco-anki-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: work, withIntermediateDirectories: true)
        let dbURL = work.appendingPathComponent("collection.anki2")
        try buildDatabase(at: dbURL, phrases: clean)
        var zip = ZipStoreWriter()
        zip.add(name: "collection.anki2", contents: try Data(contentsOf: dbURL))
        zip.add(name: "media", contents: Data("{}".utf8))
        let packageURL = work.appendingPathComponent("Condisco Flashcards.apkg")
        try zip.finalize().write(to: packageURL)
        return packageURL
    }

    // MARK: database

    private static func buildDatabase(
        at url: URL, phrases: [SavedPhrase]
    ) throws {
        var raw: OpaquePointer?
        guard sqlite3_open(url.path, &raw) == SQLITE_OK, let db = raw else {
            throw ExportError(message: "Couldn't create the export file.")
        }
        defer { sqlite3_close(db) }

        try exec(db, """
            CREATE TABLE col (id INTEGER PRIMARY KEY,
                crt INTEGER NOT NULL, mod INTEGER NOT NULL,
                scm INTEGER NOT NULL, ver INTEGER NOT NULL,
                dty INTEGER NOT NULL, usn INTEGER NOT NULL,
                ls INTEGER NOT NULL, conf TEXT NOT NULL,
                models TEXT NOT NULL, decks TEXT NOT NULL,
                dconf TEXT NOT NULL, tags TEXT NOT NULL);
            """)
        try exec(db, """
            CREATE TABLE notes (id INTEGER PRIMARY KEY,
                guid TEXT NOT NULL, mid INTEGER NOT NULL,
                mod INTEGER NOT NULL, usn INTEGER NOT NULL,
                tags TEXT NOT NULL, flds TEXT NOT NULL,
                sfld TEXT NOT NULL, csum INTEGER NOT NULL,
                flags INTEGER NOT NULL, data TEXT NOT NULL);
            """)
        try exec(db, """
            CREATE TABLE cards (id INTEGER PRIMARY KEY,
                nid INTEGER NOT NULL, did INTEGER NOT NULL,
                ord INTEGER NOT NULL, mod INTEGER NOT NULL,
                usn INTEGER NOT NULL, type INTEGER NOT NULL,
                queue INTEGER NOT NULL, due INTEGER NOT NULL,
                ivl INTEGER NOT NULL, factor INTEGER NOT NULL,
                reps INTEGER NOT NULL, lapses INTEGER NOT NULL,
                left INTEGER NOT NULL, odue INTEGER NOT NULL,
                odid INTEGER NOT NULL, flags INTEGER NOT NULL,
                data TEXT NOT NULL);
            """)
        try exec(db, """
            CREATE TABLE revlog (id INTEGER PRIMARY KEY,
                cid INTEGER NOT NULL, usn INTEGER NOT NULL,
                ease INTEGER NOT NULL, ivl INTEGER NOT NULL,
                lastIvl INTEGER NOT NULL, factor INTEGER NOT NULL,
                time INTEGER NOT NULL, type INTEGER NOT NULL);
            """)
        try exec(db, """
            CREATE TABLE graves (usn INTEGER NOT NULL,
                oid INTEGER NOT NULL, type INTEGER NOT NULL);
            """)

        let nowS = Int64(Date().timeIntervalSince1970)
        let nowMs = nowS * 1000
        let mid = nowMs + 1

        // One deck per language, in first-seen order.
        var order: [String] = []
        var byLanguage: [String: [SavedPhrase]] = [:]
        for phrase in phrases {
            if byLanguage[phrase.languageName] == nil {
                order.append(phrase.languageName)
            }
            byLanguage[phrase.languageName, default: []].append(phrase)
        }
        var deckIds: [String: Int64] = [:]
        for (index, language) in order.enumerated() {
            deckIds[language] = nowMs + 100 + Int64(index)
        }

        let modelsJSON = try jsonString([
            "\(mid)": notetype(mid: mid, deckId: deckIds[order[0]]!, nowS: nowS),
        ])
        var decks: [String: Any] = [
            "1": deck(id: 1, name: "Default", nowS: nowS),
        ]
        for language in order {
            decks["\(deckIds[language]!)"] = deck(
                id: deckIds[language]!, name: "Condisco::\(language)", nowS: nowS)
        }
        let decksJSON = try jsonString(decks)
        let confJSON = try jsonString([
            "nextPos": 1,
            "estTimes": true,
            "activeDecks": [1],
            "sortType": "noteFld",
            "timeLim": 0,
            "sortBackwards": false,
            "addToCur": true,
            "curDeck": deckIds[order[0]]!,
            "newBury": true,
            "newSpread": 0,
            "dueCounts": true,
            "curModel": "\(mid)",
            "collapseTime": 1200,
        ] as [String: Any])
        let dconfJSON = try jsonString([
            "1": [
                "name": "Default",
                "replayq": true,
                "lapse": ["leechFails": 8, "minInt": 1, "delays": [10],
                          "leechAction": 1] as [String: Any],
                "rev": ["perDay": 200, "fuzz": 1, "ivlFct": 1,
                        "maxIvl": 36500, "ease4": 1.3, "bury": true,
                        "minSpace": 1] as [String: Any],
                "new": ["perDay": 20, "delays": [1, 10], "separate": true,
                        "ints": [1, 4, 7], "initialFactor": 2500,
                        "bury": true, "order": 1] as [String: Any],
                "timer": 0,
                "maxTaken": 60,
                "usn": 0,
                "id": 1,
            ] as [String: Any],
        ])

        try insert(
            db,
            sql: """
                INSERT INTO col
                    (id, crt, mod, scm, ver, dty, usn, ls,
                     conf, models, decks, dconf, tags)
                VALUES (1, ?, ?, ?, 11, 0, 0, 0, ?, ?, ?, ?, '');
                """,
            args: [.int(nowS), .int(nowMs), .int(nowMs), .text(confJSON),
                   .text(modelsJSON), .text(decksJSON), .text(dconfJSON)])

        var position: Int64 = 0
        for language in order {
            let did = deckIds[language]!
            for phrase in byLanguage[language]! {
                let nid = nowMs + 1_000 + position
                let cid = nowMs + 100_000 + position
                let front = phrase.target
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let back = phrase.meaning
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                try insert(
                    db,
                    sql: """
                        INSERT INTO notes
                            (id, guid, mid, mod, usn, tags, flds,
                             sfld, csum, flags, data)
                        VALUES (?, ?, ?, ?, -1, ?, ?, ?, ?, 0, '');
                        """,
                    args: [.int(nid), .text(guidString()), .int(mid),
                           .int(nowS), .text("condisco \(phrase.languageSlug)"),
                           .text("\(front)\u{1f}\(back)"), .text(front),
                           .int(Int64(checksum(front)))])
                try insert(
                    db,
                    sql: """
                        INSERT INTO cards
                            (id, nid, did, ord, mod, usn, type, queue,
                             due, ivl, factor, reps, lapses, left,
                             odue, odid, flags, data)
                        VALUES (?, ?, ?, 0, ?, -1, 0, 0, ?,
                                0, 0, 0, 0, 0, 0, 0, 0, '');
                        """,
                    args: [.int(cid), .int(nid), .int(did), .int(nowS),
                           .int(position)])
                position += 1
            }
        }
    }

    // MARK: notetype / decks

    private static func notetype(
        mid: Int64, deckId: Int64, nowS: Int64
    ) -> [String: Any] {
        let field: (String, Int) -> [String: Any] = { name, ord in
            ["name": name, "ord": ord, "sticky": false, "rtl": false,
             "font": "Arial", "size": 20, "media": [] as [Any]]
        }
        return [
            "id": mid,
            "name": "Condisco Basic",
            "type": 0,
            "mod": nowS,
            "usn": 0,
            "sortf": 0,
            "did": deckId,
            "tmpls": [[
                "name": "Card 1",
                "ord": 0,
                "qfmt": "{{Front}}",
                "afmt": "{{FrontSide}}\n\n<hr id=answer>\n\n{{Back}}",
                "bqfmt": "",
                "bafmt": "",
                "did": NSNull(),
                "bfont": "",
                "bsize": 0,
            ] as [String: Any]],
            "flds": [field("Front", 0), field("Back", 1)],
            "css": ".card {\n font-family: Arial;\n font-size: 20px;\n"
                + " text-align: center;\n color: black;\n"
                + " background-color: white;\n}",
            "latexPre": "\\documentclass[12pt]{article}\n"
                + "\\special{papersize=3in,5in}\n"
                + "\\usepackage[utf8]{inputenc}\n"
                + "\\usepackage{amssymb,amsmath}\n"
                + "\\pagestyle{empty}\n"
                + "\\setlength{\\parindent}{0in}\n"
                + "\\begin{document}\n",
            "latexPost": "\\end{document}",
            "req": [[0, "any", [0]] as [Any]],
        ]
    }

    private static func deck(
        id: Int64, name: String, nowS: Int64
    ) -> [String: Any] {
        ["id": id, "name": name, "mod": nowS, "usn": 0,
         "collapsed": false, "browserCollapsed": false,
         "desc": "", "dyn": 0, "extendNew": 10, "extendRev": 50,
         "conf": 1, "newToday": [0, 0], "revToday": [0, 0],
         "lrnToday": [0, 0], "timeToday": [0, 0]]
    }

    // MARK: sqlite helpers

    private enum Arg {
        case int(Int64)
        case text(String)
    }

    private static func exec(_ db: OpaquePointer, _ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown error"
            throw ExportError(message: "Export failed: \(message)")
        }
    }

    private static func insert(
        _ db: OpaquePointer, sql: String, args: [Arg]
    ) throws {
        var raw: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &raw, nil) == SQLITE_OK,
              let stmt = raw else {
            throw ExportError(
                message: "Export failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, arg) in args.enumerated() {
            let position = Int32(index + 1)
            switch arg {
            case .int(let value):
                sqlite3_bind_int64(stmt, position, value)
            case .text(let value):
                sqlite3_bind_text(stmt, position, value, -1, transient)
            }
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ExportError(
                message: "Export failed: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private static func jsonString(_ value: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            throw ExportError(message: "Export failed: bad deck data.")
        }
        return string
    }

    /// First 8 hex digits of the SHA-1, as Anki computes note checksums.
    private static func checksum(_ text: String) -> UInt32 {
        let digest = Insecure.SHA1.hash(data: Data(text.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return UInt32(hex.prefix(8), radix: 16) ?? 0
    }

    private static func guidString() -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<10).map { _ in alphabet.randomElement()! })
    }
}

// MARK: - Stored zip writer
//
// Minimal ZIP with stored (uncompressed) entries: local headers, then
// the central directory. Anki accepts stored entries, and this keeps
// the app free of third-party archive dependencies.

struct ZipStoreWriter {
    private var data = Data()
    private var entries: [(name: Data, crc: UInt32, size: UInt32, offset: UInt32)] = []

    mutating func add(name: String, contents: Data) {
        let nameData = Data(name.utf8)
        let offset = UInt32(data.count)
        let crc = contents.crc32()
        let size = UInt32(contents.count)
        append(UInt32(0x0403_4B50))
        append(UInt16(20)) // version needed
        append(UInt16(0)) // flags
        append(UInt16(0)) // method: stored
        append(UInt16(0)) // mod time
        append(UInt16(0x21)) // mod date: 1980-01-01
        append(crc)
        append(size) // compressed size
        append(size) // uncompressed size
        append(UInt16(nameData.count))
        append(UInt16(0)) // extra length
        data.append(nameData)
        data.append(contents)
        entries.append((nameData, crc, size, offset))
    }

    func finalize() -> Data {
        var out = data
        let centralStart = UInt32(out.count)
        var centralSize: UInt32 = 0
        for entry in entries {
            let before = out.count
            appendLittleEndian(UInt32(0x0201_4B50), to: &out)
            appendLittleEndian(UInt16(20), to: &out) // version made by
            appendLittleEndian(UInt16(20), to: &out) // version needed
            appendLittleEndian(UInt16(0), to: &out) // flags
            appendLittleEndian(UInt16(0), to: &out) // method: stored
            appendLittleEndian(UInt16(0), to: &out) // mod time
            appendLittleEndian(UInt16(0x21), to: &out) // mod date
            appendLittleEndian(entry.crc, to: &out)
            appendLittleEndian(entry.size, to: &out)
            appendLittleEndian(entry.size, to: &out)
            appendLittleEndian(UInt16(entry.name.count), to: &out)
            appendLittleEndian(UInt16(0), to: &out) // extra length
            appendLittleEndian(UInt16(0), to: &out) // comment length
            appendLittleEndian(UInt16(0), to: &out) // disk number
            appendLittleEndian(UInt16(0), to: &out) // internal attrs
            appendLittleEndian(UInt32(0), to: &out) // external attrs
            appendLittleEndian(entry.offset, to: &out)
            out.append(entry.name)
            centralSize += UInt32(out.count - before)
        }
        appendLittleEndian(UInt32(0x0605_4B50), to: &out) // end of central directory
        appendLittleEndian(UInt16(0), to: &out) // disk number
        appendLittleEndian(UInt16(0), to: &out) // central dir disk
        appendLittleEndian(UInt16(entries.count), to: &out)
        appendLittleEndian(UInt16(entries.count), to: &out)
        appendLittleEndian(centralSize, to: &out)
        appendLittleEndian(centralStart, to: &out)
        appendLittleEndian(UInt16(0), to: &out) // comment length
        return out
    }

    private mutating func append<T: FixedWidthInteger>(_ value: T) {
        appendLittleEndian(value, to: &data)
    }
}

private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
}

private extension Data {
    func crc32() -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in self {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = ZipStoreWriter.crcTable[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension ZipStoreWriter {
    static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1
            }
            return c
        }
    }()
}

// MARK: - Export button

/// Builds the .apkg off the main thread, then hands it to the share
/// sheet. AnkiMobile and Anki desktop open it from there.
struct AnkiExportButton: View {
    let phrases: [SavedPhrase]

    @State private var exportURL: URL?
    @State private var errorMessage: String?
    @State private var isExporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Share Anki deck", systemImage: "square.and.arrow.up")
                        .font(DesignTokens.text(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.primary)
                }
            } else {
                Button {
                    Task {
                        isExporting = true
                        errorMessage = nil
                        exportURL = nil
                        do {
                            exportURL = try await Task.detached(
                                priority: .userInitiated
                            ) {
                                try AnkiExporter.export(phrases: phrases)
                            }.value
                        } catch {
                            errorMessage = (error as? LocalizedError)?
                                .errorDescription ?? error.localizedDescription
                        }
                        isExporting = false
                    }
                } label: {
                    Label(
                        isExporting ? "Building deck…" : "Export to Anki",
                        systemImage: "square.and.arrow.down"
                    )
                    .font(DesignTokens.text(15, weight: .semibold))
                    .foregroundStyle(DesignTokens.primary)
                }
                .disabled(isExporting || phrases.isEmpty)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(DesignTokens.text(13))
                    .foregroundStyle(DesignTokens.attentionInk)
            }
        }
    }
}

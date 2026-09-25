import Foundation
import SQLite3

/// Minimal raw-SQLite wrapper. The store owns all SQL and the schema;
/// this type only moves values across the C boundary.
final class Database {
    enum DatabaseError: Error, CustomStringConvertible {
        case open(String)
        case exec(String)
        case prepare(String)
        case step(String)
        case bind(String)

        var description: String {
            switch self {
            case .open(let message): return "sqlite open: \(message)"
            case .exec(let message): return "sqlite exec: \(message)"
            case .prepare(let message): return "sqlite prepare: \(message)"
            case .step(let message): return "sqlite step: \(message)"
            case .bind(let message): return "sqlite bind: \(message)"
            }
        }
    }

    private var handle: OpaquePointer?

    init(path: String) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        let rc = sqlite3_open_v2(path, &db, flags, nil)
        guard rc == SQLITE_OK, let opened = db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "rc=\(rc)"
            if let leaked = db { sqlite3_close(leaked) }
            throw DatabaseError.open(message)
        }
        handle = opened
        sqlite3_busy_timeout(opened, 5_000)
        try exec("PRAGMA journal_mode = WAL;")
        try exec("PRAGMA foreign_keys = ON;")
    }

    deinit {
        if let h = handle { sqlite3_close(h) }
    }

    fileprivate func message() -> String {
        guard let h = handle else { return "no handle" }
        return String(cString: sqlite3_errmsg(h))
    }

    func exec(_ sql: String) throws {
        guard let h = handle else { throw DatabaseError.exec("no handle") }
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(h, sql, nil, nil, &err)
        guard rc == SQLITE_OK else {
            let message = err.map { String(cString: $0) } ?? self.message()
            sqlite3_free(err)
            throw DatabaseError.exec(message)
        }
    }

    func transaction(_ work: () throws -> Void) throws {
        try exec("BEGIN IMMEDIATE;")
        do {
            try work()
            try exec("COMMIT;")
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    /// Runs a statement that returns no rows (INSERT / UPDATE / DELETE / DDL).
    func execute(_ sql: String, bind: ((Statement) throws -> Void)? = nil) throws {
        let statement = try prepare(sql)
        if let bind = bind { try bind(statement) }
        let hasRow = try statement.step()
        if hasRow { throw DatabaseError.step("non-query returned a row") }
    }

    /// Runs a SELECT, calling `row` once per returned row.
    func query(
        _ sql: String,
        bind: ((Statement) throws -> Void)? = nil,
        row: (Statement) throws -> Void
    ) throws {
        let statement = try prepare(sql)
        if let bind = bind { try bind(statement) }
        while try statement.step() {
            try row(statement)
        }
    }

    private func prepare(_ sql: String) throws -> Statement {
        guard let h = handle else { throw DatabaseError.prepare("no handle") }
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(h, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let s = stmt else {
            throw DatabaseError.prepare(message())
        }
        return Statement(raw: s, owner: self)
    }
}

/// A prepared statement. Finalized when released.
final class Statement {
    fileprivate let raw: OpaquePointer
    private let owner: Database

    fileprivate init(raw: OpaquePointer, owner: Database) {
        self.raw = raw
        self.owner = owner
    }

    deinit {
        sqlite3_finalize(raw)
    }

    private func check(_ rc: Int32) throws {
        guard rc == SQLITE_OK else { throw Database.DatabaseError.bind(owner.message()) }
    }

    func bindText(_ index: Int32, _ value: String?) throws {
        if let value = value {
            let rc = value.withCString { ptr in
                sqlite3_bind_text(
                    raw, index, ptr, -1,
                    unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
            try check(rc)
        } else {
            try check(sqlite3_bind_null(raw, index))
        }
    }

    func bindInt64(_ index: Int32, _ value: Int64) throws {
        try check(sqlite3_bind_int64(raw, index, value))
    }

    func bindDouble(_ index: Int32, _ value: Double) throws {
        try check(sqlite3_bind_double(raw, index, value))
    }

    func bindNull(_ index: Int32) throws {
        try check(sqlite3_bind_null(raw, index))
    }

    /// Advances to the next row. Returns false when the statement is done.
    @discardableResult
    func step() throws -> Bool {
        switch sqlite3_step(raw) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw Database.DatabaseError.step(owner.message())
        }
    }

    func isNull(_ index: Int32) -> Bool {
        sqlite3_column_type(raw, index) == SQLITE_NULL
    }

    func text(_ index: Int32) -> String? {
        guard let ptr = sqlite3_column_text(raw, index) else { return nil }
        return String(cString: ptr)
    }

    func int64(_ index: Int32) -> Int64 {
        sqlite3_column_int64(raw, index)
    }

    func double(_ index: Int32) -> Double {
        sqlite3_column_double(raw, index)
    }
}

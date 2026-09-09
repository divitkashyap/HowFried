import Foundation
import CSQLite
import Darwin

public struct Preferences: Codable {
    public var appearance: String? = nil
    public var rule = BreakSettings()
    public var claudeEnabled = false
    public var codexEnabled = false
    public var tokensEnabled = false
    public var tokensSince: Date?
    public var paused = false
    public var suspended = false
    public var sound = false
    public var shortcutKey = "B"
    public var shortcutControl = true
    public var shortcutOption = true
    public var shortcutCommand = true
    public var onboarded = false
    public init() {}
    public func accepts(_ source: Integration) -> Bool {
        !paused && !suspended && (source == .claude ? claudeEnabled : source == .codex ? codexEnabled : false)
    }
}

public struct DailySummary {
    public var claudePrompts = 0, codexPrompts = 0
    public var usage = TokenUsage()
    public var completed = 0, skipped = 0
    public var totalPrompts: Int { claudePrompts + codexPrompts }
    public init() {}
}

public struct StoredEvent { public let sequence: Int64; public let event: ActivityEvent }
public enum StoreError: Error { case unavailable, unsafeLocation, invalidData }

/// A private SQLite spool. PERSIST journaling reuses its journal; no file cleanup scripts.
/// Separate connections may be used by hook processes. Each connection stays on one thread.
public final class ActivityStore {
    private var db: OpaquePointer?
    public let directory: URL
    public static var defaultDirectory: URL {
        if let custom = ProcessInfo.processInfo.environment["HOWFRIED_DATA_DIR"], custom.hasPrefix("/") {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HowFried", isDirectory: true)
    }
    public init(directory: URL = ActivityStore.defaultDirectory, create: Bool = true) throws {
        self.directory = directory
        let fm = FileManager.default
        if create { try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
        let url = directory.appendingPathComponent("activity.sqlite")
        for candidate in [directory, url, directory.appendingPathComponent("activity.sqlite-journal")] {
            var info = stat()
            if lstat(candidate.path, &info) == 0 {
                guard (info.st_mode & S_IFMT) != S_IFLNK, info.st_uid == getuid() else { throw StoreError.unsafeLocation }
            }
        }
        let flags = SQLITE_OPEN_READWRITE | (create ? SQLITE_OPEN_CREATE : 0) | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK else { throw StoreError.unavailable }
        chmod(url.path, 0o600)
        sqlite3_busy_timeout(db, 150)
        if create {
            try execute("PRAGMA journal_mode=PERSIST")
            try execute("PRAGMA secure_delete=ON")
            try execute("CREATE TABLE IF NOT EXISTS events (seq INTEGER PRIMARY KEY AUTOINCREMENT, identity TEXT UNIQUE NOT NULL, time REAL NOT NULL, source TEXT NOT NULL, payload TEXT NOT NULL)")
            try execute("CREATE INDEX IF NOT EXISTS event_time ON events(time)")
            try execute("CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL, time REAL NOT NULL)")
            try execute("CREATE TABLE IF NOT EXISTS outcomes (id TEXT PRIMARY KEY, time REAL NOT NULL, kind TEXT NOT NULL)")
        }
    }
    deinit { sqlite3_close(db) }
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private func prepared(_ sql: String, _ args: [String]) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw StoreError.unavailable }
        for (index, arg) in args.enumerated() { sqlite3_bind_text(stmt, Int32(index + 1), arg, -1, transient) }
        return stmt
    }
    private func execute(_ sql: String, _ args: [String] = []) throws {
        let statement = try prepared(sql, args); defer { sqlite3_finalize(statement) }
        let status = sqlite3_step(statement)
        guard status == SQLITE_DONE || status == SQLITE_ROW else { throw StoreError.unavailable }
    }
    private func rows(_ sql: String, _ args: [String] = []) throws -> [[String]] {
        let statement = try prepared(sql, args); defer { sqlite3_finalize(statement) }
        var result: [[String]] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return result }
            guard status == SQLITE_ROW else { throw StoreError.unavailable }
            result.append((0..<sqlite3_column_count(statement)).map { column in
                sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
            })
        }
    }
    public func value(_ key: String) throws -> String? {
        try rows("SELECT value FROM metadata WHERE key=?", [key]).first?.first
    }
    public func setValue(_ key: String, _ value: String, now: Date = Date()) throws {
        try execute("INSERT INTO metadata(key,value,time) VALUES(?,?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value,time=excluded.time",
                    [key, value, String(now.timeIntervalSince1970)])
    }
    public func preferences() throws -> Preferences {
        guard let text = try value("preferences") else { return Preferences() }
        guard let result = try? JSONDecoder().decode(Preferences.self, from: Data(text.utf8)) else { throw StoreError.invalidData }
        return result
    }
    public func savePreferences(_ prefs: Preferences) throws {
        try setValue("preferences", String(decoding: JSONEncoder().encode(prefs), as: UTF8.self))
    }
    public func latestSequence() throws -> Int64 {
        Int64(try rows("SELECT COALESCE(MAX(seq),0) FROM events").first?.first ?? "0") ?? 0
    }
    @discardableResult public func insert(_ event: ActivityEvent, now: Date = Date(), enforcePreferences: Bool = true) throws -> Bool {
        guard event.valid, event.source != .demo,
              event.timestamp >= now.addingTimeInterval(-7 * 86400), event.timestamp <= now.addingTimeInterval(5) else { return false }
        if enforcePreferences {
            let prefs = try preferences()
            guard prefs.accepts(event.source), event.kind != .usageReported || prefs.tokensEnabled else { return false }
            if event.kind == .usageReported, let since = prefs.tokensSince, event.timestamp < since { return false }
        }
        let payload = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
        try execute("INSERT OR IGNORE INTO events(identity,time,source,payload) VALUES(?,?,?,?)",
                    [event.key, String(event.timestamp.timeIntervalSince1970), event.source.rawValue, payload])
        return sqlite3_changes(db) > 0
    }
    public func events(after sequence: Int64, limit: Int = 2000) throws -> [StoredEvent] {
        try rows("SELECT seq,payload FROM events WHERE seq>? ORDER BY seq LIMIT ?", [String(sequence), String(limit)]).compactMap { row in
            guard let seq = Int64(row[0]), let event = try? JSONDecoder().decode(ActivityEvent.self, from: Data(row[1].utf8)) else { return nil }
            return StoredEvent(sequence: seq, event: event)
        }
    }
    public func summary(now: Date = Date(), calendar: Calendar = .current) throws -> DailySummary {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        var summary = DailySummary()
        for row in try rows("SELECT payload FROM events WHERE time>=? AND time<?", [String(start.timeIntervalSince1970), String(end.timeIntervalSince1970)]) {
            guard let event = try? JSONDecoder().decode(ActivityEvent.self, from: Data(row[0].utf8)) else { continue }
            if event.kind == .promptSubmitted {
                if event.source == .claude { summary.claudePrompts += 1 }
                if event.source == .codex { summary.codexPrompts += 1 }
            }
            if let usage = event.usage { summary.usage = summary.usage + usage }
        }
        for row in try rows("SELECT kind,COUNT(*) FROM outcomes WHERE time>=? AND time<? GROUP BY kind", [String(start.timeIntervalSince1970), String(end.timeIntervalSince1970)]) {
            if row[0] == "completed" { summary.completed = Int(row[1]) ?? 0 }
            if row[0] == "skipped" { summary.skipped = Int(row[1]) ?? 0 }
        }
        return summary
    }
    public func record(_ outcome: BreakOutcome, now: Date = Date()) throws {
        try execute("INSERT INTO outcomes VALUES(?,?,?)", [UUID().uuidString, String(now.timeIntervalSince1970), outcome == .completed ? "completed" : "skipped"])
    }
    public func lastEvent(_ source: Integration) throws -> Date? {
        guard let raw = try rows("SELECT MAX(time) FROM events WHERE source=?", [source.rawValue]).first?.first,
              let stamp = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: stamp)
    }
    /// Logical retention within this app's ledger. No filesystem removals or database drops.
    public func compact(now: Date = Date()) throws {
        let cutoff = String(now.addingTimeInterval(-7 * 86400).timeIntervalSince1970)
        try execute("DELETE FROM events WHERE time<?", [cutoff])
        try execute("DELETE FROM outcomes WHERE time<?", [cutoff])
        try execute("DELETE FROM metadata WHERE key!='preferences' AND time<?", [cutoff])
    }
    /// Atomically converts message high-water snapshots to deltas and journals the result.
    @discardableResult public func ingestUsage(_ observation: UsageObservation, now: Date = Date()) throws -> Bool {
        try execute("BEGIN IMMEDIATE")
        do {
            let key = "usage:\(observation.sessionID):\(observation.identity)"
            let old: TokenUsage = try value(key).flatMap { try? JSONDecoder().decode(TokenUsage.self, from: Data($0.utf8)) } ?? TokenUsage()
            let delta = observation.usage.positiveDifference(from: old)
            let maximum = old.maximum(observation.usage)
            try setValue(key, String(decoding: JSONEncoder().encode(maximum), as: UTF8.self), now: now)
            let event = ActivityEvent(source: .claude, sessionID: observation.sessionID,
                                      eventID: privateID(key + ":\(maximum.input):\(maximum.output):\(maximum.cacheRead):\(maximum.cacheWrite)"),
                                      timestamp: observation.timestamp, kind: .usageReported, usage: delta)
            let inserted = delta.total > 0 ? try insert(event, now: now) : false
            try execute("COMMIT"); return inserted
        } catch { try? execute("ROLLBACK"); throw error }
    }
}

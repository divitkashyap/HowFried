import XCTest
@testable import HowFriedCore

final class CoreTests: XCTestCase {
    let date = Date(timeIntervalSince1970: 1_789_000_000)
    func directory() throws -> URL {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".qa/tests/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url // Synthetic artifacts deliberately retained; no destructive tearDown.
    }
    func store(_ root: URL? = nil) throws -> ActivityStore {
        let value = try ActivityStore(directory: root ?? directory())
        var p = Preferences(); p.claudeEnabled = true; p.codexEnabled = true; p.tokensEnabled = true
        try value.savePreferences(p)
        return value
    }
    func prompt(_ id: String, source: Integration = .claude, at: Date? = nil) -> ActivityEvent {
        ActivityEvent(source: source, sessionID: "test-session", eventID: id, timestamp: at ?? date)
    }
    func wire(_ event: String = "UserPromptSubmit", id: String = "test-turn") -> Data {
        Data("""
        {"hook_event_name":"\(event)","session_id":"session", "event_id":"\(id)","turn_id":"\(id)","prompt":"SYNTHETIC_PRIVATE_PROMPT_184", "cwd":"/synthetic/private-project", "tool_input":{"command":"SYNTHETIC_TOOL_SECRET_184"}}
        """.utf8)
    }
    func usageLine(id: String = "message-1", output: Int = 20, at: Date? = nil) -> Data {
        let formatter = ISO8601DateFormatter()
        return Data("""
        {"type":"assistant","sessionId":"session","timestamp":"\(formatter.string(from: at ?? date))","message":{"id":"\(id)","content":[{"text":"SYNTHETIC_PRIVATE_REPLY"}],"usage":{"input_tokens":100,"output_tokens":\(output),"cache_read_input_tokens":40,"cache_creation_input_tokens":10}}}
        """.utf8)
    }
    func testBothAdaptersStripContentAndRejectTools() throws {
        for source in [Integration.claude, .codex] {
            let event = try XCTUnwrap(PromptAdapter.parse(wire(), source: source, receivedAt: date))
            XCTAssertEqual(event.source, source); XCTAssertEqual(event.kind, .promptSubmitted)
            let encoded = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
            for sensitive in ["SYNTHETIC_PRIVATE", "SYNTHETIC_TOOL", "/synthetic/private", "prompt\""] { XCTAssertFalse(encoded.contains(sensitive)) }
            XCTAssertNil(PromptAdapter.parse(wire("PreToolUse"), source: source))
            XCTAssertNil(PromptAdapter.parse(Data("{bad".utf8), source: source))
            XCTAssertNil(PromptAdapter.parse(Data(wire().dropLast()), source: source))
        }
    }
    func testRapidIdenticalClaudePromptsWithoutTurnIDRemainDistinct() throws {
        let data = Data("{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"s\",\"prompt\":\"same\"}".utf8)
        let a = try XCTUnwrap(PromptAdapter.parse(data, source: .claude, invocationID: "invocation-a"))
        let b = try XCTUnwrap(PromptAdapter.parse(data, source: .claude, invocationID: "invocation-b"))
        XCTAssertNotEqual(a.eventID, b.eventID)
    }
    func testCodexSteeringWithinSameTurnRemainsDistinct() throws {
        let data = Data("{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"s\",\"turn_id\":\"same-turn\",\"prompt\":\"same\"}".utf8)
        let a = try XCTUnwrap(PromptAdapter.parse(data, source: .codex, invocationID: "first-submit"))
        let b = try XCTUnwrap(PromptAdapter.parse(data, source: .codex, invocationID: "second-submit"))
        XCTAssertNotEqual(a.eventID, b.eventID)
    }
    func testLedgerReplayAndProviderAttributionSurviveRestart() throws {
        let root = try directory()
        do {
            let s = try store(root)
            for source in [Integration.claude, .codex] {
                let a = try XCTUnwrap(PromptAdapter.parse(wire(id: "a"), source: source, receivedAt: date))
                XCTAssertTrue(try s.insert(a, now: date)); XCTAssertFalse(try s.insert(a, now: date))
            }
        }
        let reopened = try ActivityStore(directory: root)
        let repeatEvent = try XCTUnwrap(PromptAdapter.parse(wire(id: "a"), source: .claude, receivedAt: date))
        XCTAssertFalse(try reopened.insert(repeatEvent, now: date))
        XCTAssertTrue(try reopened.insert(prompt("b"), now: date))
        let totals = try reopened.summary(now: date)
        XCTAssertEqual(totals.claudePrompts, 2); XCTAssertEqual(totals.codexPrompts, 1)
    }
    func testDisabledPausedAndDemoAreNotCounted() throws {
        let s = try ActivityStore(directory: directory())
        XCTAssertFalse(try s.insert(prompt("a"), now: date))
        var p = Preferences(); p.claudeEnabled = true; p.paused = true; try s.savePreferences(p)
        XCTAssertFalse(try s.insert(prompt("b"), now: date))
        p.paused = false; p.suspended = true; try s.savePreferences(p)
        XCTAssertFalse(try s.insert(prompt("c"), now: date))
        p.suspended = false; try s.savePreferences(p)
        XCTAssertFalse(try s.insert(prompt("d", source: .demo), now: date))
        XCTAssertTrue(try s.insert(prompt("e"), now: date))
    }
    func testRetentionAndLocalDayRollover() throws {
        let s = try store()
        let old = date.addingTimeInterval(-8 * 86400)
        XCTAssertTrue(try s.insert(prompt("old", at: old), now: old))
        XCTAssertFalse(try s.insert(prompt("old-replay", at: old), now: date))
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let midnight = cal.startOfDay(for: date)
        XCTAssertTrue(try s.insert(prompt("yesterday", at: midnight.addingTimeInterval(-1)), now: date))
        XCTAssertTrue(try s.insert(prompt("today", at: midnight), now: date))
        XCTAssertEqual(try s.summary(now: date, calendar: cal).totalPrompts, 1)
        try s.compact(now: date)
        XCTAssertEqual(try s.events(after: 0).count, 2)
    }
    func testConcurrentWritersDoNotLoseEvents() throws {
        let root = try directory(); _ = try store(root)
        let lock = NSLock(); var failures = 0
        DispatchQueue.concurrentPerform(iterations: 12) { index in
            do {
                let connection = try ActivityStore(directory: root, create: false)
                let inserted = try connection.insert(prompt("parallel-\(index)"), now: date)
                if !inserted { lock.lock(); failures += 1; lock.unlock() }
            } catch { lock.lock(); failures += 1; lock.unlock() }
        }
        XCTAssertEqual(failures, 0)
        XCTAssertEqual(try ActivityStore(directory: root).summary(now: date).totalPrompts, 12)
    }
    func testPromptThresholdIsLatchedAndCountdownStartsAfterEntrance() {
        var settings = BreakSettings(); settings.promptLimit = 5
        var e = BreakEngine(settings: settings)
        for i in 0..<5 { e.consume(prompt("\(i)"), now: 100) }
        XCTAssertEqual(e.phase, .warning); XCTAssertEqual(e.deadline, 130)
        e.consume(prompt("extra"), now: 115); XCTAssertEqual(e.deadline, 130)
        e.tick(now: 130); XCTAssertEqual(e.phase, .entrance); XCTAssertNil(e.deadline)
        e.tick(now: 140); XCTAssertEqual(e.phase, .entrance)
        e.sceneReady(now: 141); XCTAssertEqual(e.deadline, 441)
        XCTAssertNil(e.tick(now: 440)); XCTAssertEqual(e.tick(now: 441), .completed)
        XCTAssertEqual(e.phase, .waiting); XCTAssertEqual(e.prompts, 0)
    }
    func testTimerSnoozePauseResetAndSkip() {
        var settings = BreakSettings(); settings.mode = .timer; settings.minutes = 15
        var e = BreakEngine(settings: settings); e.consume(prompt("1"), now: 10)
        e.tick(now: 879); XCTAssertEqual(e.phase, .tracking)
        e.tick(now: 880); XCTAssertEqual(e.phase, .warning); XCTAssertEqual(e.deadline, 910)
        e.snooze(now: 890); XCTAssertEqual(e.phase, .snoozed); XCTAssertEqual(e.deadline, 1490)
        e.consume(prompt("2"), now: 1000); XCTAssertEqual(e.deadline, 1490)
        e.tick(now: 1490); XCTAssertEqual(e.phase, .warning); XCTAssertEqual(e.deadline, 1520)
        XCTAssertEqual(e.skip(), .skipped); XCTAssertEqual(e.phase, .waiting)
        e.reset(paused: true); e.consume(prompt("3"), now: 2000); XCTAssertEqual(e.phase, .paused)
        e.reset(); e.tick(now: 99999); XCTAssertEqual(e.phase, .waiting)
    }
    func testTokenThresholdAndUsageWithoutPrompt() {
        var settings = BreakSettings(); settings.mode = .tokens; settings.tokenLimit = 25_000
        var e = BreakEngine(settings: settings)
        let usage = ActivityEvent(source: .claude, sessionID: "s", eventID: "u", timestamp: date, kind: .usageReported, usage: TokenUsage(input: 25_000))
        e.consume(usage, now: 1); XCTAssertEqual(e.phase, .waiting)
        e.consume(prompt("start"), now: 2); e.consume(usage, now: 3)
        XCTAssertEqual(e.phase, .warning); XCTAssertEqual(e.tokens, 25_000)
    }
    func testUsageSnapshotsConvertToDeltasAndReplayIsIgnored() throws {
        let s = try store()
        let first = try XCTUnwrap(ClaudeUsageAdapter.parse(usageLine()))
        XCTAssertEqual(first.usage.total, 170)
        XCTAssertTrue(try s.ingestUsage(first, now: date)); XCTAssertFalse(try s.ingestUsage(first, now: date))
        let next = try XCTUnwrap(ClaudeUsageAdapter.parse(usageLine(output: 35)))
        XCTAssertTrue(try s.ingestUsage(next, now: date))
        XCTAssertFalse(try s.ingestUsage(first, now: date))
        XCTAssertEqual(try s.summary(now: date).usage.total, 185)
        XCTAssertEqual(try s.events(after: 0).last?.event.usage?.output, 15)
        XCTAssertNil(ClaudeUsageAdapter.parse(usageLine(output: -1)))
    }
    func testScannerBaselinePartialRecordAndCheckpointRestart() throws {
        let root = try directory(), s = try store(root.appendingPathComponent("store"))
        let logs = root.appendingPathComponent("fixtures")
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let file = logs.appendingPathComponent("session.jsonl")
        try (usageLine(id: "historical") + Data([10])).write(to: file)
        let scanner = UsageScanner(store: s, root: logs); try scanner.baseline(now: date)
        let line = usageLine(id: "new")
        let handle = try FileHandle(forWritingTo: file); try handle.seekToEnd()
        try handle.write(contentsOf: line.prefix(line.count / 2))
        try scanner.scan(since: date, now: date); XCTAssertEqual(try s.summary(now: date).usage.total, 0)
        try handle.write(contentsOf: line.suffix(line.count - line.count / 2) + Data([10])); try handle.close()
        try scanner.scan(since: date, now: date)
        XCTAssertEqual(try s.summary(now: date).usage.total, 170)
        try UsageScanner(store: s, root: logs).scan(since: date, now: date)
        XCTAssertEqual(try s.summary(now: date).usage.total, 170)
    }
    func testHookExecutableIsQuietAndPersistsOnlyMetadata() throws {
        let root = try directory(); _ = try store(root)
        let binary = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/debug/howfried-hook")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binary.path))
        let process = Process(); process.executableURL = binary; process.arguments = ["codex"]
        process.environment = ["HOWFRIED_DATA_DIR": root.path]
        let input = Pipe(), output = Pipe(); process.standardInput = input; process.standardOutput = output
        try process.run(); input.fileHandleForWriting.write(wire()); try input.fileHandleForWriting.close()
        process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(output.fileHandleForReading.readDataToEndOfFile().count, 0)
        let records = try ActivityStore(directory: root).events(after: 0)
        XCTAssertEqual(records.count, 1)
        let bytes = try Data(contentsOf: root.appendingPathComponent("activity.sqlite"))
        XCTAssertNil(bytes.range(of: Data("SYNTHETIC_PRIVATE".utf8)))
    }
    func testResumeBaselineRejectsDelayedUsageFromPause() throws {
        let s = try store()
        var p = try s.preferences(); p.tokensSince = date.addingTimeInterval(10); try s.savePreferences(p)
        let pausedUsage = try XCTUnwrap(ClaudeUsageAdapter.parse(usageLine()))
        XCTAssertFalse(try s.ingestUsage(pausedUsage, now: date.addingTimeInterval(20)))
        let resumedUsage = try XCTUnwrap(ClaudeUsageAdapter.parse(usageLine(id: "after-resume", at: date.addingTimeInterval(12))))
        XCTAssertTrue(try s.ingestUsage(resumedUsage, now: date.addingTimeInterval(20)))
        XCTAssertEqual(try s.summary(now: date).usage.total, 170)
    }
    func testOversizedRecordDoesNotStarveFollowingUsage() throws {
        let root = try directory(), s = try store(root.appendingPathComponent("db"))
        let logs = root.appendingPathComponent("logs"); try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let file = logs.appendingPathComponent("large.jsonl")
        try (Data(repeating: 120, count: 4_194_305) + Data([10]) + usageLine(id: "after-large") + Data([10])).write(to: file)
        let scanner = UsageScanner(store: s, root: logs)
        try scanner.scan(since: date, now: date); try scanner.scan(since: date, now: date)
        XCTAssertEqual(try s.summary(now: date).usage.total, 170)
    }
    func testFreshEngineIgnoresPriorCycleAndClampsSettings() {
        var s = BreakSettings(); s.promptLimit = 1; s.minutes = 999; s.tokenLimit = -1
        var e = BreakEngine(settings: s)
        XCTAssertEqual(e.settings.promptLimit, 1); XCTAssertEqual(e.settings.minutes, 180); XCTAssertEqual(e.settings.tokenLimit, 25_000)
        e.consume(prompt("first"), now: 0); e.reset(); e.tick(now: 100_000)
        XCTAssertEqual(e.phase, .waiting); XCTAssertEqual(e.prompts, 0); XCTAssertNil(e.cycleStart)
    }
    func testFootprintsStayPlantedAlternateAndFade() throws {
        let first = try XCTUnwrap(PawTrail.samples(elapsed: 0.2, width: 400).first)
        let later = try XCTUnwrap(PawTrail.samples(elapsed: 0.55, width: 400).first { $0.step == first.step })
        XCTAssertEqual(first.x, later.x); XCTAssertLessThan(later.opacity, first.opacity)
        let next = try XCTUnwrap(PawTrail.samples(elapsed: 0.65, width: 400).first { $0.step == 1 })
        XCTAssertGreaterThan(next.x, first.x); XCTAssertNotEqual(first.lane, next.lane)
        XCTAssertFalse(PawTrail.samples(elapsed: 1.0, width: 400).contains { $0.step == 0 })
        XCTAssertTrue(PawTrail.samples(elapsed: 8.0, width: 400).contains { !$0.facingRight })
    }
    func testNotchHasAttachedTopAndConservativePhysicalHeight() {
        XCTAssertEqual(NotchGeometry.height(safeTop: 32, scale: 2), 32.5)
        XCTAssertEqual(NotchGeometry.height(safeTop: 0, scale: 2), 32.5)
        let shape = NotchGeometry.outline(width: 580, height: 32.5)
        XCTAssertEqual(shape.boundingBox, CGRect(x: 0, y: 0, width: 580, height: 32.5))
        XCTAssertTrue(shape.contains(CGPoint(x: 2, y: 0.01)))
        XCTAssertTrue(shape.contains(CGPoint(x: 578, y: 0.01)))
        XCTAssertFalse(shape.contains(CGPoint(x: 2, y: 16)))
        XCTAssertTrue(shape.contains(CGPoint(x: 290, y: 32)))
    }
    func testPawsClearNotchAndCrossInOneSecond() throws {
        var firstSeen: [Int: (Double, Footprint)] = [:]
        for tick in 1...1200 {
            let t = Double(tick) / 100
            for foot in PawTrail.samples(elapsed: t, width: 585, deadZone: 185) {
                XCTAssertTrue((72...182).contains(foot.x) || (403...513).contains(foot.x))
                XCTAssertTrue((24...32).contains(abs(abs(foot.rotationDegrees) - 90)))
                if firstSeen[foot.step] == nil { firstSeen[foot.step] = (t, foot) }
            }
        }
        let steps = firstSeen.keys.sorted()
        var crossings = 0
        for pair in zip(steps, steps.dropFirst()) {
            let a = firstSeen[pair.0]!, b = firstSeen[pair.1]!
            if (a.1.x < 292.5) != (b.1.x < 292.5) {
                XCTAssertEqual(b.0 - a.0, 1, accuracy: 0.011); crossings += 1
            }
        }
        XCTAssertGreaterThanOrEqual(crossings, 2)
    }
    func testDaySceneUsesLocalClockAndSunArc() {
        XCTAssertTrue(DayScene(hour: 22).isNight)
        XCTAssertTrue(DayScene(hour: 6).isNight)
        XCTAssertFalse(DayScene(hour: 7).isNight)
        XCTAssertTrue(DayScene(hour: 19).isNight)
        XCTAssertLessThan(DayScene(hour: 8).sunX, DayScene(hour: 17).sunX)
        XCTAssertLessThan(DayScene(hour: 13).sunY, DayScene(hour: 8).sunY)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3600)!
        XCTAssertEqual(DayScene.local(date: Date(timeIntervalSince1970: 0), calendar: calendar).hour, 1)
    }
    func testCalmScoreProducesPlayableBoundedPCM() {
        let data = CalmScore.wave()
        XCTAssertEqual(data.count, 44 + 22050 * 16 * 2)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .utf8), "RIFF")
        XCTAssertEqual(String(data: data[8..<12], encoding: .utf8), "WAVE")
        let bytes = Array(data.dropFirst(44))
        let peak = stride(from: 0, to: bytes.count, by: 2).map {
            abs(Int(Int16(bitPattern: UInt16(bytes[$0]) | UInt16(bytes[$0+1]) << 8)))
        }.max()!
        XCTAssertGreaterThan(peak, 1000); XCTAssertLessThan(peak, 31000)
    }

    func testSinglePromptTriggersWarning() {
        var settings = BreakSettings(); settings.promptLimit = 1
        var engine = BreakEngine(settings: settings)
        engine.consume(prompt("single-submission"), now: 0)
        XCTAssertEqual(engine.phase, .warning)
        XCTAssertEqual(engine.prompts, 1)
        settings.promptLimit = 0
        XCTAssertEqual(BreakEngine(settings: settings).settings.promptLimit, 1)
    }

}

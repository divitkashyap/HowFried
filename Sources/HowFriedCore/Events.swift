import Foundation
import CryptoKit

public enum Integration: String, Codable, CaseIterable {
    case claude, codex, demo
    public var title: String { self == .claude ? "Claude Code" : self == .codex ? "Codex" : "Demo" }
}

public enum EventKind: String, Codable { case promptSubmitted, usageReported }
public enum Coverage: String, Codable { case supported, stale, unavailable, demo }

public struct TokenUsage: Codable, Equatable {
    public var input: Int64, output: Int64, cacheRead: Int64, cacheWrite: Int64
    public init(input: Int64 = 0, output: Int64 = 0, cacheRead: Int64 = 0, cacheWrite: Int64 = 0) {
        self.input = input; self.output = output; self.cacheRead = cacheRead; self.cacheWrite = cacheWrite
    }
    public var total: Int64 { input + output + cacheRead + cacheWrite }
    public var valid: Bool { [input, output, cacheRead, cacheWrite].allSatisfy { (0...1_000_000_000).contains($0) } }
    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(input: lhs.input + rhs.input, output: lhs.output + rhs.output,
             cacheRead: lhs.cacheRead + rhs.cacheRead, cacheWrite: lhs.cacheWrite + rhs.cacheWrite)
    }
    public func positiveDifference(from old: Self) -> Self {
        Self(input: max(0, input - old.input), output: max(0, output - old.output),
             cacheRead: max(0, cacheRead - old.cacheRead), cacheWrite: max(0, cacheWrite - old.cacheWrite))
    }
    public func maximum(_ other: Self) -> Self {
        Self(input: max(input, other.input), output: max(output, other.output),
             cacheRead: max(cacheRead, other.cacheRead), cacheWrite: max(cacheWrite, other.cacheWrite))
    }
}

public struct ActivityEvent: Codable, Equatable {
    public var schemaVersion = 1
    public var source: Integration
    public var sessionID: String
    public var eventID: String
    public var timestamp: Date
    public var kind: EventKind
    public var usage: TokenUsage?
    public var usageSemantics: String? = "delta"
    public var coverage: Coverage
    public init(source: Integration, sessionID: String, eventID: String, timestamp: Date,
                kind: EventKind = .promptSubmitted, usage: TokenUsage? = nil) {
        self.source = source; self.sessionID = sessionID; self.eventID = eventID
        self.timestamp = timestamp; self.kind = kind; self.usage = usage
        self.coverage = source == .demo ? .demo : .supported
    }
    public var key: String { "\(source.rawValue):\(sessionID):\(eventID)" }
    public var valid: Bool {
        schemaVersion == 1 && (usageSemantics == nil || usageSemantics == "delta") && !sessionID.isEmpty && !eventID.isEmpty && sessionID.count <= 128 && eventID.count <= 128
        && timestamp.timeIntervalSince1970.isFinite && (usage?.valid ?? true)
        && (kind != .usageReported || usage != nil)
    }
}

public func privateID(_ text: String) -> String {
    SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
}

/// Only the documented submission event counts. Never serialize the incoming dictionary.
public enum PromptAdapter {
    public static func parse(_ data: Data, source: Integration, receivedAt: Date = Date(),
                             invocationID: String = UUID().uuidString) -> ActivityEvent? {
        guard source != .demo, data.count <= 1_048_576,
              let wire = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              wire["hook_event_name"] as? String == "UserPromptSubmit",
              let session = wire["session_id"] as? String, !session.isEmpty, session.count <= 4096 else { return nil }
        // A turn ID is not a submission ID: steering can add input to an existing turn.
        // Without a source event ID, preserve each invocation, even for identical prompts.
        let identity = (wire["event_id"] as? String) ?? invocationID
        guard !identity.isEmpty, identity.count <= 4096 else { return nil }
        return ActivityEvent(source: source, sessionID: privateID(session), eventID: privateID(identity), timestamp: receivedAt)
    }
}

public struct UsageObservation {
    public var sessionID: String, identity: String
    public var timestamp: Date
    public var usage: TokenUsage
}

public enum ClaudeUsageAdapter {
    /// Repeated observations of a message are cumulative snapshots, not extra usage.
    public static func parse(_ data: Data) -> UsageObservation? {
        guard data.count <= 4_194_304,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["type"] as? String == "assistant",
              let message = object["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any],
              let id = message["id"] as? String, !id.isEmpty,
              let session = object["sessionId"] as? String, !session.isEmpty,
              let stamp = object["timestamp"] as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: stamp) ?? ISO8601DateFormatter().date(from: stamp)
        guard let date else { return nil }
        func number(_ key: String) -> Int64? {
            guard let value = usage[key] else { return 0 }
            guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
                  n.doubleValue >= 0, n.doubleValue <= 1_000_000_000,
                  n.doubleValue.rounded() == n.doubleValue else { return nil }
            return n.int64Value
        }
        guard let input = number("input_tokens"), let output = number("output_tokens"),
              let read = number("cache_read_input_tokens"), let write = number("cache_creation_input_tokens") else { return nil }
        return UsageObservation(sessionID: privateID(session), identity: privateID(id), timestamp: date,
                                usage: TokenUsage(input: input, output: output, cacheRead: read, cacheWrite: write))
    }
}

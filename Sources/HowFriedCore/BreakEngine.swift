import Foundation

public enum TriggerMode: String, Codable, CaseIterable {
    case prompts, timer, tokens
    public var title: String { self == .prompts ? "Prompts" : self == .timer ? "Session time" : "Claude tokens" }
}

public struct BreakSettings: Codable, Equatable {
    public var mode: TriggerMode = .prompts
    public var promptLimit = 20
    public var minutes = 60
    public var tokenLimit: Int64 = 100_000
    public init() {}
    public mutating func clamp() {
        promptLimit = min(200, max(5, promptLimit)); minutes = min(180, max(15, minutes))
        tokenLimit = min(2_000_000, max(25_000, tokenLimit))
    }
}

public enum BreakPhase: String { case waiting, tracking, warning, entrance, resting, snoozed, paused }
public enum BreakOutcome { case completed, skipped }

/// All time inputs are monotonic seconds supplied by the owner. No UI or provider logic.
public struct BreakEngine {
    public private(set) var phase: BreakPhase = .waiting
    public private(set) var settings = BreakSettings()
    public private(set) var prompts = 0
    public private(set) var tokens: Int64 = 0
    public private(set) var deadline: TimeInterval?
    public private(set) var cycleStart: TimeInterval?
    public let warningDuration: TimeInterval = 30
    public let breakDuration: TimeInterval = 300
    public let snoozeDuration: TimeInterval = 600
    public init(settings: BreakSettings = BreakSettings()) { self.settings = settings; self.settings.clamp() }

    public mutating func configure(_ settings: BreakSettings) {
        self.settings = settings; self.settings.clamp(); reset(paused: phase == .paused)
    }
    public mutating func reset(paused: Bool = false) {
        phase = paused ? .paused : .waiting; prompts = 0; tokens = 0; deadline = nil; cycleStart = nil
    }
    public mutating func consume(_ event: ActivityEvent, now: TimeInterval) {
        guard phase != .paused, event.source != .demo else { return }
        if phase == .waiting {
            guard event.kind == .promptSubmitted else { return }
            phase = .tracking; cycleStart = now
        }
        guard phase == .tracking else { return }
        if event.kind == .promptSubmitted { prompts += 1 }
        if event.source == .claude, let usage = event.usage { tokens += usage.total }
        if (settings.mode == .prompts && prompts >= settings.promptLimit)
            || (settings.mode == .tokens && tokens >= settings.tokenLimit) {
            phase = .warning; deadline = now + warningDuration
        }
        _ = tick(now: now)
    }
    @discardableResult public mutating func tick(now: TimeInterval) -> BreakOutcome? {
        if phase == .tracking, settings.mode == .timer, let start = cycleStart {
            let end = start + Double(settings.minutes * 60)
            if now >= end - warningDuration { phase = .warning; deadline = end }
        }
        if phase == .snoozed, let deadline, now >= deadline {
            phase = .warning; self.deadline = now + warningDuration
        }
        if phase == .warning, let deadline, now >= deadline { phase = .entrance; self.deadline = nil }
        if phase == .resting, let deadline, now >= deadline { reset(); return .completed }
        return nil
    }
    public mutating func sceneReady(now: TimeInterval) {
        guard phase == .entrance else { return }; phase = .resting; deadline = now + breakDuration
    }
    public mutating func snooze(now: TimeInterval) {
        guard [.warning, .entrance, .resting].contains(phase) else { return }
        phase = .snoozed; deadline = now + snoozeDuration
    }
    @discardableResult public mutating func skip() -> BreakOutcome? {
        guard [.warning, .entrance, .resting, .snoozed].contains(phase) else { return nil }
        reset(); return .skipped
    }
    public func remaining(now: TimeInterval) -> Int { max(0, Int(ceil((deadline ?? now) - now))) }
    public var progress: Double {
        switch settings.mode {
        case .prompts: return min(1, Double(prompts) / Double(settings.promptLimit))
        case .tokens: return min(1, Double(tokens) / Double(settings.tokenLimit))
        case .timer: return 0 // Owner computes from monotonic time.
        }
    }
    public mutating func preview(now: TimeInterval) {
        reset(); phase = .warning; deadline = now + warningDuration
    }
}

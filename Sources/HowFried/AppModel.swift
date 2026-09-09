import AppKit
import SwiftUI
import HowFriedCore

@MainActor final class AppModel: ObservableObject {
    @Published var preferences = Preferences()
    @Published var engine = BreakEngine()
    @Published var previewEngine: BreakEngine?
    @Published var summary = DailySummary()
    @Published var lastEvents: [Integration: Date] = [:]
    @Published var error: String?
    @Published var tokenStatus: String?
    @Published var shortcutError: String?
    @Published var now = ProcessInfo.processInfo.systemUptime
    @Published var configuringTokens = false
    var showWindow: (() -> Void)?
    var presentationChanged: (() -> Void)?
    var shortcutChanged: (() -> Void)?
    var appearanceChanged: (() -> Void)?
    var scene: DayScene {
        if qa, let raw = ProcessInfo.processInfo.environment["HOWFRIED_QA_HOUR"], let hour = Double(raw) { return DayScene(hour: hour) }
        return DayScene.local()
    }
    func setAppearance(_ value: String) {
        guard ["system", "light", "dark"].contains(value) else { return }
        preferences.appearance = value; save(); appearanceChanged?()
    }
    private var store: ActivityStore?
    private var timer: Timer?
    private var sequence: Int64 = 0
    private var liveSince = Date()
    private var lastPoll: TimeInterval = -100
    private var lastUsage: TimeInterval = -100
    private var lastCompact: TimeInterval = -3600
    private var scanning = false
    private var observations: [NSObjectProtocol] = []
    private let usageQueue = DispatchQueue(label: "HowFried.usage", qos: .utility)
    let qa = ProcessInfo.processInfo.environment["HOWFRIED_QA"] == "1"
    var forceReducedMotion: Bool { qa && ProcessInfo.processInfo.environment["HOWFRIED_QA_REDUCE_MOTION"] == "1" }
    var isPreview: Bool { previewEngine != nil }
    var displayed: BreakEngine { previewEngine ?? engine }
    var displayNow: TimeInterval { isPreview ? demoTime : now }
    private var demoStart: TimeInterval = 0
    private var demoTime: TimeInterval { demoStart + (now - demoStart) * (qa ? 6 : 1) }
    var shortcutLabel: String {
        (preferences.shortcutControl ? "⌃" : "") + (preferences.shortcutOption ? "⌥" : "")
        + (preferences.shortcutCommand ? "⌘" : "") + preferences.shortcutKey
    }
    var cycleLabel: String {
        switch displayed.phase {
        case .waiting: return "A little less fried."
        case .tracking: return "Room to roam."
        case .warning: return "Someone needs a walk."
        case .entrance: return "Follow that tail."
        case .resting: return "Nothing to prompt here."
        case .snoozed: return "We'll come back in a bit."
        case .paused: return "Off the clock."
        }
    }
    var progress: Double {
        if engine.settings.mode == .timer, let start = engine.cycleStart {
            return min(1, max(0, (now - start) / Double(engine.settings.minutes * 60)))
        }
        return engine.progress
    }
    var progressLabel: String {
        switch engine.settings.mode {
        case .prompts: return "\(engine.prompts) / \(engine.settings.promptLimit) prompts"
        case .timer: return "\(Int(max(0, now - (engine.cycleStart ?? now))) / 60) / \(engine.settings.minutes) minutes"
        case .tokens: return "\(engine.tokens.formatted()) / \(engine.settings.tokenLimit.formatted()) tokens"
        }
    }
    init() {
        do {
            let store = try ActivityStore(); self.store = store
            preferences = try store.preferences()
            preferences.suspended = false
            if !preferences.tokensEnabled && preferences.rule.mode == .tokens { preferences.rule.mode = .prompts }
            try store.savePreferences(preferences)
            sequence = try store.latestSequence()
            engine = BreakEngine(settings: preferences.rule); engine.reset(paused: preferences.paused)
            summary = try store.summary()
            refreshStatuses()
        } catch { self.error = "Local storage is unavailable. Tracking is stopped; you can still preview the dog." }
        timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observations.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.suspend(true) }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observations.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.suspend(false) }
            })
        }
        // Screen lock also occurs without display sleep. These notifications carry no content.
        for (name, suspended) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            observations.append(DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.suspend(suspended) }
            })
        }
    }
    func save() {
        do { try store?.savePreferences(preferences) }
        catch { self.error = "Could not save settings. Tracking changes may not reach the hooks." }
    }
    func finishOnboarding() { preferences.onboarded = true; save() }
    func applyRule(_ rule: BreakSettings) {
        preferences.rule = rule
        if rule.mode == .tokens && (!preferences.tokensEnabled || !preferences.claudeEnabled) { preferences.rule.mode = .prompts }
        preferences.rule.clamp(); save()
        engine.configure(preferences.rule); resetLiveBoundary(); previewEngine = nil
        presentationChanged?()
    }
    func enable(_ source: Integration, _ enabled: Bool) {
        if source == .claude, enabled, preferences.tokensEnabled { preferences.tokensSince = Date() }
        if source == .claude { preferences.claudeEnabled = enabled }
        if source == .claude, !enabled, preferences.rule.mode == .tokens {
            preferences.rule.mode = .prompts; engine.configure(preferences.rule)
        }
        if source == .codex { preferences.codexEnabled = enabled }
        save(); engine.reset(paused: preferences.paused); resetLiveBoundary()
    }
    func setPaused(_ paused: Bool) {
        if !paused, preferences.tokensEnabled { preferences.tokensSince = Date() }
        preferences.paused = paused; save(); engine.reset(paused: paused)
        previewEngine = nil; resetLiveBoundary(); presentationChanged?()
    }
    func suspend(_ suspended: Bool) {
        if !suspended, preferences.tokensEnabled { preferences.tokensSince = Date() }
        preferences.suspended = suspended; save()
        engine.reset(paused: preferences.paused); previewEngine = nil
        resetLiveBoundary(); presentationChanged?()
    }
    func resetLiveBoundary() {
        liveSince = Date()
        if let latest = try? store?.latestSequence() { sequence = latest }
    }
    func tick() {
        now = ProcessInfo.processInfo.systemUptime
        if now - lastPoll >= 1 { lastPoll = now; poll() }
        if !preferences.suspended {
            if let outcome = engine.tick(now: now) { record(outcome) }
            if previewEngine?.tick(now: demoTime) != nil { previewEngine = nil; showWindow?() }
        }
        if now - lastUsage >= 10 { lastUsage = now; scanUsage() }
        if now - lastCompact >= 3600 {
            lastCompact = now
            do { try store?.compact() } catch { self.error = "Local retention update failed. No external files were changed." }
        }
        presentationChanged?()
    }
    private func poll() {
        guard let store else { return }
        do {
            for item in try store.events(after: sequence) {
                sequence = item.sequence
                if item.event.timestamp >= liveSince, preferences.accepts(item.event.source) {
                    engine.consume(item.event, now: now)
                }
            }
            summary = try store.summary(); refreshStatuses()
        } catch { self.error = "Could not read local events. Observations may be delayed." }
    }
    private func refreshStatuses() {
        for source in [Integration.claude, .codex] { lastEvents[source] = try? store?.lastEvent(source) }
    }
    func connection(_ source: Integration) -> String {
        let enabled = source == .claude ? preferences.claudeEnabled : preferences.codexEnabled
        guard enabled else { return "Not configured · observation off" }
        if error != nil { return "Error · check local storage" }
        guard let last = lastEvents[source] else { return "Awaiting first event · setup required" }
        if Date().timeIntervalSince(last) > 300 { return "Quiet · last event \(last.formatted(date: .omitted, time: .shortened))" }
        return "Receiving events · \(last.formatted(date: .omitted, time: .shortened))"
    }
    func preview() {
        demoStart = now
        var preview = BreakEngine(); preview.preview(now: now); previewEngine = preview
        presentationChanged?()
    }
    func sceneReady() {
        if isPreview { previewEngine?.sceneReady(now: demoTime) } else { engine.sceneReady(now: now) }
    }
    func snooze() {
        let wasPreview = isPreview
        if wasPreview { previewEngine = nil } else { engine.snooze(now: now) }
        presentationChanged?()
        if wasPreview { showWindow?() }
    }
    func skip() {
        let wasPreview = isPreview
        if wasPreview { previewEngine = nil }
        else if let outcome = engine.skip() { record(outcome) }
        presentationChanged?()
        if wasPreview { showWindow?() }
    }
    private func record(_ outcome: BreakOutcome) {
        do { try store?.record(outcome); summary = try store?.summary() ?? DailySummary() }
        catch { self.error = "Break completed, but the local summary could not be saved." }
    }
    private var usageRoot: URL {
        // QA never reads the owner's transcripts. Production requires a separate explicit toggle.
        if qa { return ActivityStore.defaultDirectory.appendingPathComponent("synthetic-claude") }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
    }
    func enableTokens(_ enabled: Bool) {
        guard !configuringTokens else { return }
        if !enabled {
            preferences.tokensEnabled = false; preferences.tokensSince = nil
            if preferences.rule.mode == .tokens { preferences.rule.mode = .prompts; engine.configure(preferences.rule) }
            save(); tokenStatus = nil; return
        }
        configuringTokens = true
        let directory = ActivityStore.defaultDirectory, root = usageRoot
        let baselineTime = Date()
        usageQueue.async { [weak self] in
            do {
                let store = try ActivityStore(directory: directory, create: false)
                try UsageScanner(store: store, root: root).baseline(now: baselineTime)
                Task { @MainActor in
                    guard let self else { return }; self.configuringTokens = false
                    self.preferences.tokensSince = baselineTime; self.preferences.tokensEnabled = true
                    self.save(); self.tokenStatus = "Claude only · observing new local records"
                }
            } catch {
                Task { @MainActor in self?.configuringTokens = false; self?.tokenStatus = "Unavailable · could not establish a safe baseline" }
            }
        }
    }
    private func scanUsage() {
        guard preferences.tokensEnabled, preferences.claudeEnabled, !preferences.paused, !preferences.suspended,
              let since = preferences.tokensSince, !scanning else { return }
        scanning = true
        let directory = ActivityStore.defaultDirectory, root = usageRoot
        usageQueue.async { [weak self] in
            do {
                let store = try ActivityStore(directory: directory, create: false)
                try UsageScanner(store: store, root: root).scan(since: since)
                Task { @MainActor in self?.scanning = false; self?.tokenStatus = "Claude only · new local records" }
            } catch {
                Task { @MainActor in self?.scanning = false; self?.tokenStatus = "Unavailable · local usage read failed" }
            }
        }
    }
    func updateShortcut() { save(); shortcutChanged?() }
}

import SwiftUI
import HowFriedCore

enum Palette {
    static func adaptive(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light })
    }
    static let paper = adaptive(NSColor(srgbRed: 0.97, green: 0.95, blue: 0.89, alpha: 1), NSColor(srgbRed: 0.085, green: 0.12, blue: 0.11, alpha: 1))
    static let ink = adaptive(NSColor(srgbRed: 0.18, green: 0.24, blue: 0.17, alpha: 1), NSColor(srgbRed: 0.91, green: 0.93, blue: 0.86, alpha: 1))
    static let orange = adaptive(NSColor(srgbRed: 0.75, green: 0.32, blue: 0.17, alpha: 1), NSColor(srgbRed: 0.94, green: 0.62, blue: 0.39, alpha: 1))
    static let face = Color(red: 0.18, green: 0.24, blue: 0.17)
    static let bandana = Color(red: 0.75, green: 0.32, blue: 0.17)
    static let grass = Color(red: 0.43, green: 0.53, blue: 0.28)
}

struct Dashboard: View {
    @ObservedObject var model: AppModel
    @State private var rule = BreakSettings()
    @State private var setup = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Label("HOWFRIED", systemImage: "pawprint.fill").font(.system(size: 12, weight: .heavy, design: .monospaced)).tracking(2)
                    Spacer()
                    Text(model.qa ? "DEMO LAB" : "A SMALL REMINDER").font(.system(size: 9, weight: .semibold, design: .monospaced))
                }
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.cycleLabel).font(.system(size: 34, weight: .semibold, design: .serif)).fixedSize(horizontal: false, vertical: true)
                        Text("Your dog has other plans.").foregroundStyle(Palette.ink.opacity(0.65))
                    }
                    DogView().frame(width: 145, height: 112).rotationEffect(.degrees(-5)).accessibilityHidden(true)
                }
                if !model.preferences.onboarded {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("A walk between prompts.").font(.headline)
                        Text("Connect your local AI tools, pick a limit, and let a small dog remind you to step away. Prompt text is never saved. The overlay won’t stop an agent from working.").font(.callout)
                        Button("Got it. Meet my dog.") { model.finishOnboarding(); model.preview() }.buttonStyle(.borderedProminent)
                    }.card()
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text(model.isPreview ? "PREVIEW · REAL TOTALS UNCHANGED" : "THIS CYCLE").eyebrow(); Spacer(); Text(model.displayed.phase.rawValue.uppercased()).eyebrow() }
                    Text(model.progressLabel).font(.system(size: 23, weight: .medium, design: .rounded))
                    ProgressView(value: model.progress).tint(Palette.orange)
                    if model.displayed.deadline != nil {
                        Text("\(model.displayed.remaining(now: model.displayNow)) seconds remaining").font(.caption).monospacedDigit()
                    }
                    HStack {
                        Button(model.preferences.paused ? "Resume tracking" : "Pause tracking") { model.setPaused(!model.preferences.paused) }
                        Spacer()
                        Button("Preview break") { model.preview() }
                    }.buttonStyle(.bordered)
                    if model.isPreview || [.warning, .resting, .entrance, .snoozed].contains(model.engine.phase) {
                        HStack { Button("Snooze 10 min") { model.snooze() }; Button("Skip this break") { model.skip() } }
                    }
                }.card()
                HStack(spacing: 0) {
                    stat("\(model.summary.totalPrompts)", "PROMPTS TODAY")
                    Spacer()
                    stat("\(model.summary.completed)", "WALKS TAKEN")
                    Spacer()
                    stat("\(model.summary.skipped)", "SKIPPED")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("WHEN TO WANDER").eyebrow()
                    Picker("Break trigger", selection: $rule.mode) {
                        Text("Prompts").tag(TriggerMode.prompts)
                        Text("Session time").tag(TriggerMode.timer)
                        if model.preferences.tokensEnabled && model.preferences.claudeEnabled { Text("Claude tokens").tag(TriggerMode.tokens) }
                    }.pickerStyle(.segmented)
                    if rule.mode == .prompts { Stepper("After \(rule.promptLimit) prompts", value: $rule.promptLimit, in: 5...200, step: 5) }
                    if rule.mode == .timer { Stepper("After \(rule.minutes) minutes", value: $rule.minutes, in: 15...180, step: 15) }
                    if rule.mode == .tokens { Stepper("After \(rule.tokenLimit.formatted()) tokens", value: $rule.tokenLimit, in: 25_000...2_000_000, step: 25_000) }
                    Text(rule.mode == .timer ? "Elapsed time from your next prompt, including gaps. Not an attention measurement." : rule.mode == .tokens ? "Claude only. Includes cached inputs, so long contexts can reach this quickly. Not a spending cap." : "Across connected Claude Code and Codex sessions. Tool calls don’t count.").font(.caption).foregroundStyle(.secondary)
                    Button("Apply & start a fresh cycle") { model.applyRule(rule) }.disabled(rule == model.preferences.rule)
                    Text("30-second warning · 5-minute break · 10-minute snooze").font(.caption2).foregroundStyle(.secondary)
                }.card()
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("CONNECTIONS").eyebrow(); Spacer(); Button("Setup guide") { setup.toggle() }.font(.caption) }
                    provider(.claude, enabled: model.preferences.claudeEnabled, count: model.summary.claudePrompts)
                    Divider()
                    provider(.codex, enabled: model.preferences.codexEnabled, count: model.summary.codexPrompts)
                    if setup {
                        Text("Enabling observation does not install a hook. Use the additive snippets in the bundled setup guide, then send one prompt in each client. Existing hooks must be preserved.").font(.caption)
                        Button("Open setup instructions") {
                            if let url = Bundle.main.url(forResource: "SETUP", withExtension: "md") { NSWorkspace.shared.open(url) }
                        }
                    }
                    Toggle("Read new Claude token records locally", isOn: Binding(get: { model.preferences.tokensEnabled }, set: { model.enableTokens($0) }))
                        .disabled(model.configuringTokens || !model.preferences.claudeEnabled)
                    Text("Opt-in: reads new usage fields in Claude’s local session files. Conversation text is discarded; no history is imported.").font(.caption).foregroundStyle(.secondary)
                    if model.preferences.tokensEnabled {
                        Text("\(model.summary.usage.total.formatted()) observed tokens today · Claude only").font(.callout)
                        Text("Input \(model.summary.usage.input.formatted()) · output \(model.summary.usage.output.formatted())\nCache read \(model.summary.usage.cacheRead.formatted()) · cache write \(model.summary.usage.cacheWrite.formatted())").font(.caption2)
                    } else { Text("Token coverage: unavailable until enabled. Codex tokens are not measured.").font(.caption).foregroundStyle(.secondary) }
                    if let status = model.tokenStatus { Text(status).font(.caption) }
                }.card()
                VStack(alignment: .leading, spacing: 12) {
                    Text("SMALL PREFERENCES").eyebrow()
                    Picker("Appearance", selection: Binding(get: { model.preferences.appearance ?? "system" }, set: { model.setAppearance($0) })) {
                        Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                    }.pickerStyle(.segmented)
                    Toggle("Play a gentle sound when the dog arrives", isOn: Binding(get: { model.preferences.sound }, set: { model.preferences.sound = $0; model.save() }))
                    HStack {
                        Text("Dismiss shortcut"); Spacer()
                        Picker("Key", selection: Binding(get: { model.preferences.shortcutKey }, set: { model.preferences.shortcutKey = $0; model.updateShortcut() })) {
                            ForEach(["B", "G", "J", "K", "P", "T"], id: \.self) { Text($0) }
                        }.frame(width: 75)
                    }
                    HStack {
                        Toggle("⌃ Control", isOn: Binding(get: { model.preferences.shortcutControl }, set: { model.preferences.shortcutControl = $0; model.updateShortcut() }))
                        Toggle("⌥ Option", isOn: Binding(get: { model.preferences.shortcutOption }, set: { model.preferences.shortcutOption = $0; model.updateShortcut() }))
                        Toggle("⌘ Cmd", isOn: Binding(get: { model.preferences.shortcutCommand }, set: { model.preferences.shortcutCommand = $0; model.updateShortcut() }))
                    }.font(.caption)
                    Text(model.shortcutError ?? "\(model.shortcutLabel) skips a break. Escape also works when the overlay has focus.").font(.caption).foregroundStyle(model.shortcutError == nil ? Palette.ink : Palette.orange)
                    Text("Pause excludes new observations and clears the cycle. Data stays on this Mac for up to seven days.").font(.caption).foregroundStyle(.secondary)
                }.card()
                if let error = model.error { Text(error).foregroundStyle(Palette.orange).font(.caption) }
                HStack { Text("Go easy on your human.").font(.system(.callout, design: .serif)).italic(); Spacer(); Button("Quit HowFried") { NSApp.terminate(nil) } }
            }.padding(26)
        }.background(Palette.paper).foregroundStyle(Palette.ink).tint(Palette.orange)
            .frame(width: 440).onAppear { rule = model.preferences.rule }
            .onChange(of: model.preferences.rule) { _, value in rule = value }
    }
    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(value).font(.system(size: 29, weight: .semibold, design: .serif)); Text(label).font(.system(size: 9, weight: .medium, design: .monospaced)) }
    }
    private func provider(_ source: Integration, enabled: Bool, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("\(source.title) · \(count) prompts today", isOn: Binding(get: { enabled }, set: { model.enable(source, $0) }))
            Text(model.connection(source)).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

extension View {
    func card() -> some View { padding(16).background(Color(nsColor: .controlBackgroundColor).opacity(0.66), in: RoundedRectangle(cornerRadius: 18)) }
    func eyebrow() -> some View { font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1) }
}

/// Original vector illustration, no external artwork or copied Loch assets.
struct DogView: View {
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 220, y: size.height / 170)
            func ellipse(_ rect: CGRect, _ color: Color) { context.fill(Path(ellipseIn: rect), with: .color(color)) }
            let gold = Color(red: 0.89, green: 0.63, blue: 0.29)
            let light = Color(red: 0.98, green: 0.78, blue: 0.45)
            let cream = Color(red: 1, green: 0.87, blue: 0.62)
            let shade = Color(red: 0.69, green: 0.43, blue: 0.21)
            var tail = Path(); tail.move(to: CGPoint(x: 149, y: 129))
            tail.addQuadCurve(to: CGPoint(x: 175, y: 103), control: CGPoint(x: 180, y: 137))
            context.stroke(tail, with: .color(gold), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            ellipse(CGRect(x: 84, y: 89, width: 76, height: 59), gold)
            ellipse(CGRect(x: 98, y: 101, width: 48, height: 44), light)
            ellipse(CGRect(x: 81, y: 129, width: 31, height: 22), gold)
            ellipse(CGRect(x: 137, y: 129, width: 28, height: 22), gold)
            // Tiny front paws tucked into the soft belly.
            ellipse(CGRect(x: 101, y: 126, width: 18, height: 25), light)
            ellipse(CGRect(x: 128, y: 126, width: 18, height: 25), light)
            // Same head height, coat and face details as the walking puppy.
            ellipse(CGRect(x: 87, y: 44, width: 73, height: 67), light)
            ellipse(CGRect(x: 79, y: 57, width: 25, height: 48), shade)
            ellipse(CGRect(x: 147, y: 57, width: 25, height: 48), shade)
            ellipse(CGRect(x: 101, y: 77, width: 48, height: 30), cream)
            ellipse(CGRect(x: 106, y: 65, width: 8, height: 11), Palette.face)
            ellipse(CGRect(x: 136, y: 65, width: 8, height: 11), Palette.face)
            ellipse(CGRect(x: 108, y: 66, width: 2.5, height: 3), .white)
            ellipse(CGRect(x: 138, y: 66, width: 2.5, height: 3), .white)
            ellipse(CGRect(x: 117, y: 79, width: 15, height: 11), Palette.face)
            let blush = Color(red: 0.95, green: 0.64, blue: 0.42)
            ellipse(CGRect(x: 102, y: 86, width: 10, height: 6), blush)
            ellipse(CGRect(x: 138, y: 86, width: 10, height: 6), blush)
            var smile = Path(); smile.move(to: CGPoint(x: 114, y: 96))
            smile.addQuadCurve(to: CGPoint(x: 135, y: 96), control: CGPoint(x: 124, y: 106))
            context.stroke(smile, with: .color(Palette.face), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            var scarf = Path(); scarf.move(to: CGPoint(x: 104, y: 107))
            scarf.addQuadCurve(to: CGPoint(x: 146, y: 107), control: CGPoint(x: 125, y: 115))
            scarf.addLine(to: CGPoint(x: 125, y: 127)); scarf.closeSubpath()
            context.fill(scarf, with: .color(Palette.bandana))
        }.accessibilityLabel("A small round golden puppy sitting with tucked paws")
    }
}

struct AttachedNotchShape: Shape {
    func path(in rect: CGRect) -> Path { Path(NotchGeometry.outline(width: rect.width, height: rect.height)) }
}

struct PawWarning: View {
    @ObservedObject var model: AppModel
    let deadZone: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { timeline in
            ZStack {
                AttachedNotchShape().fill(.black)
                Canvas { context, size in
                    var mask = Path()
                    let wing = (size.width - deadZone) / 2
                    mask.addRect(CGRect(x: 60, y: 2, width: max(0, wing - 66), height: size.height - 4))
                    mask.addRect(CGRect(x: wing + deadZone + 6, y: 2, width: max(0, wing - 66), height: size.height - 4))
                    context.clip(to: mask)
                    guard let paw = context.resolveSymbol(id: "paw") else { return }
                    if reduceMotion || model.forceReducedMotion {
                        context.draw(paw, at: CGPoint(x: wing / 2, y: size.height / 2))
                        context.draw(paw, at: CGPoint(x: size.width - wing / 2, y: size.height / 2))
                    } else {
                        for foot in PawTrail.samples(elapsed: timeline.date.timeIntervalSince(started), width: size.width, deadZone: deadZone) {
                            var stamp = context
                            stamp.opacity = foot.opacity
                            stamp.translateBy(x: foot.x, y: size.height / 2 + (foot.lane == 0 ? -3 : 3))
                            stamp.rotate(by: .degrees(foot.rotationDegrees))
                            stamp.draw(paw, at: .zero)
                        }
                    }
                } symbols: {
                    Image(systemName: "pawprint.fill").font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.91, green: 0.71, blue: 0.43)).tag("paw")
                }
                HStack { Text(model.isPreview ? "DEMO" : "WALK"); Spacer(); Text("\(model.displayed.remaining(now: model.displayNow))s").monospacedDigit() }
                    .font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.65)).padding(.horizontal, 24)
            }.clipShape(AttachedNotchShape())
        }.accessibilityElement(children: .ignore).accessibilityLabel("Break warning. \(model.displayed.remaining(now: model.displayNow)) seconds. Open HowFried to snooze.")
    }
}

struct ParkView: View {
    @ObservedObject var model: AppModel
    var bottomSafeInset: CGFloat = 34
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var began = Date()
    @State private var ready = false
    @StateObject private var audio = CalmAudio()
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: ready ? 1 : 0.033)) { time in
                let elapsed = time.date.timeIntervalSince(began)
                let reduced = reduceMotion || model.forceReducedMotion
                let p = reduced ? 1 : min(1, max(0, elapsed / 5))
                ZStack {
                    LinearGradient(colors: model.scene.isNight ? [Color(red: 0.055, green: 0.09, blue: 0.16), Color(red: 0.14, green: 0.23, blue: 0.24)] : [Color(red: 0.97, green: 0.95, blue: 0.89), Color(red: 0.85, green: 0.90, blue: 0.76)], startPoint: .top, endPoint: .bottom).opacity(min(1, p * 1.8))
                    Group {
                        if model.scene.isNight {
                            Image(systemName: "moon.fill").font(.system(size: 115)).foregroundStyle(Color(red: 0.91, green: 0.91, blue: 0.75))
                        } else {
                            Circle().fill(Color(red: 0.97, green: 0.79, blue: 0.43)).frame(width: 150, height: 150)
                        }
                    }.position(x: geo.size.width * (model.scene.isNight ? 0.18 : model.scene.sunX), y: geo.size.height * (model.scene.isNight ? 0.20 : model.scene.sunY)).opacity(p)
                    Ellipse().fill(Palette.grass.opacity(0.35)).frame(width: geo.size.width * 1.6, height: geo.size.height * 0.65).position(x: geo.size.width * 0.30, y: geo.size.height * 0.99).opacity(p)
                    Ellipse().fill(Palette.grass.opacity(0.35)).frame(width: geo.size.width * 1.3, height: geo.size.height * 0.65).position(x: geo.size.width * 0.95, y: geo.size.height * 1.03).opacity(p)
                    VStack(spacing: 18) {
                        Text(model.isPreview ? "PREVIEW · NO ACTIVITY IS COUNTED" : "A LITTLE TIME OFFLINE").eyebrow()
                        Text("Your tokens can wait.\nTime for a walk.").font(.system(size: min(64, geo.size.width / 15), weight: .medium, design: .serif)).multilineTextAlignment(.center)
                        Text("Leave the screen. We’ll keep your spot.").font(.system(size: 17)).foregroundStyle(Palette.ink.opacity(0.65))
                        Text(ready ? clock(model.displayed.remaining(now: model.displayNow)) : "Follow that tail…")
                            .font(.system(size: 38, weight: .light, design: .monospaced)).monospacedDigit().padding(.top, 8)
                    }.position(x: geo.size.width / 2, y: geo.size.height * 0.32).opacity(p)
                    let x = (-70 + (geo.size.width / 2 + 70) * p) + sin(p * .pi * 3) * 105 * (1 - p)
                    let y = geo.size.height - 90 - p * geo.size.height * 0.28
                    Ellipse().fill(Palette.ink.opacity(0.18)).frame(width: 180 - p * 60, height: 18 - p * 6).blur(radius: 7 - p * 3).position(x: x, y: y + 83 - p * 15)
                    let seated = reduced ? 1.0 : min(1, max(0, (p - 0.86) / 0.14))
                    ZStack {
                        WalkingDog(phase: elapsed * 8).frame(width: 290 - p * 65, height: 224 - p * 50).opacity(1 - seated)
                            .offset(y: reduced ? 0 : sin(elapsed * 16) * 1.2)
                        DogView().frame(width: 290 - p * 65, height: 224 - p * 50).opacity(seated)
                    }.position(x: x, y: y)
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            if audio.playing {
                                Label(audio.title, systemImage: "music.note").font(.caption)
                                Button("Mute music") { audio.stop() }
                            } else {
                                Button(audio.loading ? "Finding a quiet tune…" : "Play something peaceful") { audio.play() }.disabled(audio.loading)
                                Text("Optional · local piano").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.bottom, 12)
                        if let error = audio.error { Text(error).font(.caption) }
                        HStack(spacing: 14) {
                            Button("Snooze 10 min") { model.snooze() }.buttonStyle(.borderedProminent)
                            Button("Skip this break") { model.skip() }.buttonStyle(.bordered)
                        }.controlSize(.large)
                        Text("\(model.shortcutLabel) to skip · Escape when focused").font(.caption).padding(.top, 7)
                    }.padding(.bottom, bottomSafeInset)
                }.foregroundStyle(Palette.ink).tint(Palette.ink)
                    .opacity(reduced ? min(1, max(0, elapsed / 0.3)) : 1)
            }
        }.environment(\.colorScheme, model.scene.isNight ? .dark : .light)
            .onAppear { began = Date() }.onDisappear { audio.stop() }.onExitCommand { model.skip() }
            .task {
                do { try await Task.sleep(for: .seconds((reduceMotion || model.forceReducedMotion) ? 0.3 : 5)) }
                catch { return }
                guard !Task.isCancelled else { return }
                ready = true; model.sceneReady()
            }
    }
    private func clock(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
}

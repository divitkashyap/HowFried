import AppKit
import SwiftUI
import HowFriedCore

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    var escape: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { escape?() }
}

final class NotchPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var status: NSStatusItem!
    private var dashboard: NSWindow?
    private var warning: NSPanel?
    private var park: OverlayPanel?
    private let shortcut = HotKey()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "HowFried")
        status.button?.target = self; status.button?.action = #selector(toggleDashboard)
        model.presentationChanged = { [weak self] in self?.updatePanels() }
        model.showWindow = { [weak self] in self?.showDashboard() }
        model.shortcutChanged = { [weak self] in self?.registerShortcut() }
        model.appearanceChanged = { [weak self] in
            guard let self else { return }; self.dashboard?.appearance = self.dashboardAppearance
        }
        shortcut.action = { [weak self] in self?.model.skip() }
        registerShortcut()
        showDashboard()
    }
    private func registerShortcut() {
        let p = model.preferences
        let success = shortcut.register(key: p.shortcutKey, control: p.shortcutControl, option: p.shortcutOption, command: p.shortcutCommand)
        model.shortcutError = success ? nil : "Shortcut unavailable. Choose another combination; visible dismissal still works."
    }
    private var dashboardAppearance: NSAppearance? {
        switch model.preferences.appearance {
        case "light": return NSAppearance(named: .aqua)
        case "dark": return NSAppearance(named: .darkAqua)
        default: return nil
        }
    }
    @objc private func toggleDashboard() {
        if dashboard?.isVisible == true { dashboard?.orderOut(nil) } else { showDashboard() }
    }
    private func showDashboard() {
        if dashboard == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 760), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "HowFried"; window.isReleasedWhenClosed = false
            window.appearance = dashboardAppearance
            window.contentView = NSHostingView(rootView: Dashboard(model: model))
            window.center(); dashboard = window
        }
        dashboard?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard(); return true
    }
    private func updatePanels() {
        guard let screen = NSScreen.screens.first else { return }
        let phase = model.displayed.phase
        if model.preferences.suspended { warning?.orderOut(nil); park?.orderOut(nil); return }
        if phase == .warning {
            if warning == nil {
                let gap: CGFloat
                if model.qa || screen.safeAreaInsets.top == 0 { gap = 70 }
                else if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea { gap = max(70, right.minX - left.maxX) }
                else { gap = 180 }
                let width = gap + 400
                let height = NotchGeometry.height(safeTop: screen.safeAreaInsets.top, scale: screen.backingScaleFactor)
                let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
                let panel = NotchPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
                panel.level = .statusBar; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                panel.ignoresMouseEvents = true
                panel.contentView = NSHostingView(rootView: PawWarning(model: model, deadZone: gap).frame(width: width, height: height).ignoresSafeArea())
                panel.setFrame(frame, display: true)
                if ProcessInfo.processInfo.environment["HOWFRIED_LAYOUT_DIAGNOSTICS"] == "1" {
                    print("HowFried warning: topFlush=\(panel.frame.maxY == screen.frame.maxY), height=\(panel.frame.height), width=\(panel.frame.width), deadZone=\(gap)")
                }
                warning = panel
            }
            warning?.orderFrontRegardless()
        } else { warning?.orderOut(nil); warning = nil }
        if phase == .entrance || phase == .resting {
            if park == nil {
                let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
                // Above the Dock, below the menu bar. The owner can still reach menu-bar Quit.
                panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                panel.appearance = NSAppearance(named: model.scene.isNight ? .darkAqua : .aqua)
                panel.isReleasedWhenClosed = false; panel.escape = { [weak self] in self?.model.skip() }
                let bottomInset = max(96, screen.visibleFrame.minY - screen.frame.minY + 24)
                panel.contentView = NSHostingView(rootView: ParkView(model: model, bottomSafeInset: bottomInset))
                park = panel; dashboard?.orderOut(nil)
                panel.makeKeyAndOrderFront(nil)
                if model.preferences.sound { NSSound(named: "Pop")?.play() }
            }
        } else { park?.orderOut(nil); park = nil }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}

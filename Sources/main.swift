import SwiftUI
import AppKit
import Combine

final class ClockWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// Keep backdrop effects in the window's native view tree. SwiftUI clipping/shadows
// can flatten an NSVisualEffectView into a gray offscreen surface.
final class ClockSurface: NSView {
    private var themeSubscription: AnyCancellable?
    init(model: AppModel) {
        super.init(frame: NSRect(x: 0, y: 0, width: 184, height: 210))
        let dialRect = NSRect(x: 16, y: 46, width: 152, height: 152)
        // Sample the windows and wallpaper behind this window, with a deliberately
        // low opacity so the desktop remains visible rather than becoming gray.
        let frost = NSVisualEffectView(frame: dialRect)
        frost.material = .underWindowBackground
        frost.blendingMode = .behindWindow
        frost.state = .active
        frost.alphaValue = 0.32
        frost.wantsLayer = true
        frost.layer?.cornerRadius = 76
        frost.layer?.masksToBounds = true
        addSubview(frost)
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: dialRect)
            glass.style = .clear
            glass.cornerRadius = 76
            glass.tintColor = nil
            glass.appearance = NSAppearance(named: .aqua)
            glass.contentView = NSView(frame: NSRect(origin: .zero, size: dialRect.size))
            addSubview(glass)
        }
        let tint = NSView(frame: dialRect)
        tint.wantsLayer = true
        tint.layer?.cornerRadius = 76
        addSubview(tint)
        themeSubscription = model.$theme.sink { [weak tint] theme in
            tint?.layer?.backgroundColor = theme.native.withAlphaComponent(0.09).cgColor
        }
        let hosting = NSHostingView(rootView: ContentView(model: model))
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(hosting)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    var model: AppModel!
    var window: NSWindow!
    var status: NSStatusItem!
    var dashboard: NSWindow?
    var reminder: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        model.onReminder = { [weak self] rest, test in self?.showReminder(rest: rest, test: test) }
        model.openDashboard = { [weak self] in self?.showDashboard() }
        window = ClockWindow(contentRect: NSRect(x: 0, y: 0, width: 184, height: 210),
                          styleMask: [.borderless],
                          backing: .buffered, defer: false)
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.title = "栖刻 · 专注当下"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.level = model.pinned ? .floating : .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self
        window.contentView = ClockSurface(model: model)
        if UserDefaults.standard.string(forKey: "clockPosition") != nil {
            window.setFrameOrigin(NSPointFromString(UserDefaults.standard.string(forKey: "clockPosition")!))
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        } else if let screen = NSScreen.main {
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 210, y: screen.visibleFrame.minY + 80))
        }
        showWindow()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        status.button?.imagePosition = .imageLeading
        let statusMenu = NSMenu()
        statusMenu.delegate = self
        status.menu = statusMenu
        model.onTick = { [weak self] in self?.updateStatus() }
        model.notifications.openWindow = { [weak self] in self?.showWindow() }
        updateStatus()
        let appMenu = NSMenu()
        let root = NSMenuItem()
        let actions = NSMenu()
        actions.addItem(withTitle: "关于栖刻", action: #selector(about), keyEquivalent: "")
        let dashboardItem = actions.addItem(withTitle: "今日专注统计", action: #selector(showDashboard), keyEquivalent: "1")
        dashboardItem.target = self
        actions.addItem(NSMenuItem.separator())
        actions.addItem(withTitle: "退出栖刻", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = actions
        appMenu.addItem(root)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        appMenu.addItem(editItem)
        NSApp.mainMenu = appMenu
    }
    func updateStatus() {
        status.button?.title = " " + model.time
        status.button?.image = NSImage(systemSymbolName: model.engine.phase == .rest ? "leaf" : "circle.lefthalf.filled", accessibilityDescription: "栖刻")
        status.button?.toolTip = "栖刻 · \(model.engine.phase.title) · \(model.engine.running ? "计时中" : "已暂停")"
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "\(model.engine.phase.title) · \(model.time)", action: nil, keyEquivalent: "")
        menu.addItem(title)
        menu.addItem(.separator())
        addItem("打开栖刻", action: #selector(showWindow), menu: menu)
        addItem("今日专注统计", action: #selector(showDashboard), menu: menu)
        addItem(model.engine.running ? "暂停计时" : "开始计时", action: #selector(toggle), menu: menu)
        if model.engine.phase == .focus { addItem("提前结束专注…", action: #selector(endFocus), menu: menu) }
        if model.engine.phase == .rest { addItem("结束休息", action: #selector(skip), menu: menu) }
        addItem("测试结束提醒与通知", action: #selector(testReminder), menu: menu)
        menu.addItem(.separator())
        addItem("退出栖刻", action: #selector(quit), menu: menu)
    }
    func addItem(_ title: String, action: Selector, menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func toggle() { model.toggle() }
    @objc func skip() { model.skipRest() }
    @objc func endFocus() {
        showWindow()
        let alert = NSAlert()
        alert.messageText = "提前结束这次专注？"
        alert.informativeText = "已专注的实际时长会保留，不计为完整一轮。正在计时则自动进入 5 分钟休息，暂停中则等待手动开始。"
        alert.addButton(withTitle: "结束并进入休息")
        alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn { self?.model.endFocus() }
        }
    }
    @objc func showDashboard() {
        if dashboard == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 700),
                                 styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            panel.title = "栖刻 · 今日专注"
            panel.identifier = NSUserInterfaceItemIdentifier("dashboard")
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            panel.contentView = NSHostingView(rootView: DashboardView(model: model, collapse: { [weak self] in
                self?.dashboard?.orderOut(nil)
                self?.showWindow()
            }))
            panel.center()
            dashboard = panel
        }
        dashboard?.deminiaturize(nil)
        dashboard?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func testReminder() { model.testReminder() }
    func showReminder(rest: Bool, test: Bool = false) {
        if reminder == nil {
            let panel = ClockWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
                                    styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            panel.title = "栖刻 · 时间到了"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.identifier = NSUserInterfaceItemIdentifier("reminder")
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            reminder = panel
        }
        reminder?.contentView = NSHostingView(rootView: ReminderView(model: model, rest: rest, test: test, dismiss: { [weak self] in
            self?.reminder?.orderOut(nil)
            self?.model.stopReminderSound()
        }))
        reminder?.center()
        reminder?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationDidBecomeActive(_ notification: Notification) { model?.notifications.refreshStatus() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "栖刻", .applicationVersion: "1.0", .credits: NSAttributedString(string: "可选专注时长 · 5 分钟休息\n通知模块与提示音改编自 TomatoBar (MIT)\nCopyright © 2022 Ilya Voronin")])
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        if sender.identifier?.rawValue == "reminder" { model.stopReminderSound() }
        if sender.identifier?.rawValue == "dashboard" { showWindow() }
        return false
    }
    func windowDidMiniaturize(_ notification: Notification) {
        if let panel = notification.object as? NSWindow, panel.identifier?.rawValue == "dashboard" { showWindow() }
    }
    func windowDidMove(_ notification: Notification) {
        if let moved = notification.object as? NSWindow, moved.identifier?.rawValue == "main" {
            UserDefaults.standard.set(NSStringFromPoint(moved.frame.origin), forKey: "clockPosition")
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) {
        model.engine.pause(at: Date())
        model.save()
        model.notifications.cancel()
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = AppDelegate()
application.delegate = delegate
application.run()

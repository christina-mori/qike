import SwiftUI
import AppKit
import AVFoundation

final class AppModel: ObservableObject {
    @Published var engine: TimerEngine
    @Published var notificationsAllowed = false
    @Published var notificationStatus = "正在检查通知权限…"
    @Published var notificationError: String?
    @Published var reminderTestStatus: String?
    @Published private(set) var breakVideoLink = UserDefaults.standard.string(forKey: "breakVideoLink") ?? ""
    @Published var showingBreakVideoSettings = false
    @Published private(set) var breakVideoError: String?
    var onReminder: ((Bool, Bool) -> Void)?
    @Published var theme = GlassTheme(rawValue: UserDefaults.standard.string(forKey: "glassTheme") ?? "silver") ?? .silver {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "glassTheme") }
    }
    var openDashboard: (() -> Void)?
    @Published var sound: Bool { didSet { UserDefaults.standard.set(sound, forKey: "sound"); reschedule() } }
    @Published var pinned = UserDefaults.standard.object(forKey: "pinned") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(pinned, forKey: "pinned")
            NSApp.windows.filter { $0.identifier?.rawValue == "main" }.forEach { $0.level = pinned ? .floating : .normal }
        }
    }
    let notifications = TBNotificationCenter()
    var onTick: (() -> Void)?
    private var ticker: Timer?
    private var player: AVAudioPlayer?
    var time: String {
        let value = Int(ceil(engine.remaining))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
    var progress: Double { 1 - engine.remaining / engine.phaseDuration }
    init() {
        sound = UserDefaults.standard.object(forKey: "sound") as? Bool ?? true
        if let data = UserDefaults.standard.data(forKey: "timer"), let saved = try? JSONDecoder().decode(TimerEngine.self, from: data) { engine = saved }
        else { engine = TimerEngine() }
        engine.advance(to: Date())
        if let url = Bundle.main.url(forResource: "ding", withExtension: "wav") { player = try? AVAudioPlayer(contentsOf: url) }
        notifications.onStatus = { [weak self] allowed, description in
            self?.notificationsAllowed = allowed
            self?.notificationStatus = description
        }
        notifications.onError = { [weak self] message in self?.notificationError = message }
        notifications.refreshStatus()
        notifications.setActionHandler { [weak self] _ in self?.skipRest() }
        ticker = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(ticker!, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.tick() }
        reschedule()
    }
    func tick() {
        let transitions = engine.advance(to: Date())
        if transitions > 0 {
            announce(rest: engine.phase == .rest)
            openBreakVideoIfResting()
            save()
            // Keep the just-due reminder queued while extending the future horizon.
            notifications.schedule(engine: engine, sound: sound, clearingExisting: false)
        }
        onTick?()
    }
    func toggle() {
        let oldPhase = engine.phase
        if engine.running { engine.pause(at: Date()); reschedule() }
        else {
            engine.start(at: Date())
            notifications.authorize { [weak self] allowed in self?.notificationsAllowed = allowed; self?.reschedule() }
        }
        if oldPhase != engine.phase { openBreakVideoIfResting() }
        save(); onTick?()
    }
    func announce(rest: Bool, test: Bool = false) {
        onReminder?(rest, test)
        NSApp.requestUserAttention(.criticalRequest)
        if sound {
            player?.currentTime = 0
            player?.numberOfLoops = 2
            player?.play()
        }
    }
    func changeFocusMinutes(_ minutes: Int) {
        let oldPhase = engine.phase
        engine.setFocusMinutes(minutes, at: Date())
        if oldPhase != engine.phase {
            announce(rest: engine.phase == .rest)
            openBreakVideoIfResting()
        }
        save(); reschedule(); onTick?()
    }
    func testReminder() {
        notifications.authorize { [weak self] _ in
            guard let self else { return }
            self.reminderTestStatus = "测试通知发送中…"
            self.notifications.test(sound: false) { [weak self] delivered in
                self?.reminderTestStatus = delivered ? "测试通知已送达通知中心" : "未检测到测试通知，请检查专注模式或系统通知设置"
            }
            self.announce(rest: true, test: true)
        }
    }
    func reset() { engine.reset(); save(); reschedule(); onTick?() }
    func endFocus() {
        let oldPhase = engine.phase
        engine.endFocus(at: Date())
        if oldPhase == .focus { openBreakVideoIfResting() }
        save(); reschedule(); onTick?()
    }
    static func breakVideoURL(_ link: String) -> URL? {
        guard let parts = URLComponents(string: link),
              let scheme = parts.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil else { return nil }
        return parts.url
    }
    static func normalizedBreakVideoLink(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if !trimmed.contains(where: \.isWhitespace), let url = breakVideoURL(trimmed) {
            return url.absoluteString
        }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) ?? []
        return matches.lazy.compactMap { match -> String? in
            guard let range = Range(match.range, in: trimmed) else { return nil }
            return breakVideoURL(String(trimmed[range]))?.absoluteString
        }.first
    }
    func saveBreakVideo(_ input: String) -> Bool {
        guard let link = Self.normalizedBreakVideoLink(input) else { return false }
        breakVideoLink = link
        UserDefaults.standard.set(link, forKey: "breakVideoLink")
        breakVideoError = nil
        return true
    }
    private func openBreakVideoIfResting() {
        guard engine.phase == .rest, let url = Self.breakVideoURL(breakVideoLink) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(url, configuration: config) { _, error in
            DispatchQueue.main.async {
                self.breakVideoError = error == nil ? nil : "未能打开休息视频，请检查默认浏览器设置。"
            }
        }
    }
    var todayDuration: String {
        let seconds = Int(engine.todayFocusSeconds())
        if seconds >= 3600 { return "\(seconds / 3600) 小时 \(seconds % 3600 / 60) 分钟" }
        return "\(seconds / 60) 分 \(seconds % 60) 秒"
    }
    func skipRest() {
        guard engine.phase == .rest else { return }
        let wasRunning = engine.running
        engine.skip()
        if wasRunning { engine.start(at: Date()) }
        save(); reschedule(); onTick?()
    }
    func save() { if let data = try? JSONEncoder().encode(engine) { UserDefaults.standard.set(data, forKey: "timer") } }
    func reschedule() { notifications.schedule(engine: engine, sound: sound) }
    func stopReminderSound() { player?.stop() }
    func testSound() { player?.numberOfLoops = 0; player?.currentTime = 0; player?.play() }
}

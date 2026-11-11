// Adapted from TomatoBar, Copyright (c) 2022 Ilya Voronin (MIT).
// Original: https://github.com/ivoronin/TomatoBar/blob/main/TomatoBar/Notifications.swift
// See ThirdParty/TomatoBar-LICENSE. Added timed scheduling and foreground alerts.
import UserNotifications
import AppKit

enum TBNotification {
    enum Category: String { case restStarted, restFinished }
    enum Action: String { case skipRest }
}
typealias TBNotificationHandler = (TBNotification.Action) -> Void

class TBNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var handler: TBNotificationHandler?
    var openWindow: (() -> Void)?
    var onStatus: ((Bool, String) -> Void)?
    var onError: ((String) -> Void)?
    override init() {
        super.init()
        center.delegate = self
        let action = UNNotificationAction(identifier: TBNotification.Action.skipRest.rawValue,
                                          title: "结束休息，继续专注", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: TBNotification.Category.restStarted.rawValue,
                                   actions: [action], intentIdentifiers: []),
            UNNotificationCategory(identifier: TBNotification.Category.restFinished.rawValue,
                                   actions: [], intentIdentifiers: [])
        ])
    }
    func authorize(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { self.refreshStatus(); completion(granted) }
        }
    }
    func refreshStatus() {
        center.getNotificationSettings { settings in
            let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            let status = !allowed ? "系统通知未开启，请在系统设置中允许栖刻通知" : settings.alertSetting != .enabled ? "通知已授权，但横幅未开启，请在系统设置中开启" : "系统通知已开启"
            DispatchQueue.main.async { self.onStatus?(allowed, status) }
        }
    }
    private func add(_ request: UNNotificationRequest) {
        center.add(request) { error in
            if let error { DispatchQueue.main.async { self.onError?("通知发送失败：\(error.localizedDescription)") } }
        }
    }
    func test(sound: Bool, completion: @escaping (Bool) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "栖刻 · 提醒测试"
        content.body = "喝口水、起来活动一下。看到这条通知就表示系统通知可正常送达。"
        content.interruptionLevel = .active
        if sound { content.sound = .default }
        add(UNNotificationRequest(identifier: "qike-test", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)))
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            self.center.getDeliveredNotifications { delivered in
                DispatchQueue.main.async { completion(delivered.contains { $0.request.identifier == "qike-test" }) }
            }
        }
    }
    func setActionHandler(handler: @escaping TBNotificationHandler) { self.handler = handler }
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            if let action = TBNotification.Action(rawValue: response.actionIdentifier) { self.handler?(action) }
            else { self.openWindow?() }
        }
        completion()
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .list, .sound])
    }
    func cancel() { center.removeAllPendingNotificationRequests() }
    func schedule(engine: TimerEngine, sound: Bool, clearingExisting: Bool = true) {
        if clearingExisting { cancel() }
        guard var end = engine.deadline else { return }
        var phase = engine.phase
        for _ in 0..<48 {
            let delay = end.timeIntervalSinceNow
            if delay > 0 {
                let content = UNMutableNotificationContent()
                let rest = phase == .focus
                content.title = rest ? "喝口水，起来活动一下 💧" : "休息结束，继续专注 ✨"
                content.body = rest ? "已经专注 \(engine.focusMinutes) 分钟。放松肩颈，看看远处，休息 5 分钟。" : "新的 \(engine.focusMinutes) 分钟已经开始，慢慢进入状态。"
                content.interruptionLevel = .active
                content.categoryIdentifier = rest ? TBNotification.Category.restStarted.rawValue : TBNotification.Category.restFinished.rawValue
                if sound { content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "ding.wav")) }
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
                let identifier = "qike-\(Int(end.timeIntervalSince1970 * 1000))"
                add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            }
            phase = phase.next
            end = end.addingTimeInterval(phase == .focus ? TimeInterval(engine.focusMinutes * 60) : 300)
        }
    }
}

import SwiftUI
import AppKit

private let ink = Color(red: 0.20, green: 0.23, blue: 0.28)
private let blue = Color(red: 0.44, green: 0.52, blue: 0.63)

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var hovering = false
    @State private var settings = false
    @State private var confirmReset = false
    @State private var confirmEnd = false
    var rest: Bool { model.engine.phase == .rest }
    var accent: Color { model.theme.color }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                Circle().fill(LinearGradient(
                    colors: [.white.opacity(0.12), accent.opacity(0.055), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                    .allowsHitTesting(false)
                Circle().strokeBorder(LinearGradient(
                    colors: [.white.opacity(0.90), .white.opacity(0.30), .white.opacity(0.60)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                    .allowsHitTesting(false)
                Circle().stroke(ink.opacity(0.065), lineWidth: 1.5).padding(10)
                Circle().trim(from: 0, to: max(0.002, 1 - model.progress))
                    .stroke(accent.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(10)
                VStack(spacing: 8) {
                    Text(rest ? "休 息" : "专 注")
                        .font(.system(size: 8, weight: .medium)).tracking(2)
                        .foregroundStyle(ink.opacity(0.45))
                    Text(model.time)
                        .font(.system(size: 34, weight: .light))
                        .monospacedDigit().tracking(-1.6)
                    Button { model.toggle() } label: {
                        Image(systemName: model.engine.running ? "pause.fill" : "play.fill")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(ink.opacity(0.60)).frame(width: 25, height: 20)
                            .background(.white.opacity(0.22), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.38), lineWidth: 0.5))
                    }.buttonStyle(.plain)
                        .keyboardShortcut(.space, modifiers: [])
                        .help(model.engine.running ? "暂停计时 · 空格" : "开始计时 · 空格")
                }
            }
            .frame(width: 152, height: 152)
            .padding(.top, 12)
            HStack(spacing: 13) {
                Button { model.openDashboard?() } label: { Image(systemName: "chart.bar.xaxis") }.help("今日专注统计")
                Button { confirmReset = true } label: { Image(systemName: "arrow.counterclockwise") }.help("重置当前计时")
                Button { model.pinned.toggle() } label: { Image(systemName: model.pinned ? "pin.fill" : "pin") }.help("窗口置顶")
                Button { settings.toggle() } label: { Image(systemName: "ellipsis") }.help("设置")
                    .popover(isPresented: $settings, arrowEdge: .bottom) { preferences }
            }
            .font(.system(size: 11)).foregroundStyle(ink.opacity(0.7))
            .buttonStyle(.plain).padding(.horizontal, 14).padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.7)))
            .opacity(hovering || settings ? 1 : 0)
            .allowsHitTesting(hovering || settings)
            .padding(.top, 175)
        }
        .frame(width: 184, height: 210)
        .foregroundStyle(ink).preferredColorScheme(.light)
        .onHover { value in withAnimation(.easeInOut(duration: 0.18)) { hovering = value } }
        .contextMenu {
            Button(model.engine.running ? "暂停计时" : "开始计时") { model.toggle() }
            if !rest { Button("提前结束专注…") { confirmEnd = true } }
            if rest { Button("结束休息") { model.skipRest() } }
            Button("今日专注统计") { model.openDashboard?() }
            Button("设置休息视频…") {
                model.openDashboard?()
                model.showingBreakVideoSettings = true
            }
            Menu("专注时长 · \(model.engine.focusMinutes) 分钟") {
                ForEach(TimerEngine.focusOptions, id: \.self) { value in
                    Button("\(value) 分钟") { model.changeFocusMinutes(value) }
                }
            }
            Button("测试结束提醒") { model.testReminder() }
            Menu("玻璃配色") {
                ForEach(GlassTheme.allCases) { theme in
                    Button { model.theme = theme } label: {
                        if model.theme == theme { Label(theme.name, systemImage: "checkmark") }
                        else { Text(theme.name) }
                    }
                }
            }
            Button("重置当前计时") { confirmReset = true }
            Divider()
            Toggle("窗口置顶", isOn: $model.pinned)
            Toggle("提醒声音", isOn: $model.sound)
            Text("今天完成 \(model.engine.todayCount()) 次专注")
            Divider()
            Button("隐藏小时钟") { NSApp.windows.first { $0.identifier?.rawValue == "main" }?.orderOut(nil) }
            Button("退出栖刻") { NSApp.terminate(nil) }
        }
        .alert("重新开始这一段？", isPresented: $confirmReset) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) { model.reset() }
        } message: { Text("当前进度将清零，已完成的专注次数会保留。") }
        .alert("提前结束这次专注？", isPresented: $confirmEnd) {
            Button("取消", role: .cancel) {}
            Button("结束并进入休息") { model.endFocus() }
        } message: { Text("已专注的实际时长会计入今天的统计，不计为完整一轮。计时中会自动开始 5 分钟休息；暂停中则停留在休息待开始状态。") }
    }
    var preferences: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("栖刻 · 小时钟").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { settings = false } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
            }
            Text("\(model.engine.focusMinutes) 分钟专注 / 5 分钟休息")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            DurationPicker(model: model)
            Text("玻璃配色 · \(model.theme.name)").font(.system(size: 11)).foregroundStyle(.secondary)
            ThemePicker(model: model)
            Toggle("窗口置顶", isOn: $model.pinned)
            Toggle("提醒声音", isOn: $model.sound)
            if rest { Button("跳过休息") { model.skipRest(); settings = false } }
            Divider()
            Text("今日专注 \(model.todayDuration)")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Button("打开今日专注统计") { settings = false; model.openDashboard?() }
            Text("拖动表盘移动位置，右键查看更多操作。\n隐藏后仍会计时，从菜单栏可重新打开。")
                .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
            Text(model.notificationStatus).font(.system(size: 10)).foregroundStyle(model.notificationsAllowed ? Color.secondary : Color.orange)
            if let result = model.reminderTestStatus { Text(result).font(.system(size: 10)).foregroundStyle(.secondary) }
            if let error = model.notificationError { Text(error).font(.system(size: 10)).foregroundStyle(.orange) }
            Button("测试结束提醒与系统通知") { model.testReminder() }
            Button("系统通知设置") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
            }
        }.font(.system(size: 12)).toggleStyle(.switch).padding(18).frame(width: 250)
    }
}

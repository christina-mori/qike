import SwiftUI

struct DashboardView: View {
    @ObservedObject var model: AppModel
    let collapse: () -> Void
    @State private var confirmEnd = false
    var accent: Color { model.theme.color }
    var spans: [FocusSpan] { model.engine.todaySpans() }
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text("今天，把时间留给重要的事。")
                        .font(.system(size: 22, weight: .medium))
                    Text(Date(), format: .dateTime.month(.wide).day().weekday(.wide))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: collapse) { Label("收起为小时钟", systemImage: "arrow.down.right.and.arrow.up.left") }
                    .font(.system(size: 11)).buttonStyle(.bordered)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(model.todayDuration).font(.system(size: 37, weight: .light, design: .rounded)).monospacedDigit()
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("\(model.engine.todayCount()) 轮完整专注").font(.system(size: 12, weight: .medium))
                    Text("仅累计专注时间，暂停与休息不计入")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 10)
            HStack(alignment: .top) {
                DurationPicker(model: model)
                Spacer()
                Button {
                    model.showingBreakVideoSettings = true
                } label: {
                    Label(model.breakVideoLink.isEmpty ? "设置休息视频" : "休息视频已设置", systemImage: "play.rectangle")
                }.buttonStyle(.bordered)
            }
            if let error = model.breakVideoError {
                Text(error).font(.system(size: 10)).foregroundStyle(.orange)
            }
            HStack(spacing: 13) {
                Image(systemName: model.engine.phase == .focus ? "timer" : "leaf")
                    .font(.system(size: 22, weight: .light)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.engine.phase.title + (model.engine.running ? " · 进行中" : " · 已暂停"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(model.time).font(.system(size: 24, weight: .light, design: .rounded)).monospacedDigit()
                }
                Spacer()
                Button(model.engine.running ? "暂停" : "开始") { model.toggle() }.buttonStyle(.borderedProminent).tint(accent)
                if model.engine.phase == .focus {
                    Button("提前结束") { confirmEnd = true }.buttonStyle(.bordered)
                } else {
                    Button("结束休息") { model.skipRest() }.buttonStyle(.bordered)
                }
            }.padding(17).background(.white.opacity(0.40), in: RoundedRectangle(cornerRadius: 18))
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("玻璃配色").font(.system(size: 12, weight: .medium))
                    Text(model.theme.name + " · 保持透明质感").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                ThemePicker(model: model)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("今日专注记录").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("每段连续专注 · 实时更新").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                if spans.isEmpty {
                    VStack(spacing: 9) {
                        Image(systemName: "sun.haze").font(.system(size: 27, weight: .ultraLight)).foregroundStyle(accent)
                        Text("从一小段专注开始。") .font(.system(size: 12)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(spans) { span in
                                HStack(spacing: 12) {
                                    Circle().fill(accent.opacity(0.65)).frame(width: 6, height: 6)
                                    Text(span.start, format: .dateTime.hour().minute())
                                    Text("—").foregroundStyle(.tertiary)
                                    Text(span.end, format: .dateTime.hour().minute())
                                    Spacer()
                                    Text(duration(span.duration)).monospacedDigit().foregroundStyle(.secondary)
                                }.font(.system(size: 11)).padding(.vertical, 11)
                                Divider().opacity(0.5)
                            }
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                Text(model.notificationStatus).font(.system(size: 10)).foregroundStyle(model.notificationsAllowed ? Color.secondary : Color.orange)
                Spacer()
                Button("测试提醒") { model.testReminder() }.font(.system(size: 10))
                Button("通知设置") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                }.font(.system(size: 10))
            }
            if let result = model.reminderTestStatus { Text(result).font(.system(size: 10)).foregroundStyle(.secondary) }
            if let error = model.notificationError { Text(error).font(.system(size: 10)).foregroundStyle(.orange) }
            Text("按本机日期统计，跨午夜的时段按天拆分；记录仅保存在这台 Mac。")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 30).padding(.top, 47).padding(.bottom, 23)
        .frame(width: 620, height: 700)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(colors: [accent.opacity(0.10), .white.opacity(0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $model.showingBreakVideoSettings) {
            BreakVideoSettings(model: model)
        }
        .alert("提前结束这次专注？", isPresented: $confirmEnd) {
            Button("取消", role: .cancel) {}
            Button("结束并进入休息") { model.endFocus() }
        } message: { Text("已专注的实际时长会保留，不计为完整一轮。正在计时则自动进入 5 分钟休息，暂停中则等待手动开始。") }
    }
    func duration(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        return value >= 60 ? "\(value / 60) 分 \(value % 60) 秒" : "\(value) 秒"
    }
}

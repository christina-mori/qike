import SwiftUI

struct DurationPicker: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("专注时长", selection: Binding(get: { model.engine.focusMinutes }, set: { model.changeFocusMinutes($0) })) {
                ForEach(TimerEngine.focusOptions, id: \.self) { value in Text("\(value) 分钟").tag(value) }
            }
            Text("立即应用本轮，已专注时间保留；若已达到所选时长，则进入休息。")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

struct ReminderView: View {
    @ObservedObject var model: AppModel
    let rest: Bool
    let test: Bool
    let dismiss: () -> Void
    var body: some View {
        VStack(spacing: 19) {
            Image(systemName: rest ? "drop.circle.fill" : "sun.max.circle.fill")
                .font(.system(size: 54, weight: .light)).foregroundStyle(model.theme.color)
            Text(test ? "提醒效果测试" : rest ? "该喝水、活动一下了" : "休息结束，重新出发")
                .font(.system(size: 24, weight: .semibold))
            Text(test ? "这是一条测试提醒，不会改变当前计时。\n正式到点时，会提醒你喝水、起身活动。" : rest ? "离开屏幕，放松肩颈，看看远处。\n5 分钟休息\(model.engine.running ? "已开始，结束后会再次提醒。" : "已准备好，点击开始后计时。")" : "新的 \(model.engine.focusMinutes) 分钟专注已经开始。\n一次，只做好一件事。")
                .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(6)
            Button("知道了") { dismiss() }.buttonStyle(.borderedProminent).tint(model.theme.color)
                .controlSize(.large).keyboardShortcut(.defaultAction)
            if !test { Button(model.engine.running ? "暂停计时" : "开始计时") {
                model.toggle()
                dismiss()
            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary) }
        }
        .padding(30).frame(width: 420, height: 340)
        .background(.regularMaterial).preferredColorScheme(.light)
    }
}

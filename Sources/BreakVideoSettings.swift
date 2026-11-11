import SwiftUI
import AppKit

struct BreakVideoSettings: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var invalid = false
    @FocusState private var editingLink: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("休息视频", systemImage: "play.rectangle")
                .font(.system(size: 20, weight: .semibold))
            Text("粘贴肩颈放松视频的链接。每次进入休息时，栖刻会用默认浏览器打开它。")
                .foregroundStyle(.secondary)
            HStack {
                TextField("https://…", text: $link)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("休息视频链接")
                    .focused($editingLink)
                    .onChange(of: link) { _, _ in invalid = false }
                Button("粘贴链接") {
                    guard let clipboard = NSPasteboard.general.string(forType: .string),
                          !clipboard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        invalid = true
                        return
                    }
                    link = AppModel.normalizedBreakVideoLink(clipboard) ?? clipboard
                    editingLink = true
                }
            }
            if invalid {
                Text("请输入完整的 https:// 或 http:// 视频链接。")
                    .foregroundStyle(.orange)
            }
            Text("留空并保存可关闭。视频能否自动播放取决于网站和浏览器。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") {
                    if model.saveBreakVideo(link) { dismiss() }
                    else { invalid = true }
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            link = model.breakVideoLink
            editingLink = true
        }
    }
}

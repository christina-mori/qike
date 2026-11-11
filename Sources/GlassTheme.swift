import SwiftUI
import AppKit

enum GlassTheme: String, CaseIterable, Identifiable {
    case silver, ocean, jade, violet, rose
    var id: String { rawValue }
    var name: String {
        switch self {
        case .silver: return "雾银"
        case .ocean: return "海蓝"
        case .jade: return "青玉"
        case .violet: return "烟紫"
        case .rose: return "玫瑰"
        }
    }
    var color: Color { Color(nsColor: native) }
    var native: NSColor {
        switch self {
        case .silver: return NSColor(red: 0.48, green: 0.54, blue: 0.63, alpha: 1)
        case .ocean: return NSColor(red: 0.21, green: 0.53, blue: 0.86, alpha: 1)
        case .jade: return NSColor(red: 0.20, green: 0.65, blue: 0.52, alpha: 1)
        case .violet: return NSColor(red: 0.60, green: 0.43, blue: 0.79, alpha: 1)
        case .rose: return NSColor(red: 0.81, green: 0.43, blue: 0.54, alpha: 1)
        }
    }
}

struct ThemePicker: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 15) {
            ForEach(GlassTheme.allCases) { theme in
                Button { withAnimation(.easeInOut(duration: 0.25)) { model.theme = theme } } label: {
                    Circle().fill(theme.color.opacity(0.45))
                        .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1))
                        .overlay {
                            if model.theme == theme {
                                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 27, height: 27)
                }.buttonStyle(.plain).help(theme.name).accessibilityLabel(theme.name)
            }
        }
    }
}

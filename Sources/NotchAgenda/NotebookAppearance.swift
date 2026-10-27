import SwiftUI

struct PaperPalette {
    var sheet = Color(red: 0.98, green: 0.96, blue: 0.91)
    var ink = Color(red: 0.25, green: 0.25, blue: 0.22)
    var faint = Color(red: 0.49, green: 0.47, blue: 0.41)
    var accent = Color(red: 0.58, green: 0.30, blue: 0.22)
    var line = Color(red: 0.76, green: 0.78, blue: 0.73)
    var cover = Color(red: 0.98, green: 0.96, blue: 0.91)
    var coverInk = Color(red: 0.25, green: 0.25, blue: 0.22)
    var coverMuted = Color(red: 0.49, green: 0.47, blue: 0.41)
}

extension NotebookAppearance {
    var palette: PaperPalette {
        var palette = PaperPalette()
        switch self {
        case .cream: break
        case .rose:
            palette.sheet = Color(red: 1, green: 0.96, blue: 0.95)
            palette.cover = Color(red: 0.95, green: 0.82, blue: 0.84)
            palette.accent = Color(red: 0.57, green: 0.25, blue: 0.35)
            palette.line = Color(red: 0.78, green: 0.64, blue: 0.67)
            palette.coverInk = Color(red: 0.34, green: 0.19, blue: 0.25)
            palette.coverMuted = Color(red: 0.46, green: 0.28, blue: 0.33)
        case .leather:
            palette.sheet = Color(red: 0.96, green: 0.93, blue: 0.86)
            palette.cover = Color(red: 0.28, green: 0.23, blue: 0.19)
            palette.coverInk = Color(red: 0.97, green: 0.91, blue: 0.77)
            palette.coverMuted = Color(red: 0.84, green: 0.77, blue: 0.65)
            palette.accent = Color(red: 0.38, green: 0.37, blue: 0.23)
            palette.line = Color(red: 0.70, green: 0.67, blue: 0.56)
        case .minimal:
            palette.sheet = Color(red: 0.98, green: 0.98, blue: 0.97)
            palette.cover = palette.sheet
            palette.accent = Color(red: 0.22, green: 0.25, blue: 0.28)
            palette.line = Color(red: 0.61, green: 0.63, blue: 0.64)
            palette.faint = Color(red: 0.43, green: 0.45, blue: 0.46)
            palette.coverMuted = palette.faint
        }
        return palette
    }
}

private struct PaperPaletteKey: EnvironmentKey { static let defaultValue = PaperPalette() }
private struct NotebookPaperKey: EnvironmentKey { static let defaultValue = NotebookPaper.ruled }
extension EnvironmentValues {
    var paperPalette: PaperPalette {
        get { self[PaperPaletteKey.self] }
        set { self[PaperPaletteKey.self] = newValue }
    }
    var notebookPaper: NotebookPaper {
        get { self[NotebookPaperKey.self] }
        set { self[NotebookPaperKey.self] = newValue }
    }
}

struct NotebookCoverTrim: View {
    let appearance: NotebookAppearance
    var body: some View {
        GeometryReader { geometry in
            let color = appearance.palette.coverMuted
            switch appearance {
            case .cream: EmptyView()
            case .rose:
                RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.22), lineWidth: 0.7).padding(7)
            case .leather:
                RoundedRectangle(cornerRadius: 9).strokeBorder(color.opacity(0.5), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])).padding(6)
            case .minimal:
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height - 1))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height - 1))
                    path.move(to: CGPoint(x: 10, y: 10))
                    path.addLine(to: CGPoint(x: 10, y: geometry.size.height - 10))
                }.stroke(color.opacity(0.5), lineWidth: 0.7)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct RuledPaper: View {
    @Environment(\.paperPalette) private var paper
    @Environment(\.notebookPaper) private var style
    var body: some View {
        Canvas { context, size in
            var lines = Path()
            switch style {
            case .ruled, .grid:
                let spacing: CGFloat = style == .grid ? 24 : 32
                for y in stride(from: CGFloat(1), to: size.height, by: spacing) {
                    lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y))
                }
                if style == .grid {
                    for x in stride(from: CGFloat(1), to: size.width, by: spacing) {
                        lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height))
                    }
                }
                context.stroke(lines, with: .color(paper.line.opacity(style == .grid ? 0.38 : 0.17)), lineWidth: 0.5)
            case .dotted:
                for y in stride(from: CGFloat(12), to: size.height, by: 20) {
                    for x in stride(from: CGFloat(12), to: size.width, by: 20) {
                        lines.addEllipse(in: CGRect(x: x, y: y, width: 1.5, height: 1.5))
                    }
                }
                context.fill(lines, with: .color(paper.faint.opacity(0.25)))
            case .plain: break
            }
            if style == .ruled {
                var margin = Path()
                margin.move(to: CGPoint(x: 25, y: 0)); margin.addLine(to: CGPoint(x: 25, y: size.height))
                context.stroke(margin, with: .color(paper.accent.opacity(0.17)), lineWidth: 0.7)
            }
        }.background(paper.sheet)
    }
}

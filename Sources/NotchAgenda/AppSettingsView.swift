import SwiftUI

struct AppSettingsView: View {
    let preferences: AppPreferences
    var close: (() -> Void)? = nil
    private var paper: PaperPalette { preferences.appearance.palette }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(preferences.text("設定")).font(.system(size: 27, design: .serif))
                Spacer()
                if let close { Button(preferences.text("完成"), action: close).accessibilityIdentifier("settings.close") }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(preferences.text("介面語言"), systemImage: "globe").font(.headline)
                        #if os(macOS)
                        LanguagePopup(preferences: preferences).frame(height: 34)
                        #else
                        Menu {
                            ForEach(AppLanguage.allCases) { language in
                                Button { preferences.setLanguage(language) } label: {
                                    if language == preferences.language { Label(language.name, systemImage: "checkmark") }
                                    else { Text(language.name) }
                                }
                            }
                        } label: {
                            HStack {
                                Text(preferences.language.name).font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .bold))
                            }.padding(12).foregroundStyle(.white)
                                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).menuIndicator(.hidden)
                            .accessibilityLabel(preferences.text("介面語言"))
                            .accessibilityValue(preferences.language.name).accessibilityIdentifier("settings.language")
                        #endif
                        Text(preferences.text("語言即時套用，筆記內容保持原文。"))
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                    }.padding(14).foregroundStyle(.white)
                        .background(Color(red: 0.17, green: 0.19, blue: 0.23), in: RoundedRectangle(cornerRadius: 12))
                    #if os(macOS)
                    Divider()
                    VStack(alignment: .leading, spacing: 9) {
                        Text(preferences.text("面板滑動速度")).font(.headline)
                        Picker(preferences.text("面板滑動速度"), selection: Binding(get: { preferences.hoverSpeed }, set: { preferences.setHoverSpeed($0) })) {
                            ForEach(HoverSpeed.allCases) { Text(preferences.text($0.title)).tag($0) }
                        }.pickerStyle(.segmented).labelsHidden().accessibilityIdentifier("settings.hoverSpeed")
                        Text(preferences.text("控制展開與收起動畫；滑鼠停留時間不變。"))
                            .font(.system(size: 11)).foregroundStyle(paper.faint)
                    }
                    #endif
                    Divider()
                    Text(preferences.text("筆記本外表")).font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(NotebookAppearance.allCases) { appearance in
                            Button { preferences.setAppearance(appearance) } label: {
                                VStack(spacing: 8) {
                                    appearancePreview(appearance)
                                    HStack(spacing: 5) {
                                        Text(preferences.text(appearance.title)).font(.system(size: 12))
                                        if preferences.appearance == appearance { Image(systemName: "checkmark.circle.fill").font(.system(size: 11)) }
                                    }.foregroundStyle(paper.ink)
                                }.padding(5).frame(maxWidth: .infinity)
                                    .background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
                                    .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(preferences.appearance == appearance ? paper.accent : .clear, lineWidth: 1.5) }
                            }.buttonStyle(.plain).accessibilityIdentifier("settings.appearance.\(appearance.id)")
                                .accessibilityAddTraits(preferences.appearance == appearance ? [.isSelected] : [])
                        }
                    }
                    Divider()
                    Text(preferences.text("內頁紙張")).font(.headline)
                    HStack(spacing: 9) {
                        ForEach(NotebookPaper.allCases) { style in
                            Button { preferences.setPaper(style) } label: {
                                VStack(spacing: 7) {
                                    RuledPaper().environment(\.notebookPaper, style).frame(height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(preferences.paper == style ? paper.accent : paper.line, lineWidth: 1) }
                                    Text(preferences.text(style.title)).font(.system(size: 11)).foregroundStyle(paper.ink)
                                }.frame(maxWidth: .infinity)
                            }.buttonStyle(.plain).accessibilityIdentifier("settings.paper.\(style.id)")
                                .accessibilityAddTraits(preferences.paper == style ? [.isSelected] : [])
                        }
                    }
                    Text(preferences.text("外表與內頁可自由配搭，即時套用並自動保存。")).font(.system(size: 11)).foregroundStyle(paper.faint)
                    if let error = preferences.errorMessage { Text(preferences.text(error)).font(.caption).foregroundStyle(.red) }
                }.padding(.horizontal, 2).padding(.bottom, 12)
            }
        }.padding(23)
            #if os(macOS)
            .frame(width: 420, height: 730)
            #else
            .frame(maxWidth: 520, maxHeight: .infinity)
            #endif
            .background(paper.sheet).foregroundStyle(paper.ink).tint(paper.accent)
            .preferredColorScheme(.light).environment(\.locale, preferences.locale)
            .environment(\.paperPalette, paper)
    }

    private func appearancePreview(_ appearance: NotebookAppearance) -> some View {
        let palette = appearance.palette
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NOTCHAGENDA").font(.system(size: 7, design: .monospaced)).tracking(1)
                Text(preferences.text("日常手記")).font(.system(size: 17, design: .serif))
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .foregroundStyle(palette.coverInk).background(palette.cover)
                .overlay { NotebookCoverTrim(appearance: appearance) }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(["每日", "週目標", "月目標"], id: \.self) { Text(preferences.text($0)).font(.system(size: 7)).frame(maxWidth: .infinity) }
                }.foregroundStyle(palette.accent)
                HStack(spacing: 7) {
                    Image(systemName: "square").font(.system(size: 9))
                    Text(preferences.text("留給今天的事")).font(.system(size: 10, design: .serif))
                }.foregroundStyle(palette.ink).padding(.horizontal, 5)
            }.padding(7).frame(maxWidth: .infinity).background(palette.sheet)
        }.clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(palette.line.opacity(0.5), lineWidth: 0.5) }
            .accessibilityHidden(true)
    }
}

#if os(macOS)
private struct LanguagePopup: NSViewRepresentable {
    let preferences: AppPreferences
    func makeCoordinator() -> Coordinator { Coordinator(preferences) }
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.appearance = NSAppearance(named: .darkAqua)
        button.controlSize = .large
        button.font = .systemFont(ofSize: 14, weight: .semibold)
        button.target = context.coordinator
        button.action = #selector(Coordinator.changed(_:))
        for language in AppLanguage.allCases {
            button.addItem(withTitle: language.name)
            button.lastItem?.representedObject = language.rawValue
        }
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.preferences = preferences
        button.selectItem(at: AppLanguage.allCases.firstIndex(of: preferences.language) ?? 0)
        button.setAccessibilityIdentifier("settings.language")
        button.setAccessibilityLabel(preferences.text("介面語言"))
        button.setAccessibilityValue(preferences.language.name)
    }
    @MainActor final class Coordinator: NSObject {
        var preferences: AppPreferences
        init(_ preferences: AppPreferences) { self.preferences = preferences }
        @objc func changed(_ sender: NSPopUpButton) {
            guard let value = sender.selectedItem?.representedObject as? String, let language = AppLanguage(rawValue: value) else { return }
            preferences.setLanguage(language)
        }
    }
}
#endif

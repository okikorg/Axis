import SwiftUI
import AppKit
import MarkdownUI

struct EditorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            if appState.showSearch && appState.activeFileURL != nil && !appState.isPreview {
                SearchBarView()
            }
            
            // Editor content
            Group {
                if appState.activeFileURL == nil {
                    EmptyEditorView()
                } else if appState.isPreview {
                    PreviewView(text: appState.currentText)
                } else {
                    EditorTextView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Colors.background)
    }
}

// MARK: - Search Bar

private struct SearchBarView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            // Search input
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .font(Theme.Fonts.icon)
                    .foregroundStyle(Theme.Colors.textMuted)
                
                TextField("Find in document...", text: $appState.editorSearchQuery)
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.uiSmall)
                    .foregroundStyle(Theme.Colors.text)
                    .focused($isSearchFocused)
                    .onSubmit {
                        appState.findNext()
                    }
                
                if !appState.editorSearchQuery.isEmpty {
                    // Match count
                    Text("\(appState.matchCount) found")
                        .font(Theme.Fonts.statusBar)
                        .foregroundStyle(Theme.Colors.textMuted)
                    
                    Button {
                        appState.editorSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(Theme.Fonts.icon)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(Theme.Colors.inputBackground)
            )
            .frame(maxWidth: 300)
            
            // Navigation buttons
            if appState.matchCount > 0 {
                HStack(spacing: Theme.Spacing.xs) {
                    Button {
                        appState.findPrevious()
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(Theme.Fonts.icon)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Previous match (Shift+Enter)")
                    
                    Text("\(appState.currentMatchIndex + 1)/\(appState.matchCount)")
                        .font(Theme.Fonts.statusBar)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .frame(minWidth: 40)
                    
                    Button {
                        appState.findNext()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(Theme.Fonts.icon)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Next match (Enter)")
                }
            }
            
            Spacer()
            
            // Close button
            Button {
                appState.closeSearch()
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.Fonts.icon)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Colors.backgroundTertiary)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
    }
}

// MARK: - Empty Editor

private struct EmptyEditorView: View {
    @EnvironmentObject private var appState: AppState
    
    private let shortcuts: [(key: String, description: String)] = [
        ("⌘ O", "Open folder"),
        ("⌘ N", "New file"),
        ("⌘ ⇧ N", "New folder"),
        ("⌘ S", "Save"),
        ("⌘ ⇧ P", "Toggle preview"),
        ("⌘ F", "Find in document"),
        ("⌘ +", "Zoom in"),
        ("⌘ −", "Zoom out"),
        ("⌘ 0", "Reset zoom"),
    ]
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            // Shortcuts list
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ForEach(shortcuts, id: \.key) { shortcut in
                    HStack(spacing: Theme.Spacing.l) {
                        Text(shortcut.key)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .frame(width: 60, alignment: .trailing)
                        
                        Text(shortcut.description)
                            .font(Theme.Fonts.uiSmall)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }
}

// MARK: - Editor Text View

private struct EditorTextView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var isFocused: Bool
    
    private var textBinding: Binding<String> {
        Binding(
            get: { appState.currentText },
            set: { appState.updateText($0) }
        )
    }
    
    private var zoomedFont: Font {
        let baseSize: CGFloat = 14
        let zoomedSize = baseSize * appState.zoomLevel
        return .system(size: zoomedSize, weight: .regular, design: .monospaced)
    }
    
    var body: some View {
        TextEditor(text: textBinding)
            .font(zoomedFont)
            .foregroundStyle(Theme.Colors.text)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.m)
            .focused($isFocused)
            .tint(Theme.Colors.textSelection)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
    }
}

// MARK: - Preview View

private struct PreviewView: View {
    @EnvironmentObject private var appState: AppState
    let text: String
    
    var body: some View {
        if text.isEmpty {
            Text("Nothing to preview")
                .font(Theme.Fonts.uiSmall)
                .foregroundStyle(Theme.Colors.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.background)
        } else {
            ScrollView {
                Markdown(text)
                    .markdownTheme(.minimalDark)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(appState.zoomLevel, anchor: .topLeading)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .topLeading
                    )
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background)
        }
    }
}

// MARK: - Minimal Dark Markdown Theme

extension MarkdownUI.Theme {
    static let minimalDark = MarkdownUI.Theme()
        .text {
            ForegroundColor(.init(hex: "d4d4d4"))
            FontSize(14)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(22)
                    FontWeight(.semibold)
                    ForegroundColor(.init(hex: "d4d4d4"))
                }
                .markdownMargin(top: 20, bottom: 8)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(18)
                    FontWeight(.semibold)
                    ForegroundColor(.init(hex: "d4d4d4"))
                }
                .markdownMargin(top: 16, bottom: 6)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(15)
                    FontWeight(.medium)
                    ForegroundColor(.init(hex: "d4d4d4"))
                }
                .markdownMargin(top: 12, bottom: 4)
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 0, bottom: 8)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(13)
            ForegroundColor(.init(hex: "888888"))
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(13)
                    ForegroundColor(.init(hex: "888888"))
                }
                .padding(10)
                .background(Color(hex: "222222"))
                .cornerRadius(4)
                .markdownMargin(top: 8, bottom: 8)
        }
        .link {
            ForegroundColor(.init(hex: "888888"))
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
}

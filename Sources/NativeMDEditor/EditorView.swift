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
    
    var body: some View {
        HighlightingTextEditor(
            text: Binding(
                get: { appState.currentText },
                set: { appState.updateText($0) }
            ),
            searchQuery: appState.editorSearchQuery,
            zoomLevel: appState.zoomLevel,
            currentMatchIndex: appState.currentMatchIndex
        )
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.m)
    }
}

// MARK: - Highlighting Text Editor (NSViewRepresentable)

private struct HighlightingTextEditor: NSViewRepresentable {
    @Binding var text: String
    let searchQuery: String
    let zoomLevel: CGFloat
    let currentMatchIndex: Int
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        // Configure text view
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindBar = false
        textView.backgroundColor = NSColor(Theme.Colors.background)
        textView.insertionPointColor = NSColor(Theme.Colors.text)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(Theme.Colors.textSelection)
        ]
        
        // Text container settings
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        
        // Scroll view settings
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        // Set delegate
        textView.delegate = context.coordinator
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Update text if changed externally
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
        
        // Apply font with zoom
        let fontSize = 14.0 * zoomLevel
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let textColor = NSColor(Theme.Colors.text)
        
        // Apply base styling
        let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
        textView.textStorage?.beginEditing()
        textView.textStorage?.setAttributes([
            .font: font,
            .foregroundColor: textColor
        ], range: fullRange)
        
        // Apply search highlighting
        if !searchQuery.isEmpty {
            let highlightColor = NSColor.systemYellow.withAlphaComponent(0.3)
            let currentHighlightColor = NSColor.systemYellow.withAlphaComponent(0.6)
            
            var matchIndex = 0
            var searchStart = text.startIndex
            
            while let range = text.range(of: searchQuery, options: .caseInsensitive, range: searchStart..<text.endIndex) {
                let nsRange = NSRange(range, in: text)
                
                let bgColor = matchIndex == currentMatchIndex ? currentHighlightColor : highlightColor
                textView.textStorage?.addAttribute(.backgroundColor, value: bgColor, range: nsRange)
                
                // Scroll to current match
                if matchIndex == currentMatchIndex {
                    textView.scrollRangeToVisible(nsRange)
                }
                
                searchStart = range.upperBound
                matchIndex += 1
            }
        }
        
        textView.textStorage?.endEditing()
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightingTextEditor
        
        init(_ parent: HighlightingTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
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
            FontSize(15)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(32)
                    FontWeight(.bold)
                    ForegroundColor(.init(hex: "e8e8e8"))
                }
                .markdownMargin(top: 24, bottom: 12)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(26)
                    FontWeight(.semibold)
                    ForegroundColor(.init(hex: "e0e0e0"))
                }
                .markdownMargin(top: 20, bottom: 10)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(21)
                    FontWeight(.semibold)
                    ForegroundColor(.init(hex: "d8d8d8"))
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(18)
                    FontWeight(.medium)
                    ForegroundColor(.init(hex: "d4d4d4"))
                }
                .markdownMargin(top: 14, bottom: 6)
        }
        .heading5 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(16)
                    FontWeight(.medium)
                    ForegroundColor(.init(hex: "d4d4d4"))
                }
                .markdownMargin(top: 12, bottom: 4)
        }
        .heading6 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(15)
                    FontWeight(.medium)
                    ForegroundColor(.init(hex: "b0b0b0"))
                }
                .markdownMargin(top: 10, bottom: 4)
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 0, bottom: 10)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(14)
            ForegroundColor(.init(hex: "a0a0a0"))
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(14)
                    ForegroundColor(.init(hex: "a0a0a0"))
                }
                .padding(12)
                .background(Color(hex: "222222"))
                .cornerRadius(4)
                .markdownMargin(top: 10, bottom: 10)
        }
        .link {
            ForegroundColor(.init(hex: "888888"))
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 3, bottom: 3)
        }
}

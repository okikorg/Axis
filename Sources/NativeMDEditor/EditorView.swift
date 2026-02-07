import SwiftUI
import AppKit

struct EditorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            if appState.showSearch && appState.activeFileURL != nil {
                SearchBarView()
            }

            // Editor content
            Group {
                if appState.activeFileURL == nil {
                    EmptyEditorView()
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
        ("⌘ B", "Bold"),
        ("⌘ I", "Italic"),
        ("⌘ E", "Inline code"),
        ("⌘ K", "Insert link"),
        ("⌘ ⇧ D", "Strikethrough"),
        ("⌘ 1/2/3", "Heading 1/2/3"),
        ("⌘ ⇧ H", "Cycle heading"),
        ("⌘ ⇧ T", "Toggle checkbox"),
        ("⌘ F", "Find in document"),
        ("⌘ S", "Save"),
        ("⌘ W", "Close tab"),
        ("⌘ /", "Toggle sidebar"),
        ("⌘ ⇧ F", "Distraction-free"),
        ("⌘ +/−/0", "Zoom in/out/reset"),
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
                            .frame(width: 72, alignment: .trailing)
                        
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
            selectionRange: Binding(
                get: { appState.selectionRange },
                set: { appState.selectionRange = $0 }
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
    @Binding var selectionRange: NSRange
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
            context.coordinator.isUpdatingText = true
            textView.string = text
            context.coordinator.isUpdatingText = false
        }

        // Apply selection from AppState (after formatting actions)
        let currentSel = textView.selectedRange()
        let maxLen = (textView.string as NSString).length
        let safeLoc = min(selectionRange.location, maxLen)
        let safeLen = min(selectionRange.length, maxLen - safeLoc)
        let safeSel = NSRange(location: safeLoc, length: safeLen)
        if safeSel != currentSel {
            context.coordinator.isUpdatingSelection = true
            textView.setSelectedRange(safeSel)
            context.coordinator.isUpdatingSelection = false
        }

        guard let storage = textView.textStorage else { return }

        let baseSize = 14.0 * zoomLevel
        let baseFont = NSFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
        let textColor = NSColor(Theme.Colors.text)
        let mutedColor = NSColor(Theme.Colors.textMuted)
        let secondaryColor = NSColor(Theme.Colors.textSecondary)
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.beginEditing()

        // Base style
        storage.setAttributes([
            .font: baseFont,
            .foregroundColor: textColor
        ], range: fullRange)

        let str = textView.string
        guard !str.isEmpty else {
            storage.endEditing()
            return
        }

        // -- WYSIWYM Markdown Styling --
        applyMarkdownStyles(storage: storage, text: str, baseSize: baseSize, textColor: textColor, mutedColor: mutedColor, secondaryColor: secondaryColor)

        // Search highlighting (on top of markdown styles)
        if !searchQuery.isEmpty {
            let highlightColor = NSColor.systemYellow.withAlphaComponent(0.3)
            let currentHighlightColor = NSColor.systemYellow.withAlphaComponent(0.6)
            var matchIndex = 0
            var searchStart = text.startIndex
            while let range = text.range(of: searchQuery, options: .caseInsensitive, range: searchStart..<text.endIndex) {
                let nsRange = NSRange(range, in: text)
                let bgColor = matchIndex == currentMatchIndex ? currentHighlightColor : highlightColor
                storage.addAttribute(.backgroundColor, value: bgColor, range: nsRange)
                if matchIndex == currentMatchIndex {
                    textView.scrollRangeToVisible(nsRange)
                }
                searchStart = range.upperBound
                matchIndex += 1
            }
        }

        storage.endEditing()
    }

    // MARK: - Markdown WYSIWYM Styling

    private func applyMarkdownStyles(storage: NSTextStorage, text: String, baseSize: CGFloat, textColor: NSColor, mutedColor: NSColor, secondaryColor: NSColor) {
        let nsText = text as NSString

        // Heading sizes relative to base
        let headingSizes: [CGFloat] = [2.0, 1.7, 1.4, 1.2, 1.1, 1.0]
        let headingWeights: [NSFont.Weight] = [.bold, .bold, .semibold, .semibold, .medium, .medium]

        // Headings: lines starting with # (1-6)
        applyLinePattern(storage: storage, nsText: nsText, pattern: "^(#{1,6})\\s+(.+)$") { match in
            let hashRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let level = min(hashRange.length, 6) - 1
            let size = baseSize * headingSizes[level]
            let weight = headingWeights[level]
            let headingFont = NSFont.systemFont(ofSize: size, weight: weight)
            // Dim the hash marks
            storage.addAttribute(.foregroundColor, value: mutedColor, range: hashRange)
            // Style the heading content
            storage.addAttributes([
                .font: headingFont,
                .foregroundColor: NSColor(Color(hex: "e8e8e8"))
            ], range: contentRange)
        }

        // Fenced code blocks: ``` ... ```
        applyPattern(storage: storage, nsText: nsText, pattern: "(?:^|\\n)(```[^\\n]*\\n[\\s\\S]*?\\n```)") { match in
            let range = match.range(at: 1)
            let codeFont = NSFont.monospacedSystemFont(ofSize: baseSize * 0.9, weight: .regular)
            storage.addAttributes([
                .font: codeFont,
                .foregroundColor: NSColor(Color(hex: "a0a0a0")),
                .backgroundColor: NSColor(Color(hex: "222222"))
            ], range: range)
        }

        // Bold + Italic: ***text*** or ___text___
        applyPattern(storage: storage, nsText: nsText, pattern: "(\\*{3}|_{3})(.+?)\\1") { match in
            let markerRange1 = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let markerRange2 = NSRange(location: contentRange.location + contentRange.length, length: markerRange1.length)
            let font = NSFont.systemFont(ofSize: baseSize, weight: .bold).withTraits(.italic)
            storage.addAttribute(.font, value: font, range: contentRange)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: markerRange1)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: markerRange2)
        }

        // Bold: **text** or __text__
        applyPattern(storage: storage, nsText: nsText, pattern: "(\\*{2}|_{2})(.+?)\\1") { match in
            let markerRange1 = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let markerRange2 = NSRange(location: contentRange.location + contentRange.length, length: markerRange1.length)
            let boldFont = NSFont.systemFont(ofSize: baseSize, weight: .bold)
            storage.addAttribute(.font, value: boldFont, range: contentRange)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: markerRange1)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: markerRange2)
        }

        // Italic: *text* or _text_ (single, not inside ** or __)
        applyPattern(storage: storage, nsText: nsText, pattern: "(?<![\\*_])(\\*|_)(?![\\*_])(.+?)(?<![\\*_])\\1(?![\\*_])") { match in
            let markerRange1 = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let markerRange2 = NSRange(location: contentRange.location + contentRange.length, length: markerRange1.length)
            let italicFont = NSFont.systemFont(ofSize: baseSize, weight: .regular).withTraits(.italic)
            storage.addAttribute(.font, value: italicFont, range: contentRange)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: markerRange1)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: markerRange2)
        }

        // Strikethrough: ~~text~~
        applyPattern(storage: storage, nsText: nsText, pattern: "(~~)(.+?)(~~)") { match in
            let open = match.range(at: 1)
            let content = match.range(at: 2)
            let close = match.range(at: 3)
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: content)
            storage.addAttribute(.foregroundColor, value: secondaryColor, range: content)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: open)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: close)
        }

        // Inline code: `text`
        applyPattern(storage: storage, nsText: nsText, pattern: "(?<!`)(`)([^`]+?)(`)(?!`)") { match in
            let open = match.range(at: 1)
            let content = match.range(at: 2)
            let close = match.range(at: 3)
            let codeFont = NSFont.monospacedSystemFont(ofSize: baseSize * 0.9, weight: .regular)
            storage.addAttributes([
                .font: codeFont,
                .foregroundColor: NSColor(Color(hex: "a0a0a0")),
                .backgroundColor: NSColor(Color(hex: "222222"))
            ], range: content)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: open)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: close)
        }

        // Blockquotes: lines starting with >
        applyLinePattern(storage: storage, nsText: nsText, pattern: "^(>+)\\s?(.*)$") { match in
            let markerRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let quoteFont = NSFont.systemFont(ofSize: baseSize, weight: .regular).withTraits(.italic)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: markerRange)
            storage.addAttributes([
                .font: quoteFont,
                .foregroundColor: secondaryColor
            ], range: contentRange)
        }

        // Links: [text](url)
        applyPattern(storage: storage, nsText: nsText, pattern: "(\\[)([^\\]]+)(\\])(\\()([^)]+)(\\))") { match in
            let openBracket = match.range(at: 1)
            let linkText = match.range(at: 2)
            let closeBracket = match.range(at: 3)
            let openParen = match.range(at: 4)
            let url = match.range(at: 5)
            let closeParen = match.range(at: 6)
            // Link text gets underline
            storage.addAttributes([
                .foregroundColor: NSColor(Color(hex: "6a9fb5")),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: linkText)
            // Dim the syntax
            for r in [openBracket, closeBracket, openParen, url, closeParen] {
                storage.addAttribute(.foregroundColor, value: mutedColor, range: r)
            }
        }

        // Images: ![alt](url)
        applyPattern(storage: storage, nsText: nsText, pattern: "(!\\[)([^\\]]*)(\\])(\\()([^)]+)(\\))") { match in
            let fullRange = match.range(at: 0)
            storage.addAttribute(.foregroundColor, value: mutedColor, range: fullRange)
            let altRange = match.range(at: 2)
            storage.addAttribute(.foregroundColor, value: secondaryColor, range: altRange)
        }

        // Horizontal rules: --- or *** or ___ (3+ chars on a line alone)
        applyLinePattern(storage: storage, nsText: nsText, pattern: "^([-*_]{3,})\\s*$") { match in
            let range = match.range(at: 0)
            storage.addAttributes([
                .foregroundColor: NSColor(Color(hex: "333333")),
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: NSColor(Color(hex: "555555"))
            ], range: range)
        }

        // Unordered list markers: - or * or + at line start
        applyLinePattern(storage: storage, nsText: nsText, pattern: "^(\\s*)([-*+])\\s") { match in
            let bulletRange = match.range(at: 2)
            storage.addAttribute(.foregroundColor, value: NSColor(Color(hex: "6a9fb5")), range: bulletRange)
        }

        // Ordered list markers: 1. 2. etc
        applyLinePattern(storage: storage, nsText: nsText, pattern: "^(\\s*)(\\d+\\.)\\s") { match in
            let numRange = match.range(at: 2)
            storage.addAttribute(.foregroundColor, value: NSColor(Color(hex: "6a9fb5")), range: numRange)
        }

        // Task lists: - [ ] or - [x]
        applyLinePattern(storage: storage, nsText: nsText, pattern: "^(\\s*[-*+]\\s)(\\[[ xX]\\])\\s") { match in
            let checkRange = match.range(at: 2)
            storage.addAttribute(.foregroundColor, value: NSColor(Color(hex: "6a9fb5")), range: checkRange)
        }
    }

    // MARK: - Regex Helpers

    private func applyPattern(storage: NSTextStorage, nsText: NSString, pattern: String, handler: (NSTextCheckingResult) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let fullRange = NSRange(location: 0, length: nsText.length)
        regex.enumerateMatches(in: nsText as String, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }
            handler(match)
        }
    }

    private func applyLinePattern(storage: NSTextStorage, nsText: NSString, pattern: String, handler: (NSTextCheckingResult) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        let fullRange = NSRange(location: 0, length: nsText.length)
        regex.enumerateMatches(in: nsText as String, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }
            handler(match)
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightingTextEditor
        var isUpdatingSelection = false
        var isUpdatingText = false

        // Patterns for list continuation
        // Checkbox: "  - [ ] " or "  - [x] "
        private static let checkboxPattern = try! NSRegularExpression(pattern: "^(\\s*[-*+]\\s)\\[[ xX]\\]\\s", options: [])
        // Unordered: "  - " or "  * " or "  + "
        private static let unorderedPattern = try! NSRegularExpression(pattern: "^(\\s*[-*+])\\s", options: [])
        // Ordered: "  1. " or "  12. "
        private static let orderedPattern = try! NSRegularExpression(pattern: "^(\\s*)(\\d+)\\.\\s", options: [])

        init(_ parent: HighlightingTextEditor) {
            self.parent = parent
        }

        // MARK: - Key Command Interception

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return handleNewline(textView)
            }
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                return handleDeleteBackward(textView)
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                return handleUnindent(textView)
            }
            return false
        }

        // MARK: - Newline: continue list / checkbox / numbered item

        private func handleNewline(_ textView: NSTextView) -> Bool {
            let nsText = textView.string as NSString
            let cursorLoc = textView.selectedRange().location
            let lineRange = nsText.lineRange(for: NSRange(location: cursorLoc, length: 0))
            let line = nsText.substring(with: lineRange)
            let trimmedLine = line.trimmingCharacters(in: .newlines)
            let matchRange = NSRange(location: 0, length: (trimmedLine as NSString).length)

            // Checkbox line
            if let match = Self.checkboxPattern.firstMatch(in: trimmedLine, range: matchRange) {
                let prefix = (trimmedLine as NSString).substring(with: match.range(at: 1))
                let contentAfterCheckbox = (trimmedLine as NSString).substring(from: match.range.length)

                // Empty checkbox item -> clear the line to plain text
                if contentAfterCheckbox.trimmingCharacters(in: .whitespaces).isEmpty {
                    return clearLinePrefix(textView: textView, lineRange: lineRange)
                }
                // Continue with unchecked checkbox
                let continuation = "\n\(prefix)[ ] "
                textView.insertText(continuation, replacementRange: textView.selectedRange())
                return true
            }

            // Ordered list line
            if let match = Self.orderedPattern.firstMatch(in: trimmedLine, range: matchRange) {
                let indent = (trimmedLine as NSString).substring(with: match.range(at: 1))
                let numStr = (trimmedLine as NSString).substring(with: match.range(at: 2))
                let contentAfterPrefix = (trimmedLine as NSString).substring(from: match.range.length)

                if contentAfterPrefix.trimmingCharacters(in: .whitespaces).isEmpty {
                    return clearLinePrefix(textView: textView, lineRange: lineRange)
                }
                let nextNum = (Int(numStr) ?? 0) + 1
                let continuation = "\n\(indent)\(nextNum). "
                textView.insertText(continuation, replacementRange: textView.selectedRange())
                return true
            }

            // Unordered list line
            if let match = Self.unorderedPattern.firstMatch(in: trimmedLine, range: matchRange) {
                let bullet = (trimmedLine as NSString).substring(with: match.range(at: 1))
                let contentAfterPrefix = (trimmedLine as NSString).substring(from: match.range.length)

                if contentAfterPrefix.trimmingCharacters(in: .whitespaces).isEmpty {
                    return clearLinePrefix(textView: textView, lineRange: lineRange)
                }
                let continuation = "\n\(bullet) "
                textView.insertText(continuation, replacementRange: textView.selectedRange())
                return true
            }

            return false // default newline behavior
        }

        // MARK: - Backspace: remove list prefix on empty list line

        private func handleDeleteBackward(_ textView: NSTextView) -> Bool {
            let sel = textView.selectedRange()
            // Only handle when there's no selection (just a cursor)
            guard sel.length == 0 else { return false }

            let nsText = textView.string as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: sel.location, length: 0))
            let line = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)
            let matchRange = NSRange(location: 0, length: (line as NSString).length)

            // Check if cursor is at the end of a prefix-only line
            // Checkbox with no content: "- [ ] "
            if let match = Self.checkboxPattern.firstMatch(in: line, range: matchRange) {
                let after = (line as NSString).substring(from: match.range.length)
                if after.trimmingCharacters(in: .whitespaces).isEmpty {
                    return clearLinePrefix(textView: textView, lineRange: lineRange)
                }
            }

            // Ordered list with no content: "1. "
            if let match = Self.orderedPattern.firstMatch(in: line, range: matchRange) {
                let after = (line as NSString).substring(from: match.range.length)
                if after.trimmingCharacters(in: .whitespaces).isEmpty {
                    return clearLinePrefix(textView: textView, lineRange: lineRange)
                }
            }

            // Unordered list with no content: "- "
            if let match = Self.unorderedPattern.firstMatch(in: line, range: matchRange) {
                let after = (line as NSString).substring(from: match.range.length)
                if after.trimmingCharacters(in: .whitespaces).isEmpty {
                    return clearLinePrefix(textView: textView, lineRange: lineRange)
                }
            }

            return false // default backspace behavior
        }

        // MARK: - Shift+Tab: unindent current or selected lines

        private func handleUnindent(_ textView: NSTextView) -> Bool {
            let nsText = textView.string as NSString
            let sel = textView.selectedRange()

            // Determine the range of lines affected
            let linesRange = nsText.lineRange(for: sel)
            let linesString = nsText.substring(with: linesRange)
            let lines = linesString.components(separatedBy: "\n")

            var resultLines: [String] = []
            var totalRemoved = 0
            var removedBeforeCursor = 0
            let cursorOffset = sel.location - linesRange.location
            var runningOffset = 0

            for line in lines {
                let removed: Int
                if line.hasPrefix("\t") {
                    resultLines.append(String(line.dropFirst()))
                    removed = 1
                } else {
                    // Remove up to 4 leading spaces
                    let spacesToRemove = min(line.prefix(while: { $0 == " " }).count, 4)
                    resultLines.append(String(line.dropFirst(spacesToRemove)))
                    removed = spacesToRemove
                }

                // Track how many characters were removed before the cursor position
                if runningOffset + line.count < cursorOffset {
                    removedBeforeCursor += removed
                } else if runningOffset <= cursorOffset {
                    // Cursor is on this line
                    let posInLine = cursorOffset - runningOffset
                    removedBeforeCursor += min(removed, posInLine)
                }

                totalRemoved += removed
                runningOffset += line.count + 1 // +1 for the \n
            }

            guard totalRemoved > 0 else { return true } // nothing to unindent, but consume the event

            let newText = resultLines.joined(separator: "\n")
            textView.insertText(newText, replacementRange: linesRange)

            // Restore selection, adjusted for removed characters
            let newSelLoc = max(linesRange.location, sel.location - removedBeforeCursor)
            if sel.length > 0 {
                // Adjust selection to account for removed indentation
                let endOfOriginalSel = sel.location + sel.length
                let endLinesRange = linesRange.location + linesRange.length
                let trailingUnselected = endLinesRange - endOfOriginalSel
                let newEnd = linesRange.location + newText.count - trailingUnselected
                let adjustedLen = max(0, newEnd - Int(newSelLoc))
                textView.setSelectedRange(NSRange(location: newSelLoc, length: adjustedLen))
            } else {
                textView.setSelectedRange(NSRange(location: newSelLoc, length: 0))
            }

            return true
        }

        // Replace the current line with just its leading whitespace (blank line)
        private func clearLinePrefix(textView: NSTextView, lineRange: NSRange) -> Bool {
            let nsText = textView.string as NSString
            let line = nsText.substring(with: lineRange)
            let leadingWhitespace = line.prefix(while: { $0 == " " || $0 == "\t" })
            // Keep trailing newline if the line had one
            let hasTrailingNewline = line.hasSuffix("\n")
            let replacement = String(leadingWhitespace) + (hasTrailingNewline ? "\n" : "")
            textView.insertText(replacement, replacementRange: lineRange)
            // Place cursor after the leading whitespace
            let newCursor = lineRange.location + leadingWhitespace.count
            textView.setSelectedRange(NSRange(location: newCursor, length: 0))
            return true
        }

        // MARK: - Smart Paste: auto-wrap URLs as markdown links

        private static let urlPattern = try! NSRegularExpression(
            pattern: "^https?://\\S+$", options: [.caseInsensitive]
        )

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedRange: NSRange, replacementString: String?) -> Bool {
            guard let pasted = replacementString else { return true }
            // Only intercept paste (multi-char replacement or insertion)
            guard pasted.count > 1 else { return true }
            let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
            let range = NSRange(location: 0, length: (trimmed as NSString).length)
            guard Self.urlPattern.firstMatch(in: trimmed, range: range) != nil else { return true }

            // It's a URL paste
            if affectedRange.length > 0 {
                // Text is selected -- wrap as [selected](url)
                let selected = (textView.string as NSString).substring(with: affectedRange)
                let link = "[\(selected)](\(trimmed))"
                textView.insertText(link, replacementRange: affectedRange)
            } else {
                // No selection -- insert [url](url)
                let link = "[\(trimmed)](\(trimmed))"
                textView.insertText(link, replacementRange: affectedRange)
                // Select the link text so user can rename it
                let linkTextStart = affectedRange.location + 1
                let linkTextLen = (trimmed as NSString).length
                textView.setSelectedRange(NSRange(location: linkTextStart, length: linkTextLen))
            }
            return false
        }

        // MARK: - Text & Selection Sync

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingText else { return }
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
            syncSelectionToParent(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdatingSelection, !isUpdatingText else { return }
            guard let textView = notification.object as? NSTextView else { return }
            syncSelectionToParent(textView)
        }

        private func syncSelectionToParent(_ textView: NSTextView) {
            let sel = textView.selectedRange()
            if parent.selectionRange != sel {
                parent.selectionRange = sel
            }
        }
    }
}

// MARK: - NSFont Trait Helper

private extension NSFont {
    func withTraits(_ traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}

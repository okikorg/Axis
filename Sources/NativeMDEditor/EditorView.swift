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
        ("⌘ ⇧ E", "Code block"),
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
            currentMatchIndex: appState.currentMatchIndex,
            appState: appState
        )
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.m)
    }
}

// MARK: - Checkbox Layout Manager

private class CheckboxLayoutManager: NSLayoutManager {
    private static let checkboxRegex = try! NSRegularExpression(
        pattern: "^(\\s*[-*+]\\s)(\\[)([ xX])(\\])",
        options: .anchorsMatchLines
    )

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)

        guard let storage = textStorage,
              let tc = textContainers.first else { return }

        let rawRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let nsText = storage.string as NSString
        guard nsText.length > 0 else { return }
        // Expand to full lines so ^ anchor matches correctly
        let charRange = nsText.lineRange(for: rawRange)

        Self.checkboxRegex.enumerateMatches(in: nsText as String, range: charRange) { result, _, _ in
            guard let match = result else { return }

            let bracketOpen = match.range(at: 2)
            let checkChar = match.range(at: 3)
            let bracketClose = match.range(at: 4)

            let fullRange = NSRange(
                location: bracketOpen.location,
                length: bracketClose.location + bracketClose.length - bracketOpen.location
            )

            let ch = nsText.substring(with: checkChar)
            let isChecked = ch == "x" || ch == "X"

            let gr = self.glyphRange(forCharacterRange: fullRange, actualCharacterRange: nil)
            guard gr.location != NSNotFound else { return }
            let rect = self.boundingRect(forGlyphRange: gr, in: tc)
                .offsetBy(dx: origin.x, dy: origin.y)

            self.drawCheckbox(in: rect, checked: isChecked)
        }
    }

    private func drawCheckbox(in rect: CGRect, checked: Bool) {
        let size = min(rect.height * 0.65, 14)
        let box = CGRect(
            x: rect.midX - size / 2,
            y: rect.midY - size / 2,
            width: size,
            height: size
        ).integral

        NSGraphicsContext.saveGraphicsState()

        let path = NSBezierPath(roundedRect: box, xRadius: 3, yRadius: 3)

        if checked {
            NSColor.controlAccentColor.setFill()
            path.fill()

            // Checkmark
            let i = size * 0.25
            let check = NSBezierPath()
            check.move(to: NSPoint(x: box.minX + i, y: box.midY))
            check.line(to: NSPoint(x: box.midX - 1, y: box.maxY - i))
            check.line(to: NSPoint(x: box.maxX - i, y: box.minY + i))
            NSColor.white.setStroke()
            check.lineWidth = 1.5
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            check.stroke()
        } else {
            NSColor.tertiaryLabelColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }

        NSGraphicsContext.restoreGraphicsState()
    }
}

// MARK: - Highlighting Text Editor (NSViewRepresentable)

private struct HighlightingTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectionRange: NSRange
    let searchQuery: String
    let zoomLevel: CGFloat
    let currentMatchIndex: Int
    let appState: AppState
    
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
        textView.isAutomaticTextCompletionEnabled = false
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

        // Ghost text label for inline autocomplete
        let ghostLabel = NSTextField(labelWithString: "")
        ghostLabel.textColor = NSColor.gray.withAlphaComponent(0.4)
        ghostLabel.backgroundColor = .clear
        ghostLabel.isBordered = false
        ghostLabel.isEditable = false
        ghostLabel.isSelectable = false
        ghostLabel.isHidden = true
        textView.addSubview(ghostLabel)
        context.coordinator.ghostLabel = ghostLabel

        // Replace layout manager with custom checkbox-rendering one
        let textContainer = textView.textContainer!
        let textStorage = textView.textStorage!
        if let oldLM = textView.layoutManager {
            oldLM.removeTextContainer(at: 0)
            textStorage.removeLayoutManager(oldLM)
        }
        let checkboxLM = CheckboxLayoutManager()
        checkboxLM.allowsNonContiguousLayout = true
        textStorage.addLayoutManager(checkboxLM)
        checkboxLM.addTextContainer(textContainer)

        // Set delegate
        textView.delegate = context.coordinator

        // Gesture recognizer for clicking checkboxes
        let checkboxGesture = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleCheckboxClick(_:))
        )
        checkboxGesture.delegate = context.coordinator
        textView.addGestureRecognizer(checkboxGesture)

        // Store reference so AppState can apply undo-safe edits directly
        appState.editorTextView = textView

        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update text if changed externally (e.g. formatting commands from AppState)
        // Use direct assignment with undo disabled — this keeps NSTextView's
        // built-in undo stack clean for normal keystrokes.
        if textView.string != text {
            context.coordinator.isUpdatingText = true
            textView.undoManager?.disableUndoRegistration()
            textView.string = text
            textView.undoManager?.enableUndoRegistration()
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

        // Update appearance-dependent colors
        textView.backgroundColor = NSColor(Theme.Colors.background)
        textView.insertionPointColor = NSColor(Theme.Colors.text)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(Theme.Colors.textSelection)
        ]

        guard let storage = textView.textStorage else { return }

        let baseSize = 14.0 * zoomLevel
        let baseFont = NSFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
        let textColor = NSColor(Theme.Colors.text)
        let mutedColor = NSColor(Theme.Colors.textMuted)
        let secondaryColor = NSColor(Theme.Colors.textSecondary)
        let fullRange = NSRange(location: 0, length: storage.length)

        // Disable undo registration for styling — attribute changes on
        // the full range would otherwise be undoable, causing Cmd+Z to
        // select-all instead of undoing the last keystroke.
        textView.undoManager?.disableUndoRegistration()

        storage.beginEditing()

        // Base style
        storage.setAttributes([
            .font: baseFont,
            .foregroundColor: textColor
        ], range: fullRange)

        let str = textView.string
        guard !str.isEmpty else {
            storage.endEditing()
            textView.undoManager?.enableUndoRegistration()
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

        textView.undoManager?.enableUndoRegistration()

        // Update inline ghost text position (font may have changed with zoom)
        context.coordinator.updateGhostText(textView)
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
                .foregroundColor: NSColor(Theme.Colors.mdHeading)
            ], range: contentRange)
        }

        // Fenced code blocks: ``` ... ``` with syntax highlighting
        applyPattern(storage: storage, nsText: nsText, pattern: "(?:^|\\n)(```([^\\n]*)\\n([\\s\\S]*?)\\n```)") { match in
            let blockRange = match.range(at: 1)
            let langRange = match.range(at: 2)
            let codeRange = match.range(at: 3)
            let codeFont = NSFont.monospacedSystemFont(ofSize: baseSize * 0.9, weight: .regular)
            let codeBg = NSColor(Theme.Colors.mdCodeBg)

            // Base styling for entire block
            storage.addAttributes([
                .font: codeFont,
                .foregroundColor: NSColor(Theme.Colors.mdCodeText),
                .backgroundColor: codeBg
            ], range: blockRange)

            // Dim fence markers
            let fenceMuted = NSColor(Theme.Colors.mdFenceMuted)
            let openLen = codeRange.location - blockRange.location
            if openLen > 0 {
                storage.addAttribute(.foregroundColor, value: fenceMuted, range: NSRange(location: blockRange.location, length: openLen))
            }
            // Language tag slightly brighter
            if langRange.length > 0 {
                storage.addAttribute(.foregroundColor, value: NSColor(Theme.Colors.mdLangTag), range: langRange)
            }
            // Closing fence
            let closeStart = codeRange.location + codeRange.length
            let closeLen = (blockRange.location + blockRange.length) - closeStart
            if closeLen > 0 {
                storage.addAttribute(.foregroundColor, value: fenceMuted, range: NSRange(location: closeStart, length: closeLen))
            }

            // Apply syntax highlighting to code content
            if codeRange.length > 0 {
                let lang = langRange.length > 0 ? nsText.substring(with: langRange).trimmingCharacters(in: .whitespaces).lowercased() : ""
                applySyntaxHighlighting(storage: storage, nsText: nsText, codeRange: codeRange, language: lang, baseSize: baseSize)
            }
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
                .foregroundColor: NSColor(Theme.Colors.mdInlineCode),
                .backgroundColor: NSColor(Theme.Colors.mdInlineCodeBg)
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
                .foregroundColor: NSColor(Theme.Colors.mdLink),
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
                .foregroundColor: NSColor(Theme.Colors.mdHrLine),
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: NSColor(Theme.Colors.mdHrStrike)
            ], range: range)
        }

        // Unordered list markers: - or * or + at line start
        applyLinePattern(storage: storage, nsText: nsText, pattern: "^(\\s*)([-*+])\\s") { match in
            let bulletRange = match.range(at: 2)
            storage.addAttribute(.foregroundColor, value: NSColor(Theme.Colors.mdLink), range: bulletRange)
        }

        // Ordered list markers: 1. 2. etc
        applyLinePattern(storage: storage, nsText: nsText, pattern: "^(\\s*)(\\d+\\.)\\s") { match in
            let numRange = match.range(at: 2)
            storage.addAttribute(.foregroundColor, value: NSColor(Theme.Colors.mdLink), range: numRange)
        }

        // Task lists: - [ ] or - [x] — visual checkboxes drawn by CheckboxLayoutManager
        applyLinePattern(storage: storage, nsText: nsText, pattern: "^(\\s*)([-*+]\\s)(\\[)([ xX])(\\])\\s(.*)$") { match in
            let bulletRange = match.range(at: 2)
            let bracketOpen = match.range(at: 3)
            let checkChar = match.range(at: 4)
            let bracketClose = match.range(at: 5)
            let contentRange = match.range(at: 6)
            let ch = nsText.substring(with: checkChar)
            let isChecked = ch == "x" || ch == "X"
            // Hide bullet and brackets — checkbox shape is drawn by the layout manager
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: bulletRange)
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: bracketOpen)
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: checkChar)
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: bracketClose)
            // Dim and strikethrough completed items
            if isChecked && contentRange.length > 0 {
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                storage.addAttribute(.foregroundColor, value: mutedColor, range: contentRange)
            }
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

    // MARK: - Code Block Syntax Highlighting

    private func applySyntaxHighlighting(storage: NSTextStorage, nsText: NSString, codeRange: NSRange, language: String, baseSize: CGFloat) {
        let codeString = nsText.substring(with: codeRange) as NSString
        let offset = codeRange.location
        let boldCodeFont = NSFont.monospacedSystemFont(ofSize: baseSize * 0.9, weight: .semibold)

        // Token colors
        let keywordColor = NSColor(Theme.Colors.syntaxKeyword)
        let typeColor = NSColor(Theme.Colors.syntaxType)
        let stringColor = NSColor(Theme.Colors.syntaxString)
        let commentColor = NSColor(Theme.Colors.syntaxComment)
        let numberColor = NSColor(Theme.Colors.syntaxNumber)
        let funcColor = NSColor(Theme.Colors.syntaxFunc)

        // 1. Keywords (lowest priority — overridden by strings & comments)
        let kw = Self.keywords(for: language)
        if !kw.isEmpty {
            let caseFlag = ["sql"].contains(language) ? "(?i)" : ""
            let pattern = caseFlag + "\\b(" + kw.joined(separator: "|") + ")\\b"
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: pattern, color: keywordColor, font: boldCodeFont)
        }

        // 2. Types / built-ins
        let tp = Self.types(for: language)
        if !tp.isEmpty {
            let pattern = "\\b(" + tp.joined(separator: "|") + ")\\b"
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: pattern, color: typeColor)
        }

        // 3. Numbers (hex, binary, decimal)
        applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: "\\b0[xX][0-9a-fA-F_]+\\b", color: numberColor)
        applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: "\\b0[bB][01_]+\\b", color: numberColor)
        applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: "\\b\\d[\\d_]*(\\.[\\d_]+)?([eE][+-]?\\d+)?\\b", color: numberColor)

        // 4. Function calls (word before parenthesis)
        if !["json", "yaml", "yml", "toml", "css", "scss", "less", "html", "xml", "svg", "markdown", "md"].contains(language) {
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: "\\b([a-zA-Z_]\\w*)\\s*(?=\\()", color: funcColor, group: 1)
        }

        // 5. Decorators / annotations (@name)
        if ["python", "py", "java", "kotlin", "kt", "typescript", "ts"].contains(language) {
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: "@[a-zA-Z_]\\w*", color: funcColor)
        }

        // 6. Language-specific extras
        if ["html", "xml", "svg"].contains(language) {
            let tagColor = NSColor(Theme.Colors.syntaxTag)
            let attrColor = NSColor(Theme.Colors.syntaxAttr)
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: "</?([a-zA-Z][a-zA-Z0-9-]*)", color: tagColor, group: 1)
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: "\\s([a-zA-Z-]+)\\s*=", color: attrColor, group: 1)
        }

        if ["css", "scss", "less"].contains(language) {
            let propertyColor = NSColor(Theme.Colors.syntaxProperty)
            let selectorColor = NSColor(Theme.Colors.syntaxSelector)
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: "\\b([a-z-]+)\\s*:", color: propertyColor, group: 1)
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: "[.#][a-zA-Z_][a-zA-Z0-9_-]*", color: selectorColor)
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: "\\b\\d+(\\.\\d+)?(px|em|rem|vh|vw|%|s|ms|deg|fr)\\b", color: numberColor)
        }

        if language == "json" {
            let keyColor = NSColor(Theme.Colors.syntaxJsonKey)
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: "(\"[^\"]*\")\\s*:", color: keyColor, group: 1)
        }

        // 7. Strings (override keywords inside strings)
        for pattern in Self.stringPatterns(for: language) {
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: pattern, color: stringColor)
        }

        // 8. Comments (highest priority — override everything)
        for pattern in Self.commentPatterns(for: language) {
            applyCodeToken(storage: storage, text: codeString, offset: offset, pattern: pattern, color: commentColor)
        }
    }

    private func applyCodeToken(storage: NSTextStorage, text: NSString, offset: Int, pattern: String, color: NSColor, font: NSFont? = nil, group: Int = 0) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let range = NSRange(location: 0, length: text.length)
        regex.enumerateMatches(in: text as String, options: [], range: range) { match, _, _ in
            guard let match = match else { return }
            let tokenRange = match.range(at: group)
            guard tokenRange.location != NSNotFound else { return }
            let adjusted = NSRange(location: tokenRange.location + offset, length: tokenRange.length)
            storage.addAttribute(.foregroundColor, value: color, range: adjusted)
            if let font = font {
                storage.addAttribute(.font, value: font, range: adjusted)
            }
        }
    }

    // MARK: - Language Definitions

    private static func keywords(for lang: String) -> [String] {
        switch lang {
        case "swift":
            return "func var let class struct enum protocol extension import return if else guard switch case default for while repeat break continue do try catch throw throws defer where in as is self super init nil true false typealias static override mutating lazy weak unowned convenience required final open public internal fileprivate private some any async await actor inout willSet didSet get set subscript".components(separatedBy: " ")
        case "python", "py":
            return "def class if elif else for while break continue return yield try except finally raise with as import from pass lambda and or not in is True False None global nonlocal del assert async await".components(separatedBy: " ")
        case "javascript", "js":
            return "var let const function return if else for while do switch case default break continue try catch finally throw new delete typeof instanceof void this class extends super import export from async await yield of in with true false null undefined static get set".components(separatedBy: " ")
        case "typescript", "ts":
            return "var let const function return if else for while do switch case default break continue try catch finally throw new delete typeof instanceof void this class extends super import export from async await yield of in with true false null undefined static get set type interface enum declare abstract as namespace implements keyof readonly".components(separatedBy: " ")
        case "rust", "rs":
            return "fn let mut const static struct enum impl trait type mod use pub crate self Self as if else match for while loop break continue return where in ref move async await dyn unsafe extern true false macro_rules".components(separatedBy: " ")
        case "go", "golang":
            return "func var const type struct interface map chan go select switch case default if else for range break continue return defer package import true false nil fallthrough goto".components(separatedBy: " ")
        case "c":
            return "int char float double void long short unsigned signed const static extern auto register volatile inline struct union enum typedef sizeof return if else for while do switch case default break continue goto true false NULL".components(separatedBy: " ")
        case "cpp", "c++", "cc", "cxx":
            return "int char float double void long short unsigned signed const static extern auto register volatile inline struct union enum typedef sizeof return if else for while do switch case default break continue goto class public private protected virtual override new delete this template typename namespace using try catch throw constexpr nullptr true false noexcept decltype".components(separatedBy: " ")
        case "java":
            return "public private protected static final abstract synchronized volatile transient native class interface enum extends implements new this super return if else for while do switch case default break continue try catch finally throw throws import package instanceof void null true false assert var".components(separatedBy: " ")
        case "kotlin", "kt":
            return "fun val var class object interface enum data sealed companion return if else when for while do break continue try catch finally throw import package is as in by lazy init true false null override open abstract internal private protected public suspend inline".components(separatedBy: " ")
        case "ruby", "rb":
            return "def class module if elsif else unless case when while until for do end begin rescue ensure raise return yield next break redo retry in then self super nil true false and or not require include extend puts print attr_reader attr_writer attr_accessor".components(separatedBy: " ")
        case "php":
            return "function class interface trait extends implements new return if else elseif for foreach while do switch case default break continue try catch finally throw use namespace public private protected static final abstract const var echo print true false null self parent".components(separatedBy: " ")
        case "bash", "sh", "shell", "zsh", "fish":
            return "if then else elif fi for while until do done case esac in function return exit break continue source export local readonly declare set unset shift eval exec trap true false echo printf read test".components(separatedBy: " ")
        case "sql":
            return "select from where and or not insert into values update set delete create table alter drop index view join inner left right outer full cross on as in between like is null order by group having limit offset union all distinct exists case when then else end count sum avg min max primary key foreign references unique check default constraint begin commit rollback with grant revoke truncate".components(separatedBy: " ")
        case "lua":
            return "and break do else elseif end false for function goto if in local nil not or repeat return then true until while".components(separatedBy: " ")
        case "r":
            return "if else for while repeat break next return function in TRUE FALSE NULL NA Inf NaN library require source".components(separatedBy: " ")
        case "scala":
            return "abstract case catch class def do else extends final finally for if implicit import lazy match new null object override package private protected return sealed super this throw trait try type val var while with yield true false".components(separatedBy: " ")
        case "dart":
            return "abstract as assert async await break case catch class const continue default do else enum export extends extension external factory false final finally for get hide if implements import in interface is late library mixin new null on operator part return set show static super switch this throw true try typedef var void while with yield".components(separatedBy: " ")
        case "haskell", "hs":
            return "module where import qualified as hiding do if then else case of let in type data newtype class instance deriving True False Nothing Just".components(separatedBy: " ")
        case "elixir", "ex":
            return "def defp defmodule defprotocol defimpl defmacro defstruct do end if else unless case cond when fn for with import require alias use raise throw catch true false nil".components(separatedBy: " ")
        case "yaml", "yml":
            return "true false null yes no on off".components(separatedBy: " ")
        case "json":
            return "true false null".components(separatedBy: " ")
        case "toml":
            return "true false".components(separatedBy: " ")
        case "css", "scss", "less":
            return "important media keyframes charset import supports page namespace".components(separatedBy: " ")
        default:
            // Generic fallback for unknown languages
            return "if else for while do return break continue switch case default true false null function class struct enum import export var let const type interface try catch throw finally async await yield void static public private this self super nil".components(separatedBy: " ")
        }
    }

    private static func types(for lang: String) -> [String] {
        switch lang {
        case "swift":
            return "Int String Bool Double Float Array Dictionary Set Optional Result Error Void Any AnyObject Character UInt CGFloat URL Data Date".components(separatedBy: " ")
        case "python", "py":
            return "int str float bool list dict set tuple type object range bytes bytearray complex frozenset Exception".components(separatedBy: " ")
        case "javascript", "js", "typescript", "ts":
            return "number string boolean object symbol bigint any unknown never void undefined Array Map Set Promise Date RegExp Error Function Object Number String Boolean".components(separatedBy: " ")
        case "rust", "rs":
            return "i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char String Vec Box Option Result HashMap HashSet Rc Arc".components(separatedBy: " ")
        case "go", "golang":
            return "int int8 int16 int32 int64 uint uint8 uint16 uint32 uint64 float32 float64 complex64 complex128 bool byte rune string error".components(separatedBy: " ")
        case "c":
            return "int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t size_t ssize_t ptrdiff_t bool FILE".components(separatedBy: " ")
        case "cpp", "c++", "cc", "cxx":
            return "string vector map set unordered_map unordered_set array deque list queue stack pair tuple optional variant any shared_ptr unique_ptr weak_ptr size_t".components(separatedBy: " ")
        case "java":
            return "int long short byte float double char boolean String Integer Long Short Byte Float Double Character Boolean Object List ArrayList Map HashMap Set HashSet Array Collection Iterator Optional Stream".components(separatedBy: " ")
        case "kotlin", "kt":
            return "Int Long Short Byte Float Double Char Boolean String Unit Any Nothing Array List MutableList Map MutableMap Set MutableSet Pair Triple".components(separatedBy: " ")
        case "ruby", "rb":
            return "Integer Float String Symbol Array Hash Set Range Regexp IO File Dir Time Date Struct Class Module".components(separatedBy: " ")
        case "php":
            return "int float string bool array object callable iterable void mixed never".components(separatedBy: " ")
        case "dart":
            return "int double num String bool List Map Set Future Stream Iterable Duration DateTime RegExp Symbol Type Object".components(separatedBy: " ")
        default:
            return []
        }
    }

    private static func commentPatterns(for lang: String) -> [String] {
        switch lang {
        case "python", "py", "ruby", "rb", "bash", "sh", "shell", "zsh", "fish", "r", "yaml", "yml", "toml", "elixir", "ex":
            return ["#[^\\n]*"]
        case "sql":
            return ["--[^\\n]*", "/\\*[\\s\\S]*?\\*/"]
        case "html", "xml", "svg":
            return ["<!--[\\s\\S]*?-->"]
        case "css", "scss", "less":
            return ["/\\*[\\s\\S]*?\\*/", "//[^\\n]*"]
        case "lua":
            return ["--\\[\\[[\\s\\S]*?\\]\\]", "--[^\\n]*"]
        case "haskell", "hs":
            return ["\\{-[\\s\\S]*?-\\}", "--[^\\n]*"]
        default:
            // C-style (Swift, JS, TS, Rust, Go, C, C++, Java, Kotlin, PHP, Dart, Scala, etc.)
            return ["//[^\\n]*", "/\\*[\\s\\S]*?\\*/"]
        }
    }

    private static func stringPatterns(for lang: String) -> [String] {
        switch lang {
        case "python", "py":
            return [
                "\"\"\"[\\s\\S]*?\"\"\"",
                "'''[\\s\\S]*?'''",
                "\"(?:[^\"\\\\\\n]|\\\\.)*\"",
                "'(?:[^'\\\\\\n]|\\\\.)*'"
            ]
        case "javascript", "js", "typescript", "ts":
            return [
                "`(?:[^`\\\\]|\\\\.)*`",
                "\"(?:[^\"\\\\\\n]|\\\\.)*\"",
                "'(?:[^'\\\\\\n]|\\\\.)*'"
            ]
        case "rust", "rs":
            return [
                "r#\"[\\s\\S]*?\"#",
                "r\"[^\"]*\"",
                "\"(?:[^\"\\\\\\n]|\\\\.)*\"",
                "'[^'\\\\]'",
                "'\\\\.'",
            ]
        case "bash", "sh", "shell", "zsh", "fish":
            return [
                "\"(?:[^\"\\\\]|\\\\.)*\"",
                "'[^']*'"
            ]
        case "sql":
            return ["'(?:[^'\\\\]|\\\\.)*'"]
        case "html", "xml", "svg":
            return ["\"[^\"]*\"", "'[^']*'"]
        case "json":
            return ["\"(?:[^\"\\\\]|\\\\.)*\""]
        case "ruby", "rb":
            return [
                "\"(?:[^\"\\\\]|\\\\.)*\"",
                "'(?:[^'\\\\]|\\\\.)*'"
            ]
        default:
            // Most C-family languages
            return [
                "\"(?:[^\"\\\\\\n]|\\\\.)*\"",
                "'(?:[^'\\\\\\n]|\\\\.)*'"
            ]
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate, NSGestureRecognizerDelegate {
        var parent: HighlightingTextEditor
        var isUpdatingSelection = false
        var isUpdatingText = false

        // Ghost text autocomplete
        var ghostLabel: NSTextField?
        private var ghostSuggestion: String?
        private static let wordRegex = try! NSRegularExpression(pattern: "\\b[a-zA-Z]\\w+\\b")

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
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                return handleTab(textView)
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                hideGhost()
                return handleNewline(textView)
            }
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                return handleDeleteBackward(textView)
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                return handleUnindent(textView)
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if ghostSuggestion != nil {
                    hideGhost()
                    return true
                }
            }
            return false
        }

        // MARK: - Tab: accept ghost suggestion or default

        private func handleTab(_ textView: NSTextView) -> Bool {
            if let suggestion = ghostSuggestion, !suggestion.isEmpty {
                textView.insertText(suggestion, replacementRange: textView.selectedRange())
                hideGhost()
                return true
            }
            // Indent list/checkbox lines with Tab for nesting
            return indentListLine(textView)
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
                renumberOrderedLists(in: textView)
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

            renumberOrderedLists(in: textView)
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

        // MARK: - Ordered List Renumbering

        /// Regex matching an ordered list line: captures (indent)(number)(. )
        private static let renumberRegex = try! NSRegularExpression(
            pattern: "^(\\s*)(\\d+)(\\.\\s)",
            options: []
        )

        /// Scans the entire document and corrects ordered-list numbers so that
        /// each contiguous group of numbered items is sequentially numbered
        /// per indentation level. Nested items restart at 1; returning to a
        /// parent level continues where it left off.
        private func renumberOrderedLists(in textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let text = textView.string
            guard !text.isEmpty else { return }

            let lines = text.components(separatedBy: "\n")
            // indentLength -> running counter for that level
            var counters: [Int: Int] = [:]
            var replacements: [(range: NSRange, newNum: String)] = []
            var offset = 0

            for line in lines {
                let lineNS = line as NSString
                let lineRange = NSRange(location: 0, length: lineNS.length)

                if let match = Self.renumberRegex.firstMatch(in: line, range: lineRange) {
                    let indentLen = match.range(at: 1).length
                    let numRange = match.range(at: 2)
                    let currentNum = Int(lineNS.substring(with: numRange)) ?? 0

                    // Reset counters for any deeper indentation levels
                    counters = counters.filter { $0.key <= indentLen }

                    counters[indentLen, default: 0] += 1
                    let correctNum = counters[indentLen]!

                    if currentNum != correctNum {
                        let absRange = NSRange(location: offset + numRange.location, length: numRange.length)
                        replacements.append((absRange, "\(correctNum)"))
                    }
                } else {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    // Unordered / checkbox list items are valid children—keep counters.
                    // Blank lines or any other content break the list block.
                    let isList = trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ")
                    if !isList {
                        counters.removeAll()
                    }
                }

                offset += lineNS.length + 1 // +1 for the \n separator
            }

            guard !replacements.isEmpty else { return }

            let sel = textView.selectedRange()
            var cursorAdjustment = 0

            textView.undoManager?.disableUndoRegistration()
            storage.beginEditing()

            for (range, newNum) in replacements.reversed() {
                let diff = newNum.count - range.length
                storage.replaceCharacters(in: range, with: newNum)
                if range.location + range.length <= sel.location {
                    cursorAdjustment += diff
                }
            }

            storage.endEditing()
            textView.undoManager?.enableUndoRegistration()

            // Adjust cursor for any character-count changes
            let maxLen = (textView.string as NSString).length
            let newLoc = max(0, min(sel.location + cursorAdjustment, maxLen))
            textView.setSelectedRange(NSRange(location: newLoc, length: sel.length))

            // Sync corrected text to parent binding
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }

        // MARK: - Tab: indent list lines for nesting

        private static let listLineRegex = try! NSRegularExpression(pattern: "^\\s*([-*+]\\s|\\d+\\.\\s)")

        private func indentListLine(_ textView: NSTextView) -> Bool {
            let nsText = textView.string as NSString
            let sel = textView.selectedRange()

            // Multi-line selection: indent all non-empty lines
            if sel.length > 0 {
                let linesRange = nsText.lineRange(for: sel)
                let linesString = nsText.substring(with: linesRange)
                let lines = linesString.components(separatedBy: "\n")

                var resultLines: [String] = []
                var totalAdded = 0
                var addedBeforeCursor = 0
                let cursorOffset = sel.location - linesRange.location
                var runningOffset = 0

                for line in lines {
                    let added: Int
                    if !line.isEmpty {
                        resultLines.append("    " + line)
                        added = 4
                    } else {
                        resultLines.append(line)
                        added = 0
                    }

                    if runningOffset + line.count < cursorOffset {
                        addedBeforeCursor += added
                    } else if runningOffset <= cursorOffset {
                        addedBeforeCursor += added
                    }

                    totalAdded += added
                    runningOffset += line.count + 1
                }

                guard totalAdded > 0 else { return true }

                let newText = resultLines.joined(separator: "\n")
                textView.insertText(newText, replacementRange: linesRange)

                let newSelLoc = sel.location + addedBeforeCursor
                let endOfOriginalSel = sel.location + sel.length
                let endLinesRange = linesRange.location + linesRange.length
                let trailingUnselected = endLinesRange - endOfOriginalSel
                let newEnd = linesRange.location + newText.count - trailingUnselected
                let adjustedLen = max(0, newEnd - newSelLoc)
                textView.setSelectedRange(NSRange(location: newSelLoc, length: adjustedLen))

                renumberOrderedLists(in: textView)
                return true
            }

            // No selection: only indent if cursor is on a list/numbered line
            let lineRange = nsText.lineRange(for: NSRange(location: sel.location, length: 0))
            let line = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)
            let matchRange = NSRange(location: 0, length: (line as NSString).length)
            guard Self.listLineRegex.firstMatch(in: line, range: matchRange) != nil else {
                return false
            }
            let insertRange = NSRange(location: lineRange.location, length: 0)
            textView.insertText("    ", replacementRange: insertRange)
            textView.setSelectedRange(NSRange(location: sel.location + 4, length: 0))
            renumberOrderedLists(in: textView)
            return true
        }

        // MARK: - Checkbox Click Handling

        private static let checkboxHitRegex = try! NSRegularExpression(
            pattern: "^(\\s*[-*+]\\s)(\\[)([ xX])(\\])",
            options: .anchorsMatchLines
        )

        func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
            guard let textView = gestureRecognizer.view as? NSTextView else { return false }
            let point = gestureRecognizer.location(in: textView)
            return isPointOnCheckbox(point, in: textView)
        }

        @objc func handleCheckboxClick(_ gesture: NSClickGestureRecognizer) {
            guard let textView = gesture.view as? NSTextView else { return }
            let point = gesture.location(in: textView)
            toggleCheckboxAt(point, in: textView)
        }

        private func isPointOnCheckbox(_ point: NSPoint, in textView: NSTextView) -> Bool {
            guard let lm = textView.layoutManager,
                  let tc = textView.textContainer else { return false }
            let origin = textView.textContainerOrigin
            let containerPoint = NSPoint(x: point.x - origin.x, y: point.y - origin.y)
            let charIndex = lm.characterIndex(for: containerPoint, in: tc, fractionOfDistanceBetweenInsertionPoints: nil)
            let nsText = textView.string as NSString
            guard charIndex < nsText.length else { return false }
            let lineRange = nsText.lineRange(for: NSRange(location: charIndex, length: 0))
            let line = nsText.substring(with: lineRange)
            guard let match = Self.checkboxHitRegex.firstMatch(
                in: line, range: NSRange(location: 0, length: (line as NSString).length)
            ) else { return false }
            let checkStart = lineRange.location + match.range(at: 2).location
            let checkEnd = lineRange.location + match.range(at: 4).location + match.range(at: 4).length
            return charIndex >= checkStart && charIndex < checkEnd
        }

        private func toggleCheckboxAt(_ point: NSPoint, in textView: NSTextView) {
            guard let lm = textView.layoutManager,
                  let tc = textView.textContainer else { return }
            let origin = textView.textContainerOrigin
            let containerPoint = NSPoint(x: point.x - origin.x, y: point.y - origin.y)
            let charIndex = lm.characterIndex(for: containerPoint, in: tc, fractionOfDistanceBetweenInsertionPoints: nil)
            let nsText = textView.string as NSString
            guard charIndex < nsText.length else { return }
            let lineRange = nsText.lineRange(for: NSRange(location: charIndex, length: 0))
            let line = nsText.substring(with: lineRange)
            let pattern = try! NSRegularExpression(pattern: "^(\\s*[-*+]\\s\\[)([ xX])(\\])")
            guard let match = pattern.firstMatch(
                in: line, range: NSRange(location: 0, length: (line as NSString).length)
            ) else { return }
            let checkLocal = match.range(at: 2)
            let checkAbs = NSRange(location: lineRange.location + checkLocal.location, length: 1)
            let ch = nsText.substring(with: checkAbs)
            let newCh = (ch == "x" || ch == "X") ? " " : "x"
            if textView.shouldChangeText(in: checkAbs, replacementString: newCh) {
                textView.replaceCharacters(in: checkAbs, with: newCh)
                textView.didChangeText()
            }
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
            hideGhost()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdatingSelection, !isUpdatingText else { return }
            guard let textView = notification.object as? NSTextView else { return }
            syncSelectionToParent(textView)
            hideGhost()
        }

        private func syncSelectionToParent(_ textView: NSTextView) {
            let sel = textView.selectedRange()
            if parent.selectionRange != sel {
                parent.selectionRange = sel
            }
        }

        // MARK: - Inline Ghost Text Autocomplete

        func updateGhostText(_ textView: NSTextView) {
            guard let ghostLabel = ghostLabel else { return }

            let sel = textView.selectedRange()
            guard sel.length == 0 else {
                hideGhost()
                return
            }

            let nsText = textView.string as NSString
            let cursorLoc = sel.location

            // Only show ghost when cursor is at end of line or before whitespace
            if cursorLoc < nsText.length {
                let nextChar = nsText.character(at: cursorLoc)
                if let scalar = Unicode.Scalar(nextChar),
                   !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                    hideGhost()
                    return
                }
            }

            // Find partial word before cursor
            var wordStart = cursorLoc
            while wordStart > 0 {
                let ch = nsText.character(at: wordStart - 1)
                guard let scalar = Unicode.Scalar(ch),
                      CharacterSet.alphanumerics.contains(scalar) || ch == 0x5F else { break }
                wordStart -= 1
            }

            let wordLen = cursorLoc - wordStart
            guard wordLen >= 2 else {
                hideGhost()
                return
            }

            let partial = nsText.substring(with: NSRange(location: wordStart, length: wordLen))
            let partialRange = NSRange(location: wordStart, length: wordLen)

            guard let match = findBestMatch(partial: partial, in: textView.string, excluding: partialRange) else {
                hideGhost()
                return
            }

            let remaining = String(match.dropFirst(partial.count))
            guard !remaining.isEmpty else {
                hideGhost()
                return
            }

            ghostSuggestion = remaining

            // Position ghost label at cursor
            let baseSize = 14.0 * parent.zoomLevel
            ghostLabel.font = NSFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
            ghostLabel.stringValue = remaining

            let point = cursorPoint(in: textView)
            let lineHeight = baseSize * 1.4
            ghostLabel.frame = NSRect(x: point.x, y: point.y, width: 400, height: lineHeight)
            ghostLabel.isHidden = false
        }

        func hideGhost() {
            ghostLabel?.isHidden = true
            ghostSuggestion = nil
        }

        private func cursorPoint(in textView: NSTextView) -> NSPoint {
            guard let lm = textView.layoutManager, let tc = textView.textContainer else {
                return .zero
            }

            let charIndex = textView.selectedRange().location
            let nsText = textView.string as NSString
            let insetX = textView.textContainerInset.width + tc.lineFragmentPadding
            let insetY = textView.textContainerInset.height

            guard nsText.length > 0 else {
                return NSPoint(x: insetX, y: insetY)
            }

            if charIndex < nsText.length {
                let gi = lm.glyphIndexForCharacter(at: charIndex)
                let lineRect = lm.lineFragmentRect(forGlyphAt: gi, effectiveRange: nil)
                let loc = lm.location(forGlyphAt: gi)
                return NSPoint(x: lineRect.minX + loc.x + insetX, y: lineRect.minY + insetY)
            } else {
                let gi = lm.glyphIndexForCharacter(at: charIndex - 1)
                let lineRect = lm.lineFragmentRect(forGlyphAt: gi, effectiveRange: nil)
                let boundingRect = lm.boundingRect(forGlyphRange: NSRange(location: gi, length: 1), in: tc)
                return NSPoint(x: boundingRect.maxX + insetX, y: lineRect.minY + insetY)
            }
        }

        private func findBestMatch(partial: String, in text: String, excluding range: NSRange) -> String? {
            let nsText = text as NSString
            let lowerPartial = partial.lowercased()
            let fullRange = NSRange(location: 0, length: nsText.length)
            let matches = Self.wordRegex.matches(in: text, range: fullRange)

            var seen = Set<String>()
            var candidates: [String] = []
            for match in matches {
                if match.range.location == range.location && match.range.length == range.length { continue }
                let word = nsText.substring(with: match.range)
                let lower = word.lowercased()
                guard lower != lowerPartial, lower.hasPrefix(lowerPartial) else { continue }
                guard !seen.contains(lower) else { continue }
                seen.insert(lower)
                candidates.append(word)
            }

            candidates.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            return candidates.first
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

import SwiftUI
import AppKit

// MARK: - Result Types

enum PaletteResultKind {
    case file
    case folder
    case contentMatch
    case command
}

struct PaletteResult: Identifiable {
    let id = UUID()
    let kind: PaletteResultKind
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let shortcutHint: String?
    let action: () -> Void
}

// MARK: - Command Definition

struct PaletteCommand {
    let name: String
    let shortcut: String
    let action: (AppState) -> Void
}

// MARK: - Content Match

private struct ContentMatch {
    let fileURL: URL
    let lineNumber: Int
    let lineText: String
}

// MARK: - Fuzzy Match (Recursive Exhaustive - Sublime Text / fts_fuzzy_match style)
//
// Considers ALL possible alignments of query chars against the target and picks
// the highest-scoring one. Recursion capped at 10 to bound worst-case cost.

private let kSequentialBonus      = 15
private let kSeparatorBonus       = 30
private let kCamelBonus           = 30
private let kFirstLetterBonus     = 15
private let kLeadingLetterPenalty = -5
private let kMaxLeadingPenalty    = -15
private let kUnmatchedPenalty     = -1
private let kCommandBias          = 40

private func fuzzyScore(_ query: String, in target: String) -> Int {
    guard !query.isEmpty else { return 1 }
    let patLower = Array(query.lowercased().unicodeScalars)
    let str = Array(target.unicodeScalars)
    let strLower = Array(target.lowercased().unicodeScalars)
    guard patLower.count <= strLower.count else { return 0 }

    var bestScore = 0
    var matched = false
    var recursions = 0
    fuzzyRecurse(
        patLower: patLower, pi: 0,
        str: str, strLower: strLower, si: 0,
        matches: [], bestScore: &bestScore, matched: &matched,
        recursions: &recursions
    )
    return matched ? max(bestScore, 1) : 0
}

private func fuzzyRecurse(
    patLower: [Unicode.Scalar], pi: Int,
    str: [Unicode.Scalar], strLower: [Unicode.Scalar], si: Int,
    matches: [Int],
    bestScore: inout Int, matched: inout Bool,
    recursions: inout Int
) {
    if recursions > 10 { return }
    recursions += 1

    if pi == patLower.count {
        matched = true
        let s = scoreAlignment(str: str, strLower: strLower, matches: matches)
        if s > bestScore { bestScore = s }
        return
    }
    guard si < strLower.count else { return }

    let pch = patLower[pi]
    for i in si..<strLower.count {
        if strLower[i] == pch {
            var next = matches
            next.append(i)
            fuzzyRecurse(
                patLower: patLower, pi: pi + 1,
                str: str, strLower: strLower, si: i + 1,
                matches: next,
                bestScore: &bestScore, matched: &matched,
                recursions: &recursions
            )
        }
    }
}

private func scoreAlignment(str: [Unicode.Scalar], strLower: [Unicode.Scalar], matches: [Int]) -> Int {
    guard let first = matches.first else { return 0 }
    var score = 0
    score += max(kMaxLeadingPenalty, kLeadingLetterPenalty * first)
    score += kUnmatchedPenalty * (str.count - matches.count)

    for (idx, mi) in matches.enumerated() {
        if mi == 0 { score += kFirstLetterBonus }
        if idx > 0 && mi == matches[idx - 1] + 1 { score += kSequentialBonus }
        if mi > 0 {
            let prev = str[mi - 1]
            if prev == " " || prev == "_" || prev == "-" || prev == "." || prev == "/" {
                score += kSeparatorBonus
            } else if isLowerScalar(prev) && isUpperScalar(str[mi]) {
                score += kCamelBonus
            }
        }
    }
    return score
}

@inline(__always)
private func isUpperScalar(_ c: Unicode.Scalar) -> Bool { c.value >= 65 && c.value <= 90 }
@inline(__always)
private func isLowerScalar(_ c: Unicode.Scalar) -> Bool { c.value >= 97 && c.value <= 122 }

private func commandScore(query: String, name: String) -> Int {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let base = fuzzyScore(trimmed, in: name)
    if trimmed.isEmpty { return base + kCommandBias }
    if base <= 0 { return 0 }

    let queryLower = trimmed.lowercased()
    let nameLower = name.lowercased()
    var bonus = 0

    let separators = CharacterSet(charactersIn: " _-./")
    let queryTokens = queryLower.split { $0.unicodeScalars.allSatisfy { separators.contains($0) } }
    let nameTokens = nameLower.split { $0.unicodeScalars.allSatisfy { separators.contains($0) } }

    // Token-aware scoring: reward matches against individual words, regardless of order.
    var tokenScore = 0
    if !queryTokens.isEmpty, !nameTokens.isEmpty {
        var matchedTokens = 0
        for token in queryTokens {
            var bestToken = 0
            for word in nameTokens {
                let s = fuzzyScore(String(token), in: String(word))
                if s > bestToken { bestToken = s }
                if word.hasPrefix(token) { bestToken += 40 }
                if word == token { bestToken += 80 }
            }
            if bestToken > 0 {
                matchedTokens += 1
                tokenScore += bestToken
            }
        }
        if matchedTokens == queryTokens.count { bonus += 80 }
        if matchedTokens == 0 { return 0 }
    }

    if nameLower == queryLower { bonus += 200 }
    if nameLower.hasPrefix(queryLower) {
        bonus += 120
    } else if nameLower.contains(queryLower) {
        bonus += 60
    }

    if !queryTokens.isEmpty, !nameTokens.isEmpty {
        var matchedWordStarts = 0
        var searchIndex = 0
        var ordered = true
        for token in queryTokens {
            var found = false
            for i in searchIndex..<nameTokens.count {
                if nameTokens[i].hasPrefix(token) {
                    matchedWordStarts += 1
                    searchIndex = i + 1
                    found = true
                    break
                }
            }
            if !found { ordered = false }
        }
        if matchedWordStarts == queryTokens.count { bonus += 80 }
        if ordered && queryTokens.count > 1 { bonus += 40 }
    }

    let combined = max(base, tokenScore)
    return combined + bonus + kCommandBias
}

// MARK: - Command Palette View

struct CommandPaletteView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var results: [PaletteResult] = []
    @State private var contentSearchWork: DispatchWorkItem?
    @State private var clickMonitor: Any?

    private static let commands: [PaletteCommand] = [
        PaletteCommand(name: "Toggle Theme", shortcut: "Cmd+T") { state in
            state.cycleAppearance()
        },
        PaletteCommand(name: "Toggle Sidebar", shortcut: "Cmd+/") { state in
            withAnimation(.easeInOut(duration: 0.2)) {
                state.isDistractionFree.toggle()
            }
        },
        PaletteCommand(name: "Toggle Line Wrap", shortcut: "Cmd+Shift+L") { state in
            state.isLineWrapping.toggle()
        },
        PaletteCommand(name: "Full Text Search", shortcut: "Cmd+Shift+F") { state in
            state.openFullTextSearch()
        },
        PaletteCommand(name: "Distraction-Free Mode", shortcut: "Cmd+/") { state in
            state.isDistractionFree.toggle()
        },
        PaletteCommand(name: "New File", shortcut: "Cmd+N") { state in
            state.createUntitledFile()
        },
        PaletteCommand(name: "New Folder", shortcut: "Cmd+Shift+N") { state in
            state.createUntitledFolder()
        },
        PaletteCommand(name: "Zoom In", shortcut: "Cmd++") { state in
            state.zoomIn()
        },
        PaletteCommand(name: "Zoom Out", shortcut: "Cmd+-") { state in
            state.zoomOut()
        },
        PaletteCommand(name: "Reset Zoom", shortcut: "Cmd+0") { state in
            state.resetZoom()
        },
        PaletteCommand(name: "Find in File", shortcut: "Cmd+F") { state in
            state.toggleSearch()
        },
        PaletteCommand(name: "Save File", shortcut: "Cmd+S") { state in
            state.saveActiveFile()
        },
        PaletteCommand(name: "Open Folder", shortcut: "Cmd+O") { state in
            state.pickRootFolder()
        },
        PaletteCommand(name: "Insert Image", shortcut: "Cmd+Shift+I") { state in
            state.insertImage()
        },
        PaletteCommand(name: "Toggle Outline", shortcut: "Cmd+Shift+O") { state in
            state.toggleOutline()
        },
    ]

    var body: some View {
        ZStack {
            // Dimmed backdrop (visual only, no gesture handling)
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
            // Floating panel
            VStack(spacing: 0) {
                // Search field
                PaletteSearchField(
                    query: $query,
                    selectedIndex: $selectedIndex,
                    resultCount: results.count,
                    placeholder: appState.fullTextSearchMode
                        ? "Search across all files..."
                        : "Search files, content, or type > for commands...",
                    onSubmit: executeSelected,
                    onEscape: dismiss,
                    onQueryChanged: { newQuery in
                        selectedIndex = 0
                        updateResults(for: newQuery)
                    }
                )
                .padding(Theme.Spacing.l)

                // Divider
                if !results.isEmpty {
                    Rectangle()
                        .fill(Theme.Colors.border)
                        .frame(height: 1)
                }

                // Results
                if !results.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                    PaletteResultRow(
                                        result: result,
                                        isSelected: index == selectedIndex
                                    )
                                    .id(index)
                                    .onTapGesture {
                                        executeResult(result)
                                    }
                                }
                            }
                            .padding(.vertical, Theme.Spacing.s)
                        }
                        .frame(maxHeight: 400)
                        .onChange(of: selectedIndex) { newIndex in
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                } else if !query.isEmpty {
                    Text(appState.fullTextSearchMode ? "No matches found" : "No results")
                        .font(Theme.Fonts.uiSmall)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(Theme.Spacing.xxl)
                } else if appState.fullTextSearchMode {
                    Text("Type to search across all markdown files")
                        .font(Theme.Fonts.uiSmall)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(Theme.Spacing.xxl)
                }
            }
            .background(Theme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .frame(width: 580)
            .padding(.top, 60)

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .onAppear {
            updateResults(for: "")
            installClickOutsideMonitor()
        }
        .onDisappear {
            removeClickOutsideMonitor()
        }
    }

    // MARK: - Click Outside to Dismiss (NSEvent monitor, doesn't block scroll)

    private func installClickOutsideMonitor() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = event.window else { return event }
            let loc = event.locationInWindow
            // Find the panel frame: centered, 580pt wide, starts 60pt from top
            let windowHeight = window.frame.height
            let panelWidth: CGFloat = 580
            let panelX = (window.frame.width - panelWidth) / 2
            // Approximate panel bounds (top-aligned with padding)
            let panelRect = NSRect(x: panelX, y: 0, width: panelWidth, height: windowHeight - 60)
            if !panelRect.contains(loc) {
                DispatchQueue.main.async { dismiss() }
            }
            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    // MARK: - Search Logic

    private func updateResults(for query: String) {
        contentSearchWork?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if appState.fullTextSearchMode {
            // Full-text search mode: only content matches
            if trimmed.isEmpty {
                results = []
                return
            }
            results = []
            let work = DispatchWorkItem { [weak appState] in
                guard let appState else { return }
                let contentResults = self.searchContent(query: trimmed, appState: appState)
                DispatchQueue.main.async {
                    let currentTrimmed = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard currentTrimmed == trimmed else { return }
                    self.results = contentResults
                    if self.selectedIndex >= self.results.count {
                        self.selectedIndex = max(0, self.results.count - 1)
                    }
                }
            }
            contentSearchWork = work
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15, execute: work)
            return
        }

        if trimmed.isEmpty {
            // Show all commands when empty
            results = searchCommands(query: "")
            return
        }

        // ">" prefix = command-only mode
        if trimmed.hasPrefix(">") {
            let cmdQuery = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            results = searchCommands(query: cmdQuery)
            return
        }

        // Mixed mode: files + folders + commands + content, sorted by score
        var scored: [(result: PaletteResult, score: Int)] = []
        scored.append(contentsOf: searchFilesScored(query: trimmed))
        scored.append(contentsOf: searchFoldersScored(query: trimmed))
        scored.append(contentsOf: searchCommandsScored(query: trimmed))
        scored.sort { $0.score > $1.score }
        results = Array(scored.map(\.result).prefix(50))

        // Debounced content search
        let work = DispatchWorkItem { [weak appState] in
            guard let appState else { return }
            let contentResults = searchContent(query: trimmed, appState: appState)
            DispatchQueue.main.async {
                let currentTrimmed = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard currentTrimmed == trimmed else { return }
                var updated: [(result: PaletteResult, score: Int)] = []
                updated.append(contentsOf: self.searchFilesScored(query: trimmed))
                updated.append(contentsOf: self.searchFoldersScored(query: trimmed))
                updated.append(contentsOf: self.searchCommandsScored(query: trimmed))
                updated.append(contentsOf: contentResults.map { ($0, 1) })
                updated.sort { $0.score > $1.score }
                self.results = Array(updated.map(\.result).prefix(50))
                if self.selectedIndex >= self.results.count {
                    self.selectedIndex = max(0, self.results.count - 1)
                }
            }
        }
        contentSearchWork = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func searchFilesScored(query: String) -> [(result: PaletteResult, score: Int)] {
        guard let rootURL = appState.rootURL else { return [] }
        let files = appState.allMarkdownFiles()

        return files
            .compactMap { url -> (URL, Int)? in
                let score = fuzzyScore(query, in: url.lastPathComponent)
                return score > 0 ? (url, score) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(15)
            .map { (url, score) in
                let relative = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                let result = PaletteResult(
                    kind: .file,
                    title: url.lastPathComponent,
                    subtitle: relative,
                    icon: appState.markdownDefaults.icon,
                    iconColor: appState.markdownDefaults.color,
                    shortcutHint: nil
                ) { [weak appState] in
                    appState?.setSelectedNode(url)
                    appState?.openFile(at: url)
                }
                return (result: result, score: score)
            }
    }

    private func searchFoldersScored(query: String) -> [(result: PaletteResult, score: Int)] {
        guard let rootURL = appState.rootURL else { return [] }
        let folders = appState.allFolders()

        return folders
            .filter { $0 != rootURL }
            .compactMap { url -> (URL, Int)? in
                let score = fuzzyScore(query, in: url.lastPathComponent)
                return score > 0 ? (url, score) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(10)
            .map { (url, score) in
                let relative = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                let customization = appState.folderCustomization(for: url)
                let result = PaletteResult(
                    kind: .folder,
                    title: url.lastPathComponent,
                    subtitle: relative,
                    icon: customization.icon,
                    iconColor: customization.color,
                    shortcutHint: nil
                ) { [weak appState] in
                    appState?.setExpanded(url, expanded: true)
                    appState?.selectedNodeURL = url
                }
                return (result: result, score: score)
            }
    }

    private func searchContent(query: String, appState: AppState) -> [PaletteResult] {
        guard let rootURL = appState.rootURL else { return [] }
        let files = appState.allMarkdownFiles()
        let lowered = query.lowercased()
        var matches: [ContentMatch] = []
        let maxResults = appState.fullTextSearchMode ? 50 : 20

        for fileURL in files {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            for (lineIndex, line) in lines.enumerated() {
                if line.lowercased().contains(lowered) {
                    matches.append(ContentMatch(
                        fileURL: fileURL,
                        lineNumber: lineIndex + 1,
                        lineText: line.trimmingCharacters(in: .whitespaces)
                    ))
                    if matches.count >= maxResults { break }
                }
            }
            if matches.count >= maxResults { break }
        }

        return matches.map { match in
            let relative = match.fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            let preview = String(match.lineText.prefix(80))
            return PaletteResult(
                kind: .contentMatch,
                title: preview,
                subtitle: "\(relative):\(match.lineNumber)",
                icon: "text.line.first.and.arrowtriangle.forward",
                iconColor: Theme.Colors.textMuted,
                shortcutHint: nil
            ) { [weak appState] in
                let lineNum = match.lineNumber
                appState?.setSelectedNode(match.fileURL)
                appState?.openFile(at: match.fileURL)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    appState?.navigateToLine(lineNum)
                }
            }
        }
    }

    private func searchCommands(query: String) -> [PaletteResult] {
        searchCommandsScored(query: query).map(\.result)
    }

    private func searchCommandsScored(query: String) -> [(result: PaletteResult, score: Int)] {
        Self.commands
            .map { ($0, commandScore(query: query, name: $0.name)) }
            .filter { query.isEmpty || $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { (cmd, score) in
                let result = PaletteResult(
                    kind: .command,
                    title: cmd.name,
                    subtitle: "",
                    icon: "gearshape",
                    iconColor: Theme.Colors.textSecondary,
                    shortcutHint: cmd.shortcut
                ) { [weak appState] in
                    guard let appState else { return }
                    cmd.action(appState)
                }
                return (result: result, score: score)
            }
    }

    // MARK: - Actions

    private func executeSelected() {
        guard selectedIndex >= 0, selectedIndex < results.count else { return }
        executeResult(results[selectedIndex])
    }

    private func executeResult(_ result: PaletteResult) {
        dismiss()
        result.action()
    }

    private func dismiss() {
        removeClickOutsideMonitor()
        appState.fullTextSearchMode = false
        appState.showCommandPalette = false
    }
}

// MARK: - Search Field (NSViewRepresentable for reliable key handling)

struct PaletteSearchField: NSViewRepresentable {
    @Binding var query: String
    @Binding var selectedIndex: Int
    let resultCount: Int
    let placeholder: String
    let onSubmit: () -> Void
    let onEscape: () -> Void
    let onQueryChanged: (String) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBordered = false
        field.backgroundColor = .clear
        field.focusRingType = .none
        field.isContinuous = true
        field.font = NSFont(name: "RobotoMono-Regular", size: 14) ?? NSFont.systemFont(ofSize: 14)
        field.delegate = context.coordinator
        field.cell?.sendsActionOnEndEditing = false

        // Auto-focus after a brief delay to ensure the view is in the hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            field.window?.makeFirstResponder(field)
        }

        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        let currentText: String
        if let editor = nsView.currentEditor() as? NSTextView {
            currentText = editor.string
        } else {
            currentText = nsView.stringValue
        }
        if currentText != query {
            nsView.stringValue = query
        }
        context.coordinator.resultCount = resultCount
        context.coordinator.selectedIndex = $selectedIndex
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onEscape = onEscape
        context.coordinator.onQueryChanged = onQueryChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(query: $query, selectedIndex: $selectedIndex, resultCount: resultCount, onSubmit: onSubmit, onEscape: onEscape, onQueryChanged: onQueryChanged)
    }

    class Coordinator: NSObject, NSTextFieldDelegate, NSTextViewDelegate {
        var query: Binding<String>
        var selectedIndex: Binding<Int>
        var resultCount: Int
        var onSubmit: () -> Void
        var onEscape: () -> Void
        var onQueryChanged: (String) -> Void

        init(query: Binding<String>, selectedIndex: Binding<Int>, resultCount: Int, onSubmit: @escaping () -> Void, onEscape: @escaping () -> Void, onQueryChanged: @escaping (String) -> Void) {
            self.query = query
            self.selectedIndex = selectedIndex
            self.resultCount = resultCount
            self.onSubmit = onSubmit
            self.onEscape = onEscape
            self.onQueryChanged = onQueryChanged
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let newText: String
            if let editor = field.currentEditor() as? NSTextView {
                newText = editor.string
            } else {
                newText = field.stringValue
            }
            query.wrappedValue = newText
            onQueryChanged(newText)
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            if let editor = field.currentEditor() as? NSTextView {
                editor.delegate = self
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            let newText = editor.string
            query.wrappedValue = newText
            onQueryChanged(newText)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                if resultCount > 0 {
                    selectedIndex.wrappedValue = (selectedIndex.wrappedValue - 1 + resultCount) % resultCount
                }
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                if resultCount > 0 {
                    selectedIndex.wrappedValue = (selectedIndex.wrappedValue + 1) % resultCount
                }
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onEscape()
                return true
            }
            return false
        }
    }
}

// MARK: - Result Row

private struct PaletteResultRow: View {
    let result: PaletteResult
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: result.icon)
                .font(Theme.Fonts.icon)
                .foregroundStyle(result.iconColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(Theme.Fonts.uiSmall)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)

                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(Theme.Fonts.statusBar)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let hint = result.shortcutHint {
                Text(hint)
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.Colors.backgroundTertiary)
                    )
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(isSelected ? Theme.Colors.selection : (isHovering ? Theme.Colors.hover : Color.clear))
        )
        .padding(.horizontal, Theme.Spacing.xs)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

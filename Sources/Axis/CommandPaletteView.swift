import SwiftUI
import AppKit

// MARK: - Command Category

enum CommandCategory: String, CaseIterable {
    case file = "File"
    case edit = "Edit"
    case format = "Format"
    case view = "View"
    case navigation = "Navigation"
    case search = "Search"
}

// MARK: - Palette Mode

enum PaletteMode: Equatable {
    case mixed          // default: files + commands + content
    case commands       // ">" prefix
    case headings       // "@" prefix
    case goToLine       // ":" prefix
    case fullTextSearch // Cmd+Shift+F

    static func from(query: String, isFTS: Bool) -> (mode: PaletteMode, cleanQuery: String) {
        if isFTS { return (.fullTextSearch, query) }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix(">") {
            return (.commands, String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        if trimmed.hasPrefix("@") {
            return (.headings, String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        if trimmed.hasPrefix(":") {
            return (.goToLine, String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        return (.mixed, trimmed)
    }
}

// MARK: - Result Types

enum PaletteResultKind {
    case file
    case folder
    case contentMatch
    case command
    case heading
    case goToLine
}

struct PaletteResult: Identifiable {
    let id = UUID()
    let kind: PaletteResultKind
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let shortcutHint: String?
    let category: String?
    let matchRanges: [Range<String.Index>]
    let action: () -> Void

    init(kind: PaletteResultKind, title: String, subtitle: String, icon: String,
         iconColor: Color, shortcutHint: String? = nil, category: String? = nil,
         matchRanges: [Range<String.Index>] = [], action: @escaping () -> Void) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.shortcutHint = shortcutHint
        self.category = category
        self.matchRanges = matchRanges
        self.action = action
    }
}

// MARK: - Command Definition

struct PaletteCommand: Identifiable {
    let id: String
    let name: String
    let category: CommandCategory
    let shortcut: String?
    let icon: String
    let action: (AppState) -> Void
}

// MARK: - Content Match

private struct ContentMatch {
    let fileURL: URL
    let lineNumber: Int
    let lineText: String
}

// MARK: - Fuzzy Matching

/// Consecutive-bonus fuzzy scoring. Each consecutive matched character adds an
/// increasing score (1, 2, 3, ...), rewarding tight clusters. Returns 0 for
/// no match. Bonus for first-letter and word-boundary matches.
private func fuzzyScore(_ query: String, in target: String) -> (score: Int, ranges: [Range<String.Index>]) {
    guard !query.isEmpty else { return (1, []) }
    let queryLower = query.lowercased()
    let targetLower = target.lowercased()

    guard queryLower.count <= targetLower.count else { return (0, []) }

    var totalScore = 0
    var consecutive = 0
    var matchedRanges: [Range<String.Index>] = []
    var currentRangeStart: String.Index?
    var currentRangeEnd: String.Index?

    var qi = queryLower.startIndex
    var ti = targetLower.startIndex
    let targetOrig = target

    while qi < queryLower.endIndex && ti < targetLower.endIndex {
        if queryLower[qi] == targetLower[ti] {
            // Start or extend a match range
            if currentRangeStart == nil {
                currentRangeStart = ti
            }
            currentRangeEnd = targetLower.index(after: ti)

            consecutive += 1
            totalScore += consecutive

            // Bonus: first character match
            if ti == targetLower.startIndex { totalScore += 10 }

            // Bonus: word boundary (after space, -, _, /)
            if ti > targetLower.startIndex {
                let prevIdx = targetLower.index(before: ti)
                let prev = targetOrig[prevIdx]
                if prev == " " || prev == "-" || prev == "_" || prev == "/" || prev == "." {
                    totalScore += 20
                }
                // CamelCase boundary
                if targetOrig[prevIdx].isLowercase && targetOrig[ti].isUppercase {
                    totalScore += 20
                }
            }

            qi = queryLower.index(after: qi)
        } else {
            consecutive = 0
            if let start = currentRangeStart, let end = currentRangeEnd {
                matchedRanges.append(start..<end)
                currentRangeStart = nil
                currentRangeEnd = nil
            }
        }
        ti = targetLower.index(after: ti)
    }

    // Close last range
    if let start = currentRangeStart, let end = currentRangeEnd {
        matchedRanges.append(start..<end)
    }

    // Did we match all query characters?
    if qi < queryLower.endIndex { return (0, []) }

    // Penalty for unmatched target characters (prefer shorter targets)
    totalScore -= (targetLower.count - queryLower.count)

    return (max(totalScore, 1), matchedRanges)
}

/// Command-specific scoring with token awareness and extra bonuses.
private func commandScore(query: String, command: PaletteCommand) -> Int {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let name = command.name
    let (base, _) = fuzzyScore(trimmed, in: name)
    if trimmed.isEmpty { return 40 } // Show all commands with base bias
    if base <= 0 { return 0 }

    var bonus = 0
    let qLower = trimmed.lowercased()
    let nLower = name.lowercased()

    // Exact match
    if nLower == qLower { bonus += 200 }
    // Prefix match
    else if nLower.hasPrefix(qLower) { bonus += 120 }
    // Contains
    else if nLower.contains(qLower) { bonus += 60 }

    // Token matching: match individual words
    let separators = CharacterSet(charactersIn: " _-./")
    let queryTokens = qLower.split { $0.unicodeScalars.allSatisfy { separators.contains($0) } }
    let nameTokens = nLower.split { $0.unicodeScalars.allSatisfy { separators.contains($0) } }

    if !queryTokens.isEmpty && !nameTokens.isEmpty {
        var matched = 0
        for qt in queryTokens {
            for nt in nameTokens {
                if nt.hasPrefix(qt) { matched += 1; break }
            }
        }
        if matched == queryTokens.count { bonus += 80 }
    }

    return base + bonus + 40 // +40 command bias
}

// MARK: - Recent Commands Tracker

private struct RecentEntry: Codable {
    let commandId: String
    var lastUsed: Date
    var count: Int
}

private class RecentTracker {
    private static let key = "commandPaletteRecents"
    private static let maxRecent = 8

    static func record(_ id: String) {
        var entries = load()
        if let idx = entries.firstIndex(where: { $0.commandId == id }) {
            entries[idx].lastUsed = Date()
            entries[idx].count += 1
        } else {
            entries.append(RecentEntry(commandId: id, lastUsed: Date(), count: 1))
        }
        save(entries)
    }

    static func recentIds() -> [String] {
        load()
            .sorted { $0.lastUsed > $1.lastUsed }
            .prefix(maxRecent)
            .map(\.commandId)
    }

    private static func load() -> [RecentEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentEntry].self, from: data) else { return [] }
        return decoded
    }

    private static func save(_ entries: [RecentEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Command Registry

private let allCommands: [PaletteCommand] = [
    // File
    PaletteCommand(id: "new-file", name: "New File", category: .file, shortcut: "Cmd+N", icon: "doc.badge.plus") { $0.createUntitledFile() },
    PaletteCommand(id: "new-folder", name: "New Folder", category: .file, shortcut: "Cmd+Shift+N", icon: "folder.badge.plus") { $0.createUntitledFolder() },
    PaletteCommand(id: "open-folder", name: "Open Folder", category: .file, shortcut: "Cmd+O", icon: "folder") { $0.pickRootFolder() },
    PaletteCommand(id: "save-file", name: "Save File", category: .file, shortcut: "Cmd+S", icon: "square.and.arrow.down") { $0.saveActiveFile() },
    PaletteCommand(id: "close-tab", name: "Close Tab", category: .file, shortcut: "Cmd+W", icon: "xmark.square") { state in
        if let url = state.activeFileURL { state.closeFile(at: url) }
    },
    PaletteCommand(id: "close-all", name: "Close All Tabs", category: .file, shortcut: nil, icon: "xmark.square.fill") { $0.closeAllFiles() },

    // Edit
    PaletteCommand(id: "find-in-file", name: "Find in File", category: .edit, shortcut: "Cmd+F", icon: "magnifyingglass") { $0.toggleSearch() },
    PaletteCommand(id: "fts", name: "Search All Files", category: .edit, shortcut: "Cmd+Shift+F", icon: "doc.text.magnifyingglass") { $0.openFullTextSearch() },

    // Format
    PaletteCommand(id: "bold", name: "Toggle Bold", category: .format, shortcut: "Cmd+B", icon: "bold") { $0.toggleBold() },
    PaletteCommand(id: "italic", name: "Toggle Italic", category: .format, shortcut: "Cmd+I", icon: "italic") { $0.toggleItalic() },
    PaletteCommand(id: "code", name: "Toggle Inline Code", category: .format, shortcut: "Cmd+E", icon: "chevron.left.forwardslash.chevron.right") { $0.toggleCode() },
    PaletteCommand(id: "code-block", name: "Insert Code Block", category: .format, shortcut: "Cmd+Shift+E", icon: "curlybraces") { $0.insertCodeBlock() },
    PaletteCommand(id: "strikethrough", name: "Toggle Strikethrough", category: .format, shortcut: "Cmd+Shift+D", icon: "strikethrough") { $0.toggleStrikethrough() },
    PaletteCommand(id: "link", name: "Insert Link", category: .format, shortcut: "Cmd+K", icon: "link") { $0.insertLink() },
    PaletteCommand(id: "image", name: "Insert Image", category: .format, shortcut: "Cmd+Shift+I", icon: "photo") { $0.insertImage() },
    PaletteCommand(id: "heading", name: "Cycle Heading Level", category: .format, shortcut: "Cmd+Shift+H", icon: "number") { $0.insertHeading() },
    PaletteCommand(id: "h1", name: "Heading 1", category: .format, shortcut: "Cmd+1", icon: "number") { $0.setHeading(level: 1) },
    PaletteCommand(id: "h2", name: "Heading 2", category: .format, shortcut: "Cmd+2", icon: "number") { $0.setHeading(level: 2) },
    PaletteCommand(id: "h3", name: "Heading 3", category: .format, shortcut: "Cmd+3", icon: "number") { $0.setHeading(level: 3) },
    PaletteCommand(id: "checkbox", name: "Toggle Checkbox", category: .format, shortcut: "Cmd+Shift+T", icon: "checkmark.square") { $0.toggleCheckbox() },

    // View
    PaletteCommand(id: "theme", name: "Cycle Theme", category: .view, shortcut: "Cmd+T", icon: "circle.lefthalf.filled") { $0.cycleAppearance() },
    PaletteCommand(id: "sidebar", name: "Toggle Sidebar", category: .view, shortcut: "Cmd+/", icon: "sidebar.left") { state in
        withAnimation(.easeInOut(duration: 0.2)) { state.isDistractionFree.toggle() }
    },
    PaletteCommand(id: "outline", name: "Toggle Outline", category: .view, shortcut: "Cmd+Shift+O", icon: "list.bullet.indent") { $0.toggleOutline() },
    PaletteCommand(id: "terminal", name: "Toggle Terminal", category: .view, shortcut: "Cmd+J", icon: "terminal") { $0.toggleTerminal() },
    PaletteCommand(id: "line-wrap", name: "Toggle Line Wrap", category: .view, shortcut: "Cmd+Shift+L", icon: "text.word.spacing") { $0.isLineWrapping.toggle() },
    PaletteCommand(id: "zoom-in", name: "Zoom In", category: .view, shortcut: "Cmd++", icon: "plus.magnifyingglass") { $0.zoomIn() },
    PaletteCommand(id: "zoom-out", name: "Zoom Out", category: .view, shortcut: "Cmd+-", icon: "minus.magnifyingglass") { $0.zoomOut() },
    PaletteCommand(id: "zoom-reset", name: "Reset Zoom", category: .view, shortcut: "Cmd+0", icon: "1.magnifyingglass") { $0.resetZoom() },

    // Navigation
    PaletteCommand(id: "prev-tab", name: "Previous Tab", category: .navigation, shortcut: "Cmd+{", icon: "arrow.left.square") { $0.selectPreviousTab() },
    PaletteCommand(id: "next-tab", name: "Next Tab", category: .navigation, shortcut: "Cmd+}", icon: "arrow.right.square") { $0.selectNextTab() },
]

// MARK: - Command Palette View

struct CommandPaletteView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var results: [PaletteResult] = []
    @State private var sectionHeaders: [Int: String] = [:] // index -> header
    @State private var contentSearchWork: DispatchWorkItem?
    @State private var clickMonitor: Any?
    @State private var keyMonitor: Any?

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Search field
                    HStack(spacing: Theme.Spacing.m) {
                        modeIndicator
                        PaletteSearchField(
                            query: $query,
                            selectedIndex: $selectedIndex,
                            resultCount: results.count,
                            placeholder: placeholder,
                            onSubmit: executeSelected,
                            onQueryChanged: { newQuery in
                                selectedIndex = 0
                                updateResults(for: newQuery)
                            }
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.l)

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
                                        // Section header
                                        if let header = sectionHeaders[index] {
                                            HStack {
                                                Text(header.uppercased())
                                                    .font(Theme.Fonts.statusBar)
                                                    .foregroundStyle(Theme.Colors.textMuted)
                                                Spacer()
                                            }
                                            .padding(.horizontal, Theme.Spacing.l)
                                            .padding(.top, index == 0 ? Theme.Spacing.s : Theme.Spacing.l)
                                            .padding(.bottom, Theme.Spacing.xs)
                                        }

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
                                .padding(.vertical, Theme.Spacing.xs)
                            }
                            .frame(maxHeight: 380)
                            .onChange(of: selectedIndex) { newIndex in
                                withAnimation(.easeOut(duration: 0.1)) {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                    } else if !query.isEmpty {
                        emptyState
                    } else if appState.fullTextSearchMode {
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: "magnifyingglass")
                                .font(Theme.Fonts.icon)
                                .foregroundStyle(Theme.Colors.textMuted)
                            Text("Type to search across all files")
                                .font(Theme.Fonts.uiSmall)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        .padding(Theme.Spacing.xxl)
                    }

                    // Footer hints
                    footerBar
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

    // MARK: - Mode Indicator

    @ViewBuilder
    private var modeIndicator: some View {
        let (mode, _) = PaletteMode.from(query: query, isFTS: appState.fullTextSearchMode)
        switch mode {
        case .commands:
            modeBadge("CMD", icon: "terminal")
        case .headings:
            modeBadge("@", icon: "number")
        case .goToLine:
            modeBadge("LN", icon: "arrow.right.to.line")
        case .fullTextSearch:
            modeBadge("FTS", icon: "doc.text.magnifyingglass")
        case .mixed:
            EmptyView()
        }
    }

    private func modeBadge(_ text: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
            Text(text)
                .font(Theme.Fonts.statusBar)
        }
        .foregroundStyle(Theme.Colors.textSecondary)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(Theme.Colors.backgroundTertiary)
        )
    }

    // MARK: - Placeholder

    private var placeholder: String {
        if appState.fullTextSearchMode {
            return "Search across all files..."
        }
        return "Search files, commands, or type > @ : ..."
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "magnifyingglass")
                .font(Theme.Fonts.icon)
                .foregroundStyle(Theme.Colors.textMuted)
            Text("No results")
                .font(Theme.Fonts.uiSmall)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .padding(Theme.Spacing.xxl)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: Theme.Spacing.l) {
            footerHint(keys: ["Up", "Down"], label: "navigate")
            footerHint(keys: ["Return"], label: "open")
            footerHint(keys: ["Esc"], label: "close")
            Spacer()
            if !results.isEmpty {
                Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.Colors.backgroundTertiary.opacity(0.5))
    }

    private func footerHint(keys: [String], label: String) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.Colors.backgroundTertiary)
                    )
            }
            Text(label)
                .font(Theme.Fonts.statusBar)
                .foregroundStyle(Theme.Colors.textMuted)
        }
    }

    // MARK: - Click Outside to Dismiss

    private func installClickOutsideMonitor() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = event.window else { return event }
            let loc = event.locationInWindow
            let windowHeight = window.frame.height
            let panelWidth: CGFloat = 580
            let panelX = (window.frame.width - panelWidth) / 2
            let panelRect = NSRect(x: panelX, y: 0, width: panelWidth, height: windowHeight - 60)
            if !panelRect.contains(loc) {
                DispatchQueue.main.async { dismiss() }
            }
            return event
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async { dismiss() }
                return nil
            }
            if event.keyCode == 126 { // Up arrow
                DispatchQueue.main.async {
                    if results.count > 0 {
                        selectedIndex = (selectedIndex - 1 + results.count) % results.count
                    }
                }
                return nil
            }
            if event.keyCode == 125 { // Down arrow
                DispatchQueue.main.async {
                    if results.count > 0 {
                        selectedIndex = (selectedIndex + 1) % results.count
                    }
                }
                return nil
            }
            if event.keyCode == 36 { // Return
                DispatchQueue.main.async { executeSelected() }
                return nil
            }
            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Search Logic

    private func updateResults(for query: String) {
        contentSearchWork?.cancel()
        let (mode, cleanQuery) = PaletteMode.from(query: query, isFTS: appState.fullTextSearchMode)

        switch mode {
        case .commands:
            buildCommandResults(query: cleanQuery)
        case .headings:
            buildHeadingResults(query: cleanQuery)
        case .goToLine:
            buildGoToLineResult(query: cleanQuery)
        case .fullTextSearch:
            buildFTSResults(query: cleanQuery)
        case .mixed:
            buildMixedResults(query: cleanQuery)
        }
    }

    // MARK: Command Results

    private func buildCommandResults(query: String) {
        let scored: [(cmd: PaletteCommand, score: Int)] = allCommands
            .map { ($0, commandScore(query: query, command: $0)) }
            .filter { query.isEmpty || $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

        // When empty query, show recent first then all
        if query.isEmpty {
            let recentIds = RecentTracker.recentIds()
            let recentCmds = recentIds.compactMap { id in scored.first(where: { $0.cmd.id == id }) }
            let rest = scored.filter { item in !recentIds.contains(item.cmd.id) }

            var built: [PaletteResult] = []
            var headers: [Int: String] = [:]

            if !recentCmds.isEmpty {
                headers[0] = "Recent"
                for item in recentCmds {
                    built.append(commandToResult(item.cmd))
                }
            }

            // Group remaining by category
            let grouped = Dictionary(grouping: rest, by: { $0.cmd.category })
            for category in CommandCategory.allCases {
                guard let items = grouped[category], !items.isEmpty else { continue }
                headers[built.count] = category.rawValue
                for item in items {
                    built.append(commandToResult(item.cmd))
                }
            }

            results = built
            sectionHeaders = headers
        } else {
            var headers: [Int: String] = [:]
            let grouped = Dictionary(grouping: scored, by: { $0.cmd.category })
            var built: [PaletteResult] = []
            for category in CommandCategory.allCases {
                guard let items = grouped[category], !items.isEmpty else { continue }
                headers[built.count] = category.rawValue
                for item in items {
                    let (_, ranges) = fuzzyScore(query, in: item.cmd.name)
                    built.append(commandToResult(item.cmd, matchRanges: ranges))
                }
            }
            results = built
            sectionHeaders = headers
        }
    }

    private func commandToResult(_ cmd: PaletteCommand, matchRanges: [Range<String.Index>] = []) -> PaletteResult {
        PaletteResult(
            kind: .command,
            title: cmd.name,
            subtitle: "",
            icon: cmd.icon,
            iconColor: Theme.Colors.textSecondary,
            shortcutHint: cmd.shortcut,
            category: cmd.category.rawValue,
            matchRanges: matchRanges
        ) { [weak appState] in
            guard let appState else { return }
            RecentTracker.record(cmd.id)
            cmd.action(appState)
        }
    }

    // MARK: Heading Results

    private func buildHeadingResults(query: String) {
        let outline = appState.documentOutline
        var built: [PaletteResult] = []

        for heading in outline {
            if !query.isEmpty {
                let (score, ranges) = fuzzyScore(query, in: heading.text)
                if score <= 0 { continue }
                built.append(headingToResult(heading, matchRanges: ranges))
            } else {
                built.append(headingToResult(heading))
            }
        }

        results = built
        sectionHeaders = built.isEmpty ? [:] : [0: "Headings"]
    }

    private func headingToResult(_ heading: HeadingItem, matchRanges: [Range<String.Index>] = []) -> PaletteResult {
        let indent = String(repeating: "  ", count: heading.level - 1)
        let prefix = String(repeating: "#", count: heading.level)
        return PaletteResult(
            kind: .heading,
            title: "\(indent)\(heading.text)",
            subtitle: "\(prefix) Line \(heading.id)",
            icon: "number",
            iconColor: Theme.Colors.textMuted,
            matchRanges: matchRanges
        ) { [weak appState] in
            appState?.navigateToHeading(heading)
        }
    }

    // MARK: Go To Line

    private func buildGoToLineResult(query: String) {
        sectionHeaders = [:]
        guard let lineNum = Int(query), lineNum > 0 else {
            results = [
                PaletteResult(
                    kind: .goToLine,
                    title: "Type a line number to jump to",
                    subtitle: "",
                    icon: "arrow.right.to.line",
                    iconColor: Theme.Colors.textMuted
                ) {}
            ]
            return
        }
        let maxLine = appState.lineCount()
        let targetLine = min(lineNum, maxLine)
        results = [
            PaletteResult(
                kind: .goToLine,
                title: "Go to line \(targetLine)",
                subtitle: "of \(maxLine) lines",
                icon: "arrow.right.to.line",
                iconColor: Theme.Colors.textSecondary
            ) { [weak appState] in
                appState?.navigateToLine(targetLine)
            }
        ]
    }

    // MARK: FTS Results

    private func buildFTSResults(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            sectionHeaders = [:]
            return
        }
        results = []
        sectionHeaders = [:]

        let work = DispatchWorkItem { [weak appState] in
            guard let appState else { return }
            let contentResults = searchContent(query: trimmed, appState: appState, maxResults: 50)
            DispatchQueue.main.async {
                let currentTrimmed = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard currentTrimmed == trimmed || PaletteMode.from(query: self.query, isFTS: appState.fullTextSearchMode).1 == trimmed else { return }
                self.results = contentResults
                self.sectionHeaders = contentResults.isEmpty ? [:] : [0: "Content Matches"]
                if self.selectedIndex >= self.results.count {
                    self.selectedIndex = max(0, self.results.count - 1)
                }
            }
        }
        contentSearchWork = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    // MARK: Mixed Results

    private func buildMixedResults(query: String) {
        if query.isEmpty {
            // Show recent commands, then all commands grouped
            buildCommandResults(query: "")
            return
        }

        var headers: [Int: String] = [:]
        var built: [PaletteResult] = []

        // Files
        let files = searchFilesScored(query: query)
        if !files.isEmpty {
            headers[0] = "Files"
            built.append(contentsOf: files.map(\.result))
        }

        // Folders
        let folders = searchFoldersScored(query: query)
        if !folders.isEmpty {
            headers[built.count] = "Folders"
            built.append(contentsOf: folders.map(\.result))
        }

        // Commands
        let cmds = allCommands
            .map { ($0, commandScore(query: query, command: $0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(8)
        if !cmds.isEmpty {
            headers[built.count] = "Commands"
            for (cmd, _) in cmds {
                let (_, ranges) = fuzzyScore(query, in: cmd.name)
                built.append(commandToResult(cmd, matchRanges: ranges))
            }
        }

        results = built
        sectionHeaders = headers

        // Debounced content search
        let work = DispatchWorkItem { [weak appState] in
            guard let appState else { return }
            let contentResults = self.searchContent(query: query, appState: appState, maxResults: 20)
            DispatchQueue.main.async {
                let currentTrimmed = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard currentTrimmed == query else { return }

                var updatedHeaders = self.sectionHeaders
                var updatedResults = self.results

                if !contentResults.isEmpty {
                    updatedHeaders[updatedResults.count] = "Content"
                    updatedResults.append(contentsOf: contentResults)
                }

                self.results = Array(updatedResults.prefix(50))
                self.sectionHeaders = updatedHeaders
                if self.selectedIndex >= self.results.count {
                    self.selectedIndex = max(0, self.results.count - 1)
                }
            }
        }
        contentSearchWork = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    // MARK: - File/Folder/Content Search

    private func searchFilesScored(query: String) -> [(result: PaletteResult, score: Int)] {
        guard let rootURL = appState.rootURL else { return [] }
        let files = appState.allMarkdownFiles()

        return files
            .compactMap { url -> (URL, Int, [Range<String.Index>])? in
                let (score, ranges) = fuzzyScore(query, in: url.lastPathComponent)
                return score > 0 ? (url, score, ranges) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(15)
            .map { (url, score, ranges) in
                let relative = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                let result = PaletteResult(
                    kind: .file,
                    title: url.lastPathComponent,
                    subtitle: relative,
                    icon: appState.markdownDefaults.icon,
                    iconColor: appState.markdownDefaults.color,
                    matchRanges: ranges
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
            .compactMap { url -> (URL, Int, [Range<String.Index>])? in
                let (score, ranges) = fuzzyScore(query, in: url.lastPathComponent)
                return score > 0 ? (url, score, ranges) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(10)
            .map { (url, score, ranges) in
                let relative = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                let customization = appState.folderCustomization(for: url)
                let result = PaletteResult(
                    kind: .folder,
                    title: url.lastPathComponent,
                    subtitle: relative,
                    icon: customization.icon,
                    iconColor: customization.color,
                    matchRanges: ranges
                ) { [weak appState] in
                    appState?.setExpanded(url, expanded: true)
                    appState?.selectedNodeURL = url
                }
                return (result: result, score: score)
            }
    }

    private func searchContent(query: String, appState: AppState, maxResults: Int) -> [PaletteResult] {
        guard let rootURL = appState.rootURL else { return [] }
        let files = appState.allMarkdownFiles()
        let lowered = query.lowercased()
        var matches: [ContentMatch] = []

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
                iconColor: Theme.Colors.textMuted
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

// MARK: - Search Field (NSViewRepresentable)

struct PaletteSearchField: NSViewRepresentable {
    @Binding var query: String
    @Binding var selectedIndex: Int
    let resultCount: Int
    let placeholder: String
    let onSubmit: () -> Void
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
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
        context.coordinator.resultCount = resultCount
        context.coordinator.selectedIndex = $selectedIndex
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onQueryChanged = onQueryChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(query: $query, selectedIndex: $selectedIndex, resultCount: resultCount,
                    onSubmit: onSubmit, onQueryChanged: onQueryChanged)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var query: Binding<String>
        var selectedIndex: Binding<Int>
        var resultCount: Int
        var onSubmit: () -> Void
        var onQueryChanged: (String) -> Void

        init(query: Binding<String>, selectedIndex: Binding<Int>, resultCount: Int,
             onSubmit: @escaping () -> Void, onQueryChanged: @escaping (String) -> Void) {
            self.query = query
            self.selectedIndex = selectedIndex
            self.resultCount = resultCount
            self.onSubmit = onSubmit
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

        // Arrow keys, Return handled here. Do NOT override editor.delegate
        // (that breaks this delegate chain). Escape handled by global key monitor.
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
                // Also handle Escape here as fallback
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
                if result.matchRanges.isEmpty {
                    Text(result.title)
                        .font(Theme.Fonts.uiSmall)
                        .foregroundStyle(Theme.Colors.text)
                        .lineLimit(1)
                } else {
                    highlightedText(result.title, ranges: result.matchRanges)
                        .lineLimit(1)
                }

                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(Theme.Fonts.statusBar)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let hint = result.shortcutHint {
                shortcutBadge(hint)
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

    private func shortcutBadge(_ hint: String) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(hint.components(separatedBy: "+"), id: \.self) { part in
                Text(shortcutSymbol(part))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.horizontal, Theme.Spacing.xs)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.Colors.backgroundTertiary)
                    )
            }
        }
    }

    private func shortcutSymbol(_ part: String) -> String {
        switch part.trimmingCharacters(in: .whitespaces) {
        case "Cmd": return "Cmd"
        case "Shift": return "Shift"
        case "Alt", "Option": return "Opt"
        case "Ctrl", "Control": return "Ctrl"
        default: return part.trimmingCharacters(in: .whitespaces)
        }
    }

    private func highlightedText(_ text: String, ranges: [Range<String.Index>]) -> some View {
        var attributedString = AttributedString(text)

        // Set base style
        attributedString.font = Theme.Fonts.uiSmall
        attributedString.foregroundColor = Theme.Colors.text

        // Highlight matched ranges
        for range in ranges {
            guard let attrRange = Range(range, in: attributedString) else { continue }
            attributedString[attrRange].foregroundColor = Color.white
            attributedString[attrRange].font = Font.custom("RobotoMono-Bold", size: 12)
        }

        return Text(attributedString)
    }
}

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

// MARK: - Command Palette View

struct CommandPaletteView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @State private var results: [PaletteResult] = []
    @State private var contentSearchWork: DispatchWorkItem?

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
    ]

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

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
                    onEscape: dismiss
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
        }
        .onChange(of: query) { newQuery in
            selectedIndex = 0
            updateResults(for: newQuery)
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

        // Mixed mode: files + folders + commands + content
        var combined: [PaletteResult] = []

        // File matches
        combined.append(contentsOf: searchFiles(query: trimmed))

        // Folder matches
        combined.append(contentsOf: searchFolders(query: trimmed))

        // Command matches
        combined.append(contentsOf: searchCommands(query: trimmed))

        // Show results immediately
        results = Array(combined.prefix(50))

        // Debounced content search
        let work = DispatchWorkItem { [weak appState] in
            guard let appState else { return }
            let contentResults = searchContent(query: trimmed, appState: appState)
            DispatchQueue.main.async {
                // Rebuild to maintain order: files, folders, commands, content
                var updated: [PaletteResult] = []
                updated.append(contentsOf: self.searchFiles(query: trimmed))
                updated.append(contentsOf: self.searchFolders(query: trimmed))
                updated.append(contentsOf: self.searchCommands(query: trimmed))
                updated.append(contentsOf: contentResults)
                self.results = Array(updated.prefix(50))
                if self.selectedIndex >= self.results.count {
                    self.selectedIndex = max(0, self.results.count - 1)
                }
            }
        }
        contentSearchWork = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func searchFiles(query: String) -> [PaletteResult] {
        guard let rootURL = appState.rootURL else { return [] }
        let files = appState.allMarkdownFiles()
        let lowered = query.lowercased()

        return files
            .filter { $0.lastPathComponent.lowercased().contains(lowered) }
            .prefix(15)
            .map { url in
                let relative = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                return PaletteResult(
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
            }
    }

    private func searchFolders(query: String) -> [PaletteResult] {
        guard let rootURL = appState.rootURL else { return [] }
        let folders = appState.allFolders()
        let lowered = query.lowercased()

        return folders
            .filter { $0 != rootURL && $0.lastPathComponent.lowercased().contains(lowered) }
            .prefix(10)
            .map { url in
                let relative = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                let customization = appState.folderCustomization(for: url)
                return PaletteResult(
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
        let lowered = query.lowercased()
        let filtered = Self.commands.filter {
            lowered.isEmpty || $0.name.lowercased().contains(lowered)
        }

        return filtered.map { cmd in
            PaletteResult(
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

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBordered = false
        field.backgroundColor = .clear
        field.focusRingType = .none
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
        if nsView.stringValue != query {
            nsView.stringValue = query
        }
        context.coordinator.resultCount = resultCount
        context.coordinator.selectedIndex = $selectedIndex
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onEscape = onEscape
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(query: $query, selectedIndex: $selectedIndex, resultCount: resultCount, onSubmit: onSubmit, onEscape: onEscape)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var query: Binding<String>
        var selectedIndex: Binding<Int>
        var resultCount: Int
        var onSubmit: () -> Void
        var onEscape: () -> Void

        init(query: Binding<String>, selectedIndex: Binding<Int>, resultCount: Int, onSubmit: @escaping () -> Void, onEscape: @escaping () -> Void) {
            self.query = query
            self.selectedIndex = selectedIndex
            self.resultCount = resultCount
            self.onSubmit = onSubmit
            self.onEscape = onEscape
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            query.wrappedValue = field.stringValue
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

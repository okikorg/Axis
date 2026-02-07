import SwiftUI
import AppKit

// MARK: - Open File Tab

struct OpenFile: Identifiable, Equatable {
    let id: URL
    var url: URL
    var content: String
    var isDirty: Bool
    var lastSavedAt: Date?
    
    init(url: URL, content: String = "", isDirty: Bool = false) {
        self.id = url
        self.url = url
        self.content = content
        self.isDirty = isDirty
        self.lastSavedAt = nil
    }
}

// MARK: - App State

final class AppState: ObservableObject {
    @Published var rootURL: URL? = nil
    @Published var rootNode: FileNode? = nil
    @Published var selectedNodeURL: URL? = nil
    @Published var openFiles: [OpenFile] = []
    @Published var activeFileURL: URL? = nil
    @Published var currentText: String = ""  // Direct text binding
    @Published var isPreview: Bool = false
    @Published var isDistractionFree: Bool = false
    @Published var isLineWrapping: Bool = true
    @Published var zoomLevel: CGFloat = 1.0  // 1.0 = 100%
    @Published var showSearch: Bool = false
    @Published var editorSearchQuery: String = ""
    @Published var currentMatchIndex: Int = 0
    @Published var expandedFolderPaths: Set<String> = []
    @Published var activeSheet: ActiveSheet? = nil
    @Published var searchQuery: String = ""

    private var autosave = DebouncedAutosave()
    private var directoryMonitor: DirectoryMonitor?

    // MARK: - Computed Properties
    
    var activeFile: OpenFile? {
        guard let url = activeFileURL else { return nil }
        return openFiles.first { $0.url == url }
    }
    
    var editorText: String {
        get { currentText }
        set { updateText(newValue) }
    }
    
    var isDirty: Bool {
        activeFile?.isDirty ?? false
    }
    
    var lastSavedAt: Date? {
        activeFile?.lastSavedAt
    }
    
    var deleteTargetName: String {
        guard let url = selectedNodeURL else { return "" }
        return url.lastPathComponent
    }

    // MARK: - Root Folder Management

    func restoreLastRootIfPossible() {
        guard rootURL == nil else { return }
        guard let path = UserDefaults.standard.string(forKey: "lastRootPath") else { return }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        setRoot(url)
    }

    func pickRootFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            setRoot(url)
        }
    }

    func setRoot(_ url: URL) {
        rootURL = url
        UserDefaults.standard.set(url.path, forKey: "lastRootPath")
        loadExpandedFolders(for: url)
        reloadTree(selecting: nil)
        startMonitoringRoot(url)
    }

    func reloadTree(selecting selection: URL?) {
        guard let rootURL else { return }
        let builder = FileTreeBuilder()
        let rootNode = builder.buildRootNode(rootURL: rootURL)
        self.rootNode = rootNode
        expandedFolderPaths.insert(rootURL.path)
        persistExpandedFolders()

        if let selection {
            selectedNodeURL = selection
            openFile(at: selection)
        } else if let firstFile = rootNode.firstMarkdownFile() {
            selectedNodeURL = firstFile
            openFile(at: firstFile)
        } else {
            selectedNodeURL = rootURL
        }
    }

    // MARK: - File Selection & Tabs

    func setSelectedNode(_ url: URL?) {
        guard selectedNodeURL != url else { return }
        
        // Save current file before switching
        syncCurrentTextToFile()
        
        selectedNodeURL = url
        
        if let url = url, !isDirectory(url), url.pathExtension.lowercased() == "md" {
            openFile(at: url)
        }
    }
    
    func openFile(at url: URL) {
        guard !isDirectory(url) else { return }
        guard url.pathExtension.lowercased() == "md" else { return }
        
        // Save current file before switching
        syncCurrentTextToFile()
        
        // Check if already open
        if let existing = openFiles.first(where: { $0.url == url }) {
            activeFileURL = existing.url
            currentText = existing.content
            return
        }
        
        // Load file content
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var file = OpenFile(url: url, content: content)
        
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modified = attrs[.modificationDate] as? Date {
            file.lastSavedAt = modified
        }
        
        openFiles.append(file)
        activeFileURL = url
        currentText = content
    }
    
    func closeFile(at url: URL) {
        // Save before closing if dirty
        if url == activeFileURL {
            syncCurrentTextToFile()
        }
        if let file = openFiles.first(where: { $0.url == url }), file.isDirty {
            saveFile(at: url)
        }
        
        openFiles.removeAll { $0.url == url }
        
        // Switch to another tab or clear
        if activeFileURL == url {
            if let nextFile = openFiles.last {
                activeFileURL = nextFile.url
                currentText = nextFile.content
            } else {
                activeFileURL = nil
                currentText = ""
            }
        }
    }
    
    func closeOtherFiles(except url: URL) {
        let filesToClose = openFiles.filter { $0.url != url }
        for file in filesToClose {
            closeFile(at: file.url)
        }
    }
    
    func closeAllFiles() {
        syncCurrentTextToFile()
        for file in openFiles where file.isDirty {
            saveFile(at: file.url)
        }
        openFiles.removeAll()
        activeFileURL = nil
        currentText = ""
    }
    
    func setActiveFile(_ url: URL) {
        guard openFiles.contains(where: { $0.url == url }) else { return }
        
        // Save current before switching
        syncCurrentTextToFile()
        
        activeFileURL = url
        selectedNodeURL = url
        
        if let file = openFiles.first(where: { $0.url == url }) {
            currentText = file.content
        }
    }

    // MARK: - Editor Content
    
    private func syncCurrentTextToFile() {
        guard let url = activeFileURL,
              let index = openFiles.firstIndex(where: { $0.url == url }) else { return }
        
        if openFiles[index].content != currentText {
            openFiles[index].content = currentText
            openFiles[index].isDirty = true
        }
    }

    func updateText(_ text: String) {
        currentText = text
        
        guard let url = activeFileURL,
              let index = openFiles.firstIndex(where: { $0.url == url }) else { return }
        
        openFiles[index].content = text
        openFiles[index].isDirty = true
        
        autosave.schedule { [weak self] in
            self?.saveActiveFile()
        }
    }
    
    func updateEditorText(_ text: String) {
        updateText(text)
    }

    // MARK: - Saving

    func saveActiveFile() {
        guard let url = activeFileURL else { return }
        syncCurrentTextToFile()
        saveFile(at: url)
    }
    
    func saveFile(at url: URL) {
        guard let index = openFiles.firstIndex(where: { $0.url == url }) else { return }
        
        do {
            try openFiles[index].content.write(to: url, atomically: true, encoding: .utf8)
            openFiles[index].isDirty = false
            openFiles[index].lastSavedAt = Date()
        } catch {
            print("Failed to save file: \(error)")
        }
    }
    
    func saveAllFiles() {
        syncCurrentTextToFile()
        for file in openFiles where file.isDirty {
            saveFile(at: file.url)
        }
    }

    // MARK: - File Operations

    func presentNewFileSheet() {
        activeSheet = .newFile
    }

    func presentNewFolderSheet() {
        activeSheet = .newFolder
    }

    func presentDeleteConfirm() {
        guard let selectedNodeURL else { return }
        if selectedNodeURL == rootURL { return }
        activeSheet = .delete
    }

    func dismissSheet() {
        activeSheet = nil
    }

    func createMarkdownFile(named name: String) {
        defer { dismissSheet() }
        guard let targetFolder = currentTargetFolder() else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let finalName = cleanName.lowercased().hasSuffix(".md") ? cleanName : "\(cleanName).md"
        let url = targetFolder.appendingPathComponent(finalName)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)
        reloadTree(selecting: url)
    }

    func createFolder(named name: String) {
        defer { dismissSheet() }
        guard let targetFolder = currentTargetFolder() else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let url = targetFolder.appendingPathComponent(cleanName)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        } catch {
            print("Failed to create folder: \(error)")
        }
        reloadTree(selecting: url)
    }

    func deleteSelectedNode() {
        defer { dismissSheet() }
        guard let url = selectedNodeURL else { return }
        if url == rootURL { return }
        
        // Close if open
        closeFile(at: url)
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Failed to delete: \(error)")
        }
        reloadTree(selecting: rootURL)
    }

    // MARK: - Helpers

    private func currentTargetFolder() -> URL? {
        guard let rootURL else { return nil }
        guard let selected = selectedNodeURL else { return rootURL }
        if isDirectory(selected) { return selected }
        return selected.deletingLastPathComponent()
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }

    private func startMonitoringRoot(_ url: URL) {
        directoryMonitor?.stop()
        directoryMonitor = DirectoryMonitor(url: url) { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.reloadTree(selecting: self.selectedNodeURL)
            }
        }
        directoryMonitor?.start()
    }

    // MARK: - Statistics

    func wordCount() -> Int {
        let words = currentText.split { $0.isWhitespace || $0.isNewline }
        return words.count
    }
    
    func lineCount() -> Int {
        currentText.components(separatedBy: .newlines).count
    }
    
    func characterCount() -> Int {
        currentText.count
    }

    // MARK: - Zoom
    
    func zoomIn() {
        zoomLevel = min(zoomLevel + 0.1, 2.0)  // Max 200%
    }
    
    func zoomOut() {
        zoomLevel = max(zoomLevel - 0.1, 0.5)  // Min 50%
    }
    
    func resetZoom() {
        zoomLevel = 1.0
    }
    
    var zoomPercentage: Int {
        Int(zoomLevel * 100)
    }
    
    // MARK: - Search
    
    func toggleSearch() {
        showSearch.toggle()
        if !showSearch {
            editorSearchQuery = ""
            currentMatchIndex = 0
        }
    }
    
    func closeSearch() {
        showSearch = false
        editorSearchQuery = ""
        currentMatchIndex = 0
    }
    
    var searchMatches: [Range<String.Index>] {
        guard !editorSearchQuery.isEmpty else { return [] }
        var matches: [Range<String.Index>] = []
        var searchStart = currentText.startIndex
        
        while let range = currentText.range(of: editorSearchQuery, options: .caseInsensitive, range: searchStart..<currentText.endIndex) {
            matches.append(range)
            searchStart = range.upperBound
        }
        return matches
    }
    
    var matchCount: Int {
        searchMatches.count
    }
    
    func findNext() {
        guard matchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % matchCount
    }
    
    func findPrevious() {
        guard matchCount > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + matchCount) % matchCount
    }

    // MARK: - Folder Expansion

    func isExpanded(_ url: URL) -> Bool {
        expandedFolderPaths.contains(url.path)
    }

    func setExpanded(_ url: URL, expanded: Bool) {
        if expanded {
            expandedFolderPaths.insert(url.path)
        } else {
            expandedFolderPaths.remove(url.path)
        }
        persistExpandedFolders()
    }
    
    func toggleExpanded(_ url: URL) {
        setExpanded(url, expanded: !isExpanded(url))
    }

    private func expandedFoldersKey(for root: URL) -> String {
        "expandedFolders:\(root.path)"
    }

    private func loadExpandedFolders(for root: URL) {
        let key = expandedFoldersKey(for: root)
        let paths = UserDefaults.standard.array(forKey: key) as? [String] ?? []
        expandedFolderPaths = Set(paths)
    }

    private func persistExpandedFolders() {
        guard let rootURL else { return }
        let key = expandedFoldersKey(for: rootURL)
        UserDefaults.standard.set(Array(expandedFolderPaths), forKey: key)
    }
}

// MARK: - Active Sheet

enum ActiveSheet: Identifiable {
    case newFile
    case newFolder
    case delete

    var id: Int {
        switch self {
        case .newFile: return 0
        case .newFolder: return 1
        case .delete: return 2
        }
    }
}

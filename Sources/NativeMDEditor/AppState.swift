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

// MARK: - Customization Colors

struct CustomizationColors {
    static let available: [(name: String, color: Color)] = [
        ("default", Color(hex: "666666")),
        ("red", Color.red),
        ("orange", Color.orange),
        ("yellow", Color.yellow),
        ("green", Color.green),
        ("mint", Color.mint),
        ("cyan", Color.cyan),
        ("blue", Color.blue),
        ("purple", Color.purple),
        ("pink", Color.pink),
    ]
    
    static func color(for name: String?) -> Color {
        if let name = name,
           let found = available.first(where: { $0.name == name }) {
            return found.color
        }
        return available[0].color
    }
}

// MARK: - Markdown Defaults

struct MarkdownDefaults: Codable, Equatable {
    var colorName: String?
    var iconName: String?
    
    static let availableIcons: [String] = [
        "doc.text",
        "doc.text.fill",
        "doc.richtext",
        "doc.richtext.fill",
        "doc.plaintext",
        "doc.plaintext.fill",
        "note.text",
        "text.document",
        "text.document.fill",
        "newspaper",
        "newspaper.fill",
        "book",
        "book.fill",
        "text.book.closed",
        "text.book.closed.fill",
        "pencil",
        "square.and.pencil",
        "highlighter",
        "text.quote",
        "text.alignleft",
        "list.bullet",
        "list.number",
        "checkmark.square",
        "rectangle.and.pencil.and.ellipsis",
    ]
    
    var color: Color {
        CustomizationColors.color(for: colorName)
    }
    
    var icon: String {
        iconName ?? "doc.text"
    }
}

// MARK: - Folder Customization

struct FolderCustomization: Codable, Equatable {
    var colorName: String?
    var iconName: String?
    
    static let availableColors = CustomizationColors.available
    
    static let availableIcons: [String] = [
        // Folders
        "folder",
        "folder.badge.gear",
        "folder.badge.person.crop",
        "folder.badge.plus",
        // Favorites & Markers
        "star.fill",
        "heart.fill",
        "bookmark.fill",
        "tag.fill",
        "flag.fill",
        "pin.fill",
        // Nature & Weather
        "leaf.fill",
        "flame.fill",
        "bolt.fill",
        "snowflake",
        "drop.fill",
        "sun.max.fill",
        "moon.fill",
        "cloud.fill",
        // Objects
        "book.fill",
        "books.vertical.fill",
        "doc.text.fill",
        "newspaper.fill",
        "photo.fill",
        "camera.fill",
        "music.note",
        "music.note.list",
        "film.fill",
        "tv.fill",
        "gamecontroller.fill",
        // Tools & Work
        "hammer.fill",
        "wrench.and.screwdriver.fill",
        "gearshape.fill",
        "briefcase.fill",
        "cart.fill",
        "creditcard.fill",
        // Communication
        "envelope.fill",
        "phone.fill",
        "bubble.left.fill",
        "bell.fill",
        // People & Places
        "person.fill",
        "person.2.fill",
        "house.fill",
        "building.2.fill",
        "mappin.circle.fill",
        "globe.americas.fill",
        // Tech & Science
        "desktopcomputer",
        "laptopcomputer",
        "iphone",
        "cpu.fill",
        "network",
        "wifi",
        "lock.fill",
        "key.fill",
        // Misc
        "lightbulb.fill",
        "gift.fill",
        "graduationcap.fill",
        "trophy.fill",
        "medal.fill",
        "puzzlepiece.fill",
        "cube.fill",
        "archivebox.fill",
        "tray.full.fill",
        "externaldrive.fill",
    ]
    
    var color: Color {
        CustomizationColors.color(for: colorName)
    }
    
    var icon: String {
        iconName ?? "folder"
    }
    
    var expandedIcon: String {
        if let iconName = iconName, iconName != "folder" {
            return iconName
        }
        return "folder.fill"
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
    @Published var isDistractionFree: Bool = false
    @Published var isLineWrapping: Bool = true
    @Published var zoomLevel: CGFloat = 1.0  // 1.0 = 100%
    @Published var selectionRange: NSRange = NSRange(location: 0, length: 0)
    @Published var showSearch: Bool = false
    @Published var editorSearchQuery: String = ""
    @Published var currentMatchIndex: Int = 0
    @Published var markdownDefaults: MarkdownDefaults = MarkdownDefaults()
    @Published var expandedFolderPaths: Set<String> = []
    @Published var activeSheet: ActiveSheet? = nil
    @Published var searchQuery: String = ""
    @Published var folderCustomizations: [String: FolderCustomization] = [:]
    @Published var customizingFolderURL: URL? = nil

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
    
    var targetFolderPath: String {
        guard let rootURL else { return "" }
        guard let targetFolder = currentTargetFolder() else { return rootURL.lastPathComponent }
        
        // Return relative path from root
        let relativePath = targetFolder.path.replacingOccurrences(of: rootURL.path, with: "")
        if relativePath.isEmpty {
            return rootURL.lastPathComponent
        }
        return rootURL.lastPathComponent + relativePath
    }

    // MARK: - Root Folder Management

    func restoreLastRootIfPossible() {
        loadMarkdownDefaults()
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
        loadFolderCustomizations(for: url)
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
    
    func moveItem(from sourceURL: URL, to destinationFolderURL: URL) {
        guard let rootURL else { return }
        
        // Don't move to itself or its children
        if sourceURL == destinationFolderURL { return }
        if destinationFolderURL.path.hasPrefix(sourceURL.path + "/") { return }
        
        // Ensure destination is within root
        guard destinationFolderURL.path.hasPrefix(rootURL.path) else { return }
        
        let destinationURL = destinationFolderURL.appendingPathComponent(sourceURL.lastPathComponent)
        
        // Don't overwrite existing files
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else { return }
        
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            
            // Update open file references - handle both files and folders
            let sourcePath = sourceURL.path
            let destinationPath = destinationURL.path
            
            for i in openFiles.indices {
                let filePath = openFiles[i].url.path
                
                // Check if this file was the moved item or was inside a moved folder
                if filePath == sourcePath {
                    // Direct match - file was moved
                    openFiles[i].url = destinationURL
                } else if filePath.hasPrefix(sourcePath + "/") {
                    // File was inside the moved folder - update its path
                    let relativePath = String(filePath.dropFirst(sourcePath.count))
                    let newPath = destinationPath + relativePath
                    openFiles[i].url = URL(fileURLWithPath: newPath)
                }
            }
            
            // Update active file URL
            if let activeURL = activeFileURL {
                let activePath = activeURL.path
                if activePath == sourcePath {
                    activeFileURL = destinationURL
                } else if activePath.hasPrefix(sourcePath + "/") {
                    let relativePath = String(activePath.dropFirst(sourcePath.count))
                    let newPath = destinationPath + relativePath
                    activeFileURL = URL(fileURLWithPath: newPath)
                }
            }
            
            // Get relative paths for source and destination
            let sourceRelPath = relativePath(for: sourceURL)
            let destRelPath = relativePath(for: destinationURL)
            
            // Update expanded folder paths (now using relative paths)
            if let srcRel = sourceRelPath, let dstRel = destRelPath {
                var newExpandedPaths = Set<String>()
                for path in expandedFolderPaths {
                    if path == srcRel {
                        newExpandedPaths.insert(dstRel)
                    } else if path.hasPrefix(srcRel + "/") {
                        let suffix = String(path.dropFirst(srcRel.count))
                        newExpandedPaths.insert(dstRel + suffix)
                    } else {
                        newExpandedPaths.insert(path)
                    }
                }
                expandedFolderPaths = newExpandedPaths
                
                // Update folder customizations
                var newCustomizations = [String: FolderCustomization]()
                for (path, customization) in folderCustomizations {
                    if path == srcRel {
                        newCustomizations[dstRel] = customization
                    } else if path.hasPrefix(srcRel + "/") {
                        let suffix = String(path.dropFirst(srcRel.count))
                        newCustomizations[dstRel + suffix] = customization
                    } else {
                        newCustomizations[path] = customization
                    }
                }
                folderCustomizations = newCustomizations
                persistFolderCustomizations()
            }
            
            reloadTree(selecting: destinationURL)
        } catch {
            print("Failed to move: \(error)")
        }
    }
    
    func handleDroppedURLs(_ urls: [URL]) -> Bool {
        for url in urls {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            
            if isDir.boolValue {
                // Dropped a folder - set as root
                setRoot(url)
                return true
            } else if url.pathExtension.lowercased() == "md" {
                // Dropped a markdown file - open its parent as root and select the file
                let parentFolder = url.deletingLastPathComponent()
                setRoot(parentFolder)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.setSelectedNode(url)
                }
                return true
            }
        }
        return false
    }

    // MARK: - Helpers

    func currentTargetFolder() -> URL? {
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
    
    private func relativePath(for url: URL) -> String? {
        guard let rootURL else { return nil }
        let rootPath = rootURL.path
        let urlPath = url.path
        
        if urlPath == rootPath {
            return "."
        } else if urlPath.hasPrefix(rootPath + "/") {
            return String(urlPath.dropFirst(rootPath.count + 1))
        }
        return nil
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

    // MARK: - Inline Formatting

    /// Toggle wrapping of the selected text with the given marker (e.g. "**", "*", "`", "~~").
    /// If nothing is selected, inserts the markers and places cursor between them.
    /// If selection is already wrapped, removes the markers.
    func toggleInlineFormat(_ marker: String) {
        guard activeFileURL != nil else { return }
        let nsText = currentText as NSString
        let sel = selectionRange
        let loc = min(sel.location, nsText.length)
        let len = min(sel.length, nsText.length - loc)
        let safeSel = NSRange(location: loc, length: len)
        let ml = marker.count

        if safeSel.length > 0 {
            // Check if selection is already wrapped
            let before = safeSel.location >= ml ? NSRange(location: safeSel.location - ml, length: ml) : nil
            let after = (safeSel.location + safeSel.length + ml <= nsText.length) ? NSRange(location: safeSel.location + safeSel.length, length: ml) : nil

            if let b = before, let a = after,
               nsText.substring(with: b) == marker,
               nsText.substring(with: a) == marker {
                // Remove markers
                var result = nsText.replacingCharacters(in: a, with: "")
                result = (result as NSString).replacingCharacters(in: b, with: "")
                updateText(result)
                selectionRange = NSRange(location: b.location, length: safeSel.length)
            } else {
                // Wrap selection
                let selected = nsText.substring(with: safeSel)
                let wrapped = "\(marker)\(selected)\(marker)"
                let result = nsText.replacingCharacters(in: safeSel, with: wrapped)
                updateText(result)
                selectionRange = NSRange(location: safeSel.location + ml, length: safeSel.length)
            }
        } else {
            // No selection -- insert markers and cursor between
            let result = nsText.replacingCharacters(in: safeSel, with: "\(marker)\(marker)")
            updateText(result)
            selectionRange = NSRange(location: loc + ml, length: 0)
        }
    }

    func toggleBold() { toggleInlineFormat("**") }
    func toggleItalic() { toggleInlineFormat("*") }
    func toggleCode() { toggleInlineFormat("`") }
    func toggleStrikethrough() { toggleInlineFormat("~~") }

    func insertLink() {
        guard activeFileURL != nil else { return }
        let nsText = currentText as NSString
        let sel = selectionRange
        let loc = min(sel.location, nsText.length)
        let len = min(sel.length, nsText.length - loc)
        let safeSel = NSRange(location: loc, length: len)

        if safeSel.length > 0 {
            let selected = nsText.substring(with: safeSel)
            let link = "[\(selected)](url)"
            let result = nsText.replacingCharacters(in: safeSel, with: link)
            updateText(result)
            // Select "url" so user can type over it
            let urlStart = safeSel.location + selected.count + 2
            selectionRange = NSRange(location: urlStart, length: 3)
        } else {
            let link = "[](url)"
            let result = nsText.replacingCharacters(in: safeSel, with: link)
            updateText(result)
            selectionRange = NSRange(location: loc + 1, length: 0)
        }
    }

    func insertHeading() {
        guard activeFileURL != nil else { return }
        let nsText = currentText as NSString
        let pos = min(selectionRange.location, nsText.length)
        let lineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
        let line = nsText.substring(with: lineRange)

        // Count existing heading level
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }

        var newLine: String
        if level >= 6 {
            // Remove heading
            newLine = String(line.drop(while: { $0 == "#" }).drop(while: { $0 == " " }))
        } else if level > 0 {
            // Increase heading level
            newLine = "#\(line)"
        } else {
            // Add heading
            newLine = "# \(line)"
        }

        let result = nsText.replacingCharacters(in: lineRange, with: newLine)
        updateText(result)
    }

    /// Set the current line to a specific heading level (1-6), or remove heading if already at that level.
    func setHeading(level targetLevel: Int) {
        guard activeFileURL != nil else { return }
        guard targetLevel >= 1 && targetLevel <= 6 else { return }
        let nsText = currentText as NSString
        let pos = min(selectionRange.location, nsText.length)
        let lineRange = nsText.lineRange(for: NSRange(location: pos, length: 0))
        let line = nsText.substring(with: lineRange)

        // Count existing heading level
        var currentLevel = 0
        for ch in line {
            if ch == "#" { currentLevel += 1 } else { break }
        }

        // Strip existing heading prefix to get bare content
        let content = String(line.drop(while: { $0 == "#" }).drop(while: { $0 == " " }))
        let prefix = String(repeating: "#", count: targetLevel)

        let newLine: String
        if currentLevel == targetLevel {
            // Already at this level — remove heading
            newLine = content
        } else {
            // Set to target level
            newLine = "\(prefix) \(content)"
        }

        let result = nsText.replacingCharacters(in: lineRange, with: newLine)
        updateText(result)
    }

    // MARK: - Checkbox Toggle

    func toggleCheckbox() {
        guard activeFileURL != nil else { return }
        let text = currentText
        guard !text.isEmpty else { return }

        let nsText = text as NSString
        let clampedPos = min(selectionRange.location, nsText.length)
        let lineRange = nsText.lineRange(for: NSRange(location: clampedPos, length: 0))
        let line = nsText.substring(with: lineRange)

        var newLine: String
        if line.contains("- [x] ") || line.contains("- [X] ") {
            newLine = line.replacingOccurrences(of: "- [x] ", with: "- [ ] ")
            newLine = newLine.replacingOccurrences(of: "- [X] ", with: "- [ ] ")
        } else if line.contains("- [ ] ") {
            newLine = line.replacingOccurrences(of: "- [ ] ", with: "- [x] ")
        } else if let range = line.range(of: "^(\\s*[-*+])\\s", options: .regularExpression) {
            let marker = String(line[range])
            newLine = line.replacingCharacters(in: range, with: "\(marker)[ ] ")
        } else {
            let leadingWhitespace = line.prefix(while: { $0.isWhitespace && !$0.isNewline })
            let content = line.drop(while: { $0.isWhitespace && !$0.isNewline })
            newLine = "\(leadingWhitespace)- [ ] \(content)"
        }

        let replaced = nsText.replacingCharacters(in: lineRange, with: newLine)
        updateText(replaced)
    }

    // MARK: - Folder Expansion

    func isExpanded(_ url: URL) -> Bool {
        guard let relPath = relativePath(for: url) else { return false }
        return expandedFolderPaths.contains(relPath)
    }

    func setExpanded(_ url: URL, expanded: Bool) {
        guard let relPath = relativePath(for: url) else { return }
        if expanded {
            expandedFolderPaths.insert(relPath)
        } else {
            expandedFolderPaths.remove(relPath)
        }
        persistExpandedFolders()
    }
    
    func toggleExpanded(_ url: URL) {
        setExpanded(url, expanded: !isExpanded(url))
    }

    private func expandedFoldersKey(for root: URL) -> String {
        // Use folder name instead of full path so it's portable
        "expandedFolders:\(root.lastPathComponent)"
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
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Folder Customization
    
    func folderCustomization(for url: URL) -> FolderCustomization {
        guard let relPath = relativePath(for: url) else {
            return FolderCustomization()
        }
        return folderCustomizations[relPath] ?? FolderCustomization()
    }
    
    func setFolderCustomization(_ customization: FolderCustomization, for url: URL) {
        guard let relPath = relativePath(for: url) else { return }
        folderCustomizations[relPath] = customization
        persistFolderCustomizations()
    }
    
    func presentFolderCustomization(for url: URL) {
        customizingFolderURL = url
        activeSheet = .customizeFolder
    }
    
    private func folderCustomizationsKey(for root: URL) -> String {
        // Use folder name instead of full path so it's portable
        "folderCustomizations:\(root.lastPathComponent)"
    }
    
    private func loadFolderCustomizations(for root: URL) {
        let key = folderCustomizationsKey(for: root)
        guard let data = UserDefaults.standard.data(forKey: key) else {
            folderCustomizations = [:]
            return
        }
        do {
            let decoded = try JSONDecoder().decode([String: FolderCustomization].self, from: data)
            folderCustomizations = decoded
        } catch {
            print("Failed to decode folder customizations: \(error)")
            folderCustomizations = [:]
        }
    }
    
    private func persistFolderCustomizations() {
        guard let rootURL else { return }
        let key = folderCustomizationsKey(for: rootURL)
        do {
            let data = try JSONEncoder().encode(folderCustomizations)
            UserDefaults.standard.set(data, forKey: key)
            UserDefaults.standard.synchronize()
        } catch {
            print("Failed to encode folder customizations: \(error)")
        }
    }
    
    // MARK: - Markdown Defaults
    
    func setMarkdownDefaults(_ defaults: MarkdownDefaults) {
        markdownDefaults = defaults
        persistMarkdownDefaults()
    }
    
    func presentMarkdownCustomization() {
        activeSheet = .customizeMarkdown
    }
    
    private func loadMarkdownDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "markdownDefaults") else {
            markdownDefaults = MarkdownDefaults()
            return
        }
        do {
            let decoded = try JSONDecoder().decode(MarkdownDefaults.self, from: data)
            markdownDefaults = decoded
        } catch {
            print("Failed to decode markdown defaults: \(error)")
            markdownDefaults = MarkdownDefaults()
        }
    }
    
    private func persistMarkdownDefaults() {
        do {
            let data = try JSONEncoder().encode(markdownDefaults)
            UserDefaults.standard.set(data, forKey: "markdownDefaults")
            UserDefaults.standard.synchronize()
        } catch {
            print("Failed to encode markdown defaults: \(error)")
        }
    }
    
    func initializeMarkdownDefaults() {
        loadMarkdownDefaults()
    }
}

// MARK: - Active Sheet

enum ActiveSheet: Identifiable {
    case newFile
    case newFolder
    case delete
    case customizeFolder
    case customizeMarkdown

    var id: Int {
        switch self {
        case .newFile: return 0
        case .newFolder: return 1
        case .delete: return 2
        case .customizeFolder: return 3
        case .customizeMarkdown: return 4
        }
    }
}

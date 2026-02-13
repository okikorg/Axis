import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Window Configurator

/// Finds the hosting NSWindow and applies titlebar configuration.
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if appState.rootURL == nil {
                WelcomeView()
            } else {
                MainEditorView()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(WindowConfigurator())
        .background(Theme.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.Colors.textMuted, lineWidth: 2)
                .opacity(isDropTargeted ? 1 : 0)
                .padding(4)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .overlay {
            if appState.showCommandPalette {
                CommandPaletteView()
                    .transition(.opacity)
            }
        }
        .sheet(item: $appState.activeSheet) { sheet in
            switch sheet {
            case .newFile:
                NamePromptView(
                    title: "New Markdown File",
                    placeholder: "Notes.md",
                    confirmTitle: "Create",
                    initialValue: "",
                    targetFolder: appState.targetFolderPath,
                    onCancel: { appState.dismissSheet() },
                    onConfirm: { name in
                        appState.createMarkdownFile(named: name)
                    }
                )
            case .newFolder:
                NamePromptView(
                    title: "New Folder",
                    placeholder: "Docs",
                    confirmTitle: "Create",
                    initialValue: "",
                    targetFolder: appState.targetFolderPath,
                    onCancel: { appState.dismissSheet() },
                    onConfirm: { name in
                        appState.createFolder(named: name)
                    }
                )
            case .rename:
                if let renamingURL = appState.renamingNodeURL {
                    NamePromptView(
                        title: appState.renameTargetIsDirectory ? "Rename Folder" : "Rename File",
                        placeholder: renamingURL.lastPathComponent,
                        confirmTitle: "Rename",
                        initialValue: appState.renameTargetIsDirectory
                            ? renamingURL.lastPathComponent
                            : renamingURL.deletingPathExtension().lastPathComponent,
                        targetFolder: "",
                        onCancel: { appState.dismissSheet() },
                        onConfirm: { name in
                            appState.renameNode(to: name)
                        }
                    )
                }
            case .delete:
                DeleteConfirmView(
                    name: appState.deleteTargetName,
                    onCancel: { appState.dismissSheet() },
                    onConfirm: { appState.deleteSelectedNode() }
                )
            case .customizeFolder:
                if let folderURL = appState.customizingFolderURL {
                    FolderCustomizationView(
                        folderName: folderURL.lastPathComponent,
                        currentCustomization: appState.folderCustomization(for: folderURL),
                        onCancel: { appState.dismissSheet() },
                        onConfirm: { customization in
                            appState.setFolderCustomization(customization, for: folderURL)
                            appState.dismissSheet()
                        }
                    )
                }
            case .customizeMarkdown:
                MarkdownCustomizationView(
                    currentDefaults: appState.markdownDefaults,
                    onCancel: { appState.dismissSheet() },
                    onConfirm: { defaults in
                        appState.setMarkdownDefaults(defaults)
                        appState.dismissSheet()
                    }
                )
            }
        }
        .onAppear {
            appState.restoreLastRootIfPossible()
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async {
                        _ = appState.handleDroppedURLs([url])
                    }
                }
                return true
            }
        }
        return false
    }
}

// MARK: - Welcome View

private struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var hoveredRecent: String? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()
            
            // Minimal icon - no background
            Image(systemName: "doc.text")
                .font(Theme.Fonts.welcomeIcon)
                .foregroundStyle(Theme.Colors.textMuted)
            
            VStack(spacing: Theme.Spacing.s) {
                Text("Axis")
                    .font(Theme.Fonts.welcomeTitle)
                    .foregroundStyle(Theme.Colors.textSecondary)
                
                Text("A minimal markdown editor")
                    .font(Theme.Fonts.ui)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            
            VStack(spacing: Theme.Spacing.m) {
                Button {
                    appState.pickRootFolder()
                } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: "folder")
                            .font(Theme.Fonts.uiSmall)
                        Text("Open Folder")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                
                Text("⌘O")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            
            // Recent folders
            if !appState.recentFolders.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("RECENT")
                        .font(Theme.Fonts.statusBar)
                        .foregroundStyle(Theme.Colors.textDisabled)
                        .padding(.bottom, Theme.Spacing.xs)
                    
                    ForEach(appState.recentFolders, id: \.self) { path in
                        Button {
                            let url = URL(fileURLWithPath: path)
                            if FileManager.default.fileExists(atPath: path) {
                                appState.setRoot(url)
                            }
                        } label: {
                            HStack(spacing: Theme.Spacing.m) {
                                Image(systemName: "folder")
                                    .font(Theme.Fonts.icon)
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .frame(width: 14)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(URL(fileURLWithPath: path).lastPathComponent)
                                        .font(Theme.Fonts.uiSmall)
                                        .foregroundStyle(hoveredRecent == path ? Theme.Colors.text : Theme.Colors.textSecondary)
                                        .lineLimit(1)
                                    
                                    Text(abbreviatePath(path))
                                        .font(Theme.Fonts.statusBar)
                                        .foregroundStyle(Theme.Colors.textDisabled)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Spacing.m)
                            .padding(.vertical, Theme.Spacing.s)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.small)
                                    .fill(hoveredRecent == path ? Theme.Colors.hover : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHovering in
                            hoveredRecent = isHovering ? path : nil
                        }
                    }
                }
                .frame(width: 280)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }
    
    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - Main Editor View

private struct MainEditorView: View {
    @EnvironmentObject private var appState: AppState

    private var themeIcon: String {
        switch appState.appearanceMode {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "circle.lefthalf.filled"
        }
    }

    private var rightSidebarVisible: Bool {
        appState.showOutline || appState.showCalendar
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Sidebar - responsive width
                    if !appState.isDistractionFree {
                        SidebarView()
                            .frame(width: sidebarWidth(for: geo.size.width))
                            .transition(.move(edge: .leading).combined(with: .opacity))

                        // Subtle sidebar/editor divider
                        Rectangle()
                            .fill(Theme.Colors.divider)
                            .frame(width: 1)
                            .transition(.opacity)
                    }

                    // Editor Area - seamless transition
                    VStack(spacing: 0) {
                        // Tab Bar
                        if !appState.openFiles.isEmpty {
                            TabBarView()
                        }

                        // Breadcrumb - minimal
                        if appState.activeFileURL != nil {
                            BreadcrumbView()
                        }

                        // Editor
                        EditorView()

                        // Status Bar - subtle
                        if appState.activeFileURL != nil {
                            StatusBarView()
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Right sidebar - calendar + outline
                    if appState.activeFileURL != nil && (appState.showOutline || appState.showCalendar) {
                        Rectangle()
                            .fill(Theme.Colors.divider)
                            .frame(width: 1)

                        VStack(spacing: 0) {
                            if appState.showCalendar {
                                CalendarView()

                                if appState.showOutline {
                                    Rectangle()
                                        .fill(Theme.Colors.divider)
                                        .frame(height: 1)
                                        .padding(.horizontal, Theme.Spacing.l)
                                }
                            }

                            if appState.showOutline {
                                OutlineView()
                            } else {
                                Spacer()
                            }
                        }
                        .frame(width: outlineWidth(for: geo.size.width))
                    }
                }
                .frame(maxHeight: .infinity)

                // Terminal panel
                if appState.showTerminal {
                    TerminalPanelView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(Theme.Colors.background)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.isDistractionFree.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .accessibilityLabel("Toggle sidebar")
            }

            ToolbarItem(placement: .principal) {
                Spacer()
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let newState = !rightSidebarVisible
                        appState.showOutline = newState
                        appState.showCalendar = newState
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .accessibilityLabel("Toggle right sidebar")

                Button {
                    appState.cycleAppearance()
                } label: {
                    Image(systemName: themeIcon)
                }
                .accessibilityLabel("Switch theme")
            }
        }
    }

    private func sidebarWidth(for windowWidth: CGFloat) -> CGFloat {
        // Responsive sidebar: narrower on small windows, wider on large
        let percentage: CGFloat = windowWidth < 800 ? 0.28 : 0.22
        let width = windowWidth * percentage
        return min(max(width, 160), 280)
    }

    private func outlineWidth(for windowWidth: CGFloat) -> CGFloat {
        let width = windowWidth * 0.18
        return min(max(width, 160), 240)
    }
}

// MARK: - Tab Bar

private struct TabBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(appState.openFiles) { file in
                    TabItemView(file: file)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .background(ScrollWheelRedirector())
        }
        .frame(height: Theme.Size.tabBarHeight)
        .background(Theme.Colors.tabBar)
    }
}

/// Converts vertical scroll-wheel events into horizontal scrolling for the
/// enclosing NSScrollView. Placed inside the ScrollView content so that
/// `enclosingScrollView` resolves to the correct scroll view.
private struct ScrollWheelRedirector: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ScrollWheelInterceptorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private class ScrollWheelInterceptorView: NSView {
        override func scrollWheel(with event: NSEvent) {
            guard abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX),
                  let scrollView = enclosingScrollView,
                  let documentView = scrollView.documentView else {
                super.scrollWheel(with: event)
                return
            }

            let clipView = scrollView.contentView
            let maxX = max(0, documentView.frame.width - clipView.bounds.width)
            var origin = clipView.bounds.origin
            origin.x -= event.scrollingDeltaY
            origin.x = max(0, min(origin.x, maxX))

            clipView.scroll(to: origin)
            scrollView.reflectScrolledClipView(clipView)
        }
    }
}

private struct TabItemView: View {
    @EnvironmentObject private var appState: AppState
    let file: OpenFile
    
    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var isRenameFocused: Bool
    
    private var isActive: Bool {
        appState.activeFileURL == file.url
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if isRenaming {
                TextField("", text: $renameText)
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.tab)
                    .foregroundStyle(Theme.Colors.text)
                    .focused($isRenameFocused)
                    .frame(minWidth: 60)
                    .fixedSize()
                    .onSubmit { commitRename() }
                    .onExitCommand { cancelRename() }
                    .onChange(of: isRenameFocused) { focused in
                        if !focused { commitRename() }
                    }
            } else {
                Text(file.url.lastPathComponent)
                    .font(Theme.Fonts.tab)
                    .foregroundStyle(isActive ? Theme.Colors.text : Theme.Colors.textMuted)
                    .lineLimit(1)
            }
            
            // Dirty indicator or close button
            if !isRenaming {
                Button {
                    appState.closeFile(at: file.url)
                } label: {
                    ZStack {
                        if file.isDirty && !isHovering {
                            Circle()
                                .fill(Theme.Colors.textMuted)
                                .frame(width: 5, height: 5)
                        } else {
                            Image(systemName: "xmark")
                                .font(Theme.Fonts.disclosure)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }
                    .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                .opacity(isHovering || file.isDirty ? 1 : 0)
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(isActive ? Theme.Colors.selection : (isHovering ? Theme.Colors.hover : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            startRenaming()
        }
        .onTapGesture {
            appState.setActiveFile(file.url)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Close") {
                appState.closeFile(at: file.url)
            }
            Button("Close Others") {
                appState.closeOtherFiles(except: file.url)
            }
            Button("Close All") {
                appState.closeAllFiles()
            }
            Divider()
            Button("Rename") {
                startRenaming()
            }
        }
    }
    
    private func startRenaming() {
        renameText = file.url.deletingPathExtension().lastPathComponent
        isRenaming = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isRenameFocused = true
        }
    }
    
    private func commitRename() {
        guard isRenaming else { return }
        isRenaming = false
        isRenameFocused = false
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState.renamingNodeURL = file.url
        appState.renameNode(to: trimmed)
    }
    
    private func cancelRename() {
        isRenaming = false
        isRenameFocused = false
    }
}

// MARK: - Breadcrumb

private struct BreadcrumbItem: Identifiable {
    let id: Int
    let name: String
    let url: URL
    let isFile: Bool
}

private struct BreadcrumbView: View {
    @EnvironmentObject private var appState: AppState
    
    private var breadcrumbItems: [BreadcrumbItem] {
        guard let root = appState.rootURL,
              let active = appState.activeFileURL else { return [] }
        
        var items: [BreadcrumbItem] = []
        var currentURL = root
        
        let relativePath = active.path.replacingOccurrences(of: root.path, with: "")
        let components = relativePath.split(separator: "/").map(String.init)
        
        for (index, component) in components.enumerated() {
            currentURL = currentURL.appendingPathComponent(component)
            let isFile = index == components.count - 1
            items.append(BreadcrumbItem(id: index, name: component, url: currentURL, isFile: isFile))
        }
        
        return items
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            // Path with separators
            ForEach(breadcrumbItems) { item in
                if item.id > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(.horizontal, Theme.Spacing.xs)
                }
                
                BreadcrumbItemView(item: item)
            }
            
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(height: 24)
        .background(Theme.Colors.background)
    }
}

private struct BreadcrumbItemView: View {
    @EnvironmentObject private var appState: AppState
    let item: BreadcrumbItem
    
    private var icon: String {
        if item.isFile {
            return appState.markdownDefaults.icon
        } else {
            let customization = appState.folderCustomization(for: item.url)
            return customization.icon
        }
    }
    
    private var iconColor: Color {
        if item.isFile {
            return appState.markdownDefaults.color
        } else {
            let customization = appState.folderCustomization(for: item.url)
            return customization.color
        }
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(iconColor)
            
            Text(item.name)
                .font(Theme.Fonts.statusBar)
                .foregroundStyle(item.isFile ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
        }
    }
}

// MARK: - Status Bar

private struct StatusBarView: View {
    @EnvironmentObject private var appState: AppState
    
    private var readingTime: String {
        let words = appState.wordCount()
        let minutes = max(1, Int(ceil(Double(words) / 200.0)))
        return "\(minutes) min read"
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            // Error message (takes priority over left side stats)
            if let error = appState.errorMessage {
                Text(error)
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else {
                // Left side - cursor position
                Text("Ln \(appState.cursorLine), Col \(appState.cursorColumn)")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)

                Text("·")
                    .foregroundStyle(Theme.Colors.textDisabled)

                // Stats
                Text("\(appState.wordCount()) words")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)

                Text("·")
                    .foregroundStyle(Theme.Colors.textDisabled)

                Text(readingTime)
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            Spacer()

            // Right side - zoom and status
            if appState.zoomLevel != 1.0 {
                Text("\(appState.zoomPercentage)%")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)

                Text("·")
                    .foregroundStyle(Theme.Colors.textDisabled)
            }

            Text(appState.isDirty ? "Edited" : "Saved")
                .font(Theme.Fonts.statusBar)
                .foregroundStyle(appState.isDirty ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(height: 24)
        .background(Theme.Colors.statusBar)
        .accessibilityElement(children: .combine)
    }
}

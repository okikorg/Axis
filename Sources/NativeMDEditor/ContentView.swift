import SwiftUI
import UniformTypeIdentifiers

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

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            // Minimal icon - no background
            Image(systemName: "doc.text")
                .font(Theme.Fonts.welcomeIcon)
                .foregroundStyle(Theme.Colors.textMuted)
            
            VStack(spacing: Theme.Spacing.s) {
                Text("Native MD Editor")
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
    }
}

// MARK: - Main Editor View

private struct MainEditorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Sidebar - responsive width
                if !appState.isDistractionFree {
                    SidebarView()
                        .frame(width: sidebarWidth(for: geo.size.width))
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
            }
        }
        .background(Theme.Colors.background)
    }
    
    private func sidebarWidth(for windowWidth: CGFloat) -> CGFloat {
        // Responsive sidebar: narrower on small windows, wider on large
        let percentage: CGFloat = windowWidth < 800 ? 0.28 : 0.22
        let width = windowWidth * percentage
        return min(max(width, 160), 280)
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
                
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.m)
        }
        .frame(height: Theme.Size.tabBarHeight)
        .background(Theme.Colors.tabBar)
    }
}

private struct TabItemView: View {
    @EnvironmentObject private var appState: AppState
    let file: OpenFile
    
    @State private var isHovering = false
    
    private var isActive: Bool {
        appState.activeFileURL == file.url
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            // File name only - no icon for cleaner look
            Text(file.url.lastPathComponent)
                .font(Theme.Fonts.tab)
                .foregroundStyle(isActive ? Theme.Colors.text : Theme.Colors.textMuted)
                .lineLimit(1)
            
            // Dirty indicator or close button
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
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(isActive ? Theme.Colors.selection : (isHovering ? Theme.Colors.hover : Color.clear))
        )
        .contentShape(Rectangle())
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
        }
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
        HStack(spacing: 2) {
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
    
    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            // Left side - stats (subtle)
            Text("\(appState.wordCount()) words")
                .font(Theme.Fonts.statusBar)
                .foregroundStyle(Theme.Colors.textMuted)
            
            Text("·")
                .foregroundStyle(Theme.Colors.textMuted)
            
            Text("\(appState.lineCount()) lines")
                .font(Theme.Fonts.statusBar)
                .foregroundStyle(Theme.Colors.textMuted)
            
            Spacer()
            
            // Right side - zoom and status
            if appState.zoomLevel != 1.0 {
                Text("\(appState.zoomPercentage)%")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)
                
                Text("·")
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            
            Text(appState.isDirty ? "Edited" : "Saved")
                .font(Theme.Fonts.statusBar)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(height: 22)
        .background(Theme.Colors.statusBar)
    }
}

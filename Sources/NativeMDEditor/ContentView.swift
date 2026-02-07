import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

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
        .sheet(item: $appState.activeSheet) { sheet in
            switch sheet {
            case .newFile:
                NamePromptView(
                    title: "New Markdown File",
                    placeholder: "Notes.md",
                    confirmTitle: "Create",
                    initialValue: "",
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
            }
        }
        .onAppear {
            appState.restoreLastRootIfPossible()
        }
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

private struct BreadcrumbView: View {
    @EnvironmentObject private var appState: AppState
    
    private var pathComponents: [String] {
        guard let root = appState.rootURL,
              let active = appState.activeFileURL else { return [] }
        
        let relativePath = active.path.replacingOccurrences(of: root.path, with: "")
        return relativePath.split(separator: "/").map(String.init)
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            // Path as single text with separators
            ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                
                let isFile = index == pathComponents.count - 1
                Image(systemName: isFile ? "doc.text" : "folder")
                    .font(.system(size: 10))
                    .foregroundStyle(isFile ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
                
                Text(component)
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(isFile ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
            }
            
            Spacer()
            
            // Mode toggle - icon only, minimal
            HStack(spacing: Theme.Spacing.xs) {
                ModeToggleButton(icon: "pencil", isActive: !appState.isPreview) {
                    appState.isPreview = false
                }
                
                ModeToggleButton(icon: "eye", isActive: appState.isPreview) {
                    appState.isPreview = true
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(height: 24)
        .background(Theme.Colors.background)
    }
}

private struct ModeToggleButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Theme.Fonts.icon)
                .foregroundStyle(isActive ? Theme.Colors.text : Theme.Colors.textMuted)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .fill(isHovering ? Theme.Colors.hover : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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

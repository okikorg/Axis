import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchQuery: String = ""
    @State private var isSearchFocused: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header - minimal
            SidebarHeader(searchQuery: $searchQuery, isSearchFocused: $isSearchFocused)
            
            // File Tree - no divider
            if let root = appState.rootNode {
                let filtered = searchQuery.isEmpty ? root : root.filtered(by: searchQuery)
                
                if let displayNode = filtered {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            FileTreeNode(node: displayNode, depth: 0, isRoot: true)
                        }
                        .padding(.vertical, Theme.Spacing.m)
                        .padding(.horizontal, Theme.Spacing.s)
                    }
                } else {
                    EmptySearchView(query: searchQuery)
                }
            } else {
                EmptySidebarView()
            }
        }
        .background(Theme.Colors.background)
    }
}

// MARK: - Sidebar Header

private struct SidebarHeader: View {
    @EnvironmentObject private var appState: AppState
    @Binding var searchQuery: String
    @Binding var isSearchFocused: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            // Project name & actions - minimal
            HStack(spacing: Theme.Spacing.s) {
                Text(appState.rootURL?.lastPathComponent ?? "Files")
                    .font(Theme.Fonts.sidebarHeader)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                
                Spacer()
                
                // Action buttons - subtle
                HStack(spacing: 0) {
                    IconButton(icon: "plus", tooltip: "New File") {
                        appState.createUntitledFile()
                    }

                    IconButton(icon: "folder", tooltip: "New Folder") {
                        appState.createUntitledFolder()
                    }
                }
            }
            
            // Search field - minimal border
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .font(Theme.Fonts.icon)
                    .foregroundStyle(Theme.Colors.textMuted)
                
                TextField("Search", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.uiSmall)
                    .foregroundStyle(Theme.Colors.text)
                    .focused($isFocused)
                
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(Theme.Fonts.iconSmall)
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
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.m)
    }
}

// MARK: - Icon Button

private struct IconButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Theme.Fonts.icon)
                .foregroundStyle(isHovering ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .fill(isHovering ? Theme.Colors.hover : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(tooltip)
    }
}

// MARK: - File Tree Node

private struct FileTreeNode: View {
    @EnvironmentObject private var appState: AppState
    let node: FileNode
    let depth: Int
    let isRoot: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if !isRoot {
                FileRowView(node: node, depth: depth)
            }
            
            if node.isDirectory {
                let isExpanded = isRoot || appState.isExpanded(node.url)
                
                if isExpanded, let children = node.children {
                    ForEach(children) { child in
                        FileTreeNode(node: child, depth: isRoot ? depth : depth + 1, isRoot: false)
                    }
                }
            }
        }
    }
}

// MARK: - File Row

private struct FileRowView: View {
    @EnvironmentObject private var appState: AppState
    let node: FileNode
    let depth: Int
    
    @State private var isHovering = false
    @State private var isDropTargeted = false
    
    private var isSelected: Bool {
        appState.selectedNodeURL == node.url
    }
    
    private var isActive: Bool {
        appState.activeFileURL == node.url
    }
    
    private var disclosureIcon: String {
        appState.isExpanded(node.url) ? "chevron.down" : "chevron.right"
    }
    
    private var folderCustomization: FolderCustomization {
        appState.folderCustomization(for: node.url)
    }
    
    private var nodeIcon: String {
        if node.isDirectory {
            let customization = folderCustomization
            if appState.isExpanded(node.url) {
                return customization.expandedIcon
            } else {
                return customization.icon
            }
        } else {
            return appState.markdownDefaults.icon
        }
    }
    
    private var nodeColor: Color {
        if node.isDirectory {
            return folderCustomization.color
        }
        return appState.markdownDefaults.color
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            // Indent - simple spacing, no lines
            Spacer()
                .frame(width: CGFloat(depth) * 14)
            
            // Disclosure for folders
            if node.isDirectory {
                Image(systemName: disclosureIcon)
                    .font(Theme.Fonts.disclosure)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .frame(width: 10)
            } else {
                Spacer().frame(width: 10)
            }
            
            // Icon
            Image(systemName: nodeIcon)
                .font(Theme.Fonts.icon)
                .foregroundStyle(nodeColor)
                .frame(width: 14)
            
            // Name
            Text(node.name)
                .font(Theme.Fonts.uiSmall)
                .foregroundStyle(isActive ? Theme.Colors.text : Theme.Colors.textSecondary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.xs)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.Colors.textMuted, lineWidth: 1)
                .opacity(isDropTargeted && node.isDirectory ? 1 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            contextMenuItems
        }
        // Drag source
        .draggable(node.url) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: nodeIcon)
                    .font(Theme.Fonts.icon)
                    .foregroundStyle(nodeColor)
                Text(node.name)
                    .font(Theme.Fonts.uiSmall)
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .background(Theme.Colors.backgroundSecondary)
            .cornerRadius(6)
        }
        // Drop target (only for folders)
        .dropDestination(for: URL.self) { urls, _ in
            guard node.isDirectory, let sourceURL = urls.first else { return false }
            // Don't drop onto itself or parent
            if sourceURL == node.url { return false }
            if node.url.path.hasPrefix(sourceURL.path + "/") { return false }
            appState.moveItem(from: sourceURL, to: node.url)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }
    
    private var backgroundColor: Color {
        if isActive {
            return Theme.Colors.selection
        } else if isHovering || isDropTargeted {
            return Theme.Colors.hover
        }
        return Color.clear
    }
    
    private func handleTap() {
        if node.isDirectory {
            withAnimation(.easeInOut(duration: 0.12)) {
                appState.toggleExpanded(node.url)
            }
        }
        appState.setSelectedNode(node.url)
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            appState.setSelectedNode(node.url)
            appState.presentNewFileSheet()
        } label: {
            Label("New File", systemImage: "plus")
        }
        
        Button {
            appState.setSelectedNode(node.url)
            appState.presentNewFolderSheet()
        } label: {
            Label("New Folder", systemImage: "folder")
        }
        
        Divider()
        
        Button {
            appState.setSelectedNode(node.url)
            appState.presentRenameSheet()
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        
        if node.isDirectory {
            Button {
                appState.presentFolderCustomization(for: node.url)
            } label: {
                Label("Customize Folder...", systemImage: "paintpalette")
            }
        } else {
            Button {
                appState.presentMarkdownCustomization()
            } label: {
                Label("Customize Markdown Files...", systemImage: "paintpalette")
            }
        }
        
        Divider()
        
        Button(role: .destructive) {
            appState.setSelectedNode(node.url)
            appState.presentDeleteConfirm()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Empty States

private struct EmptySidebarView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text("No folder")
                .font(Theme.Fonts.uiSmall)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptySearchView: View {
    let query: String
    
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text("No results")
                .font(Theme.Fonts.uiSmall)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

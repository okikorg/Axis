import Foundation

struct FileNode: Identifiable, Hashable {
    let id: URL
    let url: URL
    let name: String
    let isDirectory: Bool
    let isImageFile: Bool
    var children: [FileNode]?
    let markdownCount: Int
    let containsMarkdown: Bool

    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "tiff", "tif",
        "webp", "heic", "heif", "bmp", "svg", "ico"
    ]

    init(url: URL, isDirectory: Bool, isImageFile: Bool = false, children: [FileNode]? = nil, markdownCount: Int = 0, containsMarkdown: Bool = false) {
        self.id = url
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.isImageFile = isImageFile
        self.children = children
        self.markdownCount = markdownCount
        self.containsMarkdown = containsMarkdown
    }

    func firstMarkdownFile() -> URL? {
        if !isDirectory && url.pathExtension.lowercased() == "md" {
            return url
        }
        return children?.compactMap { $0.firstMarkdownFile() }.first
    }

    func filtered(by query: String) -> FileNode? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return self }
        let matches = name.localizedCaseInsensitiveContains(trimmed)

        if isDirectory {
            let filteredChildren = children?.compactMap { $0.filtered(by: trimmed) } ?? []
            if matches || !filteredChildren.isEmpty {
                return FileNode(
                    url: url,
                    isDirectory: true,
                    children: filteredChildren,
                    markdownCount: markdownCount,
                    containsMarkdown: containsMarkdown
                )
            }
            return nil
        }

        return matches ? self : nil
    }
}

final class FileTreeBuilder {
    private let fileManager = FileManager.default

    func buildRootNode(rootURL: URL) -> FileNode {
        let children = buildChildren(in: rootURL)
        let count = children.reduce(0) { $0 + $1.markdownCount }
        return FileNode(url: rootURL, isDirectory: true, children: children, markdownCount: count, containsMarkdown: count > 0)
    }

    private func buildChildren(in folderURL: URL) -> [FileNode] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let sorted = contents.sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }

        var nodes: [FileNode] = []
        for url in sorted {
            guard let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory else { continue }
            if isDir {
                let children = buildChildren(in: url)
                let count = children.reduce(0) { $0 + $1.markdownCount }
                nodes.append(FileNode(url: url, isDirectory: true, children: children, markdownCount: count, containsMarkdown: count > 0))
            } else if url.pathExtension.lowercased() == "md" {
                nodes.append(FileNode(url: url, isDirectory: false, markdownCount: 1, containsMarkdown: true))
            } else if FileNode.imageExtensions.contains(url.pathExtension.lowercased()) {
                nodes.append(FileNode(url: url, isDirectory: false, isImageFile: true))
            }
        }
        return nodes
    }
}

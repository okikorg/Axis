import Foundation
import Testing
@testable import AxisCore

@Suite("FileNode Tests")
struct FileNodeTests {

    // MARK: - firstMarkdownFile

    @Test func firstMarkdownFileReturnsFileNode() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let node = FileNode(url: url, isDirectory: false, markdownCount: 1, containsMarkdown: true)
        #expect(node.firstMarkdownFile() == url)
    }

    @Test func firstMarkdownFileReturnsNilForNonMarkdown() {
        let url = URL(fileURLWithPath: "/tmp/image.png")
        let node = FileNode(url: url, isDirectory: false, isImageFile: true)
        #expect(node.firstMarkdownFile() == nil)
    }

    @Test func firstMarkdownFileSearchesChildren() {
        let mdURL = URL(fileURLWithPath: "/tmp/folder/note.md")
        let child = FileNode(url: mdURL, isDirectory: false, markdownCount: 1, containsMarkdown: true)
        let folder = FileNode(
            url: URL(fileURLWithPath: "/tmp/folder"),
            isDirectory: true,
            children: [child],
            markdownCount: 1,
            containsMarkdown: true
        )
        #expect(folder.firstMarkdownFile() == mdURL)
    }

    @Test func firstMarkdownFileReturnsNilForEmptyFolder() {
        let folder = FileNode(
            url: URL(fileURLWithPath: "/tmp/empty"),
            isDirectory: true,
            children: [],
            markdownCount: 0,
            containsMarkdown: false
        )
        #expect(folder.firstMarkdownFile() == nil)
    }

    // MARK: - filtered(by:)

    @Test func filteredEmptyQueryReturnsOriginal() {
        let node = FileNode(url: URL(fileURLWithPath: "/tmp/test.md"), isDirectory: false, markdownCount: 1, containsMarkdown: true)
        let result = node.filtered(by: "")
        #expect(result != nil)
        #expect(result?.url == node.url)
    }

    @Test func filteredMatchesFileName() {
        let node = FileNode(url: URL(fileURLWithPath: "/tmp/Notes.md"), isDirectory: false, markdownCount: 1, containsMarkdown: true)
        #expect(node.filtered(by: "notes") != nil)
        #expect(node.filtered(by: "xyz") == nil)
    }

    @Test func filteredRetainsMatchingChildren() {
        let match = FileNode(url: URL(fileURLWithPath: "/tmp/dir/match.md"), isDirectory: false, markdownCount: 1, containsMarkdown: true)
        let miss = FileNode(url: URL(fileURLWithPath: "/tmp/dir/other.md"), isDirectory: false, markdownCount: 1, containsMarkdown: true)
        let folder = FileNode(
            url: URL(fileURLWithPath: "/tmp/dir"),
            isDirectory: true,
            children: [match, miss],
            markdownCount: 2,
            containsMarkdown: true
        )

        let result = folder.filtered(by: "match")
        #expect(result != nil)
        #expect(result?.children?.count == 1)
        #expect(result?.children?.first?.name == "match.md")
    }

    @Test func filteredReturnsNilWhenNoMatch() {
        let child = FileNode(url: URL(fileURLWithPath: "/tmp/dir/a.md"), isDirectory: false, markdownCount: 1, containsMarkdown: true)
        let folder = FileNode(
            url: URL(fileURLWithPath: "/tmp/dir"),
            isDirectory: true,
            children: [child],
            markdownCount: 1,
            containsMarkdown: true
        )
        #expect(folder.filtered(by: "zzz") == nil)
    }

    // MARK: - imageExtensions

    @Test func imageExtensionsContainsCommonTypes() {
        for ext in ["png", "jpg", "jpeg", "gif", "svg", "webp"] {
            #expect(FileNode.imageExtensions.contains(ext), "Missing image extension: \(ext)")
        }
    }
}

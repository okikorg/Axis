import Foundation
import Testing
@testable import AxisCore

@Suite("AppState Tests")
struct AppStateTests {

    // MARK: - Heading Regex / Document Outline

    @Test func documentOutlineParsesHeadings() {
        let state = AppState()
        state.currentText = "# Heading 1\nSome text\n## Heading 2\nMore text\n### Heading 3"
        let outline = state.documentOutline
        #expect(outline.count == 3)
        #expect(outline[0].level == 1)
        #expect(outline[0].text == "Heading 1")
        #expect(outline[1].level == 2)
        #expect(outline[1].text == "Heading 2")
        #expect(outline[2].level == 3)
        #expect(outline[2].text == "Heading 3")
    }

    @Test func documentOutlineEmptyText() {
        let state = AppState()
        state.currentText = ""
        #expect(state.documentOutline.isEmpty)
    }

    @Test func documentOutlineIgnoresNonHeadings() {
        let state = AppState()
        state.currentText = "Not a heading\nSome `# code` here"
        let outline = state.documentOutline
        #expect(outline.count == 0)
    }

    @Test func documentOutlineHandlesH1ThroughH6() {
        let state = AppState()
        state.currentText = "# H1\n## H2\n### H3\n#### H4\n##### H5\n###### H6\n####### Not a heading"
        let outline = state.documentOutline
        #expect(outline.count == 6)
        for (i, item) in outline.enumerated() {
            #expect(item.level == i + 1)
        }
    }

    // MARK: - Cursor Line / Column

    @Test func cursorLineAtStart() {
        let state = AppState()
        state.currentText = "Hello\nWorld"
        state.selectionRange = NSRange(location: 0, length: 0)
        #expect(state.cursorLine == 1)
        #expect(state.cursorColumn == 1)
    }

    @Test func cursorLineOnSecondLine() {
        let state = AppState()
        state.currentText = "Hello\nWorld"
        state.selectionRange = NSRange(location: 6, length: 0) // 'W' on line 2
        #expect(state.cursorLine == 2)
        #expect(state.cursorColumn == 1)
    }

    @Test func cursorColumnMidLine() {
        let state = AppState()
        state.currentText = "Hello\nWorld"
        state.selectionRange = NSRange(location: 9, length: 0) // 'l' in World
        #expect(state.cursorLine == 2)
        #expect(state.cursorColumn == 4)
    }

    @Test func cursorLineEmptyText() {
        let state = AppState()
        state.currentText = ""
        state.selectionRange = NSRange(location: 0, length: 0)
        #expect(state.cursorLine == 1)
        #expect(state.cursorColumn == 1)
    }

    // MARK: - Word / Line / Character Count

    @Test func wordCount() {
        let state = AppState()
        state.currentText = "Hello world foo bar"
        #expect(state.wordCount() == 4)
    }

    @Test func wordCountEmpty() {
        let state = AppState()
        state.currentText = ""
        #expect(state.wordCount() == 0)
    }

    @Test func wordCountMultiline() {
        let state = AppState()
        state.currentText = "Line one\nLine two\nLine three"
        #expect(state.wordCount() == 6)
    }

    @Test func lineCount() {
        let state = AppState()
        state.currentText = "Line 1\nLine 2\nLine 3"
        #expect(state.lineCount() == 3)
    }

    @Test func lineCountSingleLine() {
        let state = AppState()
        state.currentText = "Single line"
        #expect(state.lineCount() == 1)
    }

    @Test func characterCount() {
        let state = AppState()
        state.currentText = "Hello"
        #expect(state.characterCount() == 5)
    }

    @Test func characterCountEmpty() {
        let state = AppState()
        state.currentText = ""
        #expect(state.characterCount() == 0)
    }

    // MARK: - Zoom

    @Test func zoomPercentage() {
        let state = AppState()
        #expect(state.zoomPercentage == 100)
        state.zoomLevel = 1.5
        #expect(state.zoomPercentage == 150)
    }

    @Test func zoomInClampsAtMax() {
        let state = AppState()
        state.zoomLevel = 2.0
        state.zoomIn()
        #expect(state.zoomLevel == 2.0)
    }

    @Test func zoomOutClampsAtMin() {
        let state = AppState()
        state.zoomLevel = 0.5
        state.zoomOut()
        #expect(state.zoomLevel == 0.5)
    }

    @Test func resetZoom() {
        let state = AppState()
        state.zoomLevel = 1.5
        state.resetZoom()
        #expect(state.zoomLevel == 1.0)
    }
}

import SwiftUI
import AppKit
import CoreText

public struct AxisApp: App {
    @StateObject private var appState = AppState()

    public init() {
        Self.registerBundledFonts()
    }

    public static func registerBundledFonts() {
        let fontNames = [
            "RobotoMono-Regular",
            "RobotoMono-Medium",
            "RobotoMono-Bold",
            "RobotoMono-Italic",
            "RobotoMono-BoldItalic",
            "RobotoMono-Light"
        ]
        for name in fontNames {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    public var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            // Close Tab (before Save in File menu)
            CommandGroup(before: .saveItem) {
                Button("Close Tab") {
                    if let url = appState.activeFileURL {
                        appState.closeFile(at: url)
                    }
                }
                .keyboardShortcut("w", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Divider()
            }

            // Save command (replaces default Save/Save As)
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    appState.saveActiveFile()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)
            }

            CommandGroup(after: .newItem) {
                Button("Open Folder") {
                    appState.pickRootFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandGroup(after: .textFormatting) {
                Button("New Markdown File") {
                    appState.createUntitledFile()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Folder") {
                    appState.createUntitledFolder()
                }
                .keyboardShortcut("N", modifiers: [.command, .shift])

                Button("Delete File") {
                    appState.presentDeleteConfirm()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])

                Button("Toggle Checkbox") {
                    appState.toggleCheckbox()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(appState.activeFileURL == nil)

                Divider()

                Button("Bold") {
                    appState.toggleBold()
                }
                .keyboardShortcut("b", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Button("Italic") {
                    appState.toggleItalic()
                }
                .keyboardShortcut("i", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Button("Inline Code") {
                    appState.toggleCode()
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Button("Code Block") {
                    appState.insertCodeBlock()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(appState.activeFileURL == nil)

                Button("Strikethrough") {
                    appState.toggleStrikethrough()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(appState.activeFileURL == nil)

                Button("Link") {
                    appState.insertLink()
                }
                .keyboardShortcut("k", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Button("Insert Image") {
                    appState.insertImage()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(appState.activeFileURL == nil)

                Button("Heading") {
                    appState.insertHeading()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(appState.activeFileURL == nil)

                Button("Heading 1") {
                    appState.setHeading(level: 1)
                }
                .keyboardShortcut("1", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Button("Heading 2") {
                    appState.setHeading(level: 2)
                }
                .keyboardShortcut("2", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Button("Heading 3") {
                    appState.setHeading(level: 3)
                }
                .keyboardShortcut("3", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)

                Divider()

                Button("Toggle Line Wrap") {
                    appState.isLineWrapping.toggle()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("Search All Files") {
                    appState.openFullTextSearch()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandGroup(after: .textEditing) {
                Button("Find") {
                    appState.toggleSearch()
                }
                .keyboardShortcut("f", modifiers: [.command])

                Button("Find Next") {
                    appState.findNext()
                }
                .keyboardShortcut("g", modifiers: [.command])
                .disabled(!appState.showSearch || appState.matchCount == 0)

                Button("Find Previous") {
                    appState.findPrevious()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(!appState.showSearch || appState.matchCount == 0)
            }

            // Sidebar toggle (uses distraction-free mode)
            CommandGroup(replacing: .sidebar) {
                Button("Toggle Sidebar") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.isDistractionFree.toggle()
                    }
                }
                .keyboardShortcut("/", modifiers: [.command])
            }

            // Tab navigation & Zoom commands
            CommandGroup(after: .toolbar) {
                Button("Command Palette") {
                    appState.toggleCommandPalette()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Divider()

                Button("Show Previous Tab") {
                    appState.selectPreviousTab()
                }
                .keyboardShortcut("{", modifiers: [.command])
                .disabled(appState.openFiles.count < 2)

                Button("Show Next Tab") {
                    appState.selectNextTab()
                }
                .keyboardShortcut("}", modifiers: [.command])
                .disabled(appState.openFiles.count < 2)

                Divider()

                Button("Zoom In") {
                    appState.zoomIn()
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button("Zoom Out") {
                    appState.zoomOut()
                }
                .keyboardShortcut("-", modifiers: [.command])

                Button("Reset Zoom") {
                    appState.resetZoom()
                }
                .keyboardShortcut("0", modifiers: [.command])

                Divider()

                Button("Toggle Outline") {
                    appState.toggleOutline()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Toggle Calendar") {
                    appState.toggleCalendar()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Appearance: \(appState.appearanceMode.label)") {
                    appState.cycleAppearance()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }
    }
}

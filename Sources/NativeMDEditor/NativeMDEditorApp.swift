import SwiftUI
import AppKit

@main
struct NativeMDEditorApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .commands {
            // Replace default Close command to close tab instead of window
            CommandGroup(replacing: .saveItem) {
                Button("Close Tab") {
                    if let url = appState.activeFileURL {
                        appState.closeFile(at: url)
                    }
                }
                .keyboardShortcut("w", modifiers: [.command])
                .disabled(appState.activeFileURL == nil)
                
                Divider()
                
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

            CommandGroup(after: .saveItem) {
                Button("Save") {
                    appState.saveActiveFile()
                }
                .keyboardShortcut("s", modifiers: [.command])
            }

            CommandGroup(after: .textFormatting) {
                Button("New Markdown File") {
                    appState.presentNewFileSheet()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Folder") {
                    appState.presentNewFolderSheet()
                }
                .keyboardShortcut("N", modifiers: [.command, .shift])

                Button("Delete File") {
                    appState.presentDeleteConfirm()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])

                Divider()

                Button("Toggle Preview") {
                    appState.isPreview.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command])

                Button("Toggle Line Wrap") {
                    appState.isLineWrapping.toggle()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("Distraction-Free Mode") {
                    appState.isDistractionFree.toggle()
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
            
            // Zoom commands
            CommandGroup(after: .toolbar) {
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
            }
        }
    }
}

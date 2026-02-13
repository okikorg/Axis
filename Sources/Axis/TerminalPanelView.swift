import SwiftUI
import AppKit
import SwiftTerm

// MARK: - Persistent Terminal Session

/// Holds the LocalProcessTerminalView instance so it survives show/hide
/// toggles. Lives on AppState as a plain (non-Published) property.
final class TerminalSession {
    private(set) var terminalView: LocalProcessTerminalView?
    private(set) var isStarted = false

    deinit {
        terminalView = nil
    }

    func getOrCreateView(workingDirectory: String) -> LocalProcessTerminalView {
        if let existing = terminalView {
            return existing
        }

        let view = LocalProcessTerminalView(frame: .zero)

        if let font = NSFont(name: "RobotoMono-Regular", size: 13) {
            view.font = font
        }

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        view.startProcess(
            executable: shell,
            args: ["-l"],
            currentDirectory: workingDirectory
        )

        terminalView = view
        isStarted = true
        return view
    }
}

// MARK: - Terminal Panel View

struct TerminalPanelView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("terminalPanelHeight") private var terminalHeight: Double = 220
    @State private var isDragging = false

    private let minHeight: CGFloat = 120
    private let maxHeightFraction: CGFloat = 0.6

    var body: some View {
        GeometryReader { geo in
            let maxHeight = geo.size.height + terminalHeight
            let clampedMax = maxHeight * maxHeightFraction

            VStack(spacing: 0) {
                // Drag handle / divider
                Rectangle()
                    .fill(isDragging ? Theme.Colors.accent : Theme.Colors.divider)
                    .frame(height: 1)
                    .contentShape(Rectangle().size(width: 10000, height: 8))
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                isDragging = true
                                let delta = -value.translation.height
                                let newHeight = terminalHeight + delta
                                terminalHeight = min(max(newHeight, Double(minHeight)), Double(clampedMax))
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeUpDown.push()
                        } else {
                            NSCursor.pop()
                        }
                    }

                // Header
                TerminalHeader()

                // Terminal content -- reuses the persistent session
                TerminalContainerView(session: appState.terminalSession)
                    .environmentObject(appState)
            }
        }
        .frame(height: CGFloat(terminalHeight))
    }
}

// MARK: - Terminal Header

private struct TerminalHeader: View {
    @EnvironmentObject private var appState: AppState
    @State private var isCloseHovering = false

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "terminal")
                .font(Theme.Fonts.icon)
                .foregroundStyle(Theme.Colors.textMuted)

            Text("Terminal")
                .font(Theme.Fonts.sidebarHeader)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)

            Spacer()

            Button {
                appState.toggleTerminal()
            } label: {
                Image(systemName: "xmark")
                    .font(Theme.Fonts.icon)
                    .foregroundStyle(isCloseHovering ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .fill(isCloseHovering ? Theme.Colors.hover : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isCloseHovering = $0 }
            .help("Close terminal")
            .accessibilityLabel("Close terminal")
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.Colors.background)
    }
}

// MARK: - Terminal Container (NSViewRepresentable)

/// Wraps a plain NSView container that hosts the persistent
/// LocalProcessTerminalView. The terminal view is reparented into this
/// container on makeNSView and removed on dismantleNSView, keeping the
/// shell process alive across show/hide cycles.
struct TerminalContainerView: NSViewRepresentable {
    @EnvironmentObject private var appState: AppState
    let session: TerminalSession

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.autoresizesSubviews = true

        let workingDir = appState.rootURL?.path
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let terminalView = session.getOrCreateView(workingDirectory: workingDir)

        // Reparent into this container
        terminalView.removeFromSuperview()
        terminalView.frame = container.bounds
        terminalView.autoresizingMask = [.width, .height]
        container.addSubview(terminalView)

        applyColors(to: terminalView)

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let terminalView = session.terminalView {
            applyColors(to: terminalView)
        }
    }

    private func applyColors(to terminalView: LocalProcessTerminalView) {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let bgColor: NSColor
        let fgColor: NSColor

        if isDark {
            bgColor = NSColor(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1a/255.0, alpha: 1)
            fgColor = NSColor(red: 0xd4/255.0, green: 0xd4/255.0, blue: 0xd4/255.0, alpha: 1)
        } else {
            bgColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
            fgColor = NSColor(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1a/255.0, alpha: 1)
        }

        terminalView.nativeBackgroundColor = bgColor
        terminalView.nativeForegroundColor = fgColor
        terminalView.caretColor = fgColor
    }
}

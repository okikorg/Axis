import SwiftUI

struct OutlineView: View {
    @EnvironmentObject private var appState: AppState

    private var outline: [HeadingItem] {
        appState.documentOutline
    }

    private var activeID: Int? {
        appState.activeHeadingID()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            OutlineHeader()

            // Content
            if outline.isEmpty {
                OutlineEmptyState()
            } else {
                OutlineList(outline: outline, activeID: activeID)
            }
        }
        .background(Theme.Colors.background)
    }
}

// MARK: - Header

private struct OutlineHeader: View {
    @EnvironmentObject private var appState: AppState
    @State private var isCloseHovering = false

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text("Contents")
                .font(Theme.Fonts.sidebarHeader)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)

            Spacer()

            Button {
                appState.toggleOutline()
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
            .help("Close outline")
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, 38)
        .padding(.bottom, Theme.Spacing.m)
    }
}

// MARK: - Heading List

private struct OutlineList: View {
    @EnvironmentObject private var appState: AppState
    let outline: [HeadingItem]
    let activeID: Int?

    // Split into top-level sections for the two-section layout:
    // Section 1: H1 headings (document titles / major sections)
    // Section 2: All other headings (H2-H6 sub-structure)
    private var topLevel: [HeadingItem] {
        outline.filter { $0.level == 1 }
    }

    private var subHeadings: [HeadingItem] {
        outline.filter { $0.level > 1 }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Section 1: Top-level headings
                    if !topLevel.isEmpty {
                        OutlineSectionHeader(title: "Sections")
                            .padding(.top, Theme.Spacing.xs)

                        ForEach(topLevel) { heading in
                            OutlineRow(heading: heading, isActive: heading.id == activeID)
                                .id(heading.id)
                        }

                        if !subHeadings.isEmpty {
                            Rectangle()
                                .fill(Theme.Colors.divider)
                                .frame(height: 1)
                                .padding(.horizontal, Theme.Spacing.l)
                                .padding(.vertical, Theme.Spacing.m)
                        }
                    }

                    // Section 2: Sub-headings
                    if !subHeadings.isEmpty {
                        OutlineSectionHeader(title: topLevel.isEmpty ? "Headings" : "Sub-sections")

                        ForEach(subHeadings) { heading in
                            OutlineRow(heading: heading, isActive: heading.id == activeID)
                                .id(heading.id)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.m)
                .padding(.horizontal, Theme.Spacing.s)
            }
            .onChange(of: activeID) { newID in
                if let id = newID {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Section Header

private struct OutlineSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(Theme.Fonts.statusBar)
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(0.5)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Outline Row

private struct OutlineRow: View {
    @EnvironmentObject private var appState: AppState
    let heading: HeadingItem
    let isActive: Bool

    @State private var isHovering = false

    // Indent based on heading level, starting from level 1
    private var indent: CGFloat {
        CGFloat(max(heading.level - 1, 0)) * 12
    }

    // Heading level indicator
    private var levelPrefix: String {
        switch heading.level {
        case 1: return "H1"
        case 2: return "H2"
        case 3: return "H3"
        default: return "H\(heading.level)"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Spacer()
                .frame(width: indent)

            Text(levelPrefix)
                .font(Theme.Fonts.statusBar)
                .foregroundStyle(isActive ? Theme.Colors.textSecondary : Theme.Colors.textMuted)
                .frame(width: 20, alignment: .leading)

            Text(heading.text)
                .font(headingFont)
                .foregroundStyle(isActive ? Theme.Colors.text : Theme.Colors.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(isActive ? Theme.Colors.selection : (isHovering ? Theme.Colors.hover : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            appState.navigateToHeading(heading)
        }
        .onHover { isHovering = $0 }
    }

    private var headingFont: Font {
        switch heading.level {
        case 1: return Theme.Fonts.uiSmall
        case 2: return Theme.Fonts.uiSmall
        default: return Theme.Fonts.statusBar
        }
    }
}

// MARK: - Empty State

private struct OutlineEmptyState: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "list.bullet.indent")
                .font(Theme.Fonts.icon)
                .foregroundStyle(Theme.Colors.textMuted)

            Text("No headings")
                .font(Theme.Fonts.uiSmall)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

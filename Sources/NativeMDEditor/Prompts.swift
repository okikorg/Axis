import SwiftUI

struct NamePromptView: View {
    let title: String
    let placeholder: String
    let confirmTitle: String
    let initialValue: String
    let targetFolder: String
    let onCancel: () -> Void
    let onConfirm: (String) -> Void

    @State private var value: String = ""
    @FocusState private var isFocused: Bool
    
    private var isValid: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            // Header - minimal
            Text(title)
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.text)
            
            // Target folder indicator - prominent (hidden when empty)
            if !targetFolder.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Location")
                        .font(Theme.Fonts.statusBar)
                        .foregroundStyle(Theme.Colors.textMuted)
                    
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text(targetFolder)
                            .font(Theme.Fonts.ui)
                            .foregroundStyle(Theme.Colors.text)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, Theme.Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .fill(Theme.Colors.backgroundSecondary)
                    )
                }
            }
            
            // Input - clean
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Name")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)
                
                TextField(placeholder, text: $value)
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.ui)
                    .foregroundStyle(Theme.Colors.text)
                    .padding(Theme.Spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.small)
                            .fill(Theme.Colors.inputBackground)
                    )
                    .focused($isFocused)
                
                // Hint
                if title.contains("File") && !value.isEmpty && !value.lowercased().hasSuffix(".md") {
                    Text(".md will be added")
                        .font(Theme.Fonts.statusBar)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }

            // Actions - right aligned
            HStack(spacing: Theme.Spacing.m) {
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
                
                Button(confirmTitle) {
                    onConfirm(value)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.5)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 340)
        .background(Theme.Colors.background)
        .onAppear {
            value = initialValue
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
}

struct DeleteConfirmView: View {
    let name: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            // Header - minimal, no icon background
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Delete \"\(name)\"?")
                    .font(Theme.Fonts.title)
                    .foregroundStyle(Theme.Colors.text)
                
                Text("This cannot be undone.")
                    .font(Theme.Fonts.uiSmall)
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            // Actions
            HStack(spacing: Theme.Spacing.m) {
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
                
                Button("Delete") {
                    onConfirm()
                }
                .buttonStyle(DestructiveButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 300)
        .background(Theme.Colors.background)
    }
}

struct FolderCustomizationView: View {
    let folderName: String
    let currentCustomization: FolderCustomization
    let onCancel: () -> Void
    let onConfirm: (FolderCustomization) -> Void
    
    @State private var selectedColor: String?
    @State private var selectedIcon: String?
    
    private let iconColumns = [
        GridItem(.adaptive(minimum: 36), spacing: 8)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            // Header
            Text("Customize Folder")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.text)
            
            // Folder name
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: previewIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(previewColor)
                Text(folderName)
                    .font(Theme.Fonts.ui)
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(Theme.Colors.backgroundSecondary)
            )
            
            // Color picker
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Color")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)
                
                HStack(spacing: 8) {
                    ForEach(FolderCustomization.availableColors, id: \.name) { item in
                        Button {
                            selectedColor = item.name == "default" ? nil : item.name
                        } label: {
                            Circle()
                                .fill(item.color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Theme.Colors.text, lineWidth: 2)
                                        .opacity(isColorSelected(item.name) ? 1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Icon picker
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Icon")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)
                
                LazyVGrid(columns: iconColumns, spacing: 8) {
                    ForEach(FolderCustomization.availableIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon == "folder" ? nil : icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .foregroundStyle(previewColor)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isIconSelected(icon) ? Theme.Colors.selection : Theme.Colors.backgroundSecondary)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Actions
            HStack(spacing: Theme.Spacing.m) {
                Button("Reset") {
                    selectedColor = nil
                    selectedIcon = nil
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
                
                Button("Apply") {
                    let customization = FolderCustomization(
                        colorName: selectedColor,
                        iconName: selectedIcon
                    )
                    onConfirm(customization)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 360)
        .background(Theme.Colors.background)
        .onAppear {
            selectedColor = currentCustomization.colorName
            selectedIcon = currentCustomization.iconName
        }
    }
    
    private var previewColor: Color {
        if let colorName = selectedColor,
           let found = FolderCustomization.availableColors.first(where: { $0.name == colorName }) {
            return found.color
        }
        return FolderCustomization.availableColors[0].color
    }
    
    private var previewIcon: String {
        selectedIcon ?? "folder.fill"
    }
    
    private func isColorSelected(_ name: String) -> Bool {
        if name == "default" {
            return selectedColor == nil
        }
        return selectedColor == name
    }
    
    private func isIconSelected(_ icon: String) -> Bool {
        if icon == "folder" {
            return selectedIcon == nil
        }
        return selectedIcon == icon
    }
}

struct MarkdownCustomizationView: View {
    let currentDefaults: MarkdownDefaults
    let onCancel: () -> Void
    let onConfirm: (MarkdownDefaults) -> Void
    
    @State private var selectedColor: String?
    @State private var selectedIcon: String?
    
    private let iconColumns = [
        GridItem(.adaptive(minimum: 36), spacing: 8)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            // Header
            Text("Markdown File Appearance")
                .font(Theme.Fonts.title)
                .foregroundStyle(Theme.Colors.text)
            
            Text("Set default icon and color for all markdown files")
                .font(Theme.Fonts.uiSmall)
                .foregroundStyle(Theme.Colors.textMuted)
            
            // Preview
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: previewIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(previewColor)
                Text("Example.md")
                    .font(Theme.Fonts.ui)
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(Theme.Colors.backgroundSecondary)
            )
            
            // Color picker
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Color")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)
                
                HStack(spacing: 8) {
                    ForEach(CustomizationColors.available, id: \.name) { item in
                        Button {
                            selectedColor = item.name == "default" ? nil : item.name
                        } label: {
                            Circle()
                                .fill(item.color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Theme.Colors.text, lineWidth: 2)
                                        .opacity(isColorSelected(item.name) ? 1 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Icon picker
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Icon")
                    .font(Theme.Fonts.statusBar)
                    .foregroundStyle(Theme.Colors.textMuted)
                
                LazyVGrid(columns: iconColumns, spacing: 8) {
                    ForEach(MarkdownDefaults.availableIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon == "doc.text" ? nil : icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .foregroundStyle(previewColor)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isIconSelected(icon) ? Theme.Colors.selection : Theme.Colors.backgroundSecondary)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Actions
            HStack(spacing: Theme.Spacing.m) {
                Button("Reset") {
                    selectedColor = nil
                    selectedIcon = nil
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
                
                Button("Apply") {
                    let defaults = MarkdownDefaults(
                        colorName: selectedColor,
                        iconName: selectedIcon
                    )
                    onConfirm(defaults)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 360)
        .background(Theme.Colors.background)
        .onAppear {
            selectedColor = currentDefaults.colorName
            selectedIcon = currentDefaults.iconName
        }
    }
    
    private var previewColor: Color {
        CustomizationColors.color(for: selectedColor)
    }
    
    private var previewIcon: String {
        selectedIcon ?? "doc.text"
    }
    
    private func isColorSelected(_ name: String) -> Bool {
        if name == "default" {
            return selectedColor == nil
        }
        return selectedColor == name
    }
    
    private func isIconSelected(_ icon: String) -> Bool {
        if icon == "doc.text" {
            return selectedIcon == nil
        }
        return selectedIcon == icon
    }
}

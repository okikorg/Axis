import SwiftUI

struct NamePromptView: View {
    let title: String
    let placeholder: String
    let confirmTitle: String
    let initialValue: String
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
            
            // Input - clean
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

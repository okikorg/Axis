# Native Markdown Editor (macOS)

Minimal, native macOS markdown editor built with SwiftUI and zero external dependencies. It opens a folder, shows a right-side file tree, and edits only `.md` files.

## Build & Run

1. Open `Package.swift` in Xcode.
2. Select the `NativeMDEditor` scheme.
3. Run.

### Build a .app Bundle

```bash
scripts/build_app.sh
```

The app bundle will be at `dist/NativeMDEditor.app`.

## Keyboard Shortcuts

- `Cmd+O` Open folder
- `Cmd+N` New markdown file
- `Cmd+Shift+N` New folder
- `Cmd+S` Save
- `Cmd+Delete` Delete selected
- `Cmd+Shift+P` Toggle preview
- `Cmd+Shift+L` Toggle line wrap
- `Cmd+Shift+F` Distraction-free mode
- `Cmd+F` Find

## Notes

- The file tree only shows `.md` files and all folders.
- New files are always created with a `.md` extension.
- Autosave is debounced (~0.5s) for fast editing without manual saves
# Ny Mappe (7)

A macOS menu bar app for **file staging**, **clipboard history**, **screenshot capture**, and **path copying**. The panel floats above all windows and hides from the Dock.

**Requirements:** macOS 13.0+, Xcode Command Line Tools (`xcode-select --install`). Xcode IDE is **NOT** required.

**Architectures:** Universal binary — runs natively on both **Intel (x86_64)** and **Apple Silicon (arm64)**.

**Languages:** Norwegian (default) and English. Switch in Settings → Language.

---

## Features

### Four tabs

| Tab | Icon | Description |
|-----|------|-------------|
| **Files** | `doc.on.doc` | Drag files in manually. Copies are stored in a staging cache (originals are never touched). Drag out to other apps. |
| **Screen** | `camera.viewfinder` | Automatic screenshot capture. Toggle on/off with the camera icon in the title bar. |
| **Clipboard** | `doc.on.clipboard` | Automatic clipboard history. Captures all text you copy (⌘C). Up to 200 entries. Searchable. |
| **Path** | `folder` | Drop files/folders from Finder to capture their full path. Auto-copies to clipboard. |

### Clipboard tab details
- Text is captured automatically while the app is running (polls `NSPasteboard.general` every 0.5s)
- **Search**: Filter clipboard entries in real-time with the search bar
- **Multi-select**: Tap cards to select/deselect. Selected items get a blue border.
- **Copy selected**: Combines selected clips with double newlines (`\n\n`)
- **Export .txt / .csv**: Save selected clips to file
- **Pin**: Pinned clips are not deleted when clearing
- Duplicates of the last entry are ignored. File copies (⌘C on files in Finder) are NOT captured.

### Simple / Full mode
Toggle in Settings (gear icon):
- **Simple** (default): Shorter panel (340px). No filter/sort buttons.
- **Full**: Taller panel (520px). Shows filter pills (All, Images, Video, etc.) and sort menu (Name, Size, Date Added).

### Theme
Three choices in Settings: Dark, Light, Follow System. All colors are adaptive.

### Menu bar
- **Left-click** the icon to toggle the panel
- **Right-click** for a context menu: Open Panel, About, Quit
- Panel floats above all windows (`NSPanel` with `level = .floating`)
- No Dock icon (`LSUIElement = true`)
- Panel auto-closes after successful file drag-out

### About dialog
Accessible from Settings or right-click menu. Shows version info and a link to this GitHub repository.

---

## Project Structure

```
ny-mappe-7/
├── README.md                           # This file
├── LICENSE                             # MIT License
├── build.sh                            # Universal build script (Intel + Apple Silicon)
├── .gitignore
│
└── Ny Mappe 7/                         # SOURCE CODE
    ├── NyMappe7App.swift               # App entry point, MenuBarAppDelegate, FloatingPanel, right-click menu
    │
    ├── Models/
    │   ├── AppState.swift              # Codable struct for JSON persistence of all state
    │   ├── StashItem.swift             # File model (id, URL, type, size, isScreenshot)
    │   ├── StashSet.swift              # File set/group model
    │   ├── ClipboardEntry.swift        # Clipboard model (id, text, timestamp, isPinned)
    │   ├── PathEntry.swift             # Path model (id, path, name, isDirectory, isPinned)
    │   └── Localization.swift          # AppLanguage enum + Loc struct (Norwegian/English)
    │
    ├── ViewModels/
    │   └── StashViewModel.swift        # All app logic. @MainActor, ObservableObject.
    │
    ├── Services/
    │   ├── StagingService.swift        # Copies files to cache, zip, validation
    │   ├── ThumbnailService.swift      # QuickLook thumbnail generation
    │   ├── PersistenceService.swift    # JSON load/save to ~/Library/Application Support/GeniDrop/
    │   ├── ScreenshotWatcher.swift     # Monitors screenshot folder with DispatchSource
    │   └── ClipboardWatcher.swift      # Polls NSPasteboard.general for new text
    │
    └── Views/
        ├── ContentView.swift           # Main view: title bar, tabs, drop zone, settings menu, resize
        ├── CardsGridView.swift         # Grid/list of file cards
        └── Components/
            ├── DesignTokens.swift      # All colors, fonts, styles. Adaptive light/dark.
            ├── FileCardView.swift      # Single file card with thumbnail, stripe, hover
            ├── DraggableCardWrapper.swift   # NSViewRepresentable for NSDraggingSource per card
            ├── DragSourceView.swift    # NSViewRepresentable for "Drag all" button
            ├── DragAllButton.swift     # SwiftUI wrapper for drag-all
            ├── MultiFileDragButton.swift    # Drag button for selected files
            ├── ClipboardListView.swift # Clipboard tab: list, search, multi-select, copy, export
            ├── PathListView.swift      # Path tab: list, copy, pin, reveal in Finder
            ├── HeaderView.swift        # Stats row + filter/sort (shown in full mode)
            ├── ToolbarView.swift       # "Add files" button (Files tab only)
            ├── ActionBarView.swift     # "Remove selected" / "Clear" buttons
            ├── EmptyStateView.swift    # Empty state per tab with animation
            ├── ErrorBanner.swift       # Error message banner
            ├── TypeBadge.swift         # File type badge (Image, Video, etc.)
            ├── SetSelectorView.swift   # Set picker and management
            └── BatchRenameSheet.swift  # Batch rename dialog
```

---

## Building

### Prerequisites
- macOS 14+ with Xcode Command Line Tools: `xcode-select --install`
- **Xcode IDE is NOT required**

### Quick build (universal binary)

```bash
./build.sh
```

This builds for both Intel and Apple Silicon, creates a `.app` bundle, and outputs:
```
✅ Build complete!
   App:           ./Ny Mappe (7) v2.app
   Architectures: x86_64 arm64
```

### Run

```bash
open "Ny Mappe (7) v2.app"
```

Or double-click the `.app` in Finder.

### Install

```bash
cp -r "Ny Mappe (7) v2.app" /Applications/
```

---

## Data Storage

All data is stored under `~/Library/Application Support/GeniDrop/`:

| Path | Contents |
|------|----------|
| `state.json` | All state: sets, files, clipboard history, settings, language (JSON, Codable) |
| `StagingCache/<setId>/` | Copied files per set |
| `Thumbnails/` | Generated thumbnails |
| `Exports/` | Temporary zip files |

### Reset all data
Delete the folder: `rm -rf ~/Library/Application\ Support/GeniDrop/`

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘A` | Select all (context-aware per tab) |
| `⌘V` | Paste files from clipboard (Files/Screenshots tabs) |
| `Delete` | Remove selected items |
| `Space` | Quick Look first selected file |
| `Escape` | Deselect all, or close panel if nothing selected |

---

## Technical Details

### Drag and Drop
- **Drag in**: Custom `ExternalDropZone` (`NSViewRepresentable`) that rejects internal drags.
- **Drag out**: `DraggableCardWrapper` and `DragSourceView` implement `NSDraggingSource`. `mouseDownCanMoveWindow = false` prevents window movement.
- **Auto-close**: Panel closes automatically after successful drag-out (`operation == .copy`).

### Menu bar / Floating panel
- `NSStatusItem` with SF Symbol `tray.and.arrow.down.fill`
- Left-click toggles panel, right-click shows context menu (Open, About, Quit)
- `FloatingPanel` (subclass of `NSPanel`) with `level = .floating`, `hidesOnDeactivate = false`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]`

### Localization
- Two languages: Norwegian (`no`) and English (`en`)
- All UI strings in `Localization.swift` via the `Loc` struct
- Language choice persisted in `state.json`
- Models use `AppLanguage.current` static for computed properties

### Persistence
- `AppState` is `Codable` — serialized to JSON with 0.5s debounce
- Includes: sets, files, clipboard history, path entries, settings, language

---

## Known Limitations

- **No App Sandbox**: The app runs without sandbox to allow free file access and `/usr/bin/ditto` for zip.
- **No .xcodeproj**: Built directly with `swiftc`. All source files must be listed in `build.sh`.
- **New files**: If you add a new `.swift` file, you MUST add it to the `SOURCES` array in `build.sh`.

---

## License

MIT — see [LICENSE](LICENSE).

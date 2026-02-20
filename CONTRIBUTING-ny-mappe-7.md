# Developer Guide — Ny Mappe (7)

This file explains how the codebase works for developers and AI assistants.

---

## Build System

**No Xcode project.** Everything is compiled with `swiftc` via `build.sh`.

```bash
./build.sh    # Compile, install to /Applications, launch
```

### Adding new files

1. Create the `.swift` file under `Ny Mappe 7/`
2. Add its full path to the `SOURCES` array in `build.sh`
3. Run `./build.sh` to verify it compiles

**If you forget step 2, the new file won't compile and you'll get "undefined symbol" errors.**

### Build details

- Compiles two architectures: `x86_64` (Intel) and `arm64` (Apple Silicon)
- Merges into universal binary with `lipo`
- Creates `.app` bundle with `Info.plist`, icon, and executable
- Auto-kills previous instance, copies to `/Applications/`, launches

### Frameworks used

```
SwiftUI, AppKit, QuickLookThumbnailing, UniformTypeIdentifiers
```

### Minimum deployment target

macOS 13.0 — **do not use APIs that require macOS 14+**. Specifically:
- Use `onChange(of:) { _ in }` (not the zero-parameter closure form)
- Avoid `@Observable` macro (use `ObservableObject` + `@Published`)

---

## Architecture Overview

```
NyMappe7App.swift          Entry point, NSStatusItem, FloatingPanel
     │
     ▼
ContentView.swift          Tab bar (Files/Clipboard/Tools), keyboard shortcuts
     │
     ├── CardsGridView      Files tab — drag-in/drag-out file cards
     ├── ClipboardListView  Clipboard tab — search, grid, drag, copy
     └── ToolsTabView       Tools tab with sub-tabs:
          ├── Screenshots   (reuses CardsGridView)
          ├── PathListView  Drop files to capture paths
          └── SheetsCollectorView  Smart editable grid
```

### Key patterns

| Pattern | How it's used |
|---------|---------------|
| **MVVM** | `StashViewModel` is the single ViewModel for everything |
| **@ObservedObject** | All views observe `StashViewModel` |
| **@Published** | Every state property in ViewModel is `@Published` |
| **Debounced save** | `scheduleSave()` debounces 0.5s before writing JSON |
| **No Combine** | No reactive chains — simple imperative logic in ViewModel |

---

## StashViewModel — The Brain

`ViewModels/StashViewModel.swift` (~1200 lines) manages ALL app state and logic:

### State sections

| Section | Properties | Purpose |
|---------|-----------|---------|
| **Tabs** | `activeTab`, `activeToolsSubTab` | Navigation |
| **Files** | `stashSets`, `activeSetId`, `selectedItemIds` | File staging |
| **Clipboard** | `clipboardEntries`, `clipboardSearchText`, `maxClipboardEntries` | Clipboard history |
| **Sheets** | `sheetsGrid`, `sheetsColumnCount`, `sheetsAutoPaste`, `sheetsPasteColumn` | Sheets collector |
| **Paths** | `pathEntries`, `selectedPathIds` | Path collector |
| **Settings** | `isLightVersion`, `autoSaveScreenshots`, `cleanupAge*` | User prefs |
| **AI** | `openAIKey` | Stored in UserDefaults, not AppState |

### Important methods

| Method | What it does |
|--------|-------------|
| `addClipboardEntry(_:)` | Adds text, enforces max limit, deduplicates |
| `addToSheetsCollector(_:)` | Auto-pastes text into next empty row in selected column |
| `addPathFromURL(_:)` | Creates PathEntry, copies path to clipboard |
| `copyToClipboard(_:)` | Pauses ClipboardWatcher, writes to NSPasteboard, resumes |
| `suggestFilename(for:completion:)` | Calls OpenAI GPT-4o-mini for filename suggestion |
| `scheduleSave()` | Debounced save — calls PersistenceService after 0.5s |
| `loadState()` / `saveState()` | JSON persistence via AppState Codable struct |

---

## Data Persistence

### AppState (JSON file)

`~/Library/Application Support/GeniDrop/state.json` contains:
- All stash sets with files
- Clipboard entries (text, timestamp, pinned)
- Path entries
- Sheets grid data
- Settings (appearance, cleanup, limits)

### UserDefaults (separate)

- `openAIKey` — stored outside JSON for security
- Read on launch in `loadState()`, written via property observer

### File cache

`~/Library/Application Support/GeniDrop/StagingCache/<setId>/` — copied files per set.

To reset all data:
```bash
rm -rf ~/Library/Application\ Support/GeniDrop/
```

---

## Services

| Service | Responsibility |
|---------|---------------|
| `ClipboardWatcher` | Polls `NSPasteboard.general` every 0.5s for new text |
| `ScreenshotWatcher` | FSEvents on `~/Desktop` for new screenshots |
| `StagingService` | Copies files to cache, creates zip archives |
| `ThumbnailService` | Generates QuickLook thumbnails for file cards |
| `PersistenceService` | Reads/writes `state.json` |

---

## UI Components

### DesignTokens.swift

Centralized design system:
- `Design.primaryText`, `Design.subtleText`, `Design.accent` — adaptive colors
- `Design.headingFont`, `Design.bodyFont`, `Design.captionFont` — system fonts
- `Design.cardBackground`, `Design.cardHoverBackground` — card styling
- `Design.PillButtonStyle`, `Design.InlineActionStyle` — reusable button styles

All colors adapt to light/dark mode automatically.

### ContentView.swift — Keyboard shortcuts

Global shortcuts via `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`:

| Key | Action |
|-----|--------|
| ⌘1/2/3 | Switch tab |
| ⌘F | Focus clipboard search |
| ⌘W | Close panel |
| ⌘C | Copy selected clipboard entries |

### SettingsSheet.swift

Modal sheet with sections: Appearance, Clipboard, Screenshots, Cleanup, AI, Shortcuts.

### SheetsCollectorView.swift

Smart editable grid with:
- `sheetsSettingsPopover` — gear button opens all sheet settings
- `statusPill` — compact config display in header
- TextFields bound to `viewModel.sheetsGrid[row][col]`
- Auto-row creation via `ensureEmptyLastRow()`

---

## Floating Panel

`NyMappe7App.swift` creates:
- `NSStatusItem` in the menu bar (SF Symbol icon)
- `FloatingPanel` (subclass of `NSPanel`) with:
  - `level = .floating` — always on top
  - `hidesOnDeactivate = false` — stays visible
  - `LSUIElement = true` — no Dock icon
  - Left-click toggles, right-click shows context menu

---

## Common Tasks

### Add a new tool/sub-tab

1. Add case to `ToolsSubTab` enum in `StashViewModel.swift`
2. Add tab button in `ToolsTabView.swift` `subTabBar`
3. Add case to `switch` in `ToolsTabView.tabContent`
4. Create the view component in `Views/Components/`
5. Add the `.swift` file to `SOURCES` in `build.sh`

### Add a new setting

1. Add `@Published var` to `StashViewModel`
2. Add property to `AppState` struct (if persistent)
3. Add UI in `SettingsSheet.swift`
4. Handle load/save in `loadState()` / computed `currentState`

### Add a new keyboard shortcut

Add to the `NSEvent.addLocalMonitorForEvents` block in `ContentView.swift`.

---

## Git

Remote: `https://github.com/viavicdev/NY-MAPPE-7.git` (public)

The app is also set up as a **macOS login item** — it starts automatically on boot.

App is installed at: `/Applications/Ny Mappe (7).app`

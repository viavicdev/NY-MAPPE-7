# Ny Mappe (7) — Windows Port Plan

> Instruksjoner for Codex/AI-agent som skal bygge en Windows-versjon av den eksisterende macOS-appen "Ny Mappe (7)".

---

## 1. Hva er denne appen?

"Ny Mappe (7)" er en **system tray-app** (menubar-app på macOS) for fil-staging, clipboard-historikk, screenshot-overvåking og path-kopiering. Den fungerer som en "midlertidig samleplass" der brukeren kan:

- **Dra filer inn** for midlertidig oppbevaring (staging)
- **Organisere filer i sett** (mapper/grupper)
- **Overvåke utklippstavlen** og lagre clipboard-historikk
- **Auto-importere skjermbilder** fra screenshot-mappen
- **Lagre og kopiere filstier** (paths)
- **Eksportere** som zip, filliste (txt/csv/json)
- **Batch-rename** filer
- **Dra filer ut** igjen til andre apper

Appen lever i system tray og åpner et flytende panel når brukeren klikker på ikonet. Panelet har fire faner: Filer, Skjermbilder, Utklipp, Paths.

---

## 2. Anbefalt teknologi: Tauri 2 + React + TypeScript

### Hvorfor Tauri?

- Kan bygges fra macOS til Windows (cross-compile med `cargo tauri build --target x86_64-pc-windows-msvc`)
- Liten binary (~5-15 MB vs Electron ~100+ MB)
- **Innebygd system tray-støtte** via Tauri-plugin
- **Innebygd clipboard API**
- **Innebygd fil-dialog API**
- Rust-backend for tung I/O (filkopiering, zip, thumbnail)
- React/TypeScript frontend for UI

### Forutsetninger for bygg

- **Rust toolchain** (`rustup`)
- **Node.js** (for frontend)
- **For Windows cross-compile fra macOS:** Trenger `cargo-xwin` eller bygg på en Windows-maskin/VM
- **For native Windows-bygg:** Visual Studio Build Tools + Rust

---

## 3. Prosjektstruktur

```
ny-mappe-7-windows/
├── src-tauri/
│   ├── Cargo.toml
│   ├── tauri.conf.json
│   ├── src/
│   │   ├── main.rs              # App entry, system tray, window management
│   │   ├── lib.rs               # Tauri commands module
│   │   ├── commands/
│   │   │   ├── mod.rs
│   │   │   ├── staging.rs       # File import, copy, remove, zip
│   │   │   ├── persistence.rs   # JSON state save/load
│   │   │   ├── thumbnails.rs    # Thumbnail generation
│   │   │   ├── clipboard.rs     # Clipboard watcher (polling)
│   │   │   └── screenshot.rs    # Screenshot directory watcher
│   │   └── models.rs            # Data structures (serde)
│   └── icons/                   # App icons
├── src/
│   ├── main.tsx                 # React entry
│   ├── App.tsx                  # Main app component
│   ├── components/
│   │   ├── TabBar.tsx
│   │   ├── HeaderView.tsx
│   │   ├── ToolbarView.tsx
│   │   ├── CardsGrid.tsx
│   │   ├── FileCard.tsx
│   │   ├── ClipboardList.tsx
│   │   ├── PathList.tsx
│   │   ├── SetSelector.tsx
│   │   ├── ActionBar.tsx
│   │   ├── EmptyState.tsx
│   │   ├── ErrorBanner.tsx
│   │   ├── TypeBadge.tsx
│   │   ├── BatchRenameSheet.tsx
│   │   └── DragButton.tsx
│   ├── hooks/
│   │   ├── useStashStore.ts     # Zustand store (replaces StashViewModel)
│   │   ├── useClipboardWatcher.ts
│   │   ├── useScreenshotWatcher.ts
│   │   └── useKeyboardShortcuts.ts
│   ├── lib/
│   │   ├── design-tokens.ts     # Color system, typography, spacing
│   │   ├── types.ts             # TypeScript interfaces
│   │   └── utils.ts             # Helpers (formatSize, relativeTime, etc.)
│   └── styles/
│       └── globals.css          # Tailwind + custom CSS
├── package.json
├── tsconfig.json
├── tailwind.config.js
└── index.html
```

---

## 4. Datamodeller (oversett fra Swift)

Oversett disse Swift-strukturene til TypeScript interfaces OG Rust serde-structs:

### TypeScript (`src/lib/types.ts`)

```typescript
type TypeCategory = 'Image' | 'Video' | 'Audio' | 'Document' | 'Archive' | 'Other';

interface StashItem {
  id: string;           // UUID
  setId: string;        // UUID
  originalPath: string; // Original file path
  stagedPath: string;   // Staged copy path
  fileName: string;
  ext: string;
  typeCategory: TypeCategory;
  sizeBytes: number;
  dateAdded: string;    // ISO 8601
  thumbnailPath?: string;
  isScreenshot: boolean;
  sortIndex?: number;
}

interface StashSet {
  id: string;           // UUID
  name: string;
  createdAt: string;    // ISO 8601
}

interface ClipboardEntry {
  id: string;
  text: string;
  dateCopied: string;   // ISO 8601
  isPinned: boolean;
}

interface PathEntry {
  id: string;
  path: string;
  name: string;
  isDirectory: boolean;
  dateAdded: string;    // ISO 8601
  isPinned: boolean;
}

type SortOption = 'Name' | 'Size' | 'DateAdded' | 'Manual';
type FilterOption = 'All' | 'Images' | 'Video' | 'Audio' | 'Docs' | 'Archives' | 'Other';

interface AppState {
  sets: StashSet[];
  items: StashItem[];
  activeSetId?: string;
  alwaysOnTop: boolean;
  sortOption: SortOption;
  filterOption: FilterOption;
  clipboardEntries: ClipboardEntry[];
  pathEntries: PathEntry[];
  saveScreenshots: boolean;
  autoCleanupFilesDays?: number;
  autoCleanupClipboardDays?: number;
  autoCleanupPathsDays?: number;
}
```

### Rust (`src-tauri/src/models.rs`)

```rust
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TypeCategory {
    Image, Video, Audio, Document, Archive, Other,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StashItem {
    pub id: Uuid,
    pub set_id: Uuid,
    pub original_path: String,
    pub staged_path: String,
    pub file_name: String,
    pub ext: String,
    pub type_category: TypeCategory,
    pub size_bytes: i64,
    pub date_added: DateTime<Utc>,
    pub thumbnail_path: Option<String>,
    pub is_screenshot: bool,
    pub sort_index: Option<i32>,
}

// ... tilsvarende for StashSet, ClipboardEntry, PathEntry, AppState
```

---

## 5. Funksjon-for-funksjon oversettelse

### 5.1 System Tray + Flytende Panel

**macOS (Swift):**
- `NSStatusBar.system.statusItem()` → menubar-ikon
- `NSPanel` subclass → flytende vindu under ikonet
- `app.setActivationPolicy(.accessory)` → ingen Dock-ikon

**Windows (Tauri 2):**
```rust
// I tauri.conf.json, aktiver tray plugin:
// "plugins": { "tray": {} }

// I main.rs:
use tauri::{
    tray::TrayIconBuilder,
    Manager,
};

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            // Opprett system tray
            let tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .tooltip("Ny Mappe (7)")
                .on_tray_icon_event(|tray, event| {
                    match event {
                        tauri::tray::TrayIconEvent::Click { .. } => {
                            // Toggle vindu synlighet
                            let window = tray.app_handle().get_webview_window("main").unwrap();
                            if window.is_visible().unwrap() {
                                window.hide().unwrap();
                            } else {
                                window.show().unwrap();
                                window.set_focus().unwrap();
                                // Posisjon: nær system tray
                            }
                        }
                        _ => {}
                    }
                })
                .build(app)?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

**Vindu-konfigurasjon i `tauri.conf.json`:**
```json
{
  "app": {
    "windows": [
      {
        "label": "main",
        "title": "Ny Mappe (7)",
        "width": 380,
        "height": 520,
        "resizable": true,
        "decorations": false,
        "alwaysOnTop": true,
        "visible": false,
        "skipTaskbar": true,
        "transparent": true
      }
    ]
  }
}
```

### 5.2 Clipboard Watcher

**macOS (Swift):** Poller `NSPasteboard.general.changeCount` hvert 0.5s.

**Windows (Rust/Tauri):**
```rust
use clipboard_win::{formats, get_clipboard};
use std::thread;
use std::time::Duration;

// Poll clipboard hvert 500ms, send event til frontend ved endring
fn start_clipboard_watcher(app_handle: tauri::AppHandle) {
    thread::spawn(move || {
        let mut last_text = String::new();
        loop {
            if let Ok(text) = get_clipboard::<String, _>(formats::Unicode) {
                let trimmed = text.trim().to_string();
                if !trimmed.is_empty() && trimmed != last_text {
                    last_text = trimmed.clone();
                    app_handle.emit("clipboard-change", &trimmed).ok();
                }
            }
            thread::sleep(Duration::from_millis(500));
        }
    });
}
```

**Crate:** `clipboard-win` (for direkte Windows clipboard-tilgang) eller `arboard` (cross-platform).

### 5.3 Screenshot Watcher

**macOS (Swift):** Poller Desktop/screenshot-mappen for nye filer med "Screenshot"/"Skjermbilde" i navnet.

**Windows (Rust):**
```rust
use notify::{Watcher, RecursiveMode, watcher};

// Windows screenshot-mappe: %USERPROFILE%\Pictures\Screenshots
fn get_screenshot_dir() -> PathBuf {
    dirs::picture_dir().unwrap().join("Screenshots")
}

// Bruk `notify` crate for fil-watching (mer effektivt enn polling på Windows)
fn start_screenshot_watcher(app_handle: tauri::AppHandle) {
    let dir = get_screenshot_dir();
    let (tx, rx) = std::sync::mpsc::channel();
    let mut watcher = notify::recommended_watcher(tx).unwrap();
    watcher.watch(&dir, RecursiveMode::NonRecursive).unwrap();

    thread::spawn(move || {
        for event in rx {
            if let Ok(event) = event {
                for path in event.paths {
                    if is_screenshot_file(&path) {
                        app_handle.emit("new-screenshot", path.to_string_lossy().to_string()).ok();
                    }
                }
            }
        }
    });
}

fn is_screenshot_file(path: &Path) -> bool {
    let name = path.file_name().unwrap_or_default().to_string_lossy().to_lowercase();
    let patterns = ["screenshot", "skjermbilde", "bildschirmfoto", "capture"];
    let is_img = name.ends_with(".png") || name.ends_with(".jpg") || name.ends_with(".jpeg");
    is_img && patterns.iter().any(|p| name.contains(p))
}
```

**Crate:** `notify` (cross-platform file system watcher).

### 5.4 Fil-staging (import, kopi, fjern)

**macOS (Swift):** `FileManager.copyItem(at:to:)`, mapper i `~/Library/Application Support/GeniDrop/`

**Windows (Rust):**
```rust
use dirs::data_local_dir;

fn app_data_dir() -> PathBuf {
    // %LOCALAPPDATA%\GeniDrop\
    data_local_dir().unwrap().join("GeniDrop")
}

fn staging_dir(set_id: &str) -> PathBuf {
    app_data_dir().join("StagingCache").join(set_id)
}

// Tauri command: import files
#[tauri::command]
async fn import_files(urls: Vec<String>, set_id: String) -> Result<Vec<StashItem>, String> {
    let staging = staging_dir(&set_id);
    std::fs::create_dir_all(&staging).map_err(|e| e.to_string())?;

    let mut items = vec![];
    for url in urls {
        let source = PathBuf::from(&url);
        let file_name = source.file_name().unwrap().to_string_lossy().to_string();
        let target = staging.join(&file_name);
        std::fs::copy(&source, &target).map_err(|e| e.to_string())?;

        let metadata = std::fs::metadata(&target).map_err(|e| e.to_string())?;
        let ext = source.extension().unwrap_or_default().to_string_lossy().to_string();

        items.push(StashItem {
            id: Uuid::new_v4(),
            set_id: Uuid::parse_str(&set_id).unwrap(),
            original_path: url,
            staged_path: target.to_string_lossy().to_string(),
            file_name,
            ext: ext.clone(),
            type_category: TypeCategory::from_extension(&ext),
            size_bytes: metadata.len() as i64,
            date_added: Utc::now(),
            thumbnail_path: None,
            is_screenshot: false,
            sort_index: None,
        });
    }
    Ok(items)
}
```

### 5.5 Zip-eksport

**macOS (Swift):** Bruker `/usr/bin/ditto` (macOS-spesifikt).

**Windows (Rust):**
```rust
use zip::write::SimpleFileOptions;
use zip::ZipWriter;

#[tauri::command]
async fn create_zip(items: Vec<StashItem>, output_path: String) -> Result<String, String> {
    let file = File::create(&output_path).map_err(|e| e.to_string())?;
    let mut zip = ZipWriter::new(file);
    let options = SimpleFileOptions::default();

    for item in items {
        let path = PathBuf::from(&item.staged_path);
        let data = std::fs::read(&path).map_err(|e| e.to_string())?;
        zip.start_file(&item.file_name, options).map_err(|e| e.to_string())?;
        zip.write_all(&data).map_err(|e| e.to_string())?;
    }
    zip.finish().map_err(|e| e.to_string())?;
    Ok(output_path)
}
```

**Crate:** `zip`

### 5.6 Thumbnails

**macOS (Swift):** `QLThumbnailGenerator` + `NSImage` fallback.

**Windows (Rust):**
```rust
use image::imageops::thumbnail;

#[tauri::command]
async fn generate_thumbnail(source_path: String, thumb_path: String) -> Result<Option<String>, String> {
    let img = image::open(&source_path).map_err(|e| e.to_string())?;
    let thumb = img.thumbnail(200, 200);
    thumb.save(&thumb_path).map_err(|e| e.to_string())?;
    Ok(Some(thumb_path))
}
```

**Crate:** `image`

### 5.7 Persistens (state save/load)

**macOS (Swift):** JSON til `~/Library/Application Support/GeniDrop/state.json`

**Windows (Rust):** JSON til `%LOCALAPPDATA%\GeniDrop\state.json`

Identisk logikk, bare `serde_json` i stedet for Swift `Codable`.

### 5.8 Fil-dialoger

**macOS (Swift):** `NSOpenPanel`, `NSSavePanel`

**Windows (Tauri):**
```typescript
import { open, save } from '@tauri-apps/plugin-dialog';

// Åpne fil-dialog
const files = await open({
  multiple: true,
  directory: false,
  title: 'Velg filer',
});

// Lagre-dialog
const path = await save({
  title: 'Eksporter som .zip',
  defaultPath: 'export.zip',
  filters: [{ name: 'Zip', extensions: ['zip'] }],
});
```

### 5.9 Drag & Drop

**macOS (Swift):** Custom `NSView` subclass med `NSDraggingInfo`.

**Windows (Tauri/Web):**
```typescript
// HTML5 drag & drop + Tauri file drop event
import { listen } from '@tauri-apps/api/event';

// Lytt på filer dratt inn i vinduet
listen('tauri://drag-drop', (event) => {
  const paths: string[] = event.payload.paths;
  importFiles(paths);
});
```

### 5.10 Keyboard Shortcuts

**macOS (Swift):** `NSEvent.addLocalMonitorForEvents`

**Windows (Tauri/Web):**
```typescript
// Bruk standard web keyboard events
useEffect(() => {
  const handler = (e: KeyboardEvent) => {
    if (e.metaKey && e.key === 'a') { selectAll(); e.preventDefault(); }
    if (e.metaKey && e.key === 'v') { pasteFromClipboard(); e.preventDefault(); }
    if (e.key === 'Delete' || e.key === 'Backspace') { removeSelected(); }
    if (e.key === 'Escape') { deselectOrClose(); }
  };
  window.addEventListener('keydown', handler);
  return () => window.removeEventListener('keydown', handler);
}, []);
```

> Merk: På Windows brukes `Ctrl` i stedet for `Cmd`. Bruk `e.ctrlKey` i stedet for `e.metaKey`.

---

## 6. Design System

Oversett `DesignTokens.swift` til CSS custom properties. Appen har et komplett dark/light mode design:

```css
/* src/styles/globals.css */

:root {
  /* Light mode */
  --panel-bg: rgb(247, 247, 245);
  --card-bg: rgb(255, 255, 255);
  --card-hover-bg: rgb(245, 245, 250);
  --border: rgba(0, 0, 0, 0.06);
  --text-primary: rgb(15, 10, 26);
  --text-subtle: rgb(128, 122, 133);
  --accent: rgb(217, 46, 56);
  --accent-light: rgba(217, 46, 56, 0.12);
  --danger: rgb(204, 64, 77);
  --success: rgb(46, 153, 102);
  --badge-red: rgb(230, 51, 51);
  --button-tint: rgba(0, 0, 0, 0.05);
  --button-tint-pressed: rgba(0, 0, 0, 0.10);
  --button-border: rgba(0, 0, 0, 0.08);
  --header-surface: rgba(255, 255, 255, 0.6);
  --divider: rgba(0, 0, 0, 0.08);

  /* Color washes per type */
  --wash-image: rgba(77, 128, 230, 0.10);
  --wash-video: rgba(217, 77, 115, 0.10);
  --wash-audio: rgba(140, 89, 217, 0.10);
  --wash-document: rgba(38, 191, 140, 0.10);
  --wash-archive: rgba(217, 166, 51, 0.10);
}

@media (prefers-color-scheme: dark) {
  :root {
    --panel-bg: rgb(10, 10, 15);
    --card-bg: rgb(23, 23, 31);
    --card-hover-bg: rgb(31, 31, 41);
    --border: rgba(255, 255, 255, 0.08);
    --text-primary: rgb(245, 245, 250);
    --text-subtle: rgb(122, 122, 140);
    --accent: rgb(242, 77, 82);
    --accent-light: rgba(242, 77, 82, 0.12);
    --danger: rgb(230, 89, 102);
    --success: rgb(64, 199, 133);
    --badge-red: rgb(242, 77, 77);
    --button-tint: rgba(255, 255, 255, 0.07);
    --button-tint-pressed: rgba(255, 255, 255, 0.14);
    --button-border: rgba(255, 255, 255, 0.10);
    --header-surface: rgba(255, 255, 255, 0.03);
    --divider: rgba(255, 255, 255, 0.08);

    --wash-image: rgba(77, 128, 230, 0.16);
    --wash-video: rgba(217, 77, 115, 0.16);
    --wash-audio: rgba(140, 89, 217, 0.16);
    --wash-document: rgba(38, 191, 140, 0.16);
    --wash-archive: rgba(217, 166, 51, 0.16);
  }
}
```

### Typografi

| Token            | Størrelse | Vekt     |
|------------------|-----------|----------|
| heading          | 18px      | bold     |
| title            | 16px      | bold     |
| cardTitle        | 13px      | bold     |
| body             | 13px      | regular  |
| caption          | 11px      | regular  |
| badge            | 10px      | semibold |
| tab              | 12px      | medium   |

Font: System font med `font-family: system-ui, -apple-system, 'Segoe UI', sans-serif;` og `border-radius` verdier fra Swift: `cornerRadius: 20px`, `cardCornerRadius: 18px`.

---

## 7. UI-oppførsel å replikere

### Faner (tabs)
- 4 faner: **Filer**, **Skjerm** (screenshots), **Utklipp** (clipboard), **Path**
- Aktiv fane har tykk underline (3px) og bold tekst
- Badge med antall vises som rød sirkel (eller accent-farge for aktiv fane)

### To moduser
- **Enkel modus** (`isLightVersion = true`): Kompakt, 310px høyde, tabs øverst, enkel toolbar
- **Full modus** (`isLightVersion = false`): 520px høyde, tittel + app-ikon, set-velger, filter/sortering

### Fil-kort (cards)
- Grid med kort for hver fil
- Hvert kort viser: thumbnail, filnavn, filtype-badge, størrelse
- Color wash gradient basert på filtype (bilde=blå, video=rosa, audio=lilla, etc.)
- Hover viser action-knapper (slett, vis i Explorer)

### Drag & drop
- **Inn:** Dra filer fra Explorer inn i panelet → importerer dem
- **Ut:** Dra filer fra panelet til andre apper
- Animert drop-zone overlay med pulserende border og ikon

### Set-velger
- Dropdown for å velge aktivt sett
- Kan opprette nye sett, rename, delete
- Standard-sett heter "Engangs"

### Utklipp-fane
- Viser clipboard-historikk med preview-tekst
- Pin/unpin entries
- Kopier til clipboard ved klikk (og auto-lukk panel)
- Eksporter som .txt eller .csv

### Path-fane
- Dra fil/mappe inn → kopierer path til clipboard
- Viser path-historikk
- Pin/unpin, reveal in Explorer

### Auto-cleanup
- Konfiguerbar: Slett filer/utklipp/paths eldre enn X dager (7/14/30/60/90)
- Pinnede entries slettes aldri

### Tastatur
- `Ctrl+A` → Velg alle (kontekst-bevisst per fane)
- `Ctrl+V` → Lim inn filer fra clipboard
- `Delete`/`Backspace` → Slett valgte
- `Space` → Åpne valgt fil
- `Escape` → Deselect, eller lukk panel

---

## 8. Rust Crates (avhengigheter)

```toml
[dependencies]
tauri = { version = "2", features = ["tray-icon"] }
tauri-plugin-dialog = "2"
tauri-plugin-fs = "2"
tauri-plugin-clipboard-manager = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
dirs = "5"
notify = "6"
zip = "2"
image = "0.25"
arboard = "3"           # Cross-platform clipboard (alternativ)
walkdir = "2"           # Rekursiv mappe-traversering
```

---

## 9. NPM Dependencies (frontend)

```json
{
  "dependencies": {
    "react": "^19",
    "react-dom": "^19",
    "@tauri-apps/api": "^2",
    "@tauri-apps/plugin-dialog": "^2",
    "@tauri-apps/plugin-fs": "^2",
    "@tauri-apps/plugin-clipboard-manager": "^2",
    "zustand": "^5",
    "lucide-react": "^0.400"
  },
  "devDependencies": {
    "typescript": "^5.5",
    "@vitejs/plugin-react": "^4",
    "vite": "^6",
    "tailwindcss": "^4",
    "@tauri-apps/cli": "^2"
  }
}
```

---

## 10. Viktige forskjeller macOS → Windows

| Aspekt | macOS | Windows |
|--------|-------|---------|
| App data | `~/Library/Application Support/GeniDrop/` | `%LOCALAPPDATA%\GeniDrop\` |
| Screenshot-mappe | `~/Desktop` eller custom | `%USERPROFILE%\Pictures\Screenshots` |
| Clipboard API | `NSPasteboard` (poll `changeCount`) | `arboard` eller `clipboard-win` (poll innhold) |
| Zip | `/usr/bin/ditto` | `zip` crate |
| Thumbnails | `QLThumbnailGenerator` | `image` crate |
| Fil-explorer | `NSWorkspace.activateFileViewerSelecting()` | `Command::new("explorer").arg("/select,").arg(path)` |
| Modifier key | `Cmd` (⌘) | `Ctrl` |
| Ingen dock-ikon | `setActivationPolicy(.accessory)` | `skipTaskbar: true` i tauri.conf.json |
| Filstier | `/Users/name/...` | `C:\Users\name\...` |

---

## 11. Implementeringsrekkefølge

1. **Scaffold Tauri 2 prosjekt** med React + TypeScript
2. **Sett opp system tray** + toggle flytende vindu
3. **Implementer datamodeller** i Rust og TypeScript
4. **Persistence** (load/save state.json)
5. **Fil-import** (staging service i Rust)
6. **UI: Tab bar + Filer-fane** med tom-tilstand og fil-kort
7. **Drag & drop inn** (fil-import)
8. **Drag & drop ut** (fra kort til Explorer)
9. **Set-velger** (opprett, rename, delete, bytt)
10. **Thumbnail-generering** (Rust image crate)
11. **Clipboard watcher** + Utklipp-fane
12. **Screenshot watcher** + Skjerm-fane
13. **Path-fane** (drag inn → kopier path)
14. **Eksport** (zip, fillliste txt/csv/json)
15. **Batch rename**
16. **Auto-cleanup**
17. **Tastatur-snarveier**
18. **Design polish** (dark/light, animasjoner, farger)
19. **Bygg og test** på Windows

---

## 12. Kildekode-referanse

Den originale Swift-koden ligger i:
```
klippegeni.no/projects/software/ny-mappe-7-v2/Ny Mappe 7/
```

Viktigste filer å studere for logikk:
- `ViewModels/StashViewModel.swift` — All forretningslogikk (~1023 linjer)
- `Services/StagingService.swift` — Fil-import, zip, remove
- `Services/PersistenceService.swift` — State save/load
- `Services/ClipboardWatcher.swift` — Clipboard polling
- `Services/ScreenshotWatcher.swift` — Screenshot-deteksjon
- `Views/Components/DesignTokens.swift` — Komplett design system
- `Models/` — Alle datastrukturer

---

## 13. Merk

- Appen har **norsk UI** (knapper, labels, etc.) — behold norsk.
- Default sett heter **"Engangs"**.
- Relativ tid vises på norsk: "Akkurat nå", "5m siden", "2t siden", "I går", "3d siden".
- Maks 200 clipboard-entries, maks 100 path-entries.
- Clipboard watcher pauses midlertidig når appen selv kopierer til clipboard (for å unngå å fange sin egen output).
- Panel auto-lukkes etter copy-operasjoner (clipboard/path) etter 0.5s delay.

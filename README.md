# Ny Mappe (7)

En macOS menybar-app for **fil-staging**, **utklippshistorikk**, **skjermbilder**, **LLM-kontekst** og **verktøy**. Panelet svever over alle vinduer og skjuler seg fra Dock.

**Krav:** macOS 13.0+, Xcode Command Line Tools (`xcode-select --install`). Xcode IDE er **IKKE** nødvendig.

**Arkitekturer:** Universal binary — kjører nativt på både **Intel (x86_64)** og **Apple Silicon (arm64)**.

---

## Nytt i v5.2

### Ny hovedstruktur: fire faner

| Fane | Innhold |
|------|---------|
| **Filer** | Dra inn filer, staging-cache, dra ut til andre apper |
| **Utklipp** | Automatisk utklippshistorikk med grupper, søk og 2-kolonne grid |
| **Kontekst** | Sub-faner: **Bundles**, **Prompts** — for LLM-samtaler |
| **Tools** | Sub-faner: **Skjermbilde**, **Filsti**, **Tabell** |

Tannhjul-ikonet ligger nå helt til høyre på hovedtab-raden. Lukk panelet via macOS rød trafikklys-knapp (⌘W, ⌥Space, eller Esc).

### Kontekst-fanen — for språkmodell-samtaler

**Bundles** er selvstendige samlinger (Render, Meg, Podcast, osv.) som kombinerer:
- **Filer** (kopiert inn i bundlens egen lagring — uavhengig av Filer-fanen)
- **Tekstsnippets** (systemprompts, klient-bakgrunn, instrukser)

Hver bundle er en tab i toppen av visningen. Klikk på tab-en → aktiv mål. Alle nye filer/snippets du legger til havner i den aktive bundlen. Drag hele bundlen (eller enkelt-filer) inn i ChatGPT/Claude-samtaler, eller bruk **Kopier alt tekst** for strukturert tekstdump med filnavn-liste.

Ferdige "standard bundles" (Jobb / Meg / Tech / Traumer) kan legges til med ett klikk i Settings.

**Prompts** er navngitte kategorier med prompts. Kategoriene seedes med Musikk / Regler / Skriving ved første start. Hver prompt kan være:
- Skrevet tekst (tittel + body)
- En fil (md, txt, pdf) lagt til via dra-inn eller filvelger

For md/txt: "Kopier tekst" leser filinnholdet og legger på utklippstavla. For PDF: dra prompt-rada rett inn i chat-fanen.

### Utklipp-fanen — grupper

Organiser utklipp i **grupper** (klient, prosjekt, osv.) i full modus:
- **Aktiv mål-gruppe** — klikk header → alt du kopierer havner der automatisk
- **Kopier hele gruppa** med ett klikk (CAPS-overskrift på toppen hvis innstilling er på)
- **Tøm seksjon** (eraser-ikon) — fjerner items i gruppa uten å slette selve gruppa
- **"Usortert"** som fullverdig klikkbar seksjon (ugrupperte items)
- **Flytt til** / høyreklikk "Legg til som snippet i bundle → X"
- **Shift-klikk** for range-seleksjon (standard Finder-oppførsel)

### Quick Notes

Globalt floating panel festet til høyre skjermkant. Trykk **⌥⇧N** hvor som helst for å åpne/lukke. Flere notater i sidebar, rediger med TextEditor, **Kopier** legger tittel + body på utklippstavla.

### Skjermbilde-lightbox

I enkel modus vises skjermbilder som 3-kolonners kvadratisk grid. Klikk → lightbox som viser full bilde med:
- **Kopier bilde** (⌘C) — legger NSImage på utklippstavla, klar til å lime i Slack/mail
- **◀ ▶** — bla mellom bildene uten å lukke
- **Vis i Finder**

### Andre forbedringer (siden v3.3)

- **CSV kolonnevis-bygger**: bygg CSV-fil ved å fylle kolonne A, så B, osv.
- **Backup-rotasjon** av state.json (`.bak` + `.bak2`) — datatap ved crash er mye mer usannsynlig
- **Synlige feilmeldinger**: permanent banner brukeren må avvise, i stedet for silent `print()`
- **Ad-hoc signering** i build.sh gir stabil TCC-identitet — slipper konstante tillatelses-prompts ved rebuild
- **Custom SVG-ikoner** for tabs (Filer, Utklipp, Skjermbilde, Filsti, Tabell)
- **Global "Kopiert!"-toast** ved alle kopi-handlinger

---

## Funksjoner

### Filer-fanen
- Dra filer inn manuelt — kopier lagres i en staging-cache (originaler røres aldri)
- Dra ut til andre apper (inkl. multi-fil-drag)
- Batch-omdøpning
- Sett/grupper for organisering
- Filter (Alle, Bilder, Video, osv.) og sortering i full modus
- Høyreklikk-meny: Legg til i bundle → [Render/Meg/...]

### Utklipp-fanen
- Tekst fanges automatisk mens appen kjører (poller `NSPasteboard.general` hvert 0.5s)
- Grupper med aktiv mål-logikk
- Søkbar med `⌘F`
- 2-kolonne grid i kompakt modus
- Shift-klikk og ⌘-klikk for multi-seleksjon
- Fest viktige utklipp (slettes ikke ved tømming, bevares ved limit-endring)
- Eksporter som .txt / .csv
- CSV kolonnevis-bygger for parallell datainnsamling
- Dobbeltklikk for å kopiere, drag for å dra til andre apper
- Innstilling: antall tomme linjer mellom kopierte items (0–3)
- Innstilling: nyeste øverst / nederst

### Kontekst → Bundles
- Selvstendig lagring per bundle (`~/Library/Application Support/GeniDrop/Bundles/<uuid>/`)
- Filer vises som ikon-tiles i 3-kolonners grid, fargekodet per filtype
- Drag hele bundlen (via tab) eller enkelt-fil
- "Kopier alt tekst" bygger strukturert dump med snippets + filnavn-liste

### Kontekst → Prompts
- Kategori-tiles i toppen med custom ikoner
- Prompts kan være tekst eller filer (md/txt/pdf)
- `.onDrop` zone: dra md/txt/pdf fra Finder inn i kategori
- Md/txt kopierer filinnhold; pdf drag-out

### Tools → Skjermbilde
- Automatisk skjermbildefangst fra skrivebordet
- Lightbox i enkel modus (⌘C kopierer bilde)

### Tools → Filsti
- Slipp filer/mapper for å fange full filsti
- Kopieres automatisk til utklippstavla
- Fest, vis i Finder, shift-klikk for range-seleksjon

### Tools → Tabell (tidl. Sheets)
- Smart redigerbar grid — alle celler er alltid redigerbare
- Auto-lim fra utklippstavla i valgt kolonne, med automatisk rad-oppretting
- 2–4 kolonner, velg lim-inn-kolonne (A/B/C/D) eller skru av auto-lim
- Eksporter som .csv

### Quick Notes
- Eget floating NSPanel festet til høyre skjermkant
- Global hotkey: `⌥⇧N`
- Sidebar med liste, TextEditor per notat, "Kopier hele notatet"

### Enkel / Full modus
- **Enkel** (standard): Kompakt panel (388×310)
- **Full**: Høyere panel med filter/sortering (480×520)

### Menybar
- **Venstreklikk** for å vise/skjule panelet
- **Høyreklikk** for kontekstmeny: Åpne panel, Om, Avslutt
- Panelet svever over alle vinduer (`NSPanel` med `level = .floating`)
- Ingen Dock-ikon (`LSUIElement = true`)
- Auto-lukker etter vellykket fil-utdragning (paths holder panelet åpent)

---

## Tastatursnarveier

| Snarvei | Handling |
|---------|----------|
| `⌥Space` | Vis/skjul hovedpanelet (global) |
| `⌥⇧N` | Vis/skjul Quick Notes (global) |
| `⌘1` / `⌘2` / `⌘3` / `⌘4` | Bytt fane (Filer / Utklipp / Kontekst / Tools) |
| `⌘F` | Fokuser søkefeltet i Utklipp |
| `⌘C` | Kopier valgte utklipp / kopier bilde i lightbox |
| `⌘A` | Velg alle (kontekst-bevisst per fane) |
| `⌘V` | Lim inn filer fra utklippstavla (Filer/Skjermbilde) |
| `⌘W` | Lukk panelet |
| `Delete` | Fjern valgte elementer |
| `Space` | Quick Look på valgt fil |
| `Escape` | Fjern valg, eller lukk panel |
| `Shift-klikk` | Range-seleksjon i Filer/Utklipp/Skjermbilde/Filsti |
| `Dobbeltklikk` | Kopier utklipp direkte |

---

## Prosjektstruktur

```
NY-MAPPE-7/
├── README.md
├── LICENSE
├── build.sh                             # Universal build-script (m/ ad-hoc signering)
├── AUDIT-ny-mappe-7-forbedringer.md     # Audit-rapport
├── GUIDE-kodesignering-og-release.md
├── CONTRIBUTING-ny-mappe-7.md
│
└── Ny Mappe 7/                          # KILDEKODE
    ├── AppIcon.icns
    ├── NyMappe7App.swift                # App-inngang, menybar, floating panel, Quick Note-panel
    │
    ├── Resources/
    │   └── Icons/                       # Custom SVG-ikoner for tabs + standard bundles + prompts
    │
    ├── Models/
    │   ├── AppState.swift               # Codable root-state
    │   ├── StashItem.swift
    │   ├── StashSet.swift
    │   ├── ClipboardEntry.swift
    │   ├── ClipboardGroup.swift
    │   ├── PathEntry.swift
    │   ├── ContextBundle.swift
    │   ├── BundleItem.swift             # enum: .localFile / .file (legacy) / .text
    │   ├── Prompt.swift                 # Prompt + PromptCategory
    │   ├── QuickNote.swift
    │   ├── CSVColumnBuilderState.swift
    │   └── Date+TimeAgo.swift
    │
    ├── ViewModels/
    │   └── StashViewModel.swift         # All app-logikk (singleton via .shared)
    │
    ├── Services/
    │   ├── ClipboardWatcher.swift       # Poller NSPasteboard for ny tekst
    │   ├── PersistenceService.swift     # JSON last/lagre m/ backup-rotasjon
    │   ├── ScreenshotWatcher.swift
    │   ├── StagingService.swift
    │   └── ThumbnailService.swift
    │
    └── Views/
        ├── ContentView.swift            # Hovedvisning, 4 tabs, snarveier
        ├── CardsGridView.swift
        ├── QuickNoteView.swift          # Rendrerer i eget NSPanel
        └── Components/
            ├── DesignTokens.swift
            ├── AppIcon.swift            # Laster custom SVG fra Resources/Icons
            ├── ToastView.swift          # Global "Kopiert!"-toast
            ├── SettingsSheet.swift
            ├── KontekstView.swift       # Kontekst-fane m/ Bundles+Prompts sub-tabs
            ├── ContextBundlesView.swift # Bundles: tabs, filer som tiles, snippets
            ├── PromptsView.swift        # Prompts: kategori-tiles + tekst/fil-prompts
            ├── ToolsTabView.swift       # Tools: Skjermbilde/Filsti/Tabell sub-tabs
            ├── ScreenshotLightGridView.swift # 3-kolonne grid + lightbox i enkel modus
            ├── SheetsCollectorView.swift
            ├── SheetsTabView.swift
            ├── ClipboardListView.swift  # Utklipp m/ grupper, CSV-bygger, sok
            ├── PathListView.swift
            ├── FileCardView.swift
            ├── DraggableCardWrapper.swift
            ├── DragSourceView.swift
            ├── DragAllButton.swift
            ├── MultiFileDragButton.swift
            ├── HeaderView.swift
            ├── ToolbarView.swift
            ├── ActionBarView.swift
            ├── EmptyStateView.swift
            ├── ErrorBanner.swift
            ├── TypeBadge.swift
            ├── SetSelectorView.swift
            └── BatchRenameSheet.swift
```

---

## Bygge

### Forutsetninger
- macOS 13+ med Xcode Command Line Tools: `xcode-select --install`
- **Xcode IDE er IKKE nødvendig** — prosjektet bruker `swiftc` direkte

### Bygg, installer og start

```bash
./build.sh
```

Build-scriptet:
1. Kompilerer for Intel (x86_64) og Apple Silicon (arm64)
2. Lager universal binary med `lipo`
3. Bygger `.app`-bundle med Info.plist og ikon
4. Kopierer SVG-ikoner inn i bundlen
5. **Ad-hoc signerer** automatisk (stabil TCC-identitet = ingen konstante tillatelsesprompts)
6. Dreper eventuell kjørende instans
7. Kopierer appen til `/Applications/Ny Mappe (7).app`
8. Starter appen

### Autostart ved login

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Ny Mappe (7).app", hidden:false}'
```

### Legge til nye Swift-filer

Når du oppretter en ny `.swift`-fil, **må** du legge den til i `SOURCES`-arrayen i `build.sh`. Ellers kompileres den ikke.

Nye SVG-ikoner legges i `Ny Mappe 7/Resources/Icons/` — build.sh kopierer hele mappa automatisk.

---

## Datalagring

All data lagres under `~/Library/Application Support/GeniDrop/`:

| Sti | Innhold |
|-----|---------|
| `state.json` | All tilstand: sett, filer, utklipp, grupper, bundles, prompts, notater, innstillinger |
| `state.json.bak` + `.bak2` | Roterte backuper (skrives ved hver save; lastes automatisk hvis hovedfila er korrupt) |
| `StagingCache/<setId>/` | Kopierte filer per sett (Filer-fanen) |
| `Bundles/<bundleId>/` | Selvstendig lagring per bundle (Kontekst → Bundles) |
| `Prompts/<categoryId>/` | Vedlagte filer per prompt-kategori (Kontekst → Prompts) |
| `Thumbnails/` | Genererte miniatyrbilder |
| `Exports/` | Midlertidige zip-filer |

### Tilbakestill all data

```bash
rm -rf ~/Library/Application\ Support/GeniDrop/
```

---

## Tekniske detaljer

### Dra og slipp
- **Dra inn**: `ExternalDropZone` (`NSViewRepresentable`) som avviser interne drag
- **Dra ut**: `DraggableCardWrapper` og `DragSourceView` med `NSDraggingSource` (multi-fil via `NSPasteboardItem`)
- **Utklipp-drag**: `onDrag` med `NSItemProvider` for tekst fra utklipp-kort
- **Bundle-tabs og fil-tiles**: `.onDrag` på enkelt-URL eller `DraggableCardWrapper` for multi-URL

### Menybar / Flytende paneler
- `NSStatusItem` med SF Symbol
- Hoved-`FloatingPanel` (`NSPanel`) med `level = .floating`, `hidesOnDeactivate = false`
- Eget `FloatingPanel` for Quick Notes på høyre skjermkant
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]`

### Persistens
- `AppState` er `Codable` — serialiseres til JSON med 0.5s debounce
- Backup-rotasjon: `state.json` → `state.json.bak` → `state.json.bak2` ved hver save
- Bakoverkompatibel decoding via `decodeIfPresent(...) ?? default` på alle nye felter
- `NotificationCenter` for `saveFailedNotification` → synlig feil i UI

### Kodesignering
- `build.sh` ad-hoc signerer automatisk (`codesign --force --deep --sign -`)
- Gir appen stabil identity-hash slik at macOS TCC husker tillatelser mellom builds
- For release: `./build.sh --release` med SIGNING_IDENTITY satt

---

## Kjente begrensninger

- **Ingen App Sandbox**: Fri filtilgang, `/usr/bin/ditto` for zip
- **Ingen .xcodeproj**: Bygges med `swiftc` via `build.sh`
- **Nye filer**: Legg til i `SOURCES`-arrayen i `build.sh`
- **Ingen sync mellom enheter**: All data er lokal per maskin (macOS Universal Clipboard er en system-feature, ikke denne appens ansvar)

---

## Utviklerguide

Se [CONTRIBUTING-ny-mappe-7.md](CONTRIBUTING-ny-mappe-7.md) for:
- Arkitektur og kodestruktur
- Hvordan legge til nye filer, verktøy, innstillinger og snarveier
- Data-persistens og services
- Viktige patterns og begrensninger (macOS 13-kompatibilitet)

---

## Lisens

MIT — se [LICENSE](LICENSE).

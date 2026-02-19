# Ny Mappe (7)

En macOS menybar-app for **fil-staging**, **utklippshistorikk**, **skjermbilder**, **filsti-kopiering** og **verktøy**. Panelet svever over alle vinduer og skjuler seg fra Dock.

**Krav:** macOS 13.0+, Xcode Command Line Tools (`xcode-select --install`). Xcode IDE er **IKKE** nødvendig.

**Arkitekturer:** Universal binary — kjører nativt på både **Intel (x86_64)** og **Apple Silicon (arm64)**.

---

## Nytt i v3.3

### Smart Sheets-grid

Sheets-samleren er fullstendig omskrevet med en **smart redigerbar grid**:

- **Alle celler er alltid redigerbare** — klikk i hvilken som helst celle for å skrive eller redigere
- **Auto-lim** — kopiert tekst havner automatisk i en valgt kolonne, ny rad opprettes automatisk
- **Velg lim-inn-kolonne** — bestem hvilken kolonne (A/B/C/D) som mottar utklipp
- **Skru av auto-lim** for å jobbe helt manuelt
- **Scrollbar grid** — mange rader uten at knappene forsvinner
- **Innstillings-popover** — tannhjul-knapp med alle innstillinger + steg-for-steg guide
- **Status-pill** i headeren viser nåværende konfigurasjon (f.eks. "● 2 kol · limer i A")

### AI-navngivning av eksporter

Når du eksporterer Sheets-data som CSV, kan **GPT-4o-mini** automatisk foreslå et beskrivende filnavn basert på innholdet (f.eks. `prosjekt-kostnader.csv` i stedet for `sheets-export.csv`).

- Krever OpenAI API-nøkkel (legg inn under Innstillinger → AI)
- Fungerer automatisk ved CSV-eksport, faller tilbake til standard hvis ingen nøkkel

### Ny fanestruktur

Tre hovedfaner erstatter de gamle fire:

| Fane | Innhold |
|------|---------|
| **Filer** | Dra inn filer, staging-cache, dra ut til andre apper |
| **Utklipp** | Automatisk utklippshistorikk med søk og 2-kolonne grid |
| **Verktøy** | Sub-faner: **Skjermbilder**, **Paths**, **Sheets-samler** |

### Innstillingspanel

Innstillingene er en **modal dialog**:

- **Utseende** — Mørk / Lys / Følg system, enkel/full modus
- **Utklipp** — Konfigurerbar maks-grense (50–1000 eller ubegrenset)
- **Skjermbilder** — Auto-lagring av/på
- **Auto-opprydding** — Per kategori med valgfri alder
- **AI** — OpenAI API-nøkkel for AI-navngivning
- **Snarveier** — Oversikt over alle tastatursnarveier

### Utklipp-forbedringer

- **2-kolonne grid-layout** i kompakt modus
- **Søkebar** med `⌘F` snarvei
- **Tegnteller** på hvert kort (nyttig for tekst-arbeid)
- **Dato og klokkeslett** på hvert kort
- **«Les mer»-knapp** for lange utklipp
- **Dobbeltklikk** kopierer direkte med visuell «Kopiert!»-feedback
- **Drag & drop** — dra tekst fra utklipp-kort til andre apper
- **Maks-grense** — konfigurerbar i innstillinger, eldste slettes automatisk

### Tastatursnarveier

| Snarvei | Handling |
|---------|----------|
| `⌘1` / `⌘2` / `⌘3` | Bytt fane (Filer / Utklipp / Verktøy) |
| `⌘F` | Fokuser søkefeltet i Utklipp |
| `⌘C` | Kopier valgte utklipp |
| `⌘W` | Lukk panelet |

### Design

- Glass-aktig fane-bar med adaptiv opacity
- Dynamiske badges som skalerer for flersifrede tall
- Sub-faner med understreking-indikator
- Kompakte utklipp-kort med hover-actions

---

## Funksjoner

### Filer-fanen
- Dra filer inn manuelt — kopier lagres i en staging-cache (originaler røres aldri)
- Dra ut til andre apper
- Batch-omdøpning
- Sett/grupper for organisering
- Filter (Alle, Bilder, Video, osv.) og sortering i full modus

### Utklipp-fanen
- Tekst fanges automatisk mens appen kjører (poller `NSPasteboard.general` hvert 0.5s)
- Søkbar med `⌘F`
- 2-kolonne grid i kompakt modus
- Flervalg med blå ramme
- Fest viktige utklipp (slettes ikke ved tømming)
- Eksporter som .txt eller .csv
- Dobbeltklikk for å kopiere, drag for å dra til andre apper
- Tegnteller og tidsstempel per kort
- Konfigurerbar maks-grense med auto-sletting
- Duplikater av siste oppføring ignoreres

### Verktøy → Skjermbilder
- Automatisk skjermbildefangst fra skrivebordet
- Slå av/på i innstillinger

### Verktøy → Paths
- Slipp filer/mapper for å fange full filsti
- Kopieres automatisk til utklippstavlen
- Fest, vis i Finder

### Verktøy → Sheets-samler
- Smart redigerbar grid — alle celler er alltid redigerbare
- Auto-lim fra utklippstavlen i valgt kolonne, med automatisk rad-oppretting
- 2–4 kolonner, velg lim-inn-kolonne (A/B/C/D) eller skru av auto-lim
- Innstillings-popover med alle kontroller + steg-for-steg guide
- Kopier for Google Sheets (tab-separert) eller eksporter som .csv
- AI-navngivning av eksporterte filer (GPT-4o-mini, krever API-nøkkel)

### Enkel / Full modus
- **Enkel** (standard): Kompakt panel
- **Full**: Høyere panel med filter/sortering

### Menybar
- **Venstreklikk** for å vise/skjule panelet
- **Høyreklikk** for kontekstmeny: Åpne panel, Om, Avslutt
- Panelet svever over alle vinduer (`NSPanel` med `level = .floating`)
- Ingen Dock-ikon (`LSUIElement = true`)
- Panelet lukkes automatisk etter vellykket fil-utdragning

---

## Tastatursnarveier

| Snarvei | Handling |
|---------|----------|
| `⌘1` / `⌘2` / `⌘3` | Bytt fane (Filer / Utklipp / Verktøy) |
| `⌘F` | Fokuser søkefeltet i Utklipp |
| `⌘C` | Kopier valgte utklipp |
| `⌘A` | Velg alle (kontekst-bevisst per fane) |
| `⌘V` | Lim inn filer fra utklippstavlen (Filer/Skjermbilder) |
| `⌘W` | Lukk panelet |
| `Delete` | Fjern valgte elementer |
| `Space` | Quick Look på valgt fil |
| `Escape` | Fjern valg, eller lukk panel |
| Dobbeltklikk | Kopier utklipp direkte |

---

## Prosjektstruktur

```
NY-MAPPE-7/
├── README.md
├── LICENSE
├── build.sh                             # Universal build-script
├── .gitignore
│
└── Ny Mappe 7/                          # KILDEKODE
    ├── AppIcon.icns
    ├── NyMappe7App.swift                # App-inngang, menybar, flytende panel
    │
    ├── Models/
    │   ├── AppState.swift               # Codable struct for JSON-lagring
    │   ├── StashItem.swift              # Filmodell
    │   ├── StashSet.swift               # Filsett/gruppemodell
    │   ├── ClipboardEntry.swift         # Utklippsmodell
    │   └── PathEntry.swift              # Sti-modell
    │
    ├── ViewModels/
    │   └── StashViewModel.swift         # All app-logikk
    │
    ├── Services/
    │   ├── ClipboardWatcher.swift       # Poller NSPasteboard for ny tekst
    │   ├── PersistenceService.swift     # JSON last/lagre
    │   ├── ScreenshotWatcher.swift      # Overvåker skjermbildemappen
    │   ├── StagingService.swift         # Kopierer filer til cache, zip
    │   └── ThumbnailService.swift       # QuickLook-miniatyrbilder
    │
    └── Views/
        ├── ContentView.swift            # Hovedvisning, faner, snarveier
        ├── CardsGridView.swift          # Rutenett med filkort
        └── Components/
            ├── DesignTokens.swift       # Farger, fonter, stiler
            ├── SettingsSheet.swift       # Modal innstillingspanel
            ├── ToolsTabView.swift       # Verktøy-fane med sub-tabs
            ├── SheetsCollectorView.swift # Sheets-samler
            ├── SheetsTabView.swift       # Sheets-fane wrapper
            ├── ClipboardListView.swift  # Utklipp: grid, søk, drag
            ├── PathListView.swift       # Path-liste
            ├── FileCardView.swift       # Filkort med miniatyrbilde
            ├── DraggableCardWrapper.swift
            ├── DragSourceView.swift
            ├── DragAllButton.swift
            ├── MultiFileDragButton.swift
            ├── HeaderView.swift         # Statistikk + filter
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
- **Xcode IDE er IKKE nødvendig**

### Bygg (universal binary)

```bash
./build.sh
```

### Kjør

```bash
open "Ny Mappe (7) v2.app"
```

### Installer

```bash
cp -r "Ny Mappe (7) v2.app" /Applications/
```

---

## Datalagring

All data lagres under `~/Library/Application Support/GeniDrop/`:

| Sti | Innhold |
|-----|---------|
| `state.json` | All tilstand: sett, filer, utklipp, innstillinger (JSON, Codable) |
| `StagingCache/<setId>/` | Kopierte filer per sett |
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
- **Dra ut**: `DraggableCardWrapper` og `DragSourceView` med `NSDraggingSource`
- **Utklipp-drag**: `onDrag` med `NSItemProvider` for tekst fra utklipp-kort
- **Auto-lukking**: Panel lukkes etter vellykket utdragning

### Menybar / Flytende panel
- `NSStatusItem` med SF Symbol
- `FloatingPanel` (`NSPanel`) med `level = .floating`, `hidesOnDeactivate = false`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]`

### Persistens
- `AppState` er `Codable` — serialiseres til JSON med 0.5s debounce
- Inkluderer: sett, filer, utklippshistorikk, paths, innstillinger

---

## Kjente begrensninger

- **Ingen App Sandbox**: Fri filtilgang og `/usr/bin/ditto` for zip
- **Ingen .xcodeproj**: Bygges med `swiftc` via `build.sh`
- **Nye filer**: Legg til i `SOURCES`-arrayen i `build.sh`

---

## Lisens

MIT — se [LICENSE](LICENSE).

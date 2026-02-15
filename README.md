# Ny Mappe (7)

En macOS menybar-app for **fil-staging**, **utklippshistorikk**, **skjermbilder** og **filsti-kopiering**. Panelet svever over alle vinduer og skjuler seg fra Dock.

**Krav:** macOS 13.0+, Xcode Command Line Tools (`xcode-select --install`). Xcode IDE er **IKKE** nødvendig.

**Arkitekturer:** Universal binary — kjører nativt på både **Intel (x86_64)** og **Apple Silicon (arm64)**.

**Språk:** Norsk (standard) og engelsk. Bytt i Innstillinger → Språk.

---

## Funksjoner

### Fire faner

| Fane | Ikon | Beskrivelse |
|------|------|-------------|
| **Filer** | `doc.on.doc` | Dra filer inn manuelt. Kopier lagres i en staging-cache (originaler røres aldri). Dra ut til andre apper. |
| **Skjerm** | `camera.viewfinder` | Automatisk skjermbildefangst. Slå av/på med kamera-ikonet i tittellinja. |
| **Utklipp** | `doc.on.clipboard` | Automatisk utklippshistorikk. Fanger all tekst du kopierer (⌘C). Opptil 200 oppføringer. Søkbar. |
| **Path** | `folder` | Slipp filer/mapper fra Finder for å fange full filsti. Kopieres automatisk til utklippstavlen. |

### Utklipp-fanen i detalj
- Tekst fanges automatisk mens appen kjører (poller `NSPasteboard.general` hvert 0.5s)
- **Søk**: Filtrer oppføringer i sanntid med søkefeltet
- **Flervalg**: Trykk på kort for å velge/fjerne. Valgte elementer får blå ramme.
- **Kopier valgte**: Kombinerer valgte klipp med doble linjeskift (`\n\n`)
- **Eksporter .txt / .csv**: Lagre valgte klipp til fil
- **Fest**: Festede klipp slettes ikke ved tømming
- Duplikater av siste oppføring ignoreres. Filkopier (⌘C på filer i Finder) fanges IKKE.

### Enkel / Full modus
Veksle i Innstillinger (tannhjul-ikonet):
- **Enkel** (standard): Kortere panel (340px). Ingen filter/sorteringsknapper.
- **Full**: Høyere panel (520px). Viser filtervalg (Alle, Bilder, Video, osv.) og sorteringsmeny (Navn, Størrelse, Dato).

### Tema
Tre valg i Innstillinger: Mørk, Lys, Følg system. Alle farger er adaptive.

### Menybar
- **Venstreklikk** på ikonet for å vise/skjule panelet
- **Høyreklikk** for kontekstmeny: Åpne panel, Om, Avslutt
- Panelet svever over alle vinduer (`NSPanel` med `level = .floating`)
- Ingen Dock-ikon (`LSUIElement = true`)
- Panelet lukkes automatisk etter vellykket fil-utdragning

### Om-dialog
Tilgjengelig fra Innstillinger eller høyreklikk-menyen. Viser versjonsinformasjon og lenke til dette GitHub-repoet.

---

## Prosjektstruktur

```
ny-mappe-7/
├── README.md                           # Denne filen
├── LICENSE                             # MIT-lisens
├── build.sh                            # Universal build-script (Intel + Apple Silicon)
├── .gitignore
│
└── Ny Mappe 7/                         # KILDEKODE
    ├── NyMappe7App.swift               # App-inngang, MenuBarAppDelegate, FloatingPanel, høyreklikkmeny
    │
    ├── Models/
    │   ├── AppState.swift              # Codable struct for JSON-lagring av all tilstand
    │   ├── StashItem.swift             # Filmodell (id, URL, type, størrelse, isScreenshot)
    │   ├── StashSet.swift              # Filsett/gruppemodell
    │   ├── ClipboardEntry.swift        # Utklippsmodell (id, tekst, tidspunkt, isPinned)
    │   ├── PathEntry.swift             # Sti-modell (id, sti, navn, isDirectory, isPinned)
    │   └── Localization.swift          # AppLanguage enum + Loc struct (norsk/engelsk)
    │
    ├── ViewModels/
    │   └── StashViewModel.swift        # All app-logikk. @MainActor, ObservableObject.
    │
    ├── Services/
    │   ├── StagingService.swift        # Kopierer filer til cache, zip, validering
    │   ├── ThumbnailService.swift      # QuickLook-miniatyrbilder
    │   ├── PersistenceService.swift    # JSON last/lagre til ~/Library/Application Support/GeniDrop/
    │   ├── ScreenshotWatcher.swift     # Overvåker skjermbildemappen
    │   └── ClipboardWatcher.swift      # Poller NSPasteboard.general for ny tekst
    │
    └── Views/
        ├── ContentView.swift           # Hovedvisning: tittelbar, faner, slippsone, innstillingsmeny
        ├── CardsGridView.swift         # Rutenett med filkort
        └── Components/
            ├── DesignTokens.swift      # Alle farger, fonter, stiler. Adaptiv lys/mørk.
            ├── FileCardView.swift      # Enkelt filkort med miniatyrbilde og hover
            ├── DraggableCardWrapper.swift   # NSViewRepresentable for NSDraggingSource per kort
            ├── DragSourceView.swift    # NSViewRepresentable for "Dra alle"-knappen
            ├── DragAllButton.swift     # SwiftUI-wrapper for dra-alle
            ├── MultiFileDragButton.swift    # Dra-knapp for valgte filer
            ├── ClipboardListView.swift # Utklipp-fane: liste, søk, flervalg, kopier, eksporter
            ├── PathListView.swift      # Path-fane: liste, kopier, fest, vis i Finder
            ├── HeaderView.swift        # Statistikkrad + filter/sortering (vises i full modus)
            ├── ToolbarView.swift       # "Legg til filer"-knapp (kun Filer-fanen)
            ├── ActionBarView.swift     # "Fjern valgte" / "Tøm"-knapper
            ├── EmptyStateView.swift    # Tom tilstand per fane med animasjon
            ├── ErrorBanner.swift       # Feilmeldingsbanner
            ├── TypeBadge.swift         # Filtype-merke (Bilde, Video, osv.)
            ├── SetSelectorView.swift   # Settvelger og -administrasjon
            └── BatchRenameSheet.swift  # Batch-omdøpningsdialog
```

---

## Bygge

### Forutsetninger
- macOS 14+ med Xcode Command Line Tools: `xcode-select --install`
- **Xcode IDE er IKKE nødvendig**

### Bygg (universal binary)

```bash
./build.sh
```

Dette bygger for både Intel og Apple Silicon, lager en `.app`-bundle, og gir:
```
✅ Build complete!
   App:           ./Ny Mappe (7) v2.app
   Architectures: x86_64 arm64
```

### Kjør

```bash
open "Ny Mappe (7) v2.app"
```

Eller dobbeltklikk `.app`-filen i Finder.

### Installer

```bash
cp -r "Ny Mappe (7) v2.app" /Applications/
```

---

## Datalagring

All data lagres under `~/Library/Application Support/GeniDrop/`:

| Sti | Innhold |
|-----|---------|
| `state.json` | All tilstand: sett, filer, utklippshistorikk, innstillinger, språk (JSON, Codable) |
| `StagingCache/<setId>/` | Kopierte filer per sett |
| `Thumbnails/` | Genererte miniatyrbilder |
| `Exports/` | Midlertidige zip-filer |

### Tilbakestill all data
Slett mappen: `rm -rf ~/Library/Application\ Support/GeniDrop/`

---

## Tastatursnarveier

| Snarvei | Handling |
|---------|---------|
| `⌘A` | Velg alle (kontekst-bevisst per fane) |
| `⌘V` | Lim inn filer fra utklippstavlen (Filer/Skjerm-fanene) |
| `Delete` | Fjern valgte elementer |
| `Space` | Quick Look på første valgte fil |
| `Escape` | Fjern valg, eller lukk panel hvis ingenting er valgt |

---

## Tekniske detaljer

### Dra og slipp
- **Dra inn**: Egendefinert `ExternalDropZone` (`NSViewRepresentable`) som avviser interne drag.
- **Dra ut**: `DraggableCardWrapper` og `DragSourceView` implementerer `NSDraggingSource`. `mouseDownCanMoveWindow = false` hindrer vinduflytting.
- **Auto-lukking**: Panelet lukkes automatisk etter vellykket utdragning (`operation == .copy`).

### Menybar / Flytende panel
- `NSStatusItem` med SF Symbol `tray.and.arrow.down.fill`
- Venstreklikk veksler panel, høyreklikk viser kontekstmeny (Åpne, Om, Avslutt)
- `FloatingPanel` (subklasse av `NSPanel`) med `level = .floating`, `hidesOnDeactivate = false`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]`

### Lokalisering
- To språk: norsk (`no`) og engelsk (`en`)
- Alle UI-strenger i `Localization.swift` via `Loc`-structen
- Språkvalg lagres i `state.json`
- Modeller bruker `AppLanguage.current` statisk property

### Persistens
- `AppState` er `Codable` — serialiseres til JSON med 0.5s debounce
- Inkluderer: sett, filer, utklippshistorikk, sti-oppføringer, innstillinger, språk

---

## Kjente begrensninger

- **Ingen App Sandbox**: Appen kjører uten sandbox for fri filtilgang og `/usr/bin/ditto` for zip.
- **Ingen .xcodeproj**: Bygges direkte med `swiftc`. Alle kildefiler må listes i `build.sh`.
- **Nye filer**: Hvis du legger til en ny `.swift`-fil, MÅ du legge den til i `SOURCES`-arrayen i `build.sh`.

---

## Lisens

MIT — se [LICENSE](LICENSE).

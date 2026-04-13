# Ny Mappe (7) v3.5 — Forbedringsforslag

> Grundig gjennomgang av hele kodebasen. Sortert etter prioritet: kritisk, viktig, quick wins, og nice-to-have.

---

## KRITISK — bor fikses forst

### 1. State-lagring uten backup (datatapt-risiko)
- `PersistenceService.swift:37-46` skriver `state.json` atomisk, men **null backup**. Hvis crash under skriving, er alt borte.
- `StashViewModel.swift:219-240` debouncer lagring med 500ms — alt mellom siste lagring og en app-crash forsvinner.
- **Fix:** Skriv til `state.json.bak` for hver lagring, roter til `.bak` for brukeren ser det aldri men kan gjenopprettes.

### 2. Feilhakndtering er usynlig for bruker
- `PersistenceService.swift:45, 57` bruker bare `print()` pa errors — bruker vet aldri at lagring feilet.
- Import-feil (`StashViewModel.swift:336`) forsvinner etter 5 sekunder uten bekreftelse.
- **Fix:** Permanent feil-toast som krever brukerinteraksjon for a avvise, eller en liten rod prikk pa Settings-ikon.

### 3. maxClipboardEntries-grense ufullstendig
- `StashViewModel.swift:546-549` trimmer bare ved *insert*, men hva om bruker senker grensen fra 500 til 50 etter a ha 300 entries? De 250 ekstra blir aldri slettet.
- **Fix:** Legg til trim i setter for `maxClipboardEntries`.

### 4. Timere stoppes aldri ved app-avslutning
- `ClipboardWatcher.swift` poller clipboard hvert 0.5s — stopper aldri ved app-lukking, bare ved manuell toggle.
- `ScreenshotWatcher.swift` poller hvert 2.0s med samme problem.
- **Fix:** Stopp watchers i `applicationWillTerminate` i AppDelegate.

---

## VIKTIG — bor inn i neste versjon

### 5. Ingen undo/redo
- Slett filer, tom utklipp, slett gruppe — alt er umiddelbart og irreversibelt.
- **Fix:** Minst en "Angre siste handling"-knapp med 10s timeout, eller en trash/arkiv-keo for slettede items.

### 6. Mangler sok i Files-tab
- Utklipp har sok (`clipboardSearchText`), men Files har null. Hvis bruker har 500 filer, ma de scrolle manuelt.
- **Fix:** Sokefelt med samme monster som utklipp-soket — filtrer pa filnavn, type, kategori.

### 7. Ingen schema-versjonering pa state.json
- `AppState.swift:52-66` bruker `decodeIfPresent` for nye felter — funker i dag, men nar du endrer typer eller fjerner felter, krasjer det.
- **Fix:** Legg til `"stateVersion": 1` i JSON, og en migrasjonsfunksjon som oppgraderer eldre state steg-for-steg.

### 8. Settings bor lagres ved krasj
- `AppState` samler ALT i en JSON — bade settings og data. Bor separere innstillinger (tema, limits, API-nokkel) fra data (filer, klipp, notater) slik at crash i en del ikke dreper den andre.
- **Fix:** UserDefaults for innstillinger (allerede delvis gjort for `openAIKey`), state.json kun for data.

### 9. Quick Note debounce mangler
- `QuickNoteView.swift:154-157` oppdaterer viewModel pa hvert tastetrykk — trigger `scheduleSave()` 100x i sekundet ved rask skriving.
- **Fix:** Legg inn lokal `@State`-buffer i TextEditor med `.onChange`-debounce (0.5-1.0s) for lagring.

---

## QUICK WINS — lite arbeid, stor effekt

### 10. Aktiv malkgruppe-indikator i tab-bar
- Bruker vet ikke at "aktiv malgruppe" er satt uten a apne Utklipp-fanen.
- **Fix:** Vis gruppenavn som liten tag under tab-tittel, eller en dot-indikator.

### 11. Toast for "Kopiert!"
- `copyTextToPasteboard()` lukker panelet, men ingen visuell bekreftelse.
- `ClipboardCard.swift:467-471` flasher "Kopiert!" lokalt pa kortet, men bare ved dobbeltklikk — ikke ved Kopier-knappen i header.
- **Fix:** Global toast/snackbar-komponent brukt alle steder man kopierer.

### 12. Keyboard shortcut for Quick Note i hovedpanel
- Quick Note (Option+Shift+N) er global, men bruker vet det ikke — ingen hint i UI.
- **Fix:** Legg til `shortcutRow("Option+Shift+N", "Apne Quick Notes")` i `SettingsSheet.swift:233-246`.

### 13. Duplikert kode: timeAgo
- `ClipboardEntry.swift:30-42` og `PathEntry.swift:40-53` har identisk `timeAgo`-logikk.
- **Fix:** Trekk ut til en extension pa `Date` — en linje pr modell.

### 14. Tomme grupper skjules ikke
- Grupper uten entries viser "Tom gruppe" tekst. Etter hvert rar grupper-lista full av tomme seksjoner.
- **Fix:** Skjul tomme grupper med en toggle "Vis tomme grupper", eller knytt en "Tom? Slett?"-prompt.

### 15. Eksporter hele samling som .zip
- Kan eksportere filliste som tekst/CSV, men ikke selve filene samlet.
- `exportAsZip()` eksisterer allerede (`StashViewModel.swift:1135-1172`) — gi den en "Eksporter samling"-knapp utenfor kontekstmeny.

---

## NICE-TO-HAVE — fremtidig polering

### 16. Accessibility (WCAG)
- `DesignTokens.swift:48-50` subtleText i light mode (`0.50, 0.48, 0.52`) gir for lav kontrast mot hvit bakgrunn — WCAG AA kravet er 4.5:1.
- Mange knappers knapper mangler `.accessibilityLabel()` (FileCardView, ClipboardCard).
- Fargeblinde: valgt-tilstand vises kun som fargeskifte (bla border) — legg til checkmark-ikon.

### 17. LazyVGrid ytelse ved mange elementer
- `CardsGridView.swift` og `ClipboardListView.swift` bruker LazyVGrid, men uten pagination. Ved 1000+ items treges scrolling.
- **Fix:** `.onAppear`-basert pagination eller `.searchable` med limit.

### 18. Thumbnail-loading uten placeholder
- Nar filer importeres, vises kort uten thumbnail til `ThumbnailService` er ferdig. Visuelt hoppende.
- **Fix:** Shimmer/skeleton-placeholder pa thumbnail-omradet.

### 19. Dark/light mode transition
- `ContentView.swift:127` bruker `.preferredColorScheme()` — fungerer, men overgangen er bratt (ingen cross-fade).
- **Fix:** Wrap i `withAnimation(.easeInOut(duration: 0.3))` pa temaskiftet.

### 20. Drag & drop mellom grupper
- Grupper stotter "Flytt til"-meny, men ikke drag & drop av kort mellom gruppeoverskrifter.
- **Fix:** `.onDrop` pa groupHeader + `.onDrag` pa ClipboardCard (allerede partial — `.onDrag` finnes pa line 456).

### 21. iCloud / export av hele state
- Bruker kan miste alt ved maskinbytte. Ingen eksport/import av innstillinger + data.
- **Fix:** "Eksporter/Importer state" i Settings — JSON-fil bruker kan flytte.

### 22. Konfigurerbar Quick Note-posisjon
- Quick Note er alltid festet til hoyre skjermkant. Pa ultrawide-skjermer kan det vare langt unna arbeidet.
- **Fix:** Husk siste posisjon (NSPanel.setFrameAutosaveName) — 1-liner.

### 23. Debug-prints ma bort
- `PersistenceService.swift:45, 57` og mange services bruker `print()`.
- **Fix:** Erstatt med `os.Logger` (eller bare fjern) for release-builds.

### 24. StashViewModel som singleton hindrer testing
- `static let shared` gjor det umulig a injecte mock-dependencies.
- **Fix:** Bruk protocol-basert DI eller factory-monster. Ikke kritisk na, men viktig for testbarhet.

---

## OPPSUMMERT: Prioritert rekkefoljge

| # | Endring | Innsats | Effekt |
|---|---------|---------|--------|
| 1 | Backup av state.json | 30 min | Kritisk datavern |
| 2 | Synlige feilmeldinger | 1 time | Kritisk UX |
| 3 | Fix maxClipboardEntries-trim | 15 min | Bugfix |
| 4 | Stopp timere ved avslutning | 15 min | Ressurslekk |
| 5 | Undo for slett-operasjoner | 2-3 timer | Viktig UX |
| 6 | Sok i Files | 1 time | Viktig funksjon |
| 7 | Schema-versjon i state.json | 1 time | Fremtidssikring |
| 10 | Aktiv-gruppe indikator | 15 min | Quick win |
| 11 | Global "Kopiert!"-toast | 30 min | Quick win |
| 12 | Quick Note shortcut i Settings | 5 min | Quick win |
| 13 | Trekk ut timeAgo til Date-ext | 10 min | Quick win |

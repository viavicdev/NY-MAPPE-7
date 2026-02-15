import Foundation

// MARK: - Language Enum

enum AppLanguage: String, Codable, CaseIterable {
    case no = "no"
    case en = "en"

    var displayName: String {
        switch self {
        case .no: return "Norsk"
        case .en: return "English"
        }
    }

    /// Global accessor for use in model computed properties (e.g. timeAgo)
    static var current: AppLanguage = .no
}

// MARK: - Localization Struct

struct Loc {
    let l: AppLanguage
    private var no: Bool { l == .no }

    // MARK: Tabs
    var files: String { no ? "Filer" : "Files" }
    var screen: String { no ? "Skjerm" : "Screen" }
    var clipboard: String { no ? "Utklipp" : "Clipboard" }
    var path: String { "Path" }

    // MARK: Settings Menu
    var saveScreenshots: String { no ? "Lagre skjermbilder" : "Save screenshots" }
    var switchToFull: String { no ? "Bytt til full versjon" : "Switch to full version" }
    var switchToSimple: String { no ? "Bytt til enkel versjon" : "Switch to simple version" }
    var dark: String { no ? "Mørk" : "Dark" }
    var light: String { no ? "Lys" : "Light" }
    var followSystem: String { no ? "Følg system" : "Follow system" }
    var autoCleanup: String { no ? "Auto-opprydding" : "Auto-cleanup" }
    var filesOlderThan: String { no ? "Filer eldre enn..." : "Files older than..." }
    var clipboardOlderThan: String { no ? "Utklipp eldre enn..." : "Clipboard older than..." }
    var pathsOlderThan: String { no ? "Paths eldre enn..." : "Paths older than..." }
    var never: String { no ? "Aldri" : "Never" }
    func days(_ n: Int) -> String { no ? "\(n) dager" : "\(n) days" }
    var settings: String { no ? "Innstillinger" : "Settings" }
    var language: String { no ? "Språk" : "Language" }

    // MARK: Common Actions
    var addFiles: String { no ? "Legg til filer" : "Add files" }
    var chooseFiles: String { no ? "Velg filer" : "Choose files" }
    var closePanel: String { no ? "Lukk panelet" : "Close panel" }
    var remove: String { no ? "Fjern" : "Remove" }
    var removeSelected: String { no ? "Fjern valgte" : "Remove selected" }
    var clear: String { no ? "Tøm" : "Clear" }
    var copy: String { no ? "Kopier" : "Copy" }
    var delete: String { no ? "Slett" : "Delete" }
    var cancel: String { no ? "Avbryt" : "Cancel" }
    var save: String { no ? "Lagre" : "Save" }
    var create: String { no ? "Opprett" : "Create" }
    var rename: String { no ? "Gi nytt navn" : "Rename" }
    var pin: String { no ? "Fest" : "Pin" }
    var unpin: String { no ? "Fjern feste" : "Unpin" }
    var selectAll: String { no ? "Velg alle" : "Select all" }
    var deselect: String { no ? "Fjern valg" : "Deselect" }
    func selected(_ n: Int) -> String { no ? "\(n) valgt" : "\(n) selected" }
    var open: String { no ? "Åpne" : "Open" }
    var share: String { no ? "Del..." : "Share..." }

    // MARK: Drop Zone
    var dropToCopyPath: String { no ? "Slipp for å kopiere path" : "Drop to copy path" }
    var dropFilesHere: String { no ? "Slipp filer her" : "Drop files here" }

    // MARK: Stats Labels
    func filesCount(_ n: Int) -> String { no ? "\(n) filer" : "\(n) files" }
    func screenshotsCount(_ n: Int) -> String { no ? "\(n) skjermbilder" : "\(n) screenshots" }
    func clipsCount(_ n: Int) -> String { no ? "\(n) utklipp" : "\(n) clips" }
    func pathsCount(_ n: Int) -> String { "\(n) paths" }

    // MARK: Finder / Files
    var showInFinder: String { no ? "Vis i Finder" : "Show in Finder" }
    var renameSelectedEllipsis: String { no ? "Gi nytt navn til valgte..." : "Rename selected..." }

    // MARK: Zip
    var zipToStash: String { no ? "Zip til stash" : "Zip to stash" }
    var exportAsZipEllipsis: String { no ? "Eksporter som .zip..." : "Export as .zip..." }
    var zipAll: String { no ? "Zip alle" : "Zip all" }
    var zipSelected: String { no ? "Zip valgte" : "Zip selected" }

    // MARK: Toolbar
    var pasteFromClipboard: String { no ? "Lim inn fra utklippstavle" : "Paste from clipboard" }
    var renameSelected: String { no ? "Gi nytt navn til valgte" : "Rename selected" }
    var shareSelectedFiles: String { no ? "Del valgte filer" : "Share selected files" }
    var asTxtFilenames: String { no ? "Som .txt (filnavn)" : "As .txt (filenames)" }
    var asCsvMetadata: String { no ? "Som .csv (metadata)" : "As .csv (metadata)" }
    var asJsonFull: String { no ? "Som .json (full info)" : "As .json (full info)" }
    var exportFileList: String { no ? "Eksporter filliste" : "Export file list" }

    // MARK: Drag
    func dragAll(_ n: Int) -> String { no ? "Dra alle (\(n))" : "Drag all (\(n))" }
    var dragToTransfer: String { no ? "Dra til en annen app for å overføre filer" : "Drag to another app to transfer files" }

    // MARK: Empty States
    var noScreenshotsYet: String { no ? "Ingen screenshots ennå" : "No screenshots yet" }
    var dragFilesHere: String { no ? "Dra filer hit" : "Drag files here" }
    var enableCameraAndScreenshot: String { no ? "Slå på kamera-ikonet og ta et screenshot" : "Enable the camera icon and take a screenshot" }
    var orUseButtonsAbove: String { no ? "eller bruk knappene over" : "or use the buttons above" }

    // MARK: Clipboard Tab
    var noClipsYet: String { no ? "Ingen klipp ennå" : "No clips yet" }
    var copyWithCmdC: String { no ? "Kopier tekst med ⌘C så dukker det opp her" : "Copy text with ⌘C and it will appear here" }
    var copyToClipboard: String { no ? "Kopier til utklippstavle" : "Copy to clipboard" }

    // MARK: Path Tab
    var dragFolderOrFileHere: String { no ? "Dra mappe eller fil hit" : "Drag folder or file here" }
    var dropFromFinderToCopyPath: String { no ? "Slipp en mappe/fil fra Finder\nfor å kopiere full path" : "Drop a folder/file from Finder\nto copy full path" }
    var copied: String { no ? "Kopiert!" : "Copied!" }
    var copyPath: String { no ? "Kopier path" : "Copy path" }
    var copyPaths: String { no ? "Kopier paths" : "Copy paths" }
    var copySelectedPaths: String { no ? "Kopier valgte paths (en per linje)" : "Copy selected paths (one per line)" }
    var clearAllExceptPinned: String { no ? "Tøm alle (unntatt festede)" : "Clear all (except pinned)" }

    // MARK: Set Management
    var noSets: String { no ? "Ingen sett" : "No sets" }
    var deleteSet: String { no ? "Slett sett" : "Delete set" }
    var newSet: String { no ? "Nytt sett" : "New set" }
    var setName: String { no ? "Navn på sett" : "Set name" }

    // MARK: Batch Rename
    func renameFiles(_ n: Int) -> String { no ? "Gi nytt navn til \(n) filer" : "Rename \(n) files" }
    var prefixLabel: String { no ? "Prefiks:" : "Prefix:" }
    var prefixPlaceholder: String { no ? "prefiks" : "prefix" }
    var separatorLabel: String { no ? "Skilletegn:" : "Separator:" }
    var underscore: String { no ? "_ (understrek)" : "_ (underscore)" }
    var hyphen: String { no ? "- (bindestrek)" : "- (hyphen)" }
    var period: String { no ? ". (punktum)" : ". (period)" }
    var space: String { no ? "  (mellomrom)" : "  (space)" }
    var startNumber: String { no ? "Start nr:" : "Start #:" }
    var digits: String { no ? "Siffer:" : "Digits:" }
    var preview: String { no ? "Forhåndsvisning:" : "Preview:" }

    // MARK: Header / Import
    func importing(_ completed: Int, _ total: Int) -> String { no ? "Importerer \(completed)/\(total)" : "Importing \(completed)/\(total)" }

    // MARK: Time Ago
    var now: String { no ? "nå" : "now" }
    var justNow: String { no ? "Akkurat nå" : "Just now" }
    func minutesAgo(_ n: Int) -> String { no ? "\(n) min siden" : "\(n) min ago" }
    func hoursAgo(_ n: Int) -> String { no ? "\(n)t siden" : "\(n)h ago" }
    func daysAgo(_ n: Int) -> String { no ? "\(n)d siden" : "\(n)d ago" }
    var yesterday: String { no ? "I går" : "Yesterday" }
    func minutesAgoShort(_ n: Int) -> String { no ? "\(n)m siden" : "\(n)m ago" }
    func hoursAgoShort(_ n: Int) -> String { no ? "\(n)t siden" : "\(n)h ago" }

    // MARK: Export (ViewModel)
    var noFilesOnClipboard: String { no ? "Ingen filer funnet på utklippstavlen" : "No files found on clipboard" }
    func importFailed(_ errors: String) -> String { no ? "Noen filer kunne ikke importeres: \(errors)" : "Some files failed to import: \(errors)" }
    var exportClipboard: String { no ? "Eksporter utklipp" : "Export clipboard" }
    var clipboardTxt: String { no ? "utklipp.txt" : "clipboard.txt" }
    var clipboardCsv: String { no ? "utklipp.csv" : "clipboard.csv" }
    func couldNotSaveFile(_ err: String) -> String { no ? "Kunne ikke lagre filen: \(err)" : "Could not save file: \(err)" }
    var textHeader: String { no ? "Tekst" : "Text" }
    var timeHeader: String { no ? "Tidspunkt" : "Time" }
    var pinnedHeader: String { no ? "Festet" : "Pinned" }
    var yes: String { no ? "Ja" : "Yes" }
    var noStr: String { no ? "Nei" : "No" }
    var exportClipboardCSV: String { no ? "Eksporter utklipp som CSV" : "Export clipboard as CSV" }
    var exportFileListTitle: String { no ? "Eksporter filliste" : "Export file list" }
    var filelistTxt: String { no ? "filliste.txt" : "filelist.txt" }
    var exportFileListCSV: String { no ? "Eksporter filliste som CSV" : "Export file list as CSV" }
    var filelistCsv: String { no ? "filliste.csv" : "filelist.csv" }
    var filenameHeader: String { no ? "Filnavn" : "Filename" }
    var typeHeader: String { "Type" }
    var categoryHeader: String { no ? "Kategori" : "Category" }
    var sizeHeader: String { no ? "Størrelse" : "Size" }
    var bytesHeader: String { "Bytes" }
    var dateHeader: String { no ? "Dato" : "Date" }
    var originalPathHeader: String { no ? "Original sti" : "Original path" }
    var exportFileListJSON: String { no ? "Eksporter filliste som JSON" : "Export file list as JSON" }
    var filelistJson: String { no ? "filliste.json" : "filelist.json" }
    var exportAsZipTitle: String { no ? "Eksporter som .zip" : "Export as .zip" }
    func couldNotSaveZip(_ err: String) -> String { no ? "Kunne ikke lagre zip: \(err)" : "Could not save zip: \(err)" }
    func zipFailed(_ err: String) -> String { no ? "Zip feilet: \(err)" : "Zip failed: \(err)" }
    func couldNotRename(_ name: String, _ err: String) -> String { no ? "Kunne ikke gi nytt navn til \(name): \(err)" : "Could not rename \(name): \(err)" }

    // MARK: Status Bar Menu
    var openPanel: String { no ? "Åpne panel" : "Open panel" }
    var about: String { no ? "Om Ny Mappe (7)" : "About Ny Mappe (7)" }
    var quit: String { no ? "Avslutt" : "Quit" }
    var version: String { no ? "Versjon" : "Version" }
    var searchClipboard: String { no ? "Søk i utklipp..." : "Search clipboard..." }
    var aboutDescription: String { no ? "Fil-staging, utklippstavle-historikk og screenshot-fangst for macOS." : "File staging, clipboard history and screenshot capture for macOS." }
    var madeBy: String { no ? "Laget av" : "Made by" }
    var viewOnGithub: String { no ? "Vis på GitHub" : "View on GitHub" }
}

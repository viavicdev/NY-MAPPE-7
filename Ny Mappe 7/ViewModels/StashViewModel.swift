import Foundation
import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class StashViewModel: ObservableObject {
    // MARK: - Shared Instance

    static let shared = StashViewModel()

    // MARK: - Published State

    @Published var sets: [StashSet] = []
    @Published var items: [StashItem] = []
    @Published var activeSetId: UUID?
    @Published var alwaysOnTop: Bool = false
    @Published var sortOption: SortOption = .dateAdded
    @Published var filterOption: FilterOption = .all
    @Published var selectedItemIds: Set<UUID> = []
    @Published var isImporting: Bool = false
    @Published var importProgress: ImportProgress = ImportProgress(completed: 0, total: 0)
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var saveScreenshots: Bool = false
    @Published var clipboardWatchEnabled: Bool = false
    @Published var isLightVersion: Bool = true
    @Published var activeTab: AppTab = .files
    @Published var clipboardEntries: [ClipboardEntry] = []
    @Published var selectedClipboardIds: Set<UUID> = []
    @Published var clipboardSearchText: String = ""
    @Published var clipboardSearchFocusTrigger: Bool = false
    @Published var maxClipboardEntries: Int = 0 {
        didSet {
            enforceClipboardLimit()
        }
    }

    // Clipboard-grupper
    @Published var clipboardGroups: [ClipboardGroup] = []
    @Published var activeClipboardGroupId: UUID?
    @Published var expandedClipboardGroupIds: Set<UUID?> = [nil]
    @Published var clipboardNewestOnTop: Bool = true
    @Published var clipboardCopyBlankLines: Int = 1
    @Published var clipboardIncludeGroupHeader: Bool = true

    // Quick Notes
    @Published var quickNotes: [QuickNote] = []
    @Published var lastOpenedQuickNoteId: UUID?

    // CSV kolonnevis-bygger
    @Published var csvColumnBuilder: CSVColumnBuilderState?

    // Context Bundles
    @Published var contextBundles: [ContextBundle] = []
    @Published var activeContextBundleId: UUID?

    // Global toast (Kopiert!, Lagret! osv)
    @Published var toastMessage: String?
    private var toastDismissTask: Task<Void, Never>?

    var filteredClipboardEntries: [ClipboardEntry] {
        if clipboardSearchText.isEmpty { return clipboardEntries }
        let query = clipboardSearchText.lowercased()
        return clipboardEntries.filter { $0.text.lowercased().contains(query) }
    }
    @Published var pathEntries: [PathEntry] = []
    @Published var selectedPathIds: Set<UUID> = []
    @Published var autoCleanupFilesDays: Int? = nil
    @Published var autoCleanupClipboardDays: Int? = nil
    @Published var autoCleanupPathsDays: Int? = nil
    @Published var showBatchRenameSheet: Bool = false

    // Sheets Collector — smart grid
    @Published var sheetsCollectorEnabled: Bool = false
    @Published var sheetsColumnCount: Int = 2
    @Published var sheetsGrid: [[String]] = [["", ""]]
    @Published var sheetsPasteColumn: Int = 0
    @Published var sheetsAutoPaste: Bool = true

    enum AppTab {
        case files
        case clipboard
        case tools
    }

    enum ToolsSubTab {
        case screenshots
        case paths
        case sheets
        case bundles
    }

    @Published var activeToolsTab: ToolsSubTab = .screenshots

    // MARK: - Services

    private let staging = StagingService.shared
    private let persistence = PersistenceService.shared
    private let thumbnails = ThumbnailService.shared
    private let screenshotWatcher = ScreenshotWatcher.shared
    private let clipboardWatcher = ClipboardWatcher.shared
    private var saveTask: Task<Void, Never>?

    // MARK: - Computed

    var activeSet: StashSet? {
        sets.first { $0.id == activeSetId }
    }

    var currentItems: [StashItem] {
        guard let setId = activeSetId else { return [] }
        var filtered = items.filter { $0.setId == setId }

        // Filter by active tab
        switch activeTab {
        case .files:
            filtered = filtered.filter { !$0.isScreenshot }
        case .clipboard:
            return []
        case .tools:
            switch activeToolsTab {
            case .screenshots:
                filtered = filtered.filter { $0.isScreenshot }
            case .paths, .sheets, .bundles:
                return []
            }
        }

        // Apply filter (only in full mode)
        if let category = filterOption.matchesCategory {
            filtered = filtered.filter { $0.typeCategory == category }
        }

        // Apply sort
        switch sortOption {
        case .name:
            filtered.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        case .size:
            filtered.sort { $0.sizeBytes > $1.sizeBytes }
        case .dateAdded:
            filtered.sort { $0.dateAdded > $1.dateAdded }
        case .manual:
            filtered.sort { ($0.sortIndex ?? Int.max) < ($1.sortIndex ?? Int.max) }
        }

        return filtered
    }

    var currentSetItemCount: Int {
        currentItems.count
    }

    var currentSetTotalSize: Int64 {
        currentItems.reduce(0) { $0 + $1.sizeBytes }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: currentSetTotalSize, countStyle: .file)
    }

    var screenshotCount: Int {
        guard let setId = activeSetId else { return 0 }
        return items.filter { $0.setId == setId && $0.isScreenshot }.count
    }

    var fileCount: Int {
        guard let setId = activeSetId else { return 0 }
        return items.filter { $0.setId == setId && !$0.isScreenshot }.count
    }

    var toolsCount: Int {
        screenshotCount + pathCount + sheetsRowCount
    }

    var clipboardCount: Int {
        clipboardEntries.count
    }

    var pathCount: Int {
        pathEntries.count
    }

    var selectedItems: [StashItem] {
        currentItems.filter { selectedItemIds.contains($0.id) }
    }

    // MARK: - Init

    init() {
        loadState()
        observePersistenceNotifications()
    }

    private func observePersistenceNotifications() {
        NotificationCenter.default.addObserver(
            forName: PersistenceService.saveFailedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                let detail = (note.userInfo?["error"] as? String) ?? "ukjent feil"
                self?.errorMessage = "Kunne ikke lagre data: \(detail). Endringene dine er fortsatt i minnet \u{2014} prøv å lukke og åpne appen, eller sjekk diskplass."
                self?.showError = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: PersistenceService.loadFailedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                let source = (note.userInfo?["recoveredFrom"] as? String) ?? "backup"
                self?.showToast("Gjenopprettet fra \(source)", duration: 3.0)
            }
        }
    }

    // MARK: - State Persistence

    private func loadState() {
        if let state = persistence.loadState() {
            self.sets = state.sets
            self.items = state.items
            self.activeSetId = state.activeSetId
            self.alwaysOnTop = state.alwaysOnTop
            self.sortOption = state.sortOption
            self.filterOption = state.filterOption
            self.clipboardEntries = state.clipboardEntries
            self.pathEntries = state.pathEntries
            self.saveScreenshots = state.saveScreenshots
            self.autoCleanupFilesDays = state.autoCleanupFilesDays
            self.autoCleanupClipboardDays = state.autoCleanupClipboardDays
            self.autoCleanupPathsDays = state.autoCleanupPathsDays
            self.clipboardGroups = state.clipboardGroups
            self.activeClipboardGroupId = state.activeClipboardGroupId
            self.clipboardNewestOnTop = state.clipboardNewestOnTop
            self.clipboardCopyBlankLines = state.clipboardCopyBlankLines
            self.clipboardIncludeGroupHeader = state.clipboardIncludeGroupHeader
            self.quickNotes = state.quickNotes
            self.lastOpenedQuickNoteId = state.lastOpenedQuickNoteId
            self.contextBundles = state.contextBundles
            self.activeContextBundleId = state.activeContextBundleId
            // Alle eksisterende grupper starter ekspandert, samt "Ingen gruppe" (nil).
            self.expandedClipboardGroupIds = Set([nil] + state.clipboardGroups.map { Optional($0.id) })

            // Validate staged files still exist
            self.items = staging.validateItems(self.items)
        }

        performAutoCleanup()

        // Ensure default set exists
        if sets.isEmpty {
            let defaultSet = StashSet(name: StashSet.defaultSetName)
            sets.append(defaultSet)
            activeSetId = defaultSet.id
        }

        if activeSetId == nil {
            activeSetId = sets.first?.id
        }

        // Auto-start clipboard watcher
        startClipboardWatch()

        // Auto-start screenshot watcher if enabled in settings
        if saveScreenshots {
            screenshotWatcher.startWatching { [weak self] url in
                Task { @MainActor in
                    self?.importScreenshot(url)
                }
            }
        }

        scheduleSave()
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            let state = AppState(
                sets: self.sets,
                items: self.items,
                activeSetId: self.activeSetId,
                alwaysOnTop: self.alwaysOnTop,
                sortOption: self.sortOption,
                filterOption: self.filterOption,
                clipboardEntries: self.clipboardEntries,
                pathEntries: self.pathEntries,
                saveScreenshots: self.saveScreenshots,
                autoCleanupFilesDays: self.autoCleanupFilesDays,
                autoCleanupClipboardDays: self.autoCleanupClipboardDays,
                autoCleanupPathsDays: self.autoCleanupPathsDays,
                clipboardGroups: self.clipboardGroups,
                activeClipboardGroupId: self.activeClipboardGroupId,
                clipboardNewestOnTop: self.clipboardNewestOnTop,
                clipboardCopyBlankLines: self.clipboardCopyBlankLines,
                clipboardIncludeGroupHeader: self.clipboardIncludeGroupHeader,
                quickNotes: self.quickNotes,
                lastOpenedQuickNoteId: self.lastOpenedQuickNoteId,
                contextBundles: self.contextBundles,
                activeContextBundleId: self.activeContextBundleId
            )
            self.persistence.saveState(state)
        }
    }

    // MARK: - Set Management

    func createSet(name: String) {
        let newSet = StashSet(name: name)
        sets.append(newSet)
        activeSetId = newSet.id
        scheduleSave()
    }

    func renameSet(_ setId: UUID, to name: String) {
        if let index = sets.firstIndex(where: { $0.id == setId }) {
            sets[index].name = name
            scheduleSave()
        }
    }

    func deleteSet(_ setId: UUID) {
        staging.clearSet(setId)
        items.removeAll { $0.setId == setId }
        sets.removeAll { $0.id == setId }

        if activeSetId == setId {
            activeSetId = sets.first?.id
        }

        // Ensure at least one set exists
        if sets.isEmpty {
            let defaultSet = StashSet(name: StashSet.defaultSetName)
            sets.append(defaultSet)
            activeSetId = defaultSet.id
        }

        scheduleSave()
    }

    func switchSet(_ setId: UUID) {
        activeSetId = setId
        selectedItemIds.removeAll()
        scheduleSave()
    }

    // MARK: - Import

    func importURLs(_ urls: [URL]) {
        guard let setId = activeSetId else { return }
        let existingItems = items.filter { $0.setId == setId }

        isImporting = true
        importProgress = ImportProgress(completed: 0, total: 0)

        Task {
            let result = await staging.importURLs(
                urls,
                toSet: setId,
                existingItems: existingItems
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.importProgress = progress
                }
            }

            self.items.append(contentsOf: result.items)
            self.isImporting = false

            if !result.errors.isEmpty {
                self.errorMessage = "Noen filer kunne ikke importeres: \(result.errors.joined(separator: "; "))"
                self.showError = true
            }

            self.scheduleSave()

            // Generate thumbnails in background
            for item in result.items {
                Task.detached(priority: .utility) {
                    if let thumbPath = await self.thumbnails.generateThumbnail(for: item) {
                        await MainActor.run {
                            if let idx = self.items.firstIndex(where: { $0.id == item.id }) {
                                self.items[idx].thumbnailPath = thumbPath
                                self.scheduleSave()
                            }
                        }
                    }
                }
            }
        }
    }

    func importFromPasteboard() {
        let pasteboard = NSPasteboard.general
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty else {
            errorMessage = "No files found on clipboard"
            showError = true
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showError = false
            }
            return
        }
        importURLs(urls)
    }

    // MARK: - Selection

    func toggleSelection(_ itemId: UUID, extending: Bool) {
        if extending {
            if selectedItemIds.contains(itemId) {
                selectedItemIds.remove(itemId)
            } else {
                selectedItemIds.insert(itemId)
            }
        } else {
            if selectedItemIds.count == 1 && selectedItemIds.contains(itemId) {
                selectedItemIds.removeAll()
            } else {
                selectedItemIds = [itemId]
            }
        }
    }

    func selectRange(to itemId: UUID) {
        let items = currentItems
        guard let targetIndex = items.firstIndex(where: { $0.id == itemId }) else { return }

        if let lastSelected = selectedItemIds.first,
           let lastIndex = items.firstIndex(where: { $0.id == lastSelected }) {
            let range = min(lastIndex, targetIndex)...max(lastIndex, targetIndex)
            for i in range {
                selectedItemIds.insert(items[i].id)
            }
        } else {
            selectedItemIds = [itemId]
        }
    }

    func selectAll() {
        selectedItemIds = Set(currentItems.map { $0.id })
    }

    // MARK: - Remove Items

    func removeSelected() {
        let toRemove = selectedItems
        for item in toRemove {
            staging.removeItem(item)
        }
        items.removeAll { selectedItemIds.contains($0.id) }
        selectedItemIds.removeAll()
        scheduleSave()
    }

    func removeSelectedClipboardEntries() {
        clipboardEntries.removeAll { selectedClipboardIds.contains($0.id) }
        selectedClipboardIds.removeAll()
        scheduleSave()
    }

    func removeSelectedPathEntries() {
        pathEntries.removeAll { selectedPathIds.contains($0.id) }
        selectedPathIds.removeAll()
        scheduleSave()
    }

    // MARK: - Clear Current Set

    func clearCurrentSet() {
        guard let setId = activeSetId else { return }
        staging.clearSet(setId)
        items.removeAll { $0.setId == setId }
        selectedItemIds.removeAll()
        scheduleSave()
    }

    // MARK: - Zip

    func zipItems() {
        let itemsToZip = selectedItemIds.isEmpty ? currentItems : selectedItems
        guard !itemsToZip.isEmpty else { return }
        let setName = activeSet?.name ?? "export"

        Task {
            do {
                let zipURL = try await staging.zipItems(itemsToZip, setName: setName)

                // Add zip as a new item in the current set
                guard let setId = activeSetId else { return }
                let attrs = try FileManager.default.attributesOfItem(atPath: zipURL.path)
                let size = (attrs[.size] as? Int64) ?? 0

                let zipItem = StashItem(
                    setId: setId,
                    originalURL: zipURL,
                    stagedURL: zipURL,
                    fileName: zipURL.lastPathComponent,
                    ext: "zip",
                    typeCategory: .archive,
                    sizeBytes: size
                )
                self.items.append(zipItem)
                self.scheduleSave()
            } catch {
                self.errorMessage = "Zip failed: \(error.localizedDescription)"
                self.showError = true
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    self.showError = false
                }
            }
        }
    }

    // MARK: - Drag Out

    func dragItems(ids: Set<UUID>? = nil) -> [URL] {
        let targetIds = ids ?? Set(currentItems.map { $0.id })
        return items
            .filter { targetIds.contains($0.id) }
            .map { $0.stagedURL }
    }

    // MARK: - Reveal in Finder

    func revealInFinder(_ item: StashItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.stagedURL])
    }

    func revealSelectedInFinder() {
        let urls = selectedItems.map { $0.stagedURL }
        if !urls.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }

    // MARK: - Relative Time

    static func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Akkurat n\u{00E5}" }
        if interval < 3600 { return "\(Int(interval / 60))m siden" }
        if interval < 86400 { return "\(Int(interval / 3600))t siden" }
        if interval < 172800 { return "I g\u{00E5}r" }
        if interval < 604800 { return "\(Int(interval / 86400))d siden" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Always on Top

    func toggleAlwaysOnTop() {
        alwaysOnTop.toggle()
        scheduleSave()
    }

    // MARK: - Screenshot Setting

    func setSaveScreenshots(_ enabled: Bool) {
        saveScreenshots = enabled
        if saveScreenshots {
            screenshotWatcher.startWatching { [weak self] url in
                Task { @MainActor in
                    self?.importScreenshot(url)
                }
            }
        } else {
            screenshotWatcher.stopWatching()
        }
        scheduleSave()
    }

    // MARK: - Clipboard Watcher

    private func startClipboardWatch() {
        clipboardWatchEnabled = true
        clipboardWatcher.startWatching { [weak self] text in
            Task { @MainActor in
                self?.addClipboardEntry(text)
            }
        }
    }

    func toggleClipboardWatch() {
        clipboardWatchEnabled.toggle()
        if clipboardWatchEnabled {
            startClipboardWatch()
        } else {
            clipboardWatcher.stopWatching()
        }
    }

    private func addClipboardEntry(_ text: String) {
        // Don't add duplicates of the most recent entry
        if let last = clipboardEntries.first, last.text == text { return }

        let entry = ClipboardEntry(text: text, groupId: activeClipboardGroupId)
        clipboardEntries.insert(entry, at: 0)

        enforceClipboardLimit()

        if sheetsCollectorEnabled {
            addToSheetsCollector(text)
        }

        scheduleSave()
    }

    /// Beskjærer clipboard-lista til maxClipboardEntries. Festede items teller ikke
    /// mot grensen slik at brukeren ikke mister pinned entries når limit senkes.
    private func enforceClipboardLimit() {
        let limit = maxClipboardEntries > 0 ? maxClipboardEntries : 500
        let pinned = clipboardEntries.filter { $0.isPinned }
        let unpinned = clipboardEntries.filter { !$0.isPinned }
        guard unpinned.count > limit else { return }
        let trimmed = Array(unpinned.prefix(limit))
        // Behold original rekkefølge: pinned + unpinned slik de lå (nyeste først i lagret array).
        clipboardEntries = clipboardEntries.filter { entry in
            entry.isPinned || trimmed.contains(where: { $0.id == entry.id })
        }
        _ = pinned
        scheduleSave()
    }

    func deleteClipboardEntry(_ entry: ClipboardEntry) {
        clipboardEntries.removeAll { $0.id == entry.id }
        scheduleSave()
    }

    func togglePinClipboardEntry(_ entry: ClipboardEntry) {
        if let idx = clipboardEntries.firstIndex(where: { $0.id == entry.id }) {
            clipboardEntries[idx].isPinned.toggle()
            scheduleSave()
        }
    }

    func clearClipboardEntries() {
        clipboardEntries.removeAll { !$0.isPinned }
        scheduleSave()
    }

    func toggleClipboardSelection(_ entryId: UUID) {
        if selectedClipboardIds.contains(entryId) {
            selectedClipboardIds.remove(entryId)
        } else {
            selectedClipboardIds.insert(entryId)
        }
    }

    func copyClipboardEntry(_ entry: ClipboardEntry) {
        copyTextToPasteboard(entry.text)
    }

    func copySelectedClipboardEntries() {
        let selected = clipboardEntries.filter { selectedClipboardIds.contains($0.id) }
        guard !selected.isEmpty else { return }

        // Separator: "blank lines" = antall tomme linjer mellom entries.
        // 0 tomme linjer = "\n", 1 = "\n\n", 2 = "\n\n\n", osv.
        let blanks = max(0, clipboardCopyBlankLines)
        let separator = String(repeating: "\n", count: blanks + 1)

        // Grupperer etter groupId slik at entries fra samme gruppe samles,
        // og gruppenavnet legges øverst i CAPS (valgfritt).
        let groupOrder: [UUID?] = {
            var seen = Set<UUID?>()
            var order: [UUID?] = []
            for entry in selected {
                if !seen.contains(entry.groupId) {
                    seen.insert(entry.groupId)
                    order.append(entry.groupId)
                }
            }
            return order
        }()

        var blocks: [String] = []
        for gid in groupOrder {
            let itemsInGroup = selected.filter { $0.groupId == gid }
            let texts = itemsInGroup.map { $0.text }
            let body = texts.joined(separator: separator)

            if clipboardIncludeGroupHeader, let gid = gid,
               let group = clipboardGroups.first(where: { $0.id == gid }) {
                let header = group.name.uppercased()
                blocks.append(header + "\n" + body)
            } else {
                blocks.append(body)
            }
        }

        let combined = blocks.joined(separator: separator)
        copyTextToPasteboard(combined)
        selectedClipboardIds.removeAll()
    }

    func exportSelectedClipboardEntries() {
        let selected = clipboardEntries.filter { selectedClipboardIds.contains($0.id) }
        guard !selected.isEmpty else { return }

        let combined = selected.map { $0.text }.joined(separator: "\n\n")

        let savePanel = NSSavePanel()
        savePanel.title = "Eksporter utklipp"
        savePanel.nameFieldStringValue = "utklipp.txt"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        savePanel.level = .floating

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try combined.write(to: url, atomically: true, encoding: .utf8)
                    self.selectedClipboardIds.removeAll()
                } catch {
                    self.errorMessage = "Kunne ikke lagre filen: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }

    func exportSelectedClipboardEntriesAsCSV() {
        let selected = clipboardEntries.filter { selectedClipboardIds.contains($0.id) }
        guard !selected.isEmpty else { return }

        // Build CSV: header + one row per entry
        var csv = "\"Tekst\",\"Tidspunkt\",\"Festet\"\n"
        let formatter = ISO8601DateFormatter()
        for entry in selected {
            let escaped = entry.text.replacingOccurrences(of: "\"", with: "\"\"")
            let date = formatter.string(from: entry.dateCopied)
            let pinned = entry.isPinned ? "Ja" : "Nei"
            csv += "\"\(escaped)\",\"\(date)\",\"\(pinned)\"\n"
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Eksporter utklipp som CSV"
        savePanel.nameFieldStringValue = "utklipp.csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.canCreateDirectories = true
        savePanel.level = .floating

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                    self.selectedClipboardIds.removeAll()
                } catch {
                    self.errorMessage = "Kunne ikke lagre filen: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }

    func selectAllClipboardEntries() {
        selectedClipboardIds = Set(clipboardEntries.map { $0.id })
    }

    func deselectAllClipboardEntries() {
        selectedClipboardIds.removeAll()
    }

    // MARK: - Clipboard Groups

    @discardableResult
    func createClipboardGroup(name: String) -> ClipboardGroup {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Ny gruppe" : trimmed
        let nextIndex = (clipboardGroups.map { $0.sortIndex }.max() ?? -1) + 1
        let group = ClipboardGroup(name: finalName, sortIndex: nextIndex)
        clipboardGroups.append(group)
        expandedClipboardGroupIds.insert(group.id)
        scheduleSave()
        return group
    }

    func renameClipboardGroup(id: UUID, name: String) {
        guard let idx = clipboardGroups.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        clipboardGroups[idx].name = trimmed
        scheduleSave()
    }

    func deleteClipboardGroup(id: UUID) {
        // Items i gruppen blir ungrouped, ikke slettet.
        for i in clipboardEntries.indices {
            if clipboardEntries[i].groupId == id {
                clipboardEntries[i].groupId = nil
            }
        }
        clipboardGroups.removeAll { $0.id == id }
        if activeClipboardGroupId == id {
            activeClipboardGroupId = nil
        }
        expandedClipboardGroupIds.remove(id)
        scheduleSave()
    }

    /// Setter aktiv mål-gruppe. Klikker du samme gruppe igjen, faller du tilbake til
    /// "Ingen gruppe" (nil). For å markere "Ingen gruppe" som aktiv eksplisitt,
    /// kall med `id: nil` direkte fra Ingen gruppe-headeren.
    func setActiveClipboardGroup(_ id: UUID?) {
        activeClipboardGroupId = id
        scheduleSave()
    }

    func moveSelectedClipboardEntries(toGroup groupId: UUID?) {
        guard !selectedClipboardIds.isEmpty else { return }
        for i in clipboardEntries.indices where selectedClipboardIds.contains(clipboardEntries[i].id) {
            clipboardEntries[i].groupId = groupId
        }
        selectedClipboardIds.removeAll()
        scheduleSave()
    }

    func toggleClipboardGroupExpanded(_ id: UUID?) {
        if expandedClipboardGroupIds.contains(id) {
            expandedClipboardGroupIds.remove(id)
        } else {
            expandedClipboardGroupIds.insert(id)
        }
    }

    func isClipboardGroupExpanded(_ id: UUID?) -> Bool {
        expandedClipboardGroupIds.contains(id)
    }

    // MARK: - CSV Column Builder

    func startCSVColumnBuilder() {
        csvColumnBuilder = CSVColumnBuilderState(columns: [[]], currentColumnIndex: 0)
    }

    func cancelCSVColumnBuilder() {
        csvColumnBuilder = nil
    }

    func appendSelectedToCurrentCSVColumn() {
        guard var builder = csvColumnBuilder else { return }
        let selected = clipboardEntries.filter { selectedClipboardIds.contains($0.id) }
        guard !selected.isEmpty else { return }

        // Bevar rekkefølgen items vises i (ikke i valg-rekkefølge)
        let orderedTexts = selected.map { $0.text }
        builder.columns[builder.currentColumnIndex].append(contentsOf: orderedTexts)
        csvColumnBuilder = builder
        selectedClipboardIds.removeAll()
    }

    func startNextCSVColumn() {
        guard var builder = csvColumnBuilder else { return }
        // Bare gå videre hvis gjeldende kolonne har innhold
        guard !builder.columns[builder.currentColumnIndex].isEmpty else { return }
        builder.columns.append([])
        builder.currentColumnIndex = builder.columns.count - 1
        csvColumnBuilder = builder
    }

    func finishCSVColumnBuilderAndExport() {
        guard let builder = csvColumnBuilder else { return }
        let nonEmptyColumns = builder.columns.filter { !$0.isEmpty }
        guard !nonEmptyColumns.isEmpty else {
            csvColumnBuilder = nil
            return
        }

        let rowCount = nonEmptyColumns.map { $0.count }.max() ?? 0

        func escape(_ field: String) -> String {
            if field.contains(",") || field.contains("\"") || field.contains("\n") {
                return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return field
        }

        // Header: Kolonne A, Kolonne B, ...
        let headers = (0..<nonEmptyColumns.count).map { columnLetter(for: $0) }
        var csv = headers.map { "Kolonne \($0)" }.map(escape).joined(separator: ",") + "\n"

        for row in 0..<rowCount {
            let cells = nonEmptyColumns.map { col -> String in
                row < col.count ? col[row] : ""
            }
            csv += cells.map(escape).joined(separator: ",") + "\n"
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Eksporter CSV med kolonner"
        savePanel.nameFieldStringValue = "utklipp-kolonner.csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.canCreateDirectories = true
        savePanel.level = .floating

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                    Task { @MainActor in
                        self.csvColumnBuilder = nil
                    }
                } catch {
                    Task { @MainActor in
                        self.errorMessage = "Kunne ikke lagre filen: \(error.localizedDescription)"
                        self.showError = true
                    }
                }
            }
        }
    }

    func columnLetter(for index: Int) -> String {
        // 0 -> A, 25 -> Z, 26 -> AA, ...
        var n = index
        var result = ""
        repeat {
            let rem = n % 26
            result = String(UnicodeScalar(65 + rem)!) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }

    // MARK: - Quick Notes

    @discardableResult
    func createQuickNote() -> QuickNote {
        let note = QuickNote()
        quickNotes.insert(note, at: 0)
        lastOpenedQuickNoteId = note.id
        scheduleSave()
        return note
    }

    func deleteQuickNote(id: UUID) {
        quickNotes.removeAll { $0.id == id }
        if lastOpenedQuickNoteId == id {
            lastOpenedQuickNoteId = quickNotes.first?.id
        }
        scheduleSave()
    }

    func updateQuickNote(id: UUID, title: String? = nil, body: String? = nil) {
        guard let idx = quickNotes.firstIndex(where: { $0.id == id }) else { return }
        if let title = title { quickNotes[idx].title = title }
        if let body = body { quickNotes[idx].body = body }
        quickNotes[idx].updatedAt = Date()
        scheduleSave()
    }

    func copyQuickNote(id: UUID) {
        guard let note = quickNotes.first(where: { $0.id == id }) else { return }
        let combined: String
        let t = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            combined = note.body
        } else {
            combined = t + "\n\n" + note.body
        }
        copyTextToPasteboard(combined)
    }

    // MARK: - Context Bundles

    var activeContextBundle: ContextBundle? {
        guard let id = activeContextBundleId else { return nil }
        return contextBundles.first(where: { $0.id == id })
    }

    @discardableResult
    func createContextBundle(name: String) -> ContextBundle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Ny bundle" : trimmed
        let nextIndex = (contextBundles.map { $0.sortIndex }.max() ?? -1) + 1
        let bundle = ContextBundle(name: finalName, sortIndex: nextIndex)
        contextBundles.append(bundle)
        activeContextBundleId = bundle.id
        scheduleSave()
        return bundle
    }

    func renameContextBundle(id: UUID, name: String) {
        guard let idx = contextBundles.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        contextBundles[idx].name = trimmed
        scheduleSave()
    }

    func deleteContextBundle(id: UUID) {
        contextBundles.removeAll { $0.id == id }
        if activeContextBundleId == id {
            activeContextBundleId = contextBundles.first?.id
        }
        scheduleSave()
    }

    func setActiveContextBundle(_ id: UUID?) {
        activeContextBundleId = id
        scheduleSave()
    }

    func addFileToBundle(bundleId: UUID, stashItemId: UUID) {
        guard let idx = contextBundles.firstIndex(where: { $0.id == bundleId }) else { return }
        // Unngå duplikat — samme stashItemId i samme bundle ignoreres
        let alreadyIn = contextBundles[idx].items.contains { item in
            if case .file(_, let sid) = item, sid == stashItemId { return true }
            return false
        }
        if alreadyIn { return }
        contextBundles[idx].items.append(.file(id: UUID(), stashItemId: stashItemId))
        scheduleSave()
    }

    @discardableResult
    func addTextToBundle(bundleId: UUID, title: String = "", body: String = "") -> UUID? {
        guard let idx = contextBundles.firstIndex(where: { $0.id == bundleId }) else { return nil }
        let newId = UUID()
        contextBundles[idx].items.append(.text(id: newId, title: title, body: body))
        scheduleSave()
        return newId
    }

    func updateBundleTextItem(bundleId: UUID, itemId: UUID, title: String? = nil, body: String? = nil) {
        guard let bIdx = contextBundles.firstIndex(where: { $0.id == bundleId }) else { return }
        guard let iIdx = contextBundles[bIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        if case .text(let id, let oldTitle, let oldBody) = contextBundles[bIdx].items[iIdx] {
            contextBundles[bIdx].items[iIdx] = .text(
                id: id,
                title: title ?? oldTitle,
                body: body ?? oldBody
            )
            scheduleSave()
        }
    }

    func removeBundleItem(bundleId: UUID, itemId: UUID) {
        guard let idx = contextBundles.firstIndex(where: { $0.id == bundleId }) else { return }
        contextBundles[idx].items.removeAll { $0.id == itemId }
        scheduleSave()
    }

    /// Resolver alle .file-items i bundlen til faktiske URLs på disk.
    /// Hopper over items hvor StashItem ikke lenger finnes (slettet etter at det ble lagt til).
    func bundleFileURLs(bundleId: UUID) -> [URL] {
        guard let bundle = contextBundles.first(where: { $0.id == bundleId }) else { return [] }
        var urls: [URL] = []
        for item in bundle.items {
            if case .file(_, let sid) = item,
               let stashItem = items.first(where: { $0.id == sid }) {
                urls.append(stashItem.stagedURL)
            }
        }
        return urls
    }

    /// Bygger en strukturert tekstdump av bundlen, klar til å limes inn i en chat.
    func bundleAsCombinedText(bundleId: UUID) -> String {
        guard let bundle = contextBundles.first(where: { $0.id == bundleId }) else { return "" }

        var sections: [String] = []
        sections.append("## \(bundle.name.uppercased())")

        let textItems: [(String, String)] = bundle.items.compactMap { item in
            if case .text(_, let title, let body) = item {
                return (title, body)
            }
            return nil
        }
        if !textItems.isEmpty {
            var snippetBlock = "### Snippets\n"
            for (title, body) in textItems {
                let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty {
                    snippetBlock += "\n**\(t)**\n\(body)\n"
                } else {
                    snippetBlock += "\n\(body)\n"
                }
            }
            sections.append(snippetBlock)
        }

        let fileNames: [String] = bundle.items.compactMap { item in
            if case .file(_, let sid) = item,
               let stashItem = items.first(where: { $0.id == sid }) {
                return stashItem.fileName
            }
            return nil
        }
        if !fileNames.isEmpty {
            var fileBlock = "### Vedlagte filer\n"
            for name in fileNames {
                fileBlock += "- \(name)\n"
            }
            sections.append(fileBlock)
        }

        return sections.joined(separator: "\n\n")
    }

    func copyBundleAsText(bundleId: UUID) {
        let text = bundleAsCombinedText(bundleId: bundleId)
        guard !text.isEmpty else { return }
        copyTextToPasteboard(text)
        // copyTextToPasteboard viser allerede "Kopiert!"-toast.
        // Overstyr med en mer spesifikk melding:
        if let bundle = contextBundles.first(where: { $0.id == bundleId }) {
            showToast("\(bundle.name) kopiert!")
        }
    }

    // MARK: - Sheets Collector

    func toggleSheetsCollector() {
        sheetsCollectorEnabled.toggle()
        if !sheetsCollectorEnabled {
            clearSheetsData()
        }
    }

    func setSheetsColumnCount(_ count: Int) {
        let clamped = max(2, min(4, count))
        sheetsColumnCount = clamped
        if sheetsPasteColumn >= clamped { sheetsPasteColumn = 0 }

        for i in sheetsGrid.indices {
            if sheetsGrid[i].count < clamped {
                sheetsGrid[i].append(contentsOf: Array(repeating: "", count: clamped - sheetsGrid[i].count))
            } else if sheetsGrid[i].count > clamped {
                sheetsGrid[i] = Array(sheetsGrid[i].prefix(clamped))
            }
        }
        if sheetsGrid.isEmpty || !sheetsGridLastRowEmpty() {
            sheetsGrid.append(Array(repeating: "", count: clamped))
        }
    }

    private func addToSheetsCollector(_ text: String) {
        guard sheetsAutoPaste else { return }

        let targetRow = sheetsGridNextEmptyRow(in: sheetsPasteColumn)
        sheetsGrid[targetRow][sheetsPasteColumn] = text

        ensureEmptyLastRow()
    }

    private func sheetsGridNextEmptyRow(in col: Int) -> Int {
        for i in 0..<sheetsGrid.count {
            if sheetsGrid[i][col].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return i
            }
        }
        let newRow = Array(repeating: "", count: sheetsColumnCount)
        sheetsGrid.append(newRow)
        return sheetsGrid.count - 1
    }

    func ensureEmptyLastRow() {
        if sheetsGrid.isEmpty || !sheetsGridLastRowEmpty() {
            sheetsGrid.append(Array(repeating: "", count: sheetsColumnCount))
        }
    }

    private func sheetsGridLastRowEmpty() -> Bool {
        guard let last = sheetsGrid.last else { return false }
        return last.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func removeSheetsRow(at index: Int) {
        guard index >= 0 && index < sheetsGrid.count else { return }
        sheetsGrid.remove(at: index)
        if sheetsGrid.isEmpty {
            sheetsGrid.append(Array(repeating: "", count: sheetsColumnCount))
        }
    }

    func clearSheetsData() {
        sheetsGrid = [Array(repeating: "", count: sheetsColumnCount)]
    }

    func toggleSheetsPasteColumn() {
        sheetsPasteColumn = (sheetsPasteColumn + 1) % sheetsColumnCount
    }

    private var sheetsFilledRows: [[String]] {
        sheetsGrid.filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    func copySheetsToClipboard() {
        let allRows = sheetsFilledRows
        guard !allRows.isEmpty else { return }
        let tsv = allRows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
        copyTextToPasteboard(tsv)
    }

    func exportSheetsAsCSV() {
        let allRows = sheetsFilledRows
        guard !allRows.isEmpty else { return }

        func csvEscape(_ field: String) -> String {
            if field.contains(",") || field.contains("\"") || field.contains("\n") {
                return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return field
        }

        let csv = allRows.map { row in
            row.map { csvEscape($0) }.joined(separator: ",")
        }.joined(separator: "\n")

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "tabell-eksport.csv"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                errorMessage = "Kunne ikke lagre CSV: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    var sheetsRowCount: Int {
        sheetsFilledRows.count
    }

    var sheetsTotalEntries: Int {
        sheetsFilledRows.reduce(0) { total, row in
            total + row.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        }
    }

    func showToast(_ message: String, duration: TimeInterval = 1.4) {
        toastMessage = message
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.toastMessage = nil
            }
        }
    }

    private func copyTextToPasteboard(_ text: String) {
        // Temporarily stop watching so we don't re-capture our own paste
        let wasWatching = clipboardWatchEnabled
        if wasWatching { clipboardWatcher.stopWatching() }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        showToast("Kopiert!")

        // Resume after a short delay
        if wasWatching {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startClipboardWatch()
            }
        }

        // Auto-close panel after copy so the user can paste right away
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.windows
                .first(where: { $0.title == "Ny Mappe (7)" })?
                .orderOut(nil)
        }
    }

    // MARK: - Path Entries

    /// Add a file/folder URL as a path entry and copy path to clipboard
    func addPathFromURL(_ url: URL) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        let entry = PathEntry(
            path: url.path,
            name: url.lastPathComponent,
            isDirectory: isDir.boolValue
        )

        // Don't add duplicates of the most recent
        if let last = pathEntries.first, last.path == entry.path { return }

        pathEntries.insert(entry, at: 0)

        // Keep max 100 entries
        if pathEntries.count > 100 {
            pathEntries = Array(pathEntries.prefix(100))
        }

        // Copy path to clipboard immediately
        copyPathToPasteboard(entry.path)
        scheduleSave()
    }

    /// Handle dropped URLs on the Path tab: extract paths instead of importing files
    func handlePathDrop(_ urls: [URL]) {
        for url in urls {
            addPathFromURL(url)
        }
    }

    func copyPathEntry(_ entry: PathEntry) {
        copyPathToPasteboard(entry.path)
    }

    func copySelectedPathEntries() {
        let selected = pathEntries.filter { selectedPathIds.contains($0.id) }
        guard !selected.isEmpty else { return }
        let combined = selected.map { $0.path }.joined(separator: "\n")
        copyPathToPasteboard(combined)
        selectedPathIds.removeAll()
    }

    func deletePathEntry(_ entry: PathEntry) {
        pathEntries.removeAll { $0.id == entry.id }
        scheduleSave()
    }

    func togglePinPathEntry(_ entry: PathEntry) {
        if let idx = pathEntries.firstIndex(where: { $0.id == entry.id }) {
            pathEntries[idx].isPinned.toggle()
            scheduleSave()
        }
    }

    func clearPathEntries() {
        pathEntries.removeAll { !$0.isPinned }
        scheduleSave()
    }

    func togglePathSelection(_ entryId: UUID) {
        if selectedPathIds.contains(entryId) {
            selectedPathIds.remove(entryId)
        } else {
            selectedPathIds.insert(entryId)
        }
    }

    func selectAllPathEntries() {
        selectedPathIds = Set(pathEntries.map { $0.id })
    }

    func deselectAllPathEntries() {
        selectedPathIds.removeAll()
    }

    func revealPathInFinder(_ entry: PathEntry) {
        let url = URL(fileURLWithPath: entry.path)
        if entry.isDirectory {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func copyPathToPasteboard(_ text: String) {
        let wasWatching = clipboardWatchEnabled
        if wasWatching { clipboardWatcher.stopWatching() }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        if wasWatching {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startClipboardWatch()
            }
        }
    }

    func importScreenshot(_ url: URL) {
        guard let setId = activeSetId else { return }

        // Skip if this file is already imported (prevent duplicates)
        let fileName = url.lastPathComponent
        if items.contains(where: { $0.fileName == fileName && $0.isScreenshot }) { return }

        let existingItems = items.filter { $0.setId == setId }

        Task {
            let result = await staging.importURLs(
                [url],
                toSet: setId,
                existingItems: existingItems
            ) { _ in }

            // Mark as screenshots
            var screenshotItems = result.items
            for i in screenshotItems.indices {
                screenshotItems[i].isScreenshot = true
            }

            self.items.append(contentsOf: screenshotItems)
            self.scheduleSave()

            // Generate thumbnails
            for item in screenshotItems {
                Task.detached(priority: .utility) {
                    if let thumbPath = await self.thumbnails.generateThumbnail(for: item) {
                        await MainActor.run {
                            if let idx = self.items.firstIndex(where: { $0.id == item.id }) {
                                self.items[idx].thumbnailPath = thumbPath
                                self.scheduleSave()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Auto-Cleanup

    func performAutoCleanup() {
        let now = Date()
        var didCleanup = false

        if let days = autoCleanupFilesDays {
            let cutoff = now.addingTimeInterval(-Double(days) * 86400)
            let expired = items.filter { $0.dateAdded < cutoff }
            if !expired.isEmpty {
                for item in expired { staging.removeItem(item) }
                items.removeAll { $0.dateAdded < cutoff }
                didCleanup = true
            }
        }

        if let days = autoCleanupClipboardDays {
            let cutoff = now.addingTimeInterval(-Double(days) * 86400)
            let before = clipboardEntries.count
            clipboardEntries.removeAll { !$0.isPinned && $0.dateCopied < cutoff }
            if clipboardEntries.count != before { didCleanup = true }
        }

        if let days = autoCleanupPathsDays {
            let cutoff = now.addingTimeInterval(-Double(days) * 86400)
            let before = pathEntries.count
            pathEntries.removeAll { !$0.isPinned && $0.dateAdded < cutoff }
            if pathEntries.count != before { didCleanup = true }
        }

        if didCleanup {
            selectedItemIds.removeAll()
            selectedClipboardIds.removeAll()
            selectedPathIds.removeAll()
            scheduleSave()
        }
    }

    // MARK: - Export File List

    func exportFileListAsText() {
        let toExport = selectedItemIds.isEmpty ? currentItems : selectedItems
        guard !toExport.isEmpty else { return }
        let content = toExport.map { $0.fileName }.joined(separator: "\n")

        let savePanel = NSSavePanel()
        savePanel.title = "Eksporter filliste"
        savePanel.nameFieldStringValue = "filliste.txt"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        savePanel.level = .floating

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func exportFileListAsCSV() {
        let toExport = selectedItemIds.isEmpty ? currentItems : selectedItems
        guard !toExport.isEmpty else { return }
        let fmt = ISO8601DateFormatter()
        var csv = "\"Filnavn\",\"Type\",\"Kategori\",\"St\u{00F8}rrelse\",\"Bytes\",\"Dato\",\"Original sti\"\n"
        for item in toExport {
            let name = item.fileName.replacingOccurrences(of: "\"", with: "\"\"")
            let date = fmt.string(from: item.dateAdded)
            let orig = item.originalURL.path.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(name)\",\".\(item.ext)\",\"\(item.typeCategory.rawValue)\",\"\(item.formattedSize)\",\(item.sizeBytes),\"\(date)\",\"\(orig)\"\n"
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Eksporter filliste som CSV"
        savePanel.nameFieldStringValue = "filliste.csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.canCreateDirectories = true
        savePanel.level = .floating

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? csv.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func exportFileListAsJSON() {
        let toExport = selectedItemIds.isEmpty ? currentItems : selectedItems
        guard !toExport.isEmpty else { return }

        struct ExportItem: Codable {
            let fileName: String
            let ext: String
            let typeCategory: String
            let sizeBytes: Int64
            let formattedSize: String
            let dateAdded: Date
            let originalPath: String
            let isScreenshot: Bool
        }

        let exportItems = toExport.map {
            ExportItem(fileName: $0.fileName, ext: $0.ext, typeCategory: $0.typeCategory.rawValue,
                       sizeBytes: $0.sizeBytes, formattedSize: $0.formattedSize,
                       dateAdded: $0.dateAdded, originalPath: $0.originalURL.path,
                       isScreenshot: $0.isScreenshot)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(exportItems),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        let savePanel = NSSavePanel()
        savePanel.title = "Eksporter filliste som JSON"
        savePanel.nameFieldStringValue = "filliste.json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        savePanel.level = .floating

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? jsonString.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Export as Zip

    func exportAsZip() {
        let itemsToZip = selectedItemIds.isEmpty ? currentItems : selectedItems
        guard !itemsToZip.isEmpty else { return }
        let setName = activeSet?.name ?? "export"

        Task {
            do {
                let zipURL = try await staging.zipItems(itemsToZip, setName: setName)

                let savePanel = NSSavePanel()
                savePanel.title = "Eksporter som .zip"
                savePanel.nameFieldStringValue = zipURL.lastPathComponent
                savePanel.allowedContentTypes = [.zip]
                savePanel.canCreateDirectories = true
                savePanel.level = .floating

                savePanel.begin { response in
                    if response == .OK, let destURL = savePanel.url {
                        do {
                            if FileManager.default.fileExists(atPath: destURL.path) {
                                try FileManager.default.removeItem(at: destURL)
                            }
                            try FileManager.default.copyItem(at: zipURL, to: destURL)
                            try? FileManager.default.removeItem(at: zipURL)
                        } catch {
                            self.errorMessage = "Kunne ikke lagre zip: \(error.localizedDescription)"
                            self.showError = true
                        }
                    } else {
                        try? FileManager.default.removeItem(at: zipURL)
                    }
                }
            } catch {
                self.errorMessage = "Zip feilet: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }

    // MARK: - Batch Rename

    func batchRename(_ renames: [(id: UUID, newName: String)]) {
        let fm = FileManager.default

        for (id, newName) in renames {
            guard let idx = items.firstIndex(where: { $0.id == id }) else { continue }
            let item = items[idx]
            let oldURL = item.stagedURL
            let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newName)
            guard oldURL != newURL else { continue }

            do {
                try fm.moveItem(at: oldURL, to: newURL)
                let newExt = newURL.pathExtension
                let newCategory = TypeCategory.from(extension: newExt)
                items[idx] = StashItem(
                    id: item.id, setId: item.setId, originalURL: item.originalURL,
                    stagedURL: newURL, fileName: newName, ext: newExt,
                    typeCategory: newCategory, sizeBytes: item.sizeBytes,
                    dateAdded: item.dateAdded, thumbnailPath: item.thumbnailPath,
                    isScreenshot: item.isScreenshot
                )
            } catch {
                errorMessage = "Kunne ikke gi nytt navn til \(item.fileName): \(error.localizedDescription)"
                showError = true
            }
        }

        scheduleSave()
    }

    // MARK: - Drag Reorder

    func reorderItem(fromId: UUID, toId: UUID) {
        guard sortOption == .manual else { return }
        var ordered = currentItems
        guard let fromIndex = ordered.firstIndex(where: { $0.id == fromId }),
              let toIndex = ordered.firstIndex(where: { $0.id == toId }) else { return }

        let moved = ordered.remove(at: fromIndex)
        ordered.insert(moved, at: toIndex)

        for (index, item) in ordered.enumerated() {
            if let mainIdx = items.firstIndex(where: { $0.id == item.id }) {
                items[mainIdx].sortIndex = index
            }
        }
        scheduleSave()
    }

    func initializeManualSort() {
        let ordered = currentItems
        for (index, item) in ordered.enumerated() {
            if let mainIdx = items.firstIndex(where: { $0.id == item.id }) {
                items[mainIdx].sortIndex = index
            }
        }
        scheduleSave()
    }
}

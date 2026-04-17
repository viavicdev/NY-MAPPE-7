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

    // Prompt-bank
    @Published var promptCategories: [PromptCategory] = []
    @Published var activePromptCategoryId: UUID?

    // Visnings-preferanser per fane
    @Published var filesViewMode: ViewMode = .grid
    @Published var filesViewSize: Double = 0.5
    @Published var clipboardViewMode: ViewMode = .grid
    @Published var clipboardViewSize: Double = 0.5
    @Published var pathsViewMode: ViewMode = .list
    @Published var pathsViewSize: Double = 0.5
    @Published var screenshotsViewMode: ViewMode = .grid
    @Published var screenshotsViewSize: Double = 0.5
    @Published var bundlesViewMode: ViewMode = .grid
    @Published var bundlesViewSize: Double = 0.5

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
    @Published var finderShortcuts: [FinderShortcut] = []
    @Published var lastSelectedPathId: UUID?
    @Published var lastSelectedClipboardId: UUID?
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
        case kontekst
    }

    enum FilesSubTab {
        case files
        case screenshots
    }

    enum ToolsSubTab {
        case paths
        case sheets
        case shortcuts
    }

    enum KontekstSubTab {
        case bundles
        case prompts
    }

    @Published var activeFilesTab: FilesSubTab = .files
    @Published var activeToolsTab: ToolsSubTab = .paths
    @Published var activeKontekstTab: KontekstSubTab = .bundles

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
            switch activeFilesTab {
            case .files:
                filtered = filtered.filter { !$0.isScreenshot }
            case .screenshots:
                filtered = filtered.filter { $0.isScreenshot }
            }
        case .clipboard:
            return []
        case .tools:
            switch activeToolsTab {
            case .paths, .sheets, .shortcuts:
                return []
            }
        case .kontekst:
            return []
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
        pathCount + sheetsRowCount + finderShortcuts.count
    }

    var kontekstCount: Int {
        contextBundles.count + promptCategories.count
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
            self.promptCategories = state.promptCategories
            self.activePromptCategoryId = state.activePromptCategoryId
            self.finderShortcuts = state.finderShortcuts
            self.filesViewMode = state.filesViewMode
            self.filesViewSize = state.filesViewSize
            self.clipboardViewMode = state.clipboardViewMode
            self.clipboardViewSize = state.clipboardViewSize
            self.pathsViewMode = state.pathsViewMode
            self.pathsViewSize = state.pathsViewSize
            self.screenshotsViewMode = state.screenshotsViewMode
            self.screenshotsViewSize = state.screenshotsViewSize
            self.bundlesViewMode = state.bundlesViewMode
            self.bundlesViewSize = state.bundlesViewSize
            // Alle eksisterende grupper starter ekspandert, samt "Ingen gruppe" (nil).
            self.expandedClipboardGroupIds = Set([nil] + state.clipboardGroups.map { Optional($0.id) })

            // Validate staged files still exist
            self.items = staging.validateItems(self.items)
        }

        performAutoCleanup()
        migrateLegacyBundleFiles()
        seedDefaultPromptCategoriesIfNeeded()

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
                activeContextBundleId: self.activeContextBundleId,
                promptCategories: self.promptCategories,
                activePromptCategoryId: self.activePromptCategoryId,
                finderShortcuts: self.finderShortcuts,
                filesViewMode: self.filesViewMode,
                filesViewSize: self.filesViewSize,
                clipboardViewMode: self.clipboardViewMode,
                clipboardViewSize: self.clipboardViewSize,
                pathsViewMode: self.pathsViewMode,
                pathsViewSize: self.pathsViewSize,
                screenshotsViewMode: self.screenshotsViewMode,
                screenshotsViewSize: self.screenshotsViewSize,
                bundlesViewMode: self.bundlesViewMode,
                bundlesViewSize: self.bundlesViewSize
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

    /// T\u{00F8}mmer alle ikke-festede items i en gruppe. For nil = "Usortert".
    /// Selve gruppa beholdes. Festede items p\u{00E5}virkes aldri.
    func clearClipboardGroup(id: UUID?) {
        let knownGroupIds = Set(clipboardGroups.map { $0.id })
        let idsToRemove: Set<UUID> = Set(clipboardEntries.compactMap { entry in
            guard !entry.isPinned else { return nil }
            if let gid = id {
                return entry.groupId == gid ? entry.id : nil
            } else {
                // Usortert: ingen gruppe eller orphaned groupId
                guard let g = entry.groupId else { return entry.id }
                return knownGroupIds.contains(g) ? nil : entry.id
            }
        })
        guard !idsToRemove.isEmpty else { return }
        clipboardEntries.removeAll { idsToRemove.contains($0.id) }
        selectedClipboardIds.subtract(idsToRemove)
        scheduleSave()
    }

    func toggleClipboardSelection(_ entryId: UUID) {
        if selectedClipboardIds.contains(entryId) {
            selectedClipboardIds.remove(entryId)
        } else {
            selectedClipboardIds.insert(entryId)
        }
        lastSelectedClipboardId = entryId
    }

    /// Velger alle entries fra lastSelectedClipboardId til `id` i synlig rekkefølge.
    /// View-laget eier rekkefølgen (pga grupper) og sender den inn via orderedIds.
    func selectRangeInClipboard(to id: UUID, orderedIds: [UUID]) {
        guard let anchor = lastSelectedClipboardId,
              let fromIdx = orderedIds.firstIndex(of: anchor),
              let toIdx = orderedIds.firstIndex(of: id) else {
            selectedClipboardIds.insert(id)
            lastSelectedClipboardId = id
            return
        }
        let range = orderedIds[min(fromIdx, toIdx)...max(fromIdx, toIdx)]
        selectedClipboardIds.formUnion(range)
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

    /// Kopierer alle ikke-festede items i en gruppe som \u{00E9}n tekstblokk.
    /// id == nil betyr "Usortert" (entries uten groupId, eller groupId som peker til slettet gruppe).
    func copyClipboardGroup(id: UUID?) {
        let knownGroupIds = Set(clipboardGroups.map { $0.id })
        let entries: [ClipboardEntry]
        if let gid = id {
            entries = clipboardEntries.filter { !$0.isPinned && $0.groupId == gid }
        } else {
            entries = clipboardEntries.filter { entry in
                guard !entry.isPinned else { return false }
                guard let g = entry.groupId else { return true }
                return !knownGroupIds.contains(g)
            }
        }
        guard !entries.isEmpty else { return }

        // Respekter samme separator og header-setting som enkelt-kopier
        let blanks = max(0, clipboardCopyBlankLines)
        let separator = String(repeating: "\n", count: blanks + 1)
        let body = entries.map { $0.text }.joined(separator: separator)

        let combined: String
        if clipboardIncludeGroupHeader, let gid = id,
           let group = clipboardGroups.first(where: { $0.id == gid }) {
            combined = group.name.uppercased() + "\n" + body
        } else {
            combined = body
        }
        copyTextToPasteboard(combined)
        // copyTextToPasteboard setter "Kopiert!"-toast; overstyr med gruppenavnet
        if let gid = id, let group = clipboardGroups.first(where: { $0.id == gid }) {
            showToast("\(group.name) kopiert!")
        } else {
            showToast("Usortert kopiert!")
        }
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
    func createContextBundle(name: String, iconName: String? = nil) -> ContextBundle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Ny bundle" : trimmed
        let nextIndex = (contextBundles.map { $0.sortIndex }.max() ?? -1) + 1
        let bundle = ContextBundle(name: finalName, sortIndex: nextIndex, iconName: iconName)
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
        // Fjern bundlens egne filer fra disk
        persistence.removeBundleStorage(for: id)
        scheduleSave()
    }

    func setActiveContextBundle(_ id: UUID?) {
        activeContextBundleId = id
        scheduleSave()
    }

    /// Eksponer bundle-lagringsstien for views som trenger \u{00E5} dra enkelt-filer.
    func persistenceBundleStorageURL(for bundleId: UUID) -> URL {
        persistence.bundleStorageURL(for: bundleId)
    }

    /// Kopierer fila fra sourceURL inn i bundlens egen lagring. Bundlen blir
    /// selvstendig \u{2014} sletting i Filer-fanen p\u{00E5}virker ikke bundles.
    @discardableResult
    func addLocalFileToBundle(bundleId: UUID, sourceURL: URL) -> UUID? {
        guard let idx = contextBundles.firstIndex(where: { $0.id == bundleId }) else { return nil }
        let dir = persistence.bundleStorageURL(for: bundleId)
        let originalName = sourceURL.lastPathComponent

        // H\u{00E5}ndter navne-kollisjoner: brief.pdf \u{2192} brief-1.pdf \u{2192} brief-2.pdf
        let finalName = uniqueFilename(in: dir, for: originalName)
        let destURL = dir.appendingPathComponent(finalName)

        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: sourceURL, to: destURL)
        } catch {
            errorMessage = "Kunne ikke kopiere \(originalName) til bundle: \(error.localizedDescription)"
            showError = true
            return nil
        }

        let size = (try? fm.attributesOfItem(atPath: destURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        let newId = UUID()
        contextBundles[idx].items.append(.localFile(
            id: newId,
            fileName: finalName,
            sizeBytes: size,
            dateAdded: Date()
        ))
        scheduleSave()
        return newId
    }

    /// Genererer et unikt filnavn ved \u{00E5} legge til -1, -2 osv. dersom kollisjon.
    private func uniqueFilename(in dir: URL, for name: String) -> String {
        let fm = FileManager.default
        let url = dir.appendingPathComponent(name)
        if !fm.fileExists(atPath: url.path) { return name }

        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        var i = 1
        while true {
            let candidate = ext.isEmpty ? "\(stem)-\(i)" : "\(stem)-\(i).\(ext)"
            if !fm.fileExists(atPath: dir.appendingPathComponent(candidate).path) {
                return candidate
            }
            i += 1
        }
    }

    /// Deprecated: Legacy API for kompatibilitet. Ny kode skal bruke addLocalFileToBundle.
    func addFileToBundle(bundleId: UUID, stashItemId: UUID) {
        guard let stashItem = items.first(where: { $0.id == stashItemId }) else { return }
        addLocalFileToBundle(bundleId: bundleId, sourceURL: stashItem.stagedURL)
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
        // Hvis det er en lokal fil, slett ogs\u{00E5} fila fra bundle-lagringen
        if let item = contextBundles[idx].items.first(where: { $0.id == itemId }) {
            if case .localFile(_, let fileName, _, _) = item {
                let fileURL = persistence.bundleStorageURL(for: bundleId)
                    .appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        contextBundles[idx].items.removeAll { $0.id == itemId }
        scheduleSave()
    }

    /// Returnerer URLs til filene i bundlen. For .localFile peker til bundle-lagringen.
    /// Legacy .file-items (referanser til StashItem) skal ha blitt migrert til .localFile
    /// ved loadState; om noen har overlevd migreringen, skippes de her.
    func bundleFileURLs(bundleId: UUID) -> [URL] {
        guard let bundle = contextBundles.first(where: { $0.id == bundleId }) else { return [] }
        let storageDir = persistence.bundleStorageURL(for: bundleId)
        var urls: [URL] = []
        for item in bundle.items {
            switch item {
            case .localFile(_, let fileName, _, _):
                let url = storageDir.appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: url.path) {
                    urls.append(url)
                }
            case .file(_, let sid):
                // Legacy-fallback: kun hvis migrering ikke klarte \u{00E5} flytte den
                if let stashItem = items.first(where: { $0.id == sid }) {
                    urls.append(stashItem.stagedURL)
                }
            case .text:
                continue
            }
        }
        return urls
    }

    /// Bygger en strukturert tekstdump av bundlen, klar til \u{00E5} limes inn i en chat.
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

        var fileNames: [String] = []
        for item in bundle.items {
            switch item {
            case .localFile(_, let fileName, _, _):
                fileNames.append(fileName)
            case .file(_, let sid):
                if let stashItem = items.first(where: { $0.id == sid }) {
                    fileNames.append(stashItem.fileName)
                }
            case .text:
                continue
            }
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

    // MARK: - Prompts

    /// Seeder standard prompt-kategorier. Legger til manglende defaults uten
    /// \u{00E5} r\u{00F8}re eksisterende kategorier brukeren har endret.
    func seedDefaultPromptCategoriesIfNeeded() {
        struct DefaultCategory {
            let name: String
            let icon: String?
            let prompts: [(String, String)] // (tittel, body)
        }

        let defaults: [DefaultCategory] = [
            DefaultCategory(name: "Mest brukt", icon: "prompt-mest-brukt", prompts: [
                ("Skriv om profesjonelt", "Skriv om f\u{00F8}lgende tekst med en profesjonell og tydelig tone. Behold meningsinnholdet.\n\n[lim inn tekst]"),
                ("Forkort", "Forkort denne teksten til maks 3 setninger uten \u{00E5} miste hovedpoenget.\n\n[lim inn tekst]"),
                ("Oppsummer i punkter", "Oppsummer f\u{00F8}lgende i 3\u{2013}5 korte punkter:\n\n[lim inn tekst]"),
                ("Oversett til engelsk", "Oversett f\u{00F8}lgende til naturlig engelsk. Behold tonen.\n\n[lim inn tekst]"),
                ("Oversett til norsk", "Oversett f\u{00F8}lgende til naturlig norsk (bokm\u{00E5}l). Ikke v\u{00E6}r for formell.\n\n[lim inn tekst]"),
                ("Gi feedback", "Gi meg ærlig og konstruktiv feedback p\u{00E5} f\u{00F8}lgende. Vær konkret og forsl\u{00E5} forbedringer.\n\n[lim inn tekst]"),
            ]),
            DefaultCategory(name: "Kode", icon: nil, prompts: [
                ("Forklar koden", "Forklar hva denne koden gj\u{00F8}r, steg for steg. Bruk enkelt spr\u{00E5}k.\n\n```\n[lim inn kode]\n```"),
                ("Finn bugs", "Se over denne koden og identifiser potensielle bugs, edge-cases eller forbedringer.\n\n```\n[lim inn kode]\n```"),
                ("Skriv tester", "Skriv enhetstester for f\u{00F8}lgende kode. Dekk happy-path og edge-cases.\n\n```\n[lim inn kode]\n```"),
                ("Refaktorer", "Refaktorer denne koden for bedre lesbarhet og vedlikeholdbarhet uten \u{00E5} endre funksjonaliteten.\n\n```\n[lim inn kode]\n```"),
                ("Konverter", "Konverter denne koden fra [spr\u{00E5}k A] til [spr\u{00E5}k B]. Behold logikken.\n\n```\n[lim inn kode]\n```"),
            ]),
            DefaultCategory(name: "Musikk", icon: "prompt-musikk", prompts: []),
            DefaultCategory(name: "Regler", icon: "prompt-regler", prompts: []),
            DefaultCategory(name: "Skriving", icon: "prompt-skriving", prompts: []),
        ]

        let existingNames = Set(promptCategories.map { $0.name.lowercased() })
        var added = false
        let nextIndex = (promptCategories.map { $0.sortIndex }.max() ?? -1) + 1

        for (offset, def) in defaults.enumerated() {
            guard !existingNames.contains(def.name.lowercased()) else { continue }
            var cat = PromptCategory(
                name: def.name,
                iconName: def.icon,
                sortIndex: nextIndex + offset
            )
            for (title, body) in def.prompts {
                cat.prompts.append(Prompt(title: title, body: body))
            }
            promptCategories.append(cat)
            added = true
        }

        if added {
            if activePromptCategoryId == nil {
                activePromptCategoryId = promptCategories.first?.id
            }
            scheduleSave()
        }
    }

    /// Genererer drabare URLs for alle prompts i en kategori:
    /// - Tekst-prompts \u{2192} midlertidige .md-filer
    /// - Fil-prompts \u{2192} lagrede filer fra prompt-storage
    func promptCategoryDragURLs(categoryId: UUID) -> [URL] {
        guard let cat = promptCategories.first(where: { $0.id == categoryId }) else { return [] }
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("PromptExport", isDirectory: true)
            .appendingPathComponent(categoryId.uuidString, isDirectory: true)
        try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var urls: [URL] = []

        for prompt in cat.prompts {
            if let fileName = prompt.fileName {
                // Fil-prompt \u{2014} bruk den lagrede fila direkte
                let fileURL = persistence.promptStorageURL(for: categoryId)
                    .appendingPathComponent(fileName)
                if fm.fileExists(atPath: fileURL.path) {
                    urls.append(fileURL)
                }
            } else {
                // Tekst-prompt \u{2014} skriv til midlertidig .md-fil
                let safeName = prompt.displayTitle
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                    .prefix(60)
                let tempFile = tempDir.appendingPathComponent("\(safeName).md")
                let t = prompt.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let content = t.isEmpty ? prompt.body : "# \(t)\n\n\(prompt.body)"
                try? content.write(to: tempFile, atomically: true, encoding: .utf8)
                urls.append(tempFile)
            }
        }

        return urls
    }

    /// Legger til \u{00E9}n enkelt standard-kategori (med prompts) ved navn.
    /// Brukes fra Settings-toggles.
    func seedSinglePromptCategory(name: String) {
        // Ikke legg til duplikat
        guard !promptCategories.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }

        struct DefaultDef {
            let icon: String?
            let prompts: [(String, String)]
        }

        let defs: [String: DefaultDef] = [
            "mest brukt": DefaultDef(icon: "prompt-mest-brukt", prompts: [
                ("Skriv om profesjonelt", "Skriv om f\u{00F8}lgende tekst med en profesjonell og tydelig tone. Behold meningsinnholdet.\n\n[lim inn tekst]"),
                ("Forkort", "Forkort denne teksten til maks 3 setninger uten \u{00E5} miste hovedpoenget.\n\n[lim inn tekst]"),
                ("Oppsummer i punkter", "Oppsummer f\u{00F8}lgende i 3\u{2013}5 korte punkter:\n\n[lim inn tekst]"),
                ("Oversett til engelsk", "Oversett f\u{00F8}lgende til naturlig engelsk. Behold tonen.\n\n[lim inn tekst]"),
                ("Oversett til norsk", "Oversett f\u{00F8}lgende til naturlig norsk (bokm\u{00E5}l). Ikke v\u{00E6}r for formell.\n\n[lim inn tekst]"),
                ("Gi feedback", "Gi meg \u{00E6}rlig og konstruktiv feedback p\u{00E5} f\u{00F8}lgende. V\u{00E6}r konkret og forsl\u{00E5} forbedringer.\n\n[lim inn tekst]"),
            ]),
            "kode": DefaultDef(icon: nil, prompts: [
                ("Forklar koden", "Forklar hva denne koden gj\u{00F8}r, steg for steg. Bruk enkelt spr\u{00E5}k.\n\n```\n[lim inn kode]\n```"),
                ("Finn bugs", "Se over denne koden og identifiser potensielle bugs, edge-cases eller forbedringer.\n\n```\n[lim inn kode]\n```"),
                ("Skriv tester", "Skriv enhetstester for f\u{00F8}lgende kode. Dekk happy-path og edge-cases.\n\n```\n[lim inn kode]\n```"),
                ("Refaktorer", "Refaktorer denne koden for bedre lesbarhet og vedlikeholdbarhet uten \u{00E5} endre funksjonaliteten.\n\n```\n[lim inn kode]\n```"),
                ("Konverter", "Konverter denne koden fra [spr\u{00E5}k A] til [spr\u{00E5}k B]. Behold logikken.\n\n```\n[lim inn kode]\n```"),
            ]),
            "musikk": DefaultDef(icon: "prompt-musikk", prompts: []),
            "regler": DefaultDef(icon: "prompt-regler", prompts: []),
            "skriving": DefaultDef(icon: "prompt-skriving", prompts: []),
        ]

        guard let def = defs[name.lowercased()] else {
            // Ukjent kategori \u{2014} lag tom
            _ = createPromptCategory(name: name)
            return
        }

        let nextIndex = (promptCategories.map { $0.sortIndex }.max() ?? -1) + 1
        var cat = PromptCategory(name: name, iconName: def.icon, sortIndex: nextIndex)
        for (title, body) in def.prompts {
            cat.prompts.append(Prompt(title: title, body: body))
        }
        promptCategories.append(cat)
        scheduleSave()
    }

    var activePromptCategory: PromptCategory? {
        guard let id = activePromptCategoryId else { return nil }
        return promptCategories.first(where: { $0.id == id })
    }

    @discardableResult
    func createPromptCategory(name: String, iconName: String? = nil) -> PromptCategory {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Ny kategori" : trimmed
        let nextIndex = (promptCategories.map { $0.sortIndex }.max() ?? -1) + 1
        let cat = PromptCategory(name: finalName, iconName: iconName, sortIndex: nextIndex)
        promptCategories.append(cat)
        activePromptCategoryId = cat.id
        scheduleSave()
        return cat
    }

    func renamePromptCategory(id: UUID, name: String) {
        guard let idx = promptCategories.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        promptCategories[idx].name = trimmed
        scheduleSave()
    }

    func deletePromptCategory(id: UUID) {
        promptCategories.removeAll { $0.id == id }
        if activePromptCategoryId == id {
            activePromptCategoryId = promptCategories.first?.id
        }
        // Rydd opp filvedlegg p\u{00E5} disk
        persistence.removePromptStorage(for: id)
        scheduleSave()
    }

    /// Eksponer prompt-lagringsstien for views som trenger \u{00E5} dra enkelt-filer.
    func persistencePromptStorageURL(for categoryId: UUID) -> URL {
        persistence.promptStorageURL(for: categoryId)
    }

    func setActivePromptCategory(_ id: UUID?) {
        activePromptCategoryId = id
        scheduleSave()
    }

    @discardableResult
    func addPrompt(categoryId: UUID, title: String = "", body: String = "") -> UUID? {
        guard let idx = promptCategories.firstIndex(where: { $0.id == categoryId }) else { return nil }
        let prompt = Prompt(title: title, body: body)
        promptCategories[idx].prompts.append(prompt)
        scheduleSave()
        return prompt.id
    }

    /// Legger til en fil-basert prompt ved \u{00E5} kopiere sourceURL inn i kategoriens
    /// egen lagring. Returnerer prompt-ID eller nil ved feil.
    @discardableResult
    func addPromptFile(categoryId: UUID, sourceURL: URL) -> UUID? {
        guard let idx = promptCategories.firstIndex(where: { $0.id == categoryId }) else { return nil }
        let dir = persistence.promptStorageURL(for: categoryId)
        let originalName = sourceURL.lastPathComponent
        let finalName = uniqueFilename(in: dir, for: originalName)
        let destURL = dir.appendingPathComponent(finalName)

        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: sourceURL, to: destURL)
        } catch {
            errorMessage = "Kunne ikke kopiere \(originalName) til prompt-kategorien: \(error.localizedDescription)"
            showError = true
            return nil
        }

        let size = (try? fm.attributesOfItem(atPath: destURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        // Bruk filnavn (uten extension) som standardtittel hvis ingen er satt
        let autoTitle = (finalName as NSString).deletingPathExtension
        let prompt = Prompt(
            title: autoTitle,
            body: "",
            fileName: finalName,
            fileSizeBytes: size
        )
        promptCategories[idx].prompts.append(prompt)
        scheduleSave()
        return prompt.id
    }

    func updatePrompt(categoryId: UUID, promptId: UUID, title: String? = nil, body: String? = nil) {
        guard let cIdx = promptCategories.firstIndex(where: { $0.id == categoryId }) else { return }
        guard let pIdx = promptCategories[cIdx].prompts.firstIndex(where: { $0.id == promptId }) else { return }
        if let title = title { promptCategories[cIdx].prompts[pIdx].title = title }
        if let body = body { promptCategories[cIdx].prompts[pIdx].body = body }
        promptCategories[cIdx].prompts[pIdx].updatedAt = Date()
        scheduleSave()
    }

    func deletePrompt(categoryId: UUID, promptId: UUID) {
        guard let cIdx = promptCategories.firstIndex(where: { $0.id == categoryId }) else { return }
        // Hvis prompten har filvedlegg, slett ogs\u{00E5} fila fra disk
        if let prompt = promptCategories[cIdx].prompts.first(where: { $0.id == promptId }),
           let fileName = prompt.fileName {
            let fileURL = persistence.promptStorageURL(for: categoryId)
                .appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        promptCategories[cIdx].prompts.removeAll { $0.id == promptId }
        scheduleSave()
    }

    func copyPrompt(categoryId: UUID, promptId: UUID) {
        guard let cat = promptCategories.first(where: { $0.id == categoryId }),
              let prompt = cat.prompts.first(where: { $0.id == promptId }) else { return }

        // Hvis prompten er filbasert og lesbar som tekst (md/txt), kopier filinnholdet
        if let fileName = prompt.fileName, prompt.isTextFile {
            let fileURL = persistence.promptStorageURL(for: categoryId)
                .appendingPathComponent(fileName)
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                copyTextToPasteboard(content)
                showToast("\(prompt.displayTitle) kopiert!")
                return
            }
            errorMessage = "Kunne ikke lese \(fileName) som tekst"
            showError = true
            return
        }

        // Hvis filbasert men ikke tekst (f.eks. PDF), kan brukeren ikke kopiere innholdet \u{2014}
        // de m\u{00E5} dra fila ut. Vi gir en tydelig beskjed.
        if prompt.fileName != nil {
            showToast("Dra fila ut av appen for \u{00E5} bruke den")
            return
        }

        // Tekst-basert prompt: tittel + body
        let text: String
        let t = prompt.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            text = prompt.body
        } else {
            text = t + "\n\n" + prompt.body
        }
        copyTextToPasteboard(text)
        showToast("\(prompt.displayTitle) kopiert!")
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
        lastSelectedPathId = entryId
    }

    /// Velger alle paths mellom lastSelectedPathId og `id` i synlig rekkef\u{00F8}lge.
    func selectRangeInPaths(to id: UUID) {
        let ids = pathEntries.map { $0.id }
        guard let anchor = lastSelectedPathId,
              let fromIdx = ids.firstIndex(of: anchor),
              let toIdx = ids.firstIndex(of: id) else {
            selectedPathIds.insert(id)
            lastSelectedPathId = id
            return
        }
        let range = ids[min(fromIdx, toIdx)...max(fromIdx, toIdx)]
        selectedPathIds.formUnion(range)
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

    /// Migrerer legacy `.file(id:, stashItemId:)`-items i bundles til `.localFile` ved \u{00E5}
    /// kopiere StashItem-fila inn i bundlens egen mappe. K\u{00F8}res p\u{00E5} hver loadState \u{2014}
    /// er en no-op hvis det ikke finnes legacy-items.
    private func migrateLegacyBundleFiles() {
        var changed = false
        let fm = FileManager.default

        for bIdx in contextBundles.indices {
            let bundleId = contextBundles[bIdx].id
            var newItems: [BundleItem] = []

            for item in contextBundles[bIdx].items {
                guard case .file(_, let stashItemId) = item else {
                    newItems.append(item)
                    continue
                }

                // Legacy-item \u{2014} pr\u{00F8}v \u{00E5} migrere
                guard let stashItem = items.first(where: { $0.id == stashItemId }) else {
                    // Orphan: StashItem finnes ikke lenger, dropper item-et
                    changed = true
                    continue
                }

                let dir = persistence.bundleStorageURL(for: bundleId)
                let finalName = uniqueFilename(in: dir, for: stashItem.fileName)
                let destURL = dir.appendingPathComponent(finalName)

                do {
                    try fm.copyItem(at: stashItem.stagedURL, to: destURL)
                    let size = (try? fm.attributesOfItem(atPath: destURL.path)[.size] as? NSNumber)?.int64Value ?? 0
                    newItems.append(.localFile(
                        id: item.id,
                        fileName: finalName,
                        sizeBytes: size,
                        dateAdded: Date()
                    ))
                    changed = true
                } catch {
                    // Klarte ikke kopiere; behold legacy-referansen som fallback
                    newItems.append(item)
                }
            }

            if changed {
                contextBundles[bIdx].items = newItems
            }
        }

        if changed {
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

    // MARK: - Finder Shortcuts

    var sortedFinderShortcuts: [FinderShortcut] {
        finderShortcuts.sorted { $0.sortIndex < $1.sortIndex }
    }

    @discardableResult
    func addFinderShortcut(path: String, name: String? = nil, emoji: String = "") -> FinderShortcut {
        let url = URL(fileURLWithPath: path)
        let resolvedName = (name?.isEmpty == false ? name : nil) ?? url.lastPathComponent
        let nextIndex = (finderShortcuts.map { $0.sortIndex }.max() ?? -1) + 1
        let shortcut = FinderShortcut(
            name: resolvedName,
            path: path,
            emoji: emoji,
            sortIndex: nextIndex
        )
        finderShortcuts.append(shortcut)
        scheduleSave()
        return shortcut
    }

    func addFinderShortcut(url: URL, emoji: String = "") {
        addFinderShortcut(path: url.path, name: url.lastPathComponent, emoji: emoji)
    }

    func removeFinderShortcut(id: UUID) {
        finderShortcuts.removeAll { $0.id == id }
        scheduleSave()
    }

    func updateFinderShortcut(id: UUID, name: String? = nil, path: String? = nil, emoji: String? = nil) {
        guard let idx = finderShortcuts.firstIndex(where: { $0.id == id }) else { return }
        if let name = name { finderShortcuts[idx].name = name }
        if let path = path { finderShortcuts[idx].path = path }
        if let emoji = emoji { finderShortcuts[idx].emoji = emoji }
        scheduleSave()
    }

    func moveFinderShortcut(id: UUID, to newIndex: Int) {
        guard let fromIdx = finderShortcuts.firstIndex(where: { $0.id == id }) else { return }
        let clamped = max(0, min(newIndex, finderShortcuts.count - 1))
        let item = finderShortcuts.remove(at: fromIdx)
        finderShortcuts.insert(item, at: clamped)
        for (i, _) in finderShortcuts.enumerated() {
            finderShortcuts[i].sortIndex = i
        }
        scheduleSave()
    }

    func openFinderShortcut(_ shortcut: FinderShortcut) {
        let url = shortcut.url
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            showToast("Finner ikke \(shortcut.displayName)", duration: 2.5)
        }
    }

    // MARK: - Custom Icons

    func setContextBundleCustomIcon(id: UUID, sourceURL: URL) {
        guard let idx = contextBundles.firstIndex(where: { $0.id == id }) else { return }
        let old = contextBundles[idx].customIconPath
        if let newPath = persistence.saveCustomIcon(sourceURL: sourceURL, replacing: old) {
            contextBundles[idx].customIconPath = newPath
            scheduleSave()
        } else {
            showToast("Kunne ikke lagre ikonet", duration: 2.5)
        }
    }

    func clearContextBundleCustomIcon(id: UUID) {
        guard let idx = contextBundles.firstIndex(where: { $0.id == id }) else { return }
        if let path = contextBundles[idx].customIconPath {
            persistence.removeCustomIcon(at: path)
        }
        contextBundles[idx].customIconPath = nil
        scheduleSave()
    }

    func setPromptCategoryCustomIcon(id: UUID, sourceURL: URL) {
        guard let idx = promptCategories.firstIndex(where: { $0.id == id }) else { return }
        let old = promptCategories[idx].customIconPath
        if let newPath = persistence.saveCustomIcon(sourceURL: sourceURL, replacing: old) {
            promptCategories[idx].customIconPath = newPath
            scheduleSave()
        } else {
            showToast("Kunne ikke lagre ikonet", duration: 2.5)
        }
    }

    func clearPromptCategoryCustomIcon(id: UUID) {
        guard let idx = promptCategories.firstIndex(where: { $0.id == id }) else { return }
        if let path = promptCategories[idx].customIconPath {
            persistence.removeCustomIcon(at: path)
        }
        promptCategories[idx].customIconPath = nil
        scheduleSave()
    }

    // MARK: - Hide name (icon-only display)

    func toggleContextBundleHideName(id: UUID) {
        guard let idx = contextBundles.firstIndex(where: { $0.id == id }) else { return }
        contextBundles[idx].hideName.toggle()
        scheduleSave()
    }

    func togglePromptCategoryHideName(id: UUID) {
        guard let idx = promptCategories.firstIndex(where: { $0.id == id }) else { return }
        promptCategories[idx].hideName.toggle()
        scheduleSave()
    }

    // MARK: - Reorder (move left/right)

    func moveContextBundle(id: UUID, by offset: Int) {
        var ordered = contextBundles.sorted { $0.sortIndex < $1.sortIndex }
        guard let fromIdx = ordered.firstIndex(where: { $0.id == id }) else { return }
        let toIdx = max(0, min(ordered.count - 1, fromIdx + offset))
        guard toIdx != fromIdx else { return }
        let item = ordered.remove(at: fromIdx)
        ordered.insert(item, at: toIdx)
        for (i, b) in ordered.enumerated() {
            if let mainIdx = contextBundles.firstIndex(where: { $0.id == b.id }) {
                contextBundles[mainIdx].sortIndex = i
            }
        }
        scheduleSave()
    }

    func movePromptCategory(id: UUID, by offset: Int) {
        var ordered = promptCategories.sorted { $0.sortIndex < $1.sortIndex }
        guard let fromIdx = ordered.firstIndex(where: { $0.id == id }) else { return }
        let toIdx = max(0, min(ordered.count - 1, fromIdx + offset))
        guard toIdx != fromIdx else { return }
        let item = ordered.remove(at: fromIdx)
        ordered.insert(item, at: toIdx)
        for (i, c) in ordered.enumerated() {
            if let mainIdx = promptCategories.firstIndex(where: { $0.id == c.id }) {
                promptCategories[mainIdx].sortIndex = i
            }
        }
        scheduleSave()
    }
}

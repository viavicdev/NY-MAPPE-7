import Foundation
import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class StashViewModel: ObservableObject {
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
    @Published var maxClipboardEntries: Int = 0

    // OpenAI
    @Published var openAIKey: String = "" {
        didSet { UserDefaults.standard.set(openAIKey, forKey: "openAIAPIKey") }
    }

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
            case .paths, .sheets:
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

            // Validate staged files still exist
            self.items = staging.validateItems(self.items)
        }

        self.openAIKey = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""

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
                autoCleanupPathsDays: self.autoCleanupPathsDays
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
                self.errorMessage = "Some files failed to import: \(result.errors.joined(separator: "; "))"
                self.showError = true
                // Auto-dismiss after 5 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    self.showError = false
                }
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

        let entry = ClipboardEntry(text: text)
        clipboardEntries.insert(entry, at: 0)

        let limit = maxClipboardEntries > 0 ? maxClipboardEntries : 500
        if clipboardEntries.count > limit {
            clipboardEntries = Array(clipboardEntries.prefix(limit))
        }

        if sheetsCollectorEnabled {
            addToSheetsCollector(text)
        }

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

        let combined = selected.map { $0.text }.joined(separator: "\n\n")
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

        if !openAIKey.isEmpty {
            let preview = allRows.prefix(10).map { $0.joined(separator: " | ") }.joined(separator: "\n")
            suggestFilename(for: preview) { suggested in
                DispatchQueue.main.async {
                    self.showSavePanel(csv: csv, defaultName: suggested ?? "sheets-export")
                }
            }
        } else {
            showSavePanel(csv: csv, defaultName: "sheets-export")
        }
    }

    private func showSavePanel(csv: String, defaultName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = defaultName + ".csv"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func suggestFilename(for content: String, completion: @escaping (String?) -> Void) {
        guard !openAIKey.isEmpty else { completion(nil); return }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8

        let prompt = "Based on this spreadsheet data, suggest a short descriptive filename (2-4 words, lowercase, separated by hyphens, no file extension). Only respond with the filename, nothing else.\n\nData:\n\(content.prefix(500))"

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 20,
            "temperature": 0.3
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let text = message["content"] as? String else {
                completion(nil)
                return
            }

            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: ".csv", with: "")
                .lowercased()
                .filter { $0.isLetter || $0.isNumber || $0 == "-" }

            completion(cleaned.isEmpty ? nil : String(cleaned.prefix(40)))
        }.resume()
    }

    var sheetsRowCount: Int {
        sheetsFilledRows.count
    }

    var sheetsTotalEntries: Int {
        sheetsFilledRows.reduce(0) { total, row in
            total + row.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        }
    }

    private func copyTextToPasteboard(_ text: String) {
        // Temporarily stop watching so we don't re-capture our own paste
        let wasWatching = clipboardWatchEnabled
        if wasWatching { clipboardWatcher.stopWatching() }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

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

    /// Add a file/folder URL as a path entry, copy path to clipboard, and auto-close
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

        // Auto-close panel after copy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.windows
                .first(where: { $0.title == "Ny Mappe (7)" })?
                .orderOut(nil)
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

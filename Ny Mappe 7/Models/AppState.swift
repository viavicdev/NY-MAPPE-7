import Foundation

struct AppState: Codable {
    var sets: [StashSet]
    var items: [StashItem]
    var activeSetId: UUID?
    var alwaysOnTop: Bool
    var sortOption: SortOption
    var filterOption: FilterOption
    var clipboardEntries: [ClipboardEntry]
    var pathEntries: [PathEntry]
    var saveScreenshots: Bool
    var autoCleanupFilesDays: Int?
    var autoCleanupClipboardDays: Int?
    var autoCleanupPathsDays: Int?
    var clipboardGroups: [ClipboardGroup]
    var activeClipboardGroupId: UUID?
    var clipboardNewestOnTop: Bool
    var clipboardCopyBlankLines: Int
    var clipboardIncludeGroupHeader: Bool
    var quickNotes: [QuickNote]
    var lastOpenedQuickNoteId: UUID?
    var contextBundles: [ContextBundle]
    var activeContextBundleId: UUID?

    init(
        sets: [StashSet] = [],
        items: [StashItem] = [],
        activeSetId: UUID? = nil,
        alwaysOnTop: Bool = false,
        sortOption: SortOption = .dateAdded,
        filterOption: FilterOption = .all,
        clipboardEntries: [ClipboardEntry] = [],
        pathEntries: [PathEntry] = [],
        saveScreenshots: Bool = false,
        autoCleanupFilesDays: Int? = nil,
        autoCleanupClipboardDays: Int? = nil,
        autoCleanupPathsDays: Int? = nil,
        clipboardGroups: [ClipboardGroup] = [],
        activeClipboardGroupId: UUID? = nil,
        clipboardNewestOnTop: Bool = true,
        clipboardCopyBlankLines: Int = 1,
        clipboardIncludeGroupHeader: Bool = true,
        quickNotes: [QuickNote] = [],
        lastOpenedQuickNoteId: UUID? = nil,
        contextBundles: [ContextBundle] = [],
        activeContextBundleId: UUID? = nil
    ) {
        self.sets = sets
        self.items = items
        self.activeSetId = activeSetId
        self.alwaysOnTop = alwaysOnTop
        self.sortOption = sortOption
        self.filterOption = filterOption
        self.clipboardEntries = clipboardEntries
        self.pathEntries = pathEntries
        self.saveScreenshots = saveScreenshots
        self.autoCleanupFilesDays = autoCleanupFilesDays
        self.autoCleanupClipboardDays = autoCleanupClipboardDays
        self.autoCleanupPathsDays = autoCleanupPathsDays
        self.clipboardGroups = clipboardGroups
        self.activeClipboardGroupId = activeClipboardGroupId
        self.clipboardNewestOnTop = clipboardNewestOnTop
        self.clipboardCopyBlankLines = clipboardCopyBlankLines
        self.clipboardIncludeGroupHeader = clipboardIncludeGroupHeader
        self.quickNotes = quickNotes
        self.lastOpenedQuickNoteId = lastOpenedQuickNoteId
        self.contextBundles = contextBundles
        self.activeContextBundleId = activeContextBundleId
    }

    // Support loading old state files that may use the old key name
    enum CodingKeys: String, CodingKey {
        case sets, items, activeSetId, alwaysOnTop, sortOption, filterOption, clipboardEntries, pathEntries
        case saveScreenshots = "screenshotWatchEnabled"
        case autoCleanupFilesDays, autoCleanupClipboardDays, autoCleanupPathsDays
        case clipboardGroups, activeClipboardGroupId, clipboardNewestOnTop
        case clipboardCopyBlankLines, clipboardIncludeGroupHeader
        case quickNotes, lastOpenedQuickNoteId
        case contextBundles, activeContextBundleId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sets = try container.decode([StashSet].self, forKey: .sets)
        items = try container.decode([StashItem].self, forKey: .items)
        activeSetId = try container.decodeIfPresent(UUID.self, forKey: .activeSetId)
        alwaysOnTop = try container.decode(Bool.self, forKey: .alwaysOnTop)
        sortOption = (try? container.decode(SortOption.self, forKey: .sortOption)) ?? .dateAdded
        filterOption = try container.decode(FilterOption.self, forKey: .filterOption)
        clipboardEntries = try container.decode([ClipboardEntry].self, forKey: .clipboardEntries)
        pathEntries = try container.decodeIfPresent([PathEntry].self, forKey: .pathEntries) ?? []
        saveScreenshots = try container.decodeIfPresent(Bool.self, forKey: .saveScreenshots) ?? false
        autoCleanupFilesDays = try container.decodeIfPresent(Int.self, forKey: .autoCleanupFilesDays)
        autoCleanupClipboardDays = try container.decodeIfPresent(Int.self, forKey: .autoCleanupClipboardDays)
        autoCleanupPathsDays = try container.decodeIfPresent(Int.self, forKey: .autoCleanupPathsDays)
        clipboardGroups = try container.decodeIfPresent([ClipboardGroup].self, forKey: .clipboardGroups) ?? []
        activeClipboardGroupId = try container.decodeIfPresent(UUID.self, forKey: .activeClipboardGroupId)
        clipboardNewestOnTop = try container.decodeIfPresent(Bool.self, forKey: .clipboardNewestOnTop) ?? true
        clipboardCopyBlankLines = try container.decodeIfPresent(Int.self, forKey: .clipboardCopyBlankLines) ?? 1
        clipboardIncludeGroupHeader = try container.decodeIfPresent(Bool.self, forKey: .clipboardIncludeGroupHeader) ?? true
        quickNotes = try container.decodeIfPresent([QuickNote].self, forKey: .quickNotes) ?? []
        lastOpenedQuickNoteId = try container.decodeIfPresent(UUID.self, forKey: .lastOpenedQuickNoteId)
        contextBundles = try container.decodeIfPresent([ContextBundle].self, forKey: .contextBundles) ?? []
        activeContextBundleId = try container.decodeIfPresent(UUID.self, forKey: .activeContextBundleId)
    }
}

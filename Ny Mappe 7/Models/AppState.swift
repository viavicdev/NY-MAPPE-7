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
    var promptCategories: [PromptCategory]
    var activePromptCategoryId: UUID?
    // View-preferanser per fane (grid/list + st\u{00F8}rrelse 0.0\u{2013}1.0)
    var filesViewMode: ViewMode
    var filesViewSize: Double
    var clipboardViewMode: ViewMode
    var clipboardViewSize: Double
    var pathsViewMode: ViewMode
    var pathsViewSize: Double
    var screenshotsViewMode: ViewMode
    var screenshotsViewSize: Double

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
        activeContextBundleId: UUID? = nil,
        promptCategories: [PromptCategory] = [],
        activePromptCategoryId: UUID? = nil,
        filesViewMode: ViewMode = .grid,
        filesViewSize: Double = 0.5,
        clipboardViewMode: ViewMode = .grid,
        clipboardViewSize: Double = 0.5,
        pathsViewMode: ViewMode = .list,
        pathsViewSize: Double = 0.5,
        screenshotsViewMode: ViewMode = .grid,
        screenshotsViewSize: Double = 0.5
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
        self.promptCategories = promptCategories
        self.activePromptCategoryId = activePromptCategoryId
        self.filesViewMode = filesViewMode
        self.filesViewSize = filesViewSize
        self.clipboardViewMode = clipboardViewMode
        self.clipboardViewSize = clipboardViewSize
        self.pathsViewMode = pathsViewMode
        self.pathsViewSize = pathsViewSize
        self.screenshotsViewMode = screenshotsViewMode
        self.screenshotsViewSize = screenshotsViewSize
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
        case promptCategories, activePromptCategoryId
        case filesViewMode, filesViewSize
        case clipboardViewMode, clipboardViewSize
        case pathsViewMode, pathsViewSize
        case screenshotsViewMode, screenshotsViewSize
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
        contextBundles = (try? container.decodeIfPresent([ContextBundle].self, forKey: .contextBundles)) ?? []
        activeContextBundleId = try container.decodeIfPresent(UUID.self, forKey: .activeContextBundleId)
        promptCategories = (try? container.decodeIfPresent([PromptCategory].self, forKey: .promptCategories)) ?? []
        activePromptCategoryId = try container.decodeIfPresent(UUID.self, forKey: .activePromptCategoryId)
        filesViewMode = try container.decodeIfPresent(ViewMode.self, forKey: .filesViewMode) ?? .grid
        filesViewSize = try container.decodeIfPresent(Double.self, forKey: .filesViewSize) ?? 0.5
        clipboardViewMode = try container.decodeIfPresent(ViewMode.self, forKey: .clipboardViewMode) ?? .grid
        clipboardViewSize = try container.decodeIfPresent(Double.self, forKey: .clipboardViewSize) ?? 0.5
        pathsViewMode = try container.decodeIfPresent(ViewMode.self, forKey: .pathsViewMode) ?? .list
        pathsViewSize = try container.decodeIfPresent(Double.self, forKey: .pathsViewSize) ?? 0.5
        screenshotsViewMode = try container.decodeIfPresent(ViewMode.self, forKey: .screenshotsViewMode) ?? .grid
        screenshotsViewSize = try container.decodeIfPresent(Double.self, forKey: .screenshotsViewSize) ?? 0.5
    }
}

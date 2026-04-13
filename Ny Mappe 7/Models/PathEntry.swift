import Foundation

struct PathEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let path: String
    let name: String
    let isDirectory: Bool
    let dateAdded: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        path: String,
        name: String,
        isDirectory: Bool,
        dateAdded: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.dateAdded = dateAdded
        self.isPinned = isPinned
    }

    var icon: String {
        isDirectory ? "folder.fill" : "doc.fill"
    }

    /// Shortened path for display (e.g. ~/Desktop/project)
    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    var timeAgo: String {
        dateAdded.timeAgoNorwegian
    }
}

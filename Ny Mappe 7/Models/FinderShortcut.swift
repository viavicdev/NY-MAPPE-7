import Foundation

/// En snarvei til en mappe (eller fil) i Finder.
/// Brukeren konfigurerer disse i innstillinger, og klikker dem i Tools > Snarveier
/// for å åpne stien i Finder.
struct FinderShortcut: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    /// Valgfri emoji/ikon-identifikator. Tomt = bruk standard "folder"-ikon.
    var emoji: String
    var sortIndex: Int
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        emoji: String = "",
        sortIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.emoji = emoji
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    var url: URL {
        URL(fileURLWithPath: path)
    }

    var displayName: String {
        name.isEmpty ? url.lastPathComponent : name
    }
}

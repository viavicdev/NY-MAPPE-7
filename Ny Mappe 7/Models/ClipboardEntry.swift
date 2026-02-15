import Foundation

struct ClipboardEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let dateCopied: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        text: String,
        dateCopied: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.text = text
        self.dateCopied = dateCopied
        self.isPinned = isPinned
    }

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 120 {
            return String(trimmed.prefix(120)) + "..."
        }
        return trimmed
    }

    var timeAgo: String {
        let loc = Loc(l: AppLanguage.current)
        let interval = Date().timeIntervalSince(dateCopied)
        if interval < 60 { return loc.now }
        if interval < 3600 {
            let mins = Int(interval / 60)
            return loc.minutesAgo(mins)
        }
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return loc.hoursAgo(hours)
        }
        let days = Int(interval / 86400)
        return loc.daysAgo(days)
    }
}

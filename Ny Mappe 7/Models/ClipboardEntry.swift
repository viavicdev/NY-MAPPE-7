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
        let interval = Date().timeIntervalSince(dateCopied)
        if interval < 60 { return "n\u{00E5}" }
        if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins) min siden"
        }
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)t siden"
        }
        let days = Int(interval / 86400)
        return "\(days)d siden"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "d. MMM HH:mm"
        return formatter.string(from: dateCopied)
    }
}

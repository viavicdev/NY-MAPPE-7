import Foundation

struct ClipboardEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let dateCopied: Date
    var isPinned: Bool
    var groupId: UUID?

    init(
        id: UUID = UUID(),
        text: String,
        dateCopied: Date = Date(),
        isPinned: Bool = false,
        groupId: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.dateCopied = dateCopied
        self.isPinned = isPinned
        self.groupId = groupId
    }

    // Bakoverkompatibel decoding: eldre state-filer har ikke groupId.
    enum CodingKeys: String, CodingKey {
        case id, text, dateCopied, isPinned, groupId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        dateCopied = try container.decode(Date.self, forKey: .dateCopied)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId)
    }

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 120 {
            return String(trimmed.prefix(120)) + "..."
        }
        return trimmed
    }

    var timeAgo: String {
        dateCopied.timeAgoNorwegian
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "d. MMM HH:mm"
        return formatter.string(from: dateCopied)
    }
}

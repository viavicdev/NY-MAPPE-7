import Foundation

enum ClipboardKind: String, Codable {
    case text
    case image
}

struct ClipboardEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let dateCopied: Date
    var isPinned: Bool
    var groupId: UUID?
    var kind: ClipboardKind
    /// Filnavn (ikke full sti) for et lagret bilde under PersistenceService.clipboardImagesURL.
    /// Kun satt når kind == .image.
    var imageFileName: String?

    init(
        id: UUID = UUID(),
        text: String,
        dateCopied: Date = Date(),
        isPinned: Bool = false,
        groupId: UUID? = nil,
        kind: ClipboardKind = .text,
        imageFileName: String? = nil
    ) {
        self.id = id
        self.text = text
        self.dateCopied = dateCopied
        self.isPinned = isPinned
        self.groupId = groupId
        self.kind = kind
        self.imageFileName = imageFileName
    }

    /// Convenience-init for bilde-utklipp.
    init(imageFileName: String, dateCopied: Date = Date(), groupId: UUID? = nil) {
        self.init(
            text: "Bilde",
            dateCopied: dateCopied,
            groupId: groupId,
            kind: .image,
            imageFileName: imageFileName
        )
    }

    // Bakoverkompatibel decoding: eldre state-filer har ikke groupId/kind/imageFileName.
    enum CodingKeys: String, CodingKey {
        case id, text, dateCopied, isPinned, groupId, kind, imageFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        dateCopied = try container.decode(Date.self, forKey: .dateCopied)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        groupId = try container.decodeIfPresent(UUID.self, forKey: .groupId)
        kind = try container.decodeIfPresent(ClipboardKind.self, forKey: .kind) ?? .text
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
    }

    var isImage: Bool { kind == .image }

    var preview: String {
        if isImage { return "Bilde" }
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

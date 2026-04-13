import Foundation

struct ClipboardGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String?
    let createdAt: Date
    var sortIndex: Int

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String? = nil,
        createdAt: Date = Date(),
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.sortIndex = sortIndex
    }
}

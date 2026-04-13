import Foundation

struct ContextBundle: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var items: [BundleItem]
    let createdAt: Date
    var sortIndex: Int
    var colorHex: String?

    init(
        id: UUID = UUID(),
        name: String,
        items: [BundleItem] = [],
        createdAt: Date = Date(),
        sortIndex: Int = 0,
        colorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.colorHex = colorHex
    }

    var fileItemCount: Int {
        items.filter { $0.isFile }.count
    }

    var textItemCount: Int {
        items.filter { $0.isText }.count
    }
}

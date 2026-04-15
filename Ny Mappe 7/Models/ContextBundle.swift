import Foundation

struct ContextBundle: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var items: [BundleItem]
    let createdAt: Date
    var sortIndex: Int
    var colorHex: String?
    /// Navn p\u{00E5} custom SVG-ikon i Resources/Icons/ (uten .svg). nil = standard ikon.
    var iconName: String?

    init(
        id: UUID = UUID(),
        name: String,
        items: [BundleItem] = [],
        createdAt: Date = Date(),
        sortIndex: Int = 0,
        colorHex: String? = nil,
        iconName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.colorHex = colorHex
        self.iconName = iconName
    }

    // Bakoverkompatibel decoding: eldre bundles har ikke iconName
    enum CodingKeys: String, CodingKey {
        case id, name, items, createdAt, sortIndex, colorHex, iconName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        items = try c.decode([BundleItem].self, forKey: .items)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        sortIndex = try c.decode(Int.self, forKey: .sortIndex)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName)
    }

    var fileItemCount: Int {
        items.filter { $0.isFile }.count
    }

    var textItemCount: Int {
        items.filter { $0.isText }.count
    }
}

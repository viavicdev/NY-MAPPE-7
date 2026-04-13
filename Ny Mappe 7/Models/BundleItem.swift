import Foundation

/// Et element inne i en ContextBundle. Kan enten være en referanse til en
/// eksisterende fil i Filer-fanen, eller et tekstsnippet som lever i bundlen.
enum BundleItem: Identifiable, Codable, Hashable {
    case file(id: UUID, stashItemId: UUID)
    case text(id: UUID, title: String, body: String)

    var id: UUID {
        switch self {
        case .file(let id, _): return id
        case .text(let id, _, _): return id
        }
    }

    var isFile: Bool {
        if case .file = self { return true }
        return false
    }

    var isText: Bool {
        if case .text = self { return true }
        return false
    }
}

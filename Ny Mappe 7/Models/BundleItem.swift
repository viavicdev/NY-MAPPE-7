import Foundation

/// Et element inne i en ContextBundle.
/// - `.localFile`: fila er kopiert inn i bundlens egen lagring (selvstendig fra Filer-fanen)
/// - `.file`: LEGACY — peker til en StashItem i Filer-fanen. Migreres til .localFile ved første load.
/// - `.text`: tekstsnippet som lever i bundlen
enum BundleItem: Identifiable, Codable, Hashable {
    case file(id: UUID, stashItemId: UUID)
    case localFile(id: UUID, fileName: String, sizeBytes: Int64, dateAdded: Date)
    case text(id: UUID, title: String, body: String)

    var id: UUID {
        switch self {
        case .file(let id, _): return id
        case .localFile(let id, _, _, _): return id
        case .text(let id, _, _): return id
        }
    }

    var isFile: Bool {
        switch self {
        case .file, .localFile: return true
        case .text: return false
        }
    }

    var isText: Bool {
        if case .text = self { return true }
        return false
    }
}

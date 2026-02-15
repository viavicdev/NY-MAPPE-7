import Foundation

enum TypeCategory: String, Codable, CaseIterable {
    case image = "Image"
    case video = "Video"
    case audio = "Audio"
    case document = "Document"
    case archive = "Archive"
    case other = "Other"

    var label: String { rawValue }

    static func from(extension ext: String) -> TypeCategory {
        let lower = ext.lowercased()
        switch lower {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "svg", "ico", "raw", "cr2", "nef":
            return .image
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpg", "mpeg":
            return .video
        case "mp3", "wav", "aac", "flac", "ogg", "wma", "m4a", "aiff", "alac":
            return .audio
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv", "md", "pages", "numbers", "keynote", "json", "xml", "html", "htm", "swift", "py", "js", "ts", "c", "cpp", "h", "java", "rb", "go", "rs":
            return .document
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso":
            return .archive
        default:
            return .other
        }
    }
}

struct StashItem: Identifiable, Codable, Hashable {
    let id: UUID
    let setId: UUID
    let originalURL: URL
    let stagedURL: URL
    let fileName: String
    let ext: String
    let typeCategory: TypeCategory
    let sizeBytes: Int64
    let dateAdded: Date
    var thumbnailPath: String?
    var isScreenshot: Bool
    var sortIndex: Int?

    init(
        id: UUID = UUID(),
        setId: UUID,
        originalURL: URL,
        stagedURL: URL,
        fileName: String,
        ext: String,
        typeCategory: TypeCategory,
        sizeBytes: Int64,
        dateAdded: Date = Date(),
        thumbnailPath: String? = nil,
        isScreenshot: Bool = false,
        sortIndex: Int? = nil
    ) {
        self.id = id
        self.setId = setId
        self.originalURL = originalURL
        self.stagedURL = stagedURL
        self.fileName = fileName
        self.ext = ext
        self.typeCategory = typeCategory
        self.sizeBytes = sizeBytes
        self.dateAdded = dateAdded
        self.thumbnailPath = thumbnailPath
        self.isScreenshot = isScreenshot
        self.sortIndex = sortIndex
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var truncatedOriginalPath: String {
        let path = originalURL.path
        if path.count > 60 {
            let start = path.prefix(20)
            let end = path.suffix(35)
            return "\(start)...\(end)"
        }
        return path
    }
}

enum SortOption: String, Codable, CaseIterable {
    case name = "Name"
    case size = "Size"
    case dateAdded = "Date Added"
    case manual = "Manual"
}

enum FilterOption: String, Codable, CaseIterable {
    case all = "All"
    case images = "Images"
    case video = "Video"
    case audio = "Audio"
    case docs = "Docs"
    case archives = "Archives"
    case other = "Other"

    var matchesCategory: TypeCategory? {
        switch self {
        case .all: return nil
        case .images: return .image
        case .video: return .video
        case .audio: return .audio
        case .docs: return .document
        case .archives: return .archive
        case .other: return .other
        }
    }
}

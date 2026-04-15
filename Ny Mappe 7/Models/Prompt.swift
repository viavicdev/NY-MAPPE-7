import Foundation

struct Prompt: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var body: String
    /// Filnavn i prompt-lagringen. Hvis satt, er prompten fil-basert (md/txt/pdf).
    /// Hvis nil, er prompten tekst-basert og `body` er innholdet.
    var fileName: String?
    var fileSizeBytes: Int64?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        body: String = "",
        fileName: String? = nil,
        fileSizeBytes: Int64? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Bakoverkompatibel decoding: eldre prompts har ikke fileName/fileSizeBytes
    enum CodingKeys: String, CodingKey {
        case id, title, body, fileName, fileSizeBytes, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decode(String.self, forKey: .body)
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
        fileSizeBytes = try c.decodeIfPresent(Int64.self, forKey: .fileSizeBytes)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    var isFile: Bool { fileName != nil }

    var fileExtension: String {
        guard let name = fileName else { return "" }
        return (name as NSString).pathExtension.lowercased()
    }

    /// Kan vi lese innholdet som tekst og kopiere det direkte?
    var isTextFile: Bool {
        let ext = fileExtension
        return ext == "md" || ext == "txt" || ext == "markdown"
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let name = fileName { return name }
        let firstLine = body.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let t = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "Uten tittel" }
        return t.count > 40 ? String(t.prefix(40)) + "…" : t
    }
}

struct PromptCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var iconName: String?
    var prompts: [Prompt]
    let createdAt: Date
    var sortIndex: Int

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String? = nil,
        prompts: [Prompt] = [],
        createdAt: Date = Date(),
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.prompts = prompts
        self.createdAt = createdAt
        self.sortIndex = sortIndex
    }
}

import Foundation

final class PersistenceService {
    static let shared = PersistenceService()

    private let fileManager = FileManager.default

    var appSupportURL: URL {
        let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("GeniDrop", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    var stagingRootURL: URL {
        let url = appSupportURL.appendingPathComponent("StagingCache", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    var thumbnailsURL: URL {
        let url = appSupportURL.appendingPathComponent("Thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    var exportURL: URL {
        let url = appSupportURL.appendingPathComponent("Exports", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var stateFileURL: URL {
        appSupportURL.appendingPathComponent("state.json")
    }

    func saveState(_ state: AppState) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(state)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            print("Failed to save state: \(error)")
        }
    }

    func loadState() -> AppState? {
        guard fileManager.fileExists(atPath: stateFileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: stateFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AppState.self, from: data)
        } catch {
            print("Failed to load state: \(error)")
            return nil
        }
    }

    func stagingURL(forSet setId: UUID) -> URL {
        let url = stagingRootURL.appendingPathComponent(setId.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

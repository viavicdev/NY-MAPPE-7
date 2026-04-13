import Foundation
import os.log

final class PersistenceService {
    static let shared = PersistenceService()

    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "no.klippegeni.nymappe7", category: "Persistence")

    /// Siste feil som oppstod under lagring/lasting. Observes via NotificationCenter
    /// slik at ViewModels kan vise en synlig feilmelding uten direkte binding.
    static let saveFailedNotification = Notification.Name("PersistenceService.saveFailed")
    static let loadFailedNotification = Notification.Name("PersistenceService.loadFailed")

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

    private var stateBackupURL: URL {
        appSupportURL.appendingPathComponent("state.json.bak")
    }

    private var stateBackupOlderURL: URL {
        appSupportURL.appendingPathComponent("state.json.bak2")
    }

    func saveState(_ state: AppState) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(state)

            // Roter eksisterende fil til backup FØR vi overskriver,
            // slik at vi alltid har minst én god versjon igjen ved crash.
            if fileManager.fileExists(atPath: stateFileURL.path) {
                // state.json.bak → state.json.bak2 (eldre backup)
                if fileManager.fileExists(atPath: stateBackupURL.path) {
                    try? fileManager.removeItem(at: stateBackupOlderURL)
                    try? fileManager.moveItem(at: stateBackupURL, to: stateBackupOlderURL)
                }
                // state.json → state.json.bak (forrige versjon)
                try? fileManager.copyItem(at: stateFileURL, to: stateBackupURL)
            }

            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            logger.error("Failed to save state: \(error.localizedDescription, privacy: .public)")
            NotificationCenter.default.post(
                name: Self.saveFailedNotification,
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
        }
    }

    func loadState() -> AppState? {
        // Prøv hovedfilen, så begge backupene før vi gir opp.
        for url in [stateFileURL, stateBackupURL, stateBackupOlderURL] {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let state = try decoder.decode(AppState.self, from: data)
                if url != stateFileURL {
                    logger.notice("Loaded state from backup: \(url.lastPathComponent, privacy: .public)")
                    NotificationCenter.default.post(
                        name: Self.loadFailedNotification,
                        object: nil,
                        userInfo: ["recoveredFrom": url.lastPathComponent]
                    )
                }
                return state
            } catch {
                logger.error("Failed to load \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                continue
            }
        }
        return nil
    }

    func stagingURL(forSet setId: UUID) -> URL {
        let url = stagingRootURL.appendingPathComponent(setId.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

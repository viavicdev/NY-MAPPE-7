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

    // MARK: - Bundle Storage

    /// Hver bundle har sin egen mappe med filer \u{2014} selvstendig fra Filer-fanen.
    func bundleStorageURL(for bundleId: UUID) -> URL {
        let url = appSupportURL
            .appendingPathComponent("Bundles", isDirectory: true)
            .appendingPathComponent(bundleId.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Sletter hele bundle-mappen og alt innhold (brukes n\u{00E5}r en bundle slettes).
    func removeBundleStorage(for bundleId: UUID) {
        let url = appSupportURL
            .appendingPathComponent("Bundles", isDirectory: true)
            .appendingPathComponent(bundleId.uuidString, isDirectory: true)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Prompt Storage

    /// Hver prompt-kategori har sin egen mappe for vedlagte filer.
    func promptStorageURL(for categoryId: UUID) -> URL {
        let url = appSupportURL
            .appendingPathComponent("Prompts", isDirectory: true)
            .appendingPathComponent(categoryId.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Sletter hele kategori-mappen (brukes n\u{00E5}r en kategori slettes).
    func removePromptStorage(for categoryId: UUID) {
        let url = appSupportURL
            .appendingPathComponent("Prompts", isDirectory: true)
            .appendingPathComponent(categoryId.uuidString, isDirectory: true)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Custom Icons

    /// Mappe for opplastede custom-ikoner (bundles og prompt-kategorier).
    private var customIconsURL: URL {
        let url = appSupportURL.appendingPathComponent("CustomIcons", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Kopierer en valgt bildefil inn i app-mappen og returnerer full filsti til kopien.
    /// Gjenbruker samme UUID-prefiks hvis en gammel sti sendes inn \u{2014} og sletter den gamle.
    func saveCustomIcon(sourceURL: URL, replacing oldPath: String? = nil) -> String? {
        if let old = oldPath {
            try? fileManager.removeItem(atPath: old)
        }
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let name = "\(UUID().uuidString).\(ext)"
        let dest = customIconsURL.appendingPathComponent(name)
        do {
            try fileManager.copyItem(at: sourceURL, to: dest)
            return dest.path
        } catch {
            return nil
        }
    }

    func removeCustomIcon(at path: String) {
        try? fileManager.removeItem(atPath: path)
    }
}

import Foundation
import UniformTypeIdentifiers

struct ImportResult {
    let items: [StashItem]
    let errors: [String]
}

struct ImportProgress {
    let completed: Int
    let total: Int
    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

final class StagingService {
    static let shared = StagingService()

    private let fileManager = FileManager.default
    private let persistence = PersistenceService.shared

    // MARK: - Import Files

    func importURLs(
        _ urls: [URL],
        toSet setId: UUID,
        existingItems: [StashItem],
        progress: @escaping (ImportProgress) -> Void
    ) async -> ImportResult {
        var allFileURLs: [URL] = []

        // Expand folders recursively
        for url in urls {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let folderFiles = enumerateFolder(url)
                allFileURLs.append(contentsOf: folderFiles)
            } else {
                allFileURLs.append(url)
            }
        }

        let total = allFileURLs.count
        var completed = 0
        var items: [StashItem] = []
        var errors: [String] = []

        let stagingDir = persistence.stagingURL(forSet: setId)
        let existingNames = Set(existingItems.map { $0.stagedURL.lastPathComponent })
        var usedNames = existingNames

        for url in allFileURLs {
            do {
                let item = try copyFileToStaging(
                    url,
                    setId: setId,
                    stagingDir: stagingDir,
                    usedNames: &usedNames
                )
                items.append(item)
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
            completed += 1
            progress(ImportProgress(completed: completed, total: total))
        }

        return ImportResult(items: items, errors: errors)
    }

    private func enumerateFolder(_ folderURL: URL) -> [URL] {
        var results: [URL] = []
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return results }

        for case let fileURL as URL in enumerator {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue {
                results.append(fileURL)
            }
        }
        return results
    }

    private func copyFileToStaging(
        _ sourceURL: URL,
        setId: UUID,
        stagingDir: URL,
        usedNames: inout Set<String>
    ) throws -> StashItem {
        let fileName = sourceURL.lastPathComponent
        let ext = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent

        // Generate unique name
        var targetName = fileName
        var counter = 1
        while usedNames.contains(targetName) {
            if ext.isEmpty {
                targetName = "\(baseName)_\(counter)"
            } else {
                targetName = "\(baseName)_\(counter).\(ext)"
            }
            counter += 1
        }
        usedNames.insert(targetName)

        let targetURL = stagingDir.appendingPathComponent(targetName)

        // Copy file
        try fileManager.copyItem(at: sourceURL, to: targetURL)

        // Get file size
        let attrs = try fileManager.attributesOfItem(atPath: targetURL.path)
        let size = (attrs[.size] as? Int64) ?? 0

        let category = TypeCategory.from(extension: ext)

        return StashItem(
            setId: setId,
            originalURL: sourceURL,
            stagedURL: targetURL,
            fileName: targetName,
            ext: ext,
            typeCategory: category,
            sizeBytes: size
        )
    }

    // MARK: - Clear Set

    func clearSet(_ setId: UUID) {
        let stagingDir = persistence.stagingURL(forSet: setId)
        try? fileManager.removeItem(at: stagingDir)
    }

    // MARK: - Remove Single Item

    func removeItem(_ item: StashItem) {
        try? fileManager.removeItem(at: item.stagedURL)
        if let thumbPath = item.thumbnailPath {
            try? fileManager.removeItem(at: URL(fileURLWithPath: thumbPath))
        }
    }

    // MARK: - Zip

    func zipItems(_ items: [StashItem], setName: String) async throws -> URL {
        let exportDir = persistence.exportURL
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let zipName = "\(setName)_\(timestamp).zip"
        let zipURL = exportDir.appendingPathComponent(zipName)

        // Use /usr/bin/ditto which creates zip archives on macOS
        let tempDir = exportDir.appendingPathComponent("_zip_staging_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Copy items into temp dir
        for item in items {
            let dest = tempDir.appendingPathComponent(item.fileName)
            try? fileManager.copyItem(at: item.stagedURL, to: dest)
        }

        // Create zip using ditto
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", tempDir.path, zipURL.path]

        try process.run()
        process.waitUntilExit()

        // Cleanup temp dir
        try? fileManager.removeItem(at: tempDir)

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "StagingService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Zip creation failed with status \(process.terminationStatus)"
            ])
        }

        return zipURL
    }

    // MARK: - Validate staged files exist

    func validateItems(_ items: [StashItem]) -> [StashItem] {
        items.filter { fileManager.fileExists(atPath: $0.stagedURL.path) }
    }
}

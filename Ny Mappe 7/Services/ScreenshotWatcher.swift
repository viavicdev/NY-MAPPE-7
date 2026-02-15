import Foundation
import AppKit

/// Watches the screenshot directory for new screenshots and automatically
/// imports them into the app. Uses a polling timer to reliably catch all
/// new screenshots regardless of DispatchSource event coalescing.
final class ScreenshotWatcher {
    static let shared = ScreenshotWatcher()

    private var knownFiles: Set<String> = []
    private var onNewScreenshot: ((URL) -> Void)?
    private var isWatching = false
    private var pollTimer: Timer?
    private let lock = NSLock()

    /// The directory where macOS saves screenshots
    var screenshotDirectory: URL {
        if let customPath = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            let url = URL(fileURLWithPath: (customPath as NSString).expandingTildeInPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }

    func startWatching(onNewScreenshot: @escaping (URL) -> Void) {
        guard !isWatching else { return }
        self.onNewScreenshot = onNewScreenshot
        self.isWatching = true

        // Snapshot current files so we only catch NEW ones
        knownFiles = currentScreenshotFiles()

        // Poll every 2 seconds — simple, reliable, no race conditions
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.scanAndImport()
        }
    }

    func stopWatching() {
        pollTimer?.invalidate()
        pollTimer = nil
        isWatching = false
        onNewScreenshot = nil
    }

    private func currentScreenshotFiles() -> Set<String> {
        let dir = screenshotDirectory
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return Set(files.filter { isScreenshotFile($0) })
    }

    private func scanAndImport() {
        lock.lock()
        let currentFiles = currentScreenshotFiles()
        let newFiles = currentFiles.subtracting(knownFiles)
        knownFiles = currentFiles
        lock.unlock()

        for fileName in newFiles {
            let url = screenshotDirectory.appendingPathComponent(fileName)

            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int64, size > 0 else {
                continue
            }

            onNewScreenshot?(url)
        }
    }

    private func isScreenshotFile(_ name: String) -> Bool {
        let lower = name.lowercased()
        let patterns = [
            "screenshot", "skjermbilde", "bildschirmfoto",
            "capture d'", "captura de pantalla", "schermafbeelding"
        ]
        let isScreenshot = patterns.contains { lower.contains($0) }
        let isImage = lower.hasSuffix(".png") || lower.hasSuffix(".jpg") ||
                      lower.hasSuffix(".jpeg") || lower.hasSuffix(".tiff")
        return isScreenshot && isImage
    }
}

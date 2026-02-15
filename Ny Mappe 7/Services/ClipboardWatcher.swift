import Foundation
import AppKit

/// Watches the system pasteboard for new string content.
/// NSPasteboard doesn't post notifications, so we poll changeCount.
final class ClipboardWatcher {
    static let shared = ClipboardWatcher()

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var onNewText: ((String) -> Void)?

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func startWatching(callback: @escaping (String) -> Void) {
        onNewText = callback
        lastChangeCount = NSPasteboard.general.changeCount

        // Poll every 0.5 seconds - lightweight
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    func stopWatching() {
        timer?.invalidate()
        timer = nil
        onNewText = nil
    }

    private func checkPasteboard() {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        // Only capture string content (not file URLs, images, etc.)
        guard let text = pb.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Skip if the pasteboard also contains file URLs (likely a file copy, not text)
        if let types = pb.types, types.contains(.fileURL) {
            return
        }

        onNewText?(text)
    }
}

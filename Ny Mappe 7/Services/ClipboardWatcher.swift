import Foundation
import AppKit

/// Watches the system pasteboard for new string and image content.
/// NSPasteboard doesn't post notifications, so we poll changeCount.
final class ClipboardWatcher {
    static let shared = ClipboardWatcher()

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var onNewText: ((String) -> Void)?
    private var onNewImage: ((Data) -> Void)?

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func startWatching(
        onText: @escaping (String) -> Void,
        onImage: @escaping (Data) -> Void
    ) {
        onNewText = onText
        onNewImage = onImage
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
        onNewImage = nil
    }

    private func checkPasteboard() {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        let types = pb.types ?? []

        // 1. Bilde kopiert (nettleserens "Kopier bilde", skjermbilde, Preview osv.).
        //    Hopp over fil-URL-er: det er filkopiering (h\u{00F8}rer til Filer-fanen), ikke et bitmap.
        if !types.contains(.fileURL),
           types.contains(where: { $0 == .png || $0 == .tiff }),
           let pngData = Self.pngData(from: pb) {
            onNewImage?(pngData)
            return
        }

        // 2. Tekst (eksisterende oppf\u{00F8}rsel)
        guard let text = pb.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Skip if the pasteboard also contains file URLs (likely a file copy, not text)
        if types.contains(.fileURL) {
            return
        }

        onNewText?(text)
    }

    /// Henter PNG-data fra utklippstavla. Foretrekker ekte PNG, faller tilbake til
    /// TIFF \u{2192} PNG-konvertering.
    private static func pngData(from pb: NSPasteboard) -> Data? {
        if let png = pb.data(forType: .png) {
            return png
        }
        if let tiff = pb.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff) {
            return rep.representation(using: .png, properties: [:])
        }
        return nil
    }
}

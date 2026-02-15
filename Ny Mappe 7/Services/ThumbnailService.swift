import Foundation
import AppKit
import QuickLookThumbnailing

final class ThumbnailService {
    static let shared = ThumbnailService()

    private let persistence = PersistenceService.shared
    private let thumbnailSize = CGSize(width: 200, height: 200)
    private let queue = DispatchQueue(label: "no.klippegeni.nymappe7.thumbnails", qos: .utility, attributes: .concurrent)

    func generateThumbnail(for item: StashItem) async -> String? {
        // Check if thumbnail already exists
        if let existing = item.thumbnailPath,
           FileManager.default.fileExists(atPath: existing) {
            return existing
        }

        let thumbnailURL = persistence.thumbnailsURL
            .appendingPathComponent("\(item.id.uuidString).png")

        // Try QuickLookThumbnailing first
        if let cgImage = await generateQLThumbnail(for: item.stagedURL) {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            if savePNG(nsImage, to: thumbnailURL) {
                return thumbnailURL.path
            }
        }

        // Fallback: for images, use NSImage directly
        if item.typeCategory == .image {
            if let nsImage = NSImage(contentsOf: item.stagedURL) {
                let resized = resizeImage(nsImage, to: thumbnailSize)
                if savePNG(resized, to: thumbnailURL) {
                    return thumbnailURL.path
                }
            }
        }

        return nil
    }

    private func generateQLThumbnail(for url: URL) async -> CGImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: thumbnailSize,
            scale: 2.0,
            representationTypes: .thumbnail
        )

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return thumbnail.cgImage
        } catch {
            return nil
        }
    }

    private func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage {
        let originalSize = image.size
        let ratio = min(size.width / originalSize.width, size.height / originalSize.height)
        let newSize = NSSize(
            width: originalSize.width * ratio,
            height: originalSize.height * ratio
        )

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }

    private func savePNG(_ image: NSImage, to url: URL) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return false
        }
        do {
            try pngData.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

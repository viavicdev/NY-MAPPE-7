import SwiftUI
import AppKit

/// Loads a custom SVG icon from the app bundle's Resources/Icons folder,
/// renders it as a template so it picks up the current foregroundColor.
///
/// Usage:
///   AppIcon("filer")
///       .frame(width: 14, height: 14)
///       .foregroundColor(.red)
struct AppIcon: View {
    let name: String
    var renderingMode: Image.TemplateRenderingMode = .template

    var body: some View {
        if let image = Self.load(name: name) {
            Image(nsImage: image)
                .renderingMode(renderingMode)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback in case the icon is missing from the bundle
            Image(systemName: "questionmark.square.dashed")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    init(_ name: String, renderingMode: Image.TemplateRenderingMode = .template) {
        self.name = name
        self.renderingMode = renderingMode
    }

    // Cache loaded NSImages so we don't re-read SVG from disk on every render
    private static var cache: [String: NSImage] = [:]

    static func load(name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "svg",
            subdirectory: "Icons"
        ) ?? Bundle.main.url(forResource: name, withExtension: "svg") else {
            return nil
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        cache[name] = image
        return image
    }
}

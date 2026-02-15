import SwiftUI
import AppKit

/// NSView-based drag source that supports dragging multiple file URLs.
/// SwiftUI's built-in `.draggable` only supports single-item Transferable.
/// This view properly provides multiple NSPasteboardItem entries for file URLs.
struct DragSourceView: NSViewRepresentable {
    let urls: [URL]

    func makeNSView(context: Context) -> DragSourceNSView {
        let view = DragSourceNSView()
        view.urls = urls
        return view
    }

    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        nsView.urls = urls
    }
}

class DragSourceNSView: NSView, NSDraggingSource {
    var urls: [URL] = []
    private var mouseDownEvent: NSEvent?

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        return .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        InternalDragState.isDragging = false
        // Auto-hide panel after successful drop to another app
        if operation == .copy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApplication.shared.windows
                    .first(where: { $0.title == "Ny Mappe (7)" })?
                    .orderOut(nil)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard !urls.isEmpty, let downEvent = mouseDownEvent else { return }

        InternalDragState.isDragging = true

        var draggingItems: [NSDraggingItem] = []

        for url in urls {
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(url.absoluteString, forType: .fileURL)

            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            let dragImage = NSWorkspace.shared.icon(forFile: url.path)
            dragImage.size = NSSize(width: 32, height: 32)
            draggingItem.setDraggingFrame(
                NSRect(x: 0, y: 0, width: 32, height: 32),
                contents: dragImage
            )
            draggingItems.append(draggingItem)
        }

        beginDraggingSession(with: draggingItems, event: downEvent, source: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Transparent - the SwiftUI overlay handles rendering
    }
}

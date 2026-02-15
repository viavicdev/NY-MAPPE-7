import SwiftUI
import AppKit

/// Global flag to track when an internal drag is in progress.
/// Used to prevent the app's own onDrop handler from re-importing files
/// that are being dragged OUT of the app.
enum InternalDragState {
    static var isDragging = false
}

/// NSView wrapper that captures drag gestures (mouseDragged) and initiates
/// an NSDraggingSession with multiple file URLs. It forwards click events
/// to the provided callback so SwiftUI can handle selection.
struct DraggableCardWrapper: NSViewRepresentable {
    let urls: [URL]
    let onClick: (NSEvent) -> Void

    func makeNSView(context: Context) -> CardDragNSView {
        let view = CardDragNSView()
        view.urls = urls
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: CardDragNSView, context: Context) {
        nsView.urls = urls
        nsView.onClick = onClick
    }
}

class CardDragNSView: NSView, NSDraggingSource {
    var urls: [URL] = []
    var onClick: ((NSEvent) -> Void)?
    private var mouseDownEvent: NSEvent?
    private var didDrag = false

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
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
        didDrag = false
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onClick?(event)
        }
        mouseDownEvent = nil
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !urls.isEmpty, let downEvent = mouseDownEvent else { return }

        // Only start drag after a few pixels of movement
        let downPoint = convert(downEvent.locationInWindow, from: nil)
        let currentPoint = convert(event.locationInWindow, from: nil)
        let dx = currentPoint.x - downPoint.x
        let dy = currentPoint.y - downPoint.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > 4 else { return }

        didDrag = true
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
        // Transparent - SwiftUI renders the visual content beneath
    }
}

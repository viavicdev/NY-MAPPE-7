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
    var onDoubleClick: (() -> Void)? = nil

    func makeNSView(context: Context) -> CardDragNSView {
        let view = CardDragNSView()
        view.urls = urls
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: CardDragNSView, context: Context) {
        nsView.urls = urls
        nsView.onClick = onClick
        nsView.onDoubleClick = onDoubleClick
    }
}

class CardDragNSView: NSView, NSDraggingSource {
    var urls: [URL] = []
    var onClick: ((NSEvent) -> Void)?
    var onDoubleClick: (() -> Void)?
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
            if event.clickCount >= 2, let doubleHandler = onDoubleClick {
                doubleHandler()
            } else {
                onClick?(event)
            }
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
            // NSURL er bedre pasteboard writer enn NSPasteboardItem \u{2014} gir
            // riktige UTI-er som web-apper, chatter, browsere forventer (ikke bare Finder).
            let draggingItem = NSDraggingItem(pasteboardWriter: url as NSURL)

            // For bildefiler: bruk faktisk bilde-thumbnail som drag-preview, ikke generisk filikon.
            let dragImage: NSImage
            if let img = NSImage(contentsOf: url), img.isValid {
                dragImage = img
            } else {
                dragImage = NSWorkspace.shared.icon(forFile: url.path)
            }
            let maxSide: CGFloat = 64
            let aspect = dragImage.size.width / max(dragImage.size.height, 1)
            let frameSize: NSSize = aspect >= 1
                ? NSSize(width: maxSide, height: maxSide / aspect)
                : NSSize(width: maxSide * aspect, height: maxSide)
            dragImage.size = frameSize
            draggingItem.setDraggingFrame(
                NSRect(origin: .zero, size: frameSize),
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

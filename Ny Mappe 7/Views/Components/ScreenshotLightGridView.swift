import SwiftUI
import AppKit

struct ScreenshotLightGridView: View {
    @ObservedObject var viewModel: StashViewModel
    @State private var lightboxItem: StashItem?

    private var screenshots: [StashItem] {
        viewModel.currentItems
    }

    /// Antall kolonner styrt av size-slider: 4 (liten) → 1 (stor)
    private var columnCount: Int {
        let s = viewModel.screenshotsViewSize
        if s < 0.25 { return 4 }
        if s < 0.55 { return 3 }
        if s < 0.85 { return 2 }
        return 1
    }

    private var adaptiveColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: columnCount)
    }

    var body: some View {
        ScrollView {
            if viewModel.screenshotsViewMode == .list {
                LazyVStack(spacing: 3) {
                    ForEach(screenshots) { item in
                        screenshotListRow(for: item)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            } else {
                LazyVGrid(columns: adaptiveColumns, spacing: 6) {
                    ForEach(screenshots) { item in
                        ScreenshotTile(
                            item: item,
                            isSelected: viewModel.selectedItemIds.contains(item.id),
                            onTap: { flags in
                                if flags.contains(.shift) {
                                    viewModel.selectRange(to: item.id)
                                } else if flags.contains(.command) {
                                    viewModel.toggleSelection(item.id, extending: true)
                                } else {
                                    lightboxItem = item
                                }
                            },
                            onLongPress: {
                                viewModel.toggleSelection(item.id, extending: true)
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .sheet(item: $lightboxItem) { item in
            ScreenshotLightbox(
                item: item,
                allItems: screenshots,
                onDismiss: { lightboxItem = nil },
                onNavigate: { newItem in lightboxItem = newItem },
                viewModel: viewModel
            )
        }
    }

    @ViewBuilder
    private func screenshotListRow(for item: StashItem) -> some View {
        let isSelected = viewModel.selectedItemIds.contains(item.id)
        let rowHeight: CGFloat = 24 + CGFloat(viewModel.screenshotsViewSize) * 28

        HStack(spacing: 8) {
            Group {
                if let thumbPath = item.thumbnailPath,
                   let nsImage = NSImage(contentsOfFile: thumbPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let nsImage = NSImage(contentsOfFile: item.stagedURL.path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(Design.subtleText)
                }
            }
            .frame(width: rowHeight, height: rowHeight)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(item.fileName)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Design.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(item.formattedSize)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Design.subtleText.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .frame(height: rowHeight + 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Design.accent.opacity(0.12) : Design.cardBackground.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isSelected ? Design.accent.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .overlay(
            DraggableCardWrapper(
                urls: [item.stagedURL],
                onClick: { event in
                    let flags = event.modifierFlags
                    if flags.contains(.shift) {
                        viewModel.selectRange(to: item.id)
                    } else {
                        viewModel.toggleSelection(item.id, extending: flags.contains(.command))
                    }
                },
                onDoubleClick: {
                    lightboxItem = item
                }
            )
        )
    }
}

// MARK: - Tile

private struct ScreenshotTile: View {
    let item: StashItem
    let isSelected: Bool
    let onTap: (NSEvent.ModifierFlags) -> Void
    let onLongPress: () -> Void

    @State private var isHovered = false

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.3))

                if let nsImage = thumbnailImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: side, height: side)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .thin))
                        .foregroundColor(Design.subtleText.opacity(0.5))
                }

                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .background(Circle().fill(Design.accent))
                                .padding(4)
                        }
                        Spacer()
                    }
                }

                if isHovered {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(timestampString)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                                .padding(6)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected
                            ? Design.accent
                            : (isHovered ? Design.accent.opacity(0.4) : Color.clear),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onHover { hovering in
                isHovered = hovering
            }
            .overlay(
                // NSView-wrapper h\u{00E5}ndterer klikk+drag og blokkerer window-drag
                DraggableCardWrapper(
                    urls: [item.stagedURL],
                    onClick: { event in
                        onTap(event.modifierFlags)
                    }
                )
            )
        }
        .aspectRatio(1.0, contentMode: .fit)
    }

    private var thumbnailImage: NSImage? {
        if let thumbPath = item.thumbnailPath,
           let img = NSImage(contentsOfFile: thumbPath) {
            return img
        }
        return NSImage(contentsOfFile: item.stagedURL.path)
    }

    private var timestampString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "d. MMM HH:mm"
        return f.string(from: item.dateAdded)
    }
}

// MARK: - Lightbox

struct ScreenshotLightbox: View {
    let item: StashItem
    let allItems: [StashItem]
    let onDismiss: () -> Void
    let onNavigate: (StashItem) -> Void
    @ObservedObject var viewModel: StashViewModel

    @State private var showCopied = false

    private var currentIndex: Int? {
        allItems.firstIndex(where: { $0.id == item.id })
    }

    private var canGoPrev: Bool {
        (currentIndex ?? 0) > 0
    }

    private var canGoNext: Bool {
        guard let idx = currentIndex else { return false }
        return idx < allItems.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text(item.fileName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                    .lineLimit(1)

                if let idx = currentIndex {
                    Text("\(idx + 1) / \(allItems.count)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Design.subtleText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Design.buttonTint)
                        .clipShape(Capsule())
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Design.subtleText)
                        .frame(width: 22, height: 22)
                        .background(Design.buttonTint)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Design.headerSurface)
            .overlay(
                Rectangle().frame(height: 0.5).foregroundColor(Design.dividerColor),
                alignment: .bottom
            )

            // Image
            ZStack {
                Color.black.opacity(0.4)

                if let nsImage = NSImage(contentsOfFile: item.stagedURL.path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(10)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.system(size: 28, weight: .thin))
                            .foregroundColor(Design.subtleText.opacity(0.5))
                        Text("Kan ikke lese bildet")
                            .font(.system(size: 10))
                            .foregroundColor(Design.subtleText)
                    }
                }

                if showCopied {
                    Text("Kopiert!")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Design.accent)
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Action bar
            HStack(spacing: 6) {
                Button(action: goPrev) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(canGoPrev ? Design.primaryText : Design.subtleText.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(Design.buttonTint)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canGoPrev)
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button(action: goNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(canGoNext ? Design.primaryText : Design.subtleText.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(Design.buttonTint)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canGoNext)
                .keyboardShortcut(.rightArrow, modifiers: [])

                Spacer()

                Button(action: revealInFinder) {
                    HStack(spacing: 3) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                        Text("Vis i Finder")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                }
                .buttonStyle(Design.PillButtonStyle())

                Button(action: copyImageToPasteboard) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("Kopier bilde")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                }
                .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))
                .keyboardShortcut("c", modifiers: .command)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Design.headerSurface)
            .overlay(
                Rectangle().frame(height: 0.5).foregroundColor(Design.dividerColor),
                alignment: .top
            )
        }
        .frame(width: 640, height: 520)
        .background(Design.panelBackground)
    }

    private func goPrev() {
        guard let idx = currentIndex, idx > 0 else { return }
        onNavigate(allItems[idx - 1])
    }

    private func goNext() {
        guard let idx = currentIndex, idx < allItems.count - 1 else { return }
        onNavigate(allItems[idx + 1])
    }

    private func copyImageToPasteboard() {
        guard let nsImage = NSImage(contentsOfFile: item.stagedURL.path) else {
            viewModel.errorMessage = "Kunne ikke lese bildet fra disk"
            viewModel.showError = true
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])

        viewModel.showToast("Bilde kopiert!")
        withAnimation(.easeIn(duration: 0.15)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) { showCopied = false }
        }
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([item.stagedURL])
    }
}

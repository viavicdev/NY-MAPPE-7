import SwiftUI
import AppKit

struct ScreenshotLightGridView: View {
    @ObservedObject var viewModel: StashViewModel
    @State private var lightboxItem: StashItem?

    // 3 like store kolonner — passer i light-mode panelet (380px bredt).
    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    private var screenshots: [StashItem] {
        viewModel.currentItems
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
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
                                // Enkelt-klikk: \u{00E5}pne lightbox (nåværende adferd)
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
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
            .onTapGesture {
                let flags = NSApp.currentEvent?.modifierFlags ?? []
                onTap(flags)
            }
            .onLongPressGesture(perform: onLongPress)
            .onHover { hovering in
                isHovered = hovering
            }
            .onDrag {
                NSItemProvider(object: item.stagedURL as NSURL)
            }
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

import SwiftUI
import AppKit

struct CardsGridView: View {
    @ObservedObject var viewModel: StashViewModel

    /// Bruker riktig view-preferanse basert p\u{00E5} aktiv fane (Filer vs Skjermbilde).
    private var currentMode: ViewMode {
        isScreenshotContext ? viewModel.screenshotsViewMode : viewModel.filesViewMode
    }

    private var currentSize: Double {
        isScreenshotContext ? viewModel.screenshotsViewSize : viewModel.filesViewSize
    }

    private var isScreenshotContext: Bool {
        viewModel.activeTab == .tools && viewModel.activeToolsTab == .screenshots
    }

    /// Mapper size 0.0\u{2013}1.0 til grid-kolonne-minimum.
    private var gridColumnMinimum: CGFloat {
        // St\u{00F8}rrelse 0 = 110px min, 1.0 = 260px min
        110 + CGFloat(currentSize) * 150
    }

    private var adaptiveColumns: [GridItem] {
        [GridItem(.adaptive(minimum: gridColumnMinimum, maximum: gridColumnMinimum + 60), spacing: Design.gridSpacing)]
    }

    var body: some View {
        ScrollView {
            if currentMode == .list {
                listBody
            } else {
                gridBody
            }
        }
    }

    private var gridBody: some View {
        LazyVGrid(columns: adaptiveColumns, spacing: Design.gridSpacing) {
            ForEach(viewModel.currentItems) { item in
                cardView(for: item)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .id(item.id)
            }
        }
        .padding(.horizontal, Design.cardPadding)
        .padding(.top, 4)
        .padding(.bottom, Design.cardPadding)
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentItems.map(\.id))
    }

    private var listBody: some View {
        LazyVStack(spacing: 2) {
            ForEach(viewModel.currentItems) { item in
                listRow(for: item)
                    .id(item.id)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func listRow(for item: StashItem) -> some View {
        let isSelected = viewModel.selectedItemIds.contains(item.id)
        let dragURLs: [URL] = {
            if isSelected && viewModel.selectedItemIds.count > 1 {
                return viewModel.dragItems(ids: viewModel.selectedItemIds)
            }
            return [item.stagedURL]
        }()
        // Size 0.0 \u{2192} 24px, 1.0 \u{2192} 44px rad-h\u{00F8}yde
        let rowHeight: CGFloat = 24 + CGFloat(currentSize) * 20

        ZStack {
            HStack(spacing: 8) {
                // Thumbnail eller ikon
                Group {
                    if let thumbPath = item.thumbnailPath,
                       let nsImage = NSImage(contentsOfFile: thumbPath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "doc")
                            .font(.system(size: rowHeight * 0.45))
                            .foregroundColor(Design.subtleText)
                    }
                }
                .frame(width: rowHeight, height: rowHeight)
                .background(Design.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Filnavn
                Text(item.fileName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Design.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // St\u{00F8}rrelse
                Text(item.formattedSize)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Design.subtleText.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .frame(height: rowHeight + 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Design.accent.opacity(0.12) : Design.cardBackground.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Design.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .allowsHitTesting(false)

            DraggableCardWrapper(
                urls: dragURLs,
                onClick: { event in
                    if event.modifierFlags.contains(.shift) {
                        viewModel.selectRange(to: item.id)
                    } else {
                        let extending = event.modifierFlags.contains(.command)
                        viewModel.toggleSelection(item.id, extending: extending)
                    }
                }
            )
        }
        .contextMenu {
            Button("Vis i Finder") { viewModel.revealInFinder(item) }
            Button("\u{00C5}pne") { quickLook(item) }
            Divider()
            Button("Fjern", role: .destructive) {
                viewModel.selectedItemIds = [item.id]
                withAnimation { viewModel.removeSelected() }
            }
        }
    }

    @ViewBuilder
    private func cardView(for item: StashItem) -> some View {
        let isSelected = viewModel.selectedItemIds.contains(item.id)
        let dragURLs: [URL] = {
            if isSelected && viewModel.selectedItemIds.count > 1 {
                return viewModel.dragItems(ids: viewModel.selectedItemIds)
            }
            return [item.stagedURL]
        }()

        ZStack {
            FileCardView(
                item: item,
                isSelected: isSelected,
                isCompact: viewModel.isLightVersion,
                onTap: { _ in },
                onShiftTap: {},
                onReveal: {}
            )
            .allowsHitTesting(false)

            DraggableCardWrapper(
                urls: dragURLs,
                onClick: { event in
                    if event.modifierFlags.contains(.shift) {
                        viewModel.selectRange(to: item.id)
                    } else {
                        let extending = event.modifierFlags.contains(.command)
                        viewModel.toggleSelection(item.id, extending: extending)
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Drag handle for manual sort mode
            if viewModel.sortOption == .manual {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12))
                    .foregroundColor(Design.subtleText.opacity(0.6))
                    .padding(6)
                    .background(Design.buttonTint)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onDrag {
                        NSItemProvider(object: item.id.uuidString as NSString)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            }
        }
        .onDrop(of: [.text], isTargeted: nil) { providers in
            guard viewModel.sortOption == .manual else { return false }
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
                guard let data = data as? Data,
                      let idString = String(data: data, encoding: .utf8),
                      let sourceId = UUID(uuidString: idString) else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.reorderItem(fromId: sourceId, toId: item.id)
                    }
                }
            }
            return true
        }
        .contextMenu {
            Button("Vis i Finder") {
                viewModel.revealInFinder(item)
            }
            Button("\u{00C5}pne") {
                quickLook(item)
            }
            Divider()
            Button("Del...") {
                shareItem(item)
            }
            if viewModel.selectedItemIds.count > 1 && viewModel.selectedItemIds.contains(item.id) {
                Button("Gi nytt navn til valgte...") {
                    viewModel.showBatchRenameSheet = true
                }
            }
            if !viewModel.contextBundles.isEmpty {
                Menu("Legg til i bundle") {
                    ForEach(viewModel.contextBundles.sorted { $0.sortIndex < $1.sortIndex }) { bundle in
                        Button(bundle.name) {
                            viewModel.addFileToBundle(bundleId: bundle.id, stashItemId: item.id)
                            viewModel.showToast("Lagt til i \(bundle.name)")
                        }
                    }
                }
            }
            Divider()
            Button("Fjern", role: .destructive) {
                viewModel.selectedItemIds = [item.id]
                withAnimation {
                    viewModel.removeSelected()
                }
            }
        }
    }

    private func quickLook(_ item: StashItem) {
        NSWorkspace.shared.open(item.stagedURL)
    }

    private func shareItem(_ item: StashItem) {
        let urls = [item.stagedURL]
        guard let window = NSApplication.shared.windows.first(where: { $0.title == "Ny Mappe (7)" }),
              let contentView = window.contentView else { return }
        let picker = NSSharingServicePicker(items: urls)
        let rect = NSRect(x: contentView.bounds.midX - 1, y: contentView.bounds.midY, width: 2, height: 2)
        picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
    }
}

import SwiftUI
import AppKit

struct CardsGridView: View {
    @ObservedObject var viewModel: StashViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 145, maximum: 220), spacing: Design.gridSpacing)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Design.gridSpacing) {
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

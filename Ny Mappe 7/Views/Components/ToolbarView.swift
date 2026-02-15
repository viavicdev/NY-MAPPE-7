import SwiftUI
import AppKit

struct ToolbarView: View {
    @ObservedObject var viewModel: StashViewModel
    var isFullMode: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { addFiles() }) {
                Image(systemName: "doc.badge.plus")
            }
            .buttonStyle(Design.IconButtonStyle(isAccent: true))
            .help(viewModel.loc.addFiles)

            if isFullMode {
                Button(action: { pasteFromClipboard() }) {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(Design.IconButtonStyle())
                .help(viewModel.loc.pasteFromClipboard)

                Button(action: { viewModel.selectAll() }) {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(Design.IconButtonStyle())
                .help(viewModel.loc.selectAll)
            }

            Spacer()

            // Batch rename (full mode, multiple selected)
            if isFullMode && viewModel.selectedItemIds.count > 1 {
                Button(action: { viewModel.showBatchRenameSheet = true }) {
                    Image(systemName: "pencil.line")
                }
                .buttonStyle(Design.IconButtonStyle())
                .help(viewModel.loc.renameSelected)
            }

            // Share (full mode, has selection)
            if isFullMode && !viewModel.selectedItemIds.isEmpty {
                Button(action: { shareSelectedFiles() }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(Design.IconButtonStyle())
                .help(viewModel.loc.shareSelectedFiles)
            }

            if isFullMode && !viewModel.selectedItemIds.isEmpty {
                Button(action: { viewModel.revealSelectedInFinder() }) {
                    Image(systemName: "folder")
                }
                .buttonStyle(Design.IconButtonStyle())
                .help(viewModel.loc.showInFinder)
            }

            // Export list menu (full mode)
            if isFullMode && !viewModel.currentItems.isEmpty {
                Menu {
                    Button(action: { viewModel.exportFileListAsText() }) {
                        Label(viewModel.loc.asTxtFilenames, systemImage: "doc.text")
                    }
                    Button(action: { viewModel.exportFileListAsCSV() }) {
                        Label(viewModel.loc.asCsvMetadata, systemImage: "tablecells")
                    }
                    Button(action: { viewModel.exportFileListAsJSON() }) {
                        Label(viewModel.loc.asJsonFull, systemImage: "curlybraces")
                    }
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 14))
                        .frame(width: 36, height: 32)
                        .foregroundColor(Design.primaryText)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(viewModel.loc.exportFileList)
            }

            // Zip menu
            if !viewModel.currentItems.isEmpty {
                Menu {
                    Button(action: { viewModel.zipItems() }) {
                        Label(viewModel.loc.zipToStash, systemImage: "archivebox")
                    }
                    Button(action: { viewModel.exportAsZip() }) {
                        Label(viewModel.loc.exportAsZipEllipsis, systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "archivebox")
                        .font(.system(size: 14))
                        .frame(width: 36, height: 32)
                        .foregroundColor(Design.primaryText)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(viewModel.selectedItemIds.isEmpty ? viewModel.loc.zipAll : viewModel.loc.zipSelected)
            }
        }
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.title = viewModel.loc.chooseFiles

        if panel.runModal() == .OK {
            viewModel.importURLs(panel.urls)
        }
    }

    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        guard let items = pasteboard.pasteboardItems else { return }
        var urls: [URL] = []
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString) {
                urls.append(url)
            }
        }
        if !urls.isEmpty {
            viewModel.importURLs(urls)
        }
    }

    private func shareSelectedFiles() {
        let urls = viewModel.selectedItems.map { $0.stagedURL }
        guard !urls.isEmpty,
              let window = NSApplication.shared.windows.first(where: { $0.title == "Ny Mappe (7)" }),
              let contentView = window.contentView else { return }
        let picker = NSSharingServicePicker(items: urls)
        let rect = NSRect(x: contentView.bounds.midX - 1, y: contentView.bounds.midY, width: 2, height: 2)
        picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
    }
}

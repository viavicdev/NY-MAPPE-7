import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FinderShortcutsView: View {
    @ObservedObject var viewModel: StashViewModel

    @State private var dropTargeted: Bool = false

    private var shortcuts: [FinderShortcut] {
        viewModel.sortedFinderShortcuts
    }

    // Adaptive grid — ikontiles p\u{00E5} ca 72x72
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 72, maximum: 90), spacing: 10)]
    }

    var body: some View {
        ScrollView {
            if shortcuts.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(shortcuts) { shortcut in
                        shortcutTile(shortcut)
                    }
                }
                .padding(12)
            }
        }
        .background(
            dropTargeted ? Design.accent.opacity(0.06) : Color.clear
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    dropTargeted ? Design.accent.opacity(0.5) : Color.clear,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .padding(6)
        )
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
            return true
        }
    }

    // MARK: - Tile

    @ViewBuilder
    private func shortcutTile(_ shortcut: FinderShortcut) -> some View {
        Button(action: {
            viewModel.openFinderShortcut(shortcut)
        }) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Design.buttonTint)
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Design.buttonBorder, lineWidth: 0.5)
                        )

                    if !shortcut.emoji.isEmpty {
                        Text(shortcut.emoji)
                            .font(.system(size: 26))
                    } else {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Design.accent)
                    }
                }

                Text(shortcut.displayName)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(Design.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 72)
            }
        }
        .buttonStyle(.plain)
        .help("\u{00C5}pne \(shortcut.path)")
        .contextMenu {
            Button("\u{00C5}pne i Finder") {
                viewModel.openFinderShortcut(shortcut)
            }
            Button("Vis sti i Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([shortcut.url])
            }
            Divider()
            Button("Slett", role: .destructive) {
                withAnimation { viewModel.removeFinderShortcut(id: shortcut.id) }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 28, weight: .thin))
                .foregroundColor(Design.accent.opacity(0.5))
            Text("Ingen snarveier enn\u{00E5}")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Design.primaryText)
            Text("Dra en mappe hit, eller legg til snarveier i innstillinger.")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Design.subtleText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 24)
    }

    // MARK: - Drop handling

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async {
                    viewModel.addFinderShortcut(url: url)
                }
            }
        }
    }
}

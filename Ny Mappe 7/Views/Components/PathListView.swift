import SwiftUI

struct PathListView: View {
    @ObservedObject var viewModel: StashViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Path header
            if !viewModel.pathEntries.isEmpty {
                VStack(spacing: 4) {
                    HStack {
                        if !viewModel.selectedPathIds.isEmpty {
                            Text("\(viewModel.selectedPathIds.count) valgt")
                                .font(Design.captionFont)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Design.accent.opacity(0.15))
                                .foregroundColor(Design.accent)
                                .clipShape(Capsule())
                        }

                        Spacer()

                        // Select all / Deselect all
                        if viewModel.selectedPathIds.count == viewModel.pathEntries.count {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    viewModel.deselectAllPathEntries()
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 10))
                                    Text("Fjern valg")
                                        .font(Design.captionFont)
                                }
                                .foregroundColor(Design.subtleText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Design.buttonTint)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Design.buttonBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    viewModel.selectAllPathEntries()
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 10))
                                    Text("Velg alle")
                                        .font(Design.captionFont)
                                }
                                .foregroundColor(Design.subtleText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Design.buttonTint)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Design.buttonBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: {
                            withAnimation { viewModel.clearPathEntries() }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                Text("T\u{00F8}m")
                                    .font(Design.captionFont)
                            }
                            .foregroundColor(Design.subtleText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Design.buttonTint)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Design.buttonBorder, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .help("T\u{00F8}m alle (unntatt festede)")
                    }

                    // Action row when items are selected
                    if !viewModel.selectedPathIds.isEmpty {
                        HStack {
                            Spacer()

                            Button(action: {
                                viewModel.copySelectedPathEntries()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                    Text("Kopier paths")
                                        .font(Design.captionFont)
                                }
                            }
                            .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))
                            .help("Kopier valgte paths (en per linje)")
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            if viewModel.pathEntries.isEmpty {
                pathEmptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        let pinned = viewModel.pathEntries.filter { $0.isPinned }
                        let unpinned = viewModel.pathEntries.filter { !$0.isPinned }

                        if !pinned.isEmpty {
                            ForEach(pinned) { entry in
                                PathCard(
                                    entry: entry,
                                    isSelected: viewModel.selectedPathIds.contains(entry.id),
                                    viewModel: viewModel
                                )
                            }
                        }

                        ForEach(unpinned) { entry in
                            PathCard(
                                entry: entry,
                                isSelected: viewModel.selectedPathIds.contains(entry.id),
                                viewModel: viewModel
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pathEmptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Design.accent.opacity(0.10))
                    .frame(width: 100, height: 100)
                    .blur(radius: 25)

                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 42, weight: .thin))
                    .foregroundColor(Design.accent.opacity(0.5))
            }
            .frame(height: 90)

            VStack(spacing: 6) {
                Text("Dra mappe eller fil hit")
                    .font(Design.headingFont)
                    .foregroundColor(Design.primaryText)

                Text("Slipp en mappe/fil fra Finder\nfor \u{00E5} kopiere full path")
                    .font(Design.bodyFont)
                    .foregroundColor(Design.subtleText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct PathCard: View {
    let entry: PathEntry
    let isSelected: Bool
    @ObservedObject var viewModel: StashViewModel
    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name + icon
            HStack(spacing: 8) {
                Image(systemName: entry.icon)
                    .font(.system(size: 14))
                    .foregroundColor(entry.isDirectory ? Design.accent : Design.subtleText)

                Text(entry.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                    .lineLimit(1)

                Spacer()

                if showCopied {
                    Text("Kopiert!")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Design.accent)
                        .transition(.opacity.combined(with: .scale))
                }
            }

            // Path preview
            Text(entry.displayPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Design.subtleText)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Bottom row: time + actions
            HStack(spacing: 8) {
                Text(entry.timeAgo)
                    .font(Design.captionFont)
                    .foregroundColor(Design.subtleText)

                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Design.accent)
                }

                Spacer()

                if isHovered {
                    HStack(spacing: 6) {
                        Button(action: {
                            viewModel.copyPathEntry(entry)
                            withAnimation(.easeInOut(duration: 0.2)) { showCopied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation { showCopied = false }
                            }
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(Design.InlineActionStyle())
                        .help("Kopier path")

                        Button(action: {
                            viewModel.revealPathInFinder(entry)
                        }) {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(Design.InlineActionStyle())
                        .help("Vis i Finder")

                        Button(action: {
                            viewModel.togglePinPathEntry(entry)
                        }) {
                            Image(systemName: entry.isPinned ? "pin.slash" : "pin")
                        }
                        .buttonStyle(Design.InlineActionStyle())
                        .help(entry.isPinned ? "Fjern feste" : "Fest")

                        Button(action: {
                            withAnimation { viewModel.deletePathEntry(entry) }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(Design.InlineActionStyle())
                        .help("Slett")
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Design.cardCornerRadius)
                .fill(isSelected ? Design.accent.opacity(0.08) :
                      isHovered ? Design.cardHoverBackground : Design.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.cardCornerRadius)
                .stroke(isSelected ? Design.accent.opacity(0.5) :
                        entry.isPinned ? Design.accent.opacity(0.20) : Design.borderColor, lineWidth: isSelected ? 1.5 : 0.5)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                viewModel.togglePathSelection(entry.id)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

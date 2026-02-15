import SwiftUI

struct ClipboardListView: View {
    @ObservedObject var viewModel: StashViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            if !viewModel.clipboardEntries.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(Design.subtleText)
                    TextField(viewModel.loc.searchClipboard, text: $viewModel.clipboardSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !viewModel.clipboardSearchText.isEmpty {
                        Button(action: { viewModel.clipboardSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Design.subtleText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Design.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Design.borderColor, lineWidth: 0.5))
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            // Clipboard header (full mode: select/clear row + action row)
            if !viewModel.clipboardEntries.isEmpty && !viewModel.isLightVersion {
                VStack(spacing: 4) {
                    HStack {
                        if !viewModel.selectedClipboardIds.isEmpty {
                            Text(viewModel.loc.selected(viewModel.selectedClipboardIds.count))
                                .font(Design.captionFont)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Design.accent.opacity(0.15))
                                .foregroundColor(Design.accent)
                                .clipShape(Capsule())
                        }

                        Spacer()

                        if viewModel.selectedClipboardIds.count == viewModel.clipboardEntries.count {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    viewModel.deselectAllClipboardEntries()
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 10))
                                    Text(viewModel.loc.deselect)
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
                                    viewModel.selectAllClipboardEntries()
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 10))
                                    Text(viewModel.loc.selectAll)
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
                            withAnimation { viewModel.clearClipboardEntries() }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                Text(viewModel.loc.clear)
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

                    // Action row: copy + export buttons (when items selected)
                    if !viewModel.selectedClipboardIds.isEmpty {
                        HStack {
                            Spacer()

                            Button(action: {
                                viewModel.copySelectedClipboardEntries()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                    Text(viewModel.loc.copy)
                                        .font(Design.captionFont)
                                }
                            }
                            .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))

                            Button(action: {
                                viewModel.exportSelectedClipboardEntries()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 10))
                                    Text(".txt")
                                        .font(Design.captionFont)
                                }
                            }
                            .buttonStyle(Design.PillButtonStyle(isAccent: true))

                            Button(action: {
                                viewModel.exportSelectedClipboardEntriesAsCSV()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "tablecells")
                                        .font(.system(size: 10))
                                    Text(".csv")
                                        .font(Design.captionFont)
                                }
                            }
                            .buttonStyle(Design.PillButtonStyle(isAccent: true))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            // Simple mode: action row only (when selected)
            if !viewModel.clipboardEntries.isEmpty && viewModel.isLightVersion && !viewModel.selectedClipboardIds.isEmpty {
                HStack {
                    Text(viewModel.loc.selected(viewModel.selectedClipboardIds.count))
                        .font(Design.captionFont)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Design.accent.opacity(0.15))
                        .foregroundColor(Design.accent)
                        .clipShape(Capsule())

                    Spacer()

                    Button(action: {
                        viewModel.copySelectedClipboardEntries()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text(viewModel.loc.copy)
                                .font(Design.captionFont)
                        }
                    }
                    .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))

                    Button(action: {
                        viewModel.exportSelectedClipboardEntries()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 10))
                            Text(".txt")
                                .font(Design.captionFont)
                        }
                    }
                    .buttonStyle(Design.PillButtonStyle(isAccent: true))
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 2)
            }

            if viewModel.clipboardEntries.isEmpty {
                clipboardEmptyState
            } else {
                let filtered = viewModel.filteredClipboardEntries
                ScrollView {
                    LazyVStack(spacing: 8) {
                        let pinned = filtered.filter { $0.isPinned }
                        let unpinned = filtered.filter { !$0.isPinned }

                        if !pinned.isEmpty {
                            ForEach(pinned) { entry in
                                ClipboardCard(
                                    entry: entry,
                                    isSelected: viewModel.selectedClipboardIds.contains(entry.id),
                                    viewModel: viewModel
                                )
                            }
                        }

                        ForEach(unpinned) { entry in
                            ClipboardCard(
                                entry: entry,
                                isSelected: viewModel.selectedClipboardIds.contains(entry.id),
                                viewModel: viewModel
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }

                // Bottom action bar
                clipboardActionBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var clipboardActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Design.dividerColor)

            HStack(spacing: 8) {
                if !viewModel.selectedClipboardIds.isEmpty {
                    Text(viewModel.loc.selected(viewModel.selectedClipboardIds.count))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Design.accent.opacity(0.15))
                        .foregroundColor(Design.accent)
                        .clipShape(Capsule())
                }

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        if viewModel.selectedClipboardIds.count == viewModel.clipboardEntries.count {
                            viewModel.deselectAllClipboardEntries()
                        } else {
                            viewModel.selectAllClipboardEntries()
                        }
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: viewModel.selectedClipboardIds.count == viewModel.clipboardEntries.count ? "xmark.circle" : "checkmark.circle")
                            .font(.system(size: 9))
                        Text(viewModel.selectedClipboardIds.count == viewModel.clipboardEntries.count ? viewModel.loc.deselect : viewModel.loc.selectAll)
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(Design.PillButtonStyle())

                Button(action: {
                    withAnimation { viewModel.clearClipboardEntries() }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text(viewModel.loc.clear)
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(Design.PillButtonStyle(isDanger: true))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var clipboardEmptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Design.accent.opacity(0.10))
                    .frame(width: 100, height: 100)
                    .blur(radius: 25)

                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 42, weight: .thin))
                    .foregroundColor(Design.accent.opacity(0.5))
            }
            .frame(height: 90)

            VStack(spacing: 6) {
                Text(viewModel.loc.noClipsYet)
                    .font(Design.headingFont)
                    .foregroundColor(Design.primaryText)

                Text(viewModel.loc.copyWithCmdC)
                    .font(Design.bodyFont)
                    .foregroundColor(Design.subtleText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ClipboardCard: View {
    let entry: ClipboardEntry
    let isSelected: Bool
    @ObservedObject var viewModel: StashViewModel
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Text preview
            Text(entry.preview)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Design.primaryText)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Bottom row: timestamp + actions
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
                    HStack(spacing: 7) {
                        Button(action: {
                            viewModel.copyClipboardEntry(entry)
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(Design.InlineActionStyle())
                        .help(viewModel.loc.copyToClipboard)

                        Button(action: {
                            viewModel.togglePinClipboardEntry(entry)
                        }) {
                            Image(systemName: entry.isPinned ? "pin.slash" : "pin")
                        }
                        .buttonStyle(Design.InlineActionStyle())
                        .help(entry.isPinned ? viewModel.loc.unpin : viewModel.loc.pin)

                        Button(action: {
                            withAnimation { viewModel.deleteClipboardEntry(entry) }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .buttonStyle(Design.InlineActionStyle())
                        .help(viewModel.loc.delete)
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
                viewModel.toggleClipboardSelection(entry.id)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

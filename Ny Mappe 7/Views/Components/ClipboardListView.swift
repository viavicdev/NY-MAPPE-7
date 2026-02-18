import SwiftUI

struct ClipboardListView: View {
    @ObservedObject var viewModel: StashViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Clipboard header (full mode: select/clear row + action row)
            if !viewModel.clipboardEntries.isEmpty && !viewModel.isLightVersion {
                VStack(spacing: 4) {
                    HStack {
                        if !viewModel.selectedClipboardIds.isEmpty {
                            Text("\(viewModel.selectedClipboardIds.count) valgt")
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
                                    viewModel.selectAllClipboardEntries()
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
                            withAnimation { viewModel.clearClipboardEntries() }
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
                                    Text("Kopier")
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
                    Text("\(viewModel.selectedClipboardIds.count) valgt")
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
                            Text("Kopier")
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
                clipboardSearchBar

                let entries = viewModel.filteredClipboardEntries
                let pinned = entries.filter { $0.isPinned }
                let unpinned = entries.filter { !$0.isPinned }
                let allSorted = pinned + unpinned

                ScrollView {
                    let columns = [
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6)
                    ]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                        ForEach(allSorted) { entry in
                            ClipboardCard(
                                entry: entry,
                                isSelected: viewModel.selectedClipboardIds.contains(entry.id),
                                isCompact: viewModel.isLightVersion,
                                viewModel: viewModel
                            )
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)

                    if allSorted.isEmpty && !viewModel.clipboardSearchText.isEmpty {
                        Text("Ingen treff for \u{00AB}\(viewModel.clipboardSearchText)\u{00BB}")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(Design.subtleText)
                            .padding(.vertical, 12)
                    }
                }
            }

            if !viewModel.clipboardEntries.isEmpty {
                clipboardActionBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.clipboardSearchFocusTrigger) { _ in
            isSearchFocused = true
        }
    }

    private var clipboardActionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Design.dividerColor)

            HStack(spacing: 8) {
                if !viewModel.selectedClipboardIds.isEmpty {
                    Text("\(viewModel.selectedClipboardIds.count) valgt")
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
                        Text(viewModel.selectedClipboardIds.count == viewModel.clipboardEntries.count ? "Fjern valg" : "Velg alle")
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
                        Text("T\u{00F8}m")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(Design.PillButtonStyle(isDanger: true))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var clipboardSearchBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(Design.subtleText.opacity(0.5))

            TextField("S\u{00F8}k i utklipp\u{2026}", text: $viewModel.clipboardSearchText)
                .font(.system(size: 11, design: .rounded))
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            if !viewModel.clipboardSearchText.isEmpty {
                Button(action: { viewModel.clipboardSearchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Design.subtleText.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Design.buttonTint)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Design.borderColor, lineWidth: 0.5)
        )
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 2)
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
                Text("Ingen klipp enn\u{00E5}")
                    .font(Design.headingFont)
                    .foregroundColor(Design.primaryText)

                Text("Kopier tekst med \u{2318}C s\u{00E5} dukker det opp her")
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
    let isCompact: Bool
    @ObservedObject var viewModel: StashViewModel
    @State private var isHovered = false
    @State private var isExpanded = false
    @State private var showCopied = false

    private var charCount: Int {
        entry.text.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var isLongText: Bool {
        charCount > 60
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.preview)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(Design.primaryText)
                .lineLimit(isExpanded ? nil : 2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isLongText {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }) {
                    Text(isExpanded ? "Skjul" : "Les mer")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(Design.accent.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 4) {
                Text(entry.formattedDate)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundColor(Design.subtleText.opacity(0.5))

                Text("\(charCount) tegn")
                    .font(.system(size: 8, design: .rounded))
                    .foregroundColor(Design.subtleText.opacity(0.3))

                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 7))
                        .foregroundColor(Design.accent)
                }

                if showCopied {
                    Text("Kopiert!")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Design.accent)
                        .transition(.opacity)
                }

                Spacer()

                if isHovered {
                    HStack(spacing: 4) {
                        Button(action: {
                            viewModel.copyClipboardEntry(entry)
                            flashCopied()
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(Design.InlineActionStyle())
                        .help("Kopier")

                        Button(action: {
                            viewModel.togglePinClipboardEntry(entry)
                        }) {
                            Image(systemName: entry.isPinned ? "pin.slash" : "pin")
                        }
                        .buttonStyle(Design.InlineActionStyle())
                        .help(entry.isPinned ? "Fjern feste" : "Fest")

                        Button(action: {
                            withAnimation { viewModel.deleteClipboardEntry(entry) }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .medium))
                        }
                        .buttonStyle(Design.InlineActionStyle())
                        .help("Slett")
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(isSelected ? Design.accent.opacity(0.08) :
                      isHovered ? Design.cardHoverBackground : Design.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(isSelected ? Design.accent.opacity(0.5) :
                        entry.isPinned ? Design.accent.opacity(0.20) : Design.borderColor, lineWidth: isSelected ? 1.5 : 0.5)
        )
        .onTapGesture(count: 2) {
            viewModel.copyClipboardEntry(entry)
            flashCopied()
        }
        .onTapGesture(count: 1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                viewModel.toggleClipboardSelection(entry.id)
            }
        }
        .onDrag {
            NSItemProvider(object: entry.text as NSString)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(entry.text.prefix(300) + (entry.text.count > 300 ? "\u{2026}" : ""))
    }

    private func flashCopied() {
        withAnimation(.easeIn(duration: 0.1)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) { showCopied = false }
        }
    }
}

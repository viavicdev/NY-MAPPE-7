import SwiftUI
import AppKit

struct ClipboardListView: View {
    @ObservedObject var viewModel: StashViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var showNewGroupField: Bool = false
    @State private var newGroupName: String = ""
    @FocusState private var isNewGroupFocused: Bool
    @State private var renamingGroupId: UUID?
    @State private var renameGroupBuffer: String = ""
    @FocusState private var isRenameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Clipboard header (full mode: select/clear row + action row)
            if !viewModel.clipboardEntries.isEmpty && !viewModel.isLightVersion {
                let hasSelection = !viewModel.selectedClipboardIds.isEmpty
                VStack(spacing: 4) {
                    HStack {
                        // Venstre: selection chip fungerer som «Fjern valg»-knapp når noe er valgt
                        if hasSelection {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    viewModel.deselectAllClipboardEntries()
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Text("\(viewModel.selectedClipboardIds.count) valgt")
                                        .font(Design.captionFont)
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Design.accent.opacity(0.15))
                                .foregroundColor(Design.accent)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("Klikk for å fjerne valg")
                        }

                        Spacer()

                        // Høyre: Kopier (solid) når valgt, ellers Velg alle
                        if hasSelection {
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

                    // Action row: gruppe-kontroller + eksport-knapper
                    HStack(spacing: 6) {
                        if showNewGroupField {
                            TextField("Gruppenavn\u{2026}", text: $newGroupName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 10, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Design.buttonTint)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Design.accent.opacity(0.4), lineWidth: 0.6)
                                )
                                .focused($isNewGroupFocused)
                                .onSubmit { commitNewGroup() }
                                .frame(maxWidth: 120)
                            Button(action: { commitNewGroup() }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Design.accent)
                                    .padding(5)
                            }
                            .buttonStyle(.plain)
                            Button(action: {
                                showNewGroupField = false
                                newGroupName = ""
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Design.subtleText)
                                    .padding(5)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: {
                                showNewGroupField = true
                                isNewGroupFocused = true
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 10))
                                    Text("Gruppe")
                                        .font(Design.captionFont)
                                }
                                .foregroundColor(Design.subtleText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Design.buttonTint)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Design.buttonBorder, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .help("Lag ny gruppe")
                        }

                        if hasSelection && !viewModel.clipboardGroups.isEmpty {
                            Menu {
                                Button("Usortert") {
                                    viewModel.moveSelectedClipboardEntries(toGroup: nil)
                                }
                                Divider()
                                ForEach(viewModel.clipboardGroups.sorted { $0.sortIndex < $1.sortIndex }) { group in
                                    Button(group.name) {
                                        viewModel.moveSelectedClipboardEntries(toGroup: group.id)
                                    }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.right.to.line.compact")
                                        .font(.system(size: 10))
                                    Text("Flytt til")
                                        .font(Design.captionFont)
                                }
                                .foregroundColor(Design.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Design.accent.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        }

                        Spacer()

                        if hasSelection {
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

                            if viewModel.csvColumnBuilder == nil {
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

                                Button(action: {
                                    viewModel.startCSVColumnBuilder()
                                    viewModel.appendSelectedToCurrentCSVColumn()
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "tablecells.badge.ellipsis")
                                            .font(.system(size: 10))
                                        Text("CSV+")
                                            .font(Design.captionFont)
                                    }
                                }
                                .buttonStyle(Design.PillButtonStyle(isAccent: true))
                                .help("Bygg CSV kolonnevis \u{2014} fyll kolonne A, s\u{00E5} B, osv.")
                            }
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

            if viewModel.csvColumnBuilder != nil {
                csvBuilderBanner
            }

            if viewModel.clipboardEntries.isEmpty {
                clipboardEmptyState
            } else {
                clipboardSearchBar
                clipboardGroupedScroll
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

    // MARK: - CSV Column Builder Banner

    @ViewBuilder
    private var csvBuilderBanner: some View {
        if let builder = viewModel.csvColumnBuilder {
            let currentLetter = viewModel.columnLetter(for: builder.currentColumnIndex)
            let hasSelection = !viewModel.selectedClipboardIds.isEmpty
            let currentEmpty = builder.columns[builder.currentColumnIndex].isEmpty

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "tablecells.badge.ellipsis")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Design.accent)
                    Text("CSV-bygger \u{2014} n\u{00E5}v\u{00E6}rende: Kolonne \(currentLetter)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Design.primaryText)
                    Spacer()
                    // Live oversikt
                    HStack(spacing: 3) {
                        ForEach(Array(builder.columns.enumerated()), id: \.offset) { idx, col in
                            let letter = viewModel.columnLetter(for: idx)
                            Text("\(letter): \(col.count)")
                                .font(.system(size: 8, weight: idx == builder.currentColumnIndex ? .bold : .medium, design: .monospaced))
                                .foregroundColor(idx == builder.currentColumnIndex ? Design.accent : Design.subtleText)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(idx == builder.currentColumnIndex ? Design.accent.opacity(0.12) : Design.buttonTint)
                                .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: 5) {
                    Button(action: {
                        viewModel.appendSelectedToCurrentCSVColumn()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 9))
                            Text("Legg valgte i \(currentLetter)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                    }
                    .buttonStyle(Design.PillButtonStyle(isAccent: true))
                    .disabled(!hasSelection)
                    .opacity(hasSelection ? 1.0 : 0.5)

                    Button(action: {
                        viewModel.startNextCSVColumn()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9))
                            Text("Neste kolonne")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                    }
                    .buttonStyle(Design.PillButtonStyle())
                    .disabled(currentEmpty)
                    .opacity(currentEmpty ? 0.5 : 1.0)

                    Spacer()

                    Button(action: {
                        viewModel.finishCSVColumnBuilderAndExport()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                            Text("Ferdig")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                    }
                    .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))
                    .disabled(builder.totalEntries == 0)
                    .opacity(builder.totalEntries == 0 ? 0.5 : 1.0)

                    Button(action: {
                        viewModel.cancelCSVColumnBuilder()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Design.subtleText)
                            .padding(5)
                    }
                    .buttonStyle(.plain)
                    .help("Avbryt")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Design.accent.opacity(0.08))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Design.accent.opacity(0.3)),
                alignment: .bottom
            )
        }
    }

    private func commitNewGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            viewModel.createClipboardGroup(name: trimmed)
        }
        newGroupName = ""
        showNewGroupField = false
    }

    private func startRenameGroup(_ group: ClipboardGroup) {
        renamingGroupId = group.id
        renameGroupBuffer = group.name
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isRenameFocused = true
        }
    }

    private func commitRenameGroup() {
        guard let id = renamingGroupId else { return }
        viewModel.renameClipboardGroup(id: id, name: renameGroupBuffer)
        cancelRenameGroup()
    }

    private func cancelRenameGroup() {
        renamingGroupId = nil
        renameGroupBuffer = ""
    }

    // MARK: - Grouped Scroll (pinned + grouper + ingen gruppe)

    private struct GroupSection: Identifiable {
        let id: String          // "pinned", "none", eller UUID-string
        let groupId: UUID?      // nil for pinned eller "Ingen gruppe"
        let title: String
        let isPinnedSection: Bool
        let group: ClipboardGroup?
        let entries: [ClipboardEntry]
    }

    private var groupSections: [GroupSection] {
        let entries = viewModel.filteredClipboardEntries
        let newestTop = viewModel.clipboardNewestOnTop

        func ordered(_ items: [ClipboardEntry]) -> [ClipboardEntry] {
            newestTop ? items : Array(items.reversed())
        }

        var sections: [GroupSection] = []

        // 1. Pinned section (alltid \u{00F8}verst hvis noe er festet)
        let pinned = entries.filter { $0.isPinned }
        if !pinned.isEmpty {
            sections.append(GroupSection(
                id: "pinned",
                groupId: nil,
                title: "Festet",
                isPinnedSection: true,
                group: nil,
                entries: ordered(pinned)
            ))
        }

        // 2. Grupper (sortert p\u{00E5} sortIndex)
        let unpinnedAll = entries.filter { !$0.isPinned }
        let sortedGroups = viewModel.clipboardGroups.sorted { $0.sortIndex < $1.sortIndex }
        for group in sortedGroups {
            let groupEntries = unpinnedAll.filter { $0.groupId == group.id }
            sections.append(GroupSection(
                id: group.id.uuidString,
                groupId: group.id,
                title: group.name,
                isPinnedSection: false,
                group: group,
                entries: ordered(groupEntries)
            ))
        }

        // 3. Ingen gruppe (entries uten groupId, eller groupId som peker til slettet gruppe)
        let knownGroupIds = Set(viewModel.clipboardGroups.map { $0.id })
        let ungrouped = unpinnedAll.filter { entry in
            guard let gid = entry.groupId else { return true }
            return !knownGroupIds.contains(gid)
        }
        if !ungrouped.isEmpty || sections.isEmpty || !viewModel.clipboardGroups.isEmpty {
            sections.append(GroupSection(
                id: "none",
                groupId: nil,
                title: "Usortert",
                isPinnedSection: false,
                group: nil,
                entries: ordered(ungrouped)
            ))
        }

        return sections
    }

    private var clipboardGroupedScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                let sections = groupSections
                let orderedIds = sections.flatMap { $0.entries.map(\.id) }
                ForEach(sections) { section in
                    groupSectionView(section, orderedIds: orderedIds)
                }

                if sections.allSatisfy({ $0.entries.isEmpty }) && !viewModel.clipboardSearchText.isEmpty {
                    Text("Ingen treff for \u{00AB}\(viewModel.clipboardSearchText)\u{00BB}")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Design.subtleText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }

    @ViewBuilder
    private func groupSectionView(_ section: GroupSection, orderedIds: [UUID]) -> some View {
        // Aktiv-sjekk: en konkret gruppe er aktiv hvis IDen matcher,
        // OG "Ingen gruppe"-seksjonen er aktiv hvis activeClipboardGroupId == nil.
        // Pinned-seksjonen kan aldri være aktiv mål.
        let isActiveTarget: Bool = {
            if section.isPinnedSection { return false }
            if let groupId = section.group?.id {
                return groupId == viewModel.activeClipboardGroupId
            }
            // section.id == "none" → aktiv hvis activeClipboardGroupId er nil
            return section.id == "none" && viewModel.activeClipboardGroupId == nil
        }()
        let isExpanded = section.isPinnedSection ? true : viewModel.isClipboardGroupExpanded(section.groupId)

        VStack(alignment: .leading, spacing: 4) {
            groupHeader(section: section, isExpanded: isExpanded, isActiveTarget: isActiveTarget)

            if isExpanded {
                if section.entries.isEmpty {
                    Text(section.isPinnedSection ? "Ingen festede" : "Tom gruppe")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(Design.subtleText.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                } else if viewModel.clipboardViewMode == .list {
                    LazyVStack(spacing: 3) {
                        ForEach(section.entries) { entry in
                            ClipboardListRow(
                                entry: entry,
                                isSelected: viewModel.selectedClipboardIds.contains(entry.id),
                                orderedIds: orderedIds,
                                viewModel: viewModel
                            )
                        }
                    }
                } else {
                    // Grid med dynamisk antall kolonner styrt av size-slider
                    // size 0.0 = 3 kolonner (smal), 0.5 = 2 kolonner (standard), 1.0 = 1 kolonne (bred)
                    let colCount: Int = viewModel.clipboardViewSize < 0.33 ? 3
                        : viewModel.clipboardViewSize < 0.75 ? 2 : 1
                    let columns = Array(
                        repeating: GridItem(.flexible(), spacing: 6),
                        count: colCount
                    )
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                        ForEach(section.entries) { entry in
                            ClipboardCard(
                                entry: entry,
                                isSelected: viewModel.selectedClipboardIds.contains(entry.id),
                                isCompact: viewModel.isLightVersion,
                                orderedIds: orderedIds,
                                viewModel: viewModel
                            )
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func groupHeader(section: GroupSection, isExpanded: Bool, isActiveTarget: Bool) -> some View {
        // Pinned-seksjonen er ikke en mål-gruppe og skal ikke settes aktiv ved klikk.
        let canBeActive = !section.isPinnedSection

        HStack(spacing: 6) {
            if !section.isPinnedSection {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.toggleClipboardGroupExpanded(section.groupId)
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Design.subtleText)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Design.accent)
                    .frame(width: 12)
            }

            // Midtdel: enten inline rename eller klikkbart navn
            if let group = section.group, renamingGroupId == group.id {
                TextField("Gruppenavn", text: $renameGroupBuffer)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Design.buttonTint)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Design.accent.opacity(0.4), lineWidth: 0.6)
                    )
                    .focused($isRenameFocused)
                    .onSubmit { commitRenameGroup() }
                    .frame(maxWidth: 140)

                Button(action: { commitRenameGroup() }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Design.accent)
                        .padding(3)
                }
                .buttonStyle(.plain)

                Button(action: { cancelRenameGroup() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Design.subtleText)
                        .padding(3)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            } else {
                Button(action: {
                    guard canBeActive else { return }
                    if isActiveTarget {
                        viewModel.setActiveClipboardGroup(nil)
                    } else {
                        viewModel.setActiveClipboardGroup(section.group?.id)
                    }
                }) {
                    HStack(spacing: 6) {
                        Text(section.title)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(section.isPinnedSection ? Design.accent : Design.primaryText)

                        Text("\(section.entries.count)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(Design.subtleText)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Design.buttonTint)
                            .clipShape(Capsule())

                        if isActiveTarget {
                            Text("\u{25CF} Aktiv m\u{00E5}l")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(Design.accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Design.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(canBeActive
                    ? (isActiveTarget
                        ? "Aktiv m\u{00E5}l-gruppe \u{2014} klikk for \u{00E5} sl\u{00E5} av"
                        : "Klikk for \u{00E5} sette som aktiv m\u{00E5}l-gruppe. Dobbeltklikk for \u{00E5} gi nytt navn.")
                    : "")
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        if let group = section.group {
                            startRenameGroup(group)
                        }
                    }
                )
                .contextMenu {
                    if let group = section.group {
                        Button("Gi nytt navn\u{2026}") { startRenameGroup(group) }
                        Button(isActiveTarget ? "Sl\u{00E5} av aktiv m\u{00E5}l" : "Sett som aktiv m\u{00E5}l") {
                            viewModel.setActiveClipboardGroup(isActiveTarget ? nil : group.id)
                        }
                        Divider()
                        Button("Slett gruppe", role: .destructive) {
                            withAnimation { viewModel.deleteClipboardGroup(id: group.id) }
                        }
                    }
                }
            }

            // Kopier-gruppe-knapp (vises for alle ikke-pinned seksjoner som har items)
            if !section.isPinnedSection, renamingGroupId != section.group?.id {
                Button(action: {
                    viewModel.copyClipboardGroup(id: section.group?.id)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                        .padding(3)
                }
                .buttonStyle(.plain)
                .help("Kopier alle i denne gruppa")
                .disabled(section.entries.isEmpty)
                .opacity(section.entries.isEmpty ? 0.3 : 1.0)

                // T\u{00F8}m-seksjon-knapp (sletter alle items i gruppa, beholder selve gruppa)
                Button(action: {
                    withAnimation { viewModel.clearClipboardGroup(id: section.group?.id) }
                }) {
                    Image(systemName: "eraser")
                        .font(.system(size: 9))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                        .padding(3)
                }
                .buttonStyle(.plain)
                .help(section.group == nil
                      ? "T\u{00F8}m Usortert (sletter alle ugrupperte utklipp)"
                      : "T\u{00F8}m denne gruppa (sletter alle items, beholder gruppa)")
                .disabled(section.entries.isEmpty)
                .opacity(section.entries.isEmpty ? 0.3 : 1.0)
            }

            // Rename + slett (kun for ekte grupper, ikke under rename)
            if let group = section.group, renamingGroupId != group.id {
                Button(action: { startRenameGroup(group) }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                        .padding(3)
                }
                .buttonStyle(.plain)
                .help("Gi nytt navn")

                Button(action: {
                    withAnimation { viewModel.deleteClipboardGroup(id: group.id) }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                        .padding(3)
                }
                .buttonStyle(.plain)
                .help("Slett gruppe (items blir uten gruppe)")
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActiveTarget ? Design.accent.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActiveTarget ? Design.accent.opacity(0.4) : Color.clear, lineWidth: 1)
        )
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
        HStack(spacing: 6) {
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

            ViewControlsButton(
                mode: $viewModel.clipboardViewMode,
                size: $viewModel.clipboardViewSize,
                onChange: { viewModel.scheduleSave() }
            )
        }
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
    let orderedIds: [UUID]
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
        ZStack(alignment: .bottom) {
            // Fast innhold \u{2014} h\u{00F8}yden endres IKKE ved hover
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.preview)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(Design.primaryText)
                    .lineLimit(isExpanded ? nil : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)

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

                    if isLongText && !isExpanded {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) { isExpanded = true }
                        }) {
                            Text("Les mer")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundColor(Design.accent.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    if isLongText && isExpanded {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) { isExpanded = false }
                        }) {
                            Text("Skjul")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundColor(Design.accent.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    if showCopied {
                        Text("Kopiert!")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(Design.accent)
                            .transition(.opacity)
                    }

                    Spacer()
                }
            }

            // Hover-actions som overlay nederst til h\u{00F8}yre (p\u{00E5}virker IKKE korth\u{00F8}yden)
            if isHovered {
                HStack(spacing: 4) {
                    Spacer()
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
            let flags = NSApp.currentEvent?.modifierFlags ?? []
            withAnimation(.easeInOut(duration: 0.1)) {
                if flags.contains(.shift) {
                    viewModel.selectRangeInClipboard(to: entry.id, orderedIds: orderedIds)
                } else {
                    viewModel.toggleClipboardSelection(entry.id)
                }
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
        .contextMenu {
            Button("Kopier") {
                viewModel.copyClipboardEntry(entry)
            }
            Button(entry.isPinned ? "Fjern feste" : "Fest") {
                viewModel.togglePinClipboardEntry(entry)
            }
            if !viewModel.contextBundles.isEmpty {
                Menu("Legg til som snippet i bundle") {
                    ForEach(viewModel.contextBundles.sorted { $0.sortIndex < $1.sortIndex }) { bundle in
                        Button(bundle.name) {
                            _ = viewModel.addTextToBundle(
                                bundleId: bundle.id,
                                title: "",
                                body: entry.text
                            )
                            viewModel.showToast("Lagt til i \(bundle.name)")
                        }
                    }
                }
            }
            Divider()
            Button("Slett", role: .destructive) {
                viewModel.deleteClipboardEntry(entry)
            }
        }
    }

    private func flashCopied() {
        withAnimation(.easeIn(duration: 0.1)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) { showCopied = false }
        }
    }
}

/// Kompakt enkel-linje-rad for liste-visning av et utklipp.
struct ClipboardListRow: View {
    let entry: ClipboardEntry
    let isSelected: Bool
    let orderedIds: [UUID]
    @ObservedObject var viewModel: StashViewModel

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 7))
                    .foregroundColor(Design.accent)
                    .frame(width: 10)
            } else {
                Spacer().frame(width: 10)
            }

            Text(entry.preview)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Design.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 6)

            Text(entry.formattedDate)
                .font(.system(size: 8, design: .rounded))
                .foregroundColor(Design.subtleText.opacity(0.6))

            if isHovered {
                Button(action: { viewModel.copyClipboardEntry(entry) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                }
                .buttonStyle(Design.InlineActionStyle())
                .help("Kopier")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Design.accent.opacity(0.12) : (isHovered ? Design.cardHoverBackground : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isSelected ? Design.accent.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            viewModel.copyClipboardEntry(entry)
        }
        .onTapGesture(count: 1) {
            let flags = NSApp.currentEvent?.modifierFlags ?? []
            withAnimation(.easeInOut(duration: 0.1)) {
                if flags.contains(.shift) {
                    viewModel.selectRangeInClipboard(to: entry.id, orderedIds: orderedIds)
                } else {
                    viewModel.toggleClipboardSelection(entry.id)
                }
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onDrag { NSItemProvider(object: entry.text as NSString) }
        .help(entry.text.prefix(300) + (entry.text.count > 300 ? "\u{2026}" : ""))
    }
}

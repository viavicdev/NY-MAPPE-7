import SwiftUI

struct SheetsCollectorView: View {
    @ObservedObject var viewModel: StashViewModel
    @State private var isExpanded = true
    @State private var showInfoPopover = false

    private let columnLabels = ["A", "B", "C", "D"]

    var body: some View {
        VStack(spacing: 0) {
            collectorHeader
            if isExpanded {
                collectorBody
            }
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Design.dividerColor)
        }
    }

    // MARK: - Header

    private var collectorHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "tablecells")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Design.accent)

            Text("Sheets")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Design.primaryText)

            columnCountPicker
            pasteColumnSelector

            Spacer()

            if viewModel.sheetsRowCount > 0 {
                Text("\(viewModel.sheetsRowCount) rad\(viewModel.sheetsRowCount == 1 ? "" : "er")")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Design.subtleText)
            }

            autoPasteToggle
            infoButton

            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(Design.InlineActionStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Design.accent.opacity(0.04))
    }

    // MARK: - Column Count Picker

    private var columnCountPicker: some View {
        HStack(spacing: 2) {
            ForEach(2...4, id: \.self) { count in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        viewModel.setSheetsColumnCount(count)
                    }
                }) {
                    Text("\(count)")
                        .font(.system(size: 10, weight: viewModel.sheetsColumnCount == count ? .bold : .medium, design: .rounded))
                        .frame(width: 22, height: 20)
                        .background(viewModel.sheetsColumnCount == count ? Design.accent.opacity(0.15) : Design.buttonTint)
                        .foregroundColor(viewModel.sheetsColumnCount == count ? Design.accent : Design.subtleText)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Design.buttonTint.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Paste Column Selector

    private var pasteColumnSelector: some View {
        HStack(spacing: 2) {
            Image(systemName: "clipboard")
                .font(.system(size: 8))
                .foregroundColor(Design.subtleText.opacity(0.5))

            ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        viewModel.sheetsPasteColumn = col
                    }
                }) {
                    Text(columnLabels[col])
                        .font(.system(size: 9, weight: viewModel.sheetsPasteColumn == col ? .bold : .medium, design: .rounded))
                        .frame(width: 18, height: 18)
                        .background(viewModel.sheetsPasteColumn == col ? Design.accent.opacity(0.2) : Color.clear)
                        .foregroundColor(viewModel.sheetsPasteColumn == col ? Design.accent : Design.subtleText)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Design.buttonTint.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .help("Lim-inn-kolonne: kopiert tekst havner i \(columnLabels[viewModel.sheetsPasteColumn])")
    }

    // MARK: - Auto-Paste Toggle

    private var autoPasteToggle: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.sheetsAutoPaste.toggle()
            }
        }) {
            HStack(spacing: 3) {
                Image(systemName: viewModel.sheetsAutoPaste ? "clipboard.fill" : "clipboard")
                    .font(.system(size: 9))
                Text(viewModel.sheetsAutoPaste ? "P\u{00E5}" : "Av")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(viewModel.sheetsAutoPaste ? Design.accent.opacity(0.12) : Design.buttonTint)
            .foregroundColor(viewModel.sheetsAutoPaste ? Design.accent : Design.subtleText)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(viewModel.sheetsAutoPaste ? "Auto-lim er p\u{00E5}: kopiert tekst legges i kolonne \(columnLabels[viewModel.sheetsPasteColumn])" : "Auto-lim er av: skriv manuelt i alle celler")
    }

    // MARK: - Info Button

    private var infoButton: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(Design.subtleText.opacity(0.4))
            .onHover { hovering in
                showInfoPopover = hovering
            }
            .popover(isPresented: $showInfoPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "clipboard.fill", title: "Auto-lim",
                            desc: "N\u{00E5}r p\u{00E5}: kopiert tekst havner automatisk i valgt kolonne. Ny rad opprettes automatisk.")
                    infoRow(icon: "keyboard", title: "Manuell redigering",
                            desc: "Klikk i hvilken som helst celle for \u{00E5} skrive eller redigere. Fungerer alltid, uavhengig av auto-lim.")
                    infoRow(icon: "arrow.left.arrow.right", title: "Lim-inn-kolonne",
                            desc: "Velg hvilken kolonne som mottar kopiert tekst med A/B/C/D-knappene.")
                }
                .padding(12)
                .frame(width: 260)
            }
    }

    private func infoRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Design.accent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                Text(desc)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(Design.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Body

    private var collectorBody: some View {
        VStack(spacing: 4) {
            gridHeaders
                .padding(.horizontal, 12)

            ScrollView {
                VStack(spacing: 4) {
                    gridRows
                }
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: 200)

            actionButtons
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
    }

    // MARK: - Grid Headers

    private var gridHeaders: some View {
        HStack(spacing: 4) {
            ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                HStack(spacing: 3) {
                    Text(columnLabels[col])
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                    if col == viewModel.sheetsPasteColumn && viewModel.sheetsAutoPaste {
                        Image(systemName: "clipboard")
                            .font(.system(size: 7))
                    }
                }
                .foregroundColor(col == viewModel.sheetsPasteColumn && viewModel.sheetsAutoPaste ? Design.accent : Design.subtleText.opacity(0.6))
                .frame(maxWidth: .infinity)
            }
            Spacer().frame(width: 16)
        }
        .padding(.top, 4)
    }

    // MARK: - Grid Rows

    private var gridRows: some View {
        ForEach(0..<viewModel.sheetsGrid.count, id: \.self) { rowIdx in
            HStack(spacing: 4) {
                ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                    gridCell(row: rowIdx, col: col)
                }
                if isRowFilled(rowIdx) {
                    deleteRowButton { viewModel.removeSheetsRow(at: rowIdx) }
                } else {
                    Spacer().frame(width: 16)
                }
            }
        }
    }

    private func isRowFilled(_ rowIdx: Int) -> Bool {
        guard rowIdx < viewModel.sheetsGrid.count else { return false }
        return viewModel.sheetsGrid[rowIdx].contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func gridCell(row: Int, col: Int) -> some View {
        let isPasteTarget = col == viewModel.sheetsPasteColumn && viewModel.sheetsAutoPaste
        let isEmpty = viewModel.sheetsGrid[row][col].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isLastRow = row == viewModel.sheetsGrid.count - 1

        return ZStack(alignment: .leading) {
            if isEmpty && isLastRow {
                Text(isPasteTarget ? "limer inn\u{2026}" : "skriv\u{2026}")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(isPasteTarget ? Design.accent.opacity(0.3) : Design.subtleText.opacity(0.2))
                    .padding(.horizontal, 6)
            }
            TextField("", text: Binding(
                get: { viewModel.sheetsGrid[row][col] },
                set: { newVal in
                    viewModel.sheetsGrid[row][col] = newVal
                    viewModel.ensureEmptyLastRow()
                }
            ))
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isPasteTarget && isEmpty && isLastRow ? Design.accent.opacity(0.04) : Design.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isPasteTarget ? Design.accent.opacity(isEmpty ? 0.25 : 0.4) : Design.borderColor,
                    lineWidth: isPasteTarget ? 1 : 0.5
                )
        )
    }

    // MARK: - Actions

    private var actionButtons: some View {
        Group {
            if viewModel.sheetsRowCount > 0 {
                HStack(spacing: 6) {
                    Spacer()

                    Button(action: {
                        withAnimation { viewModel.clearSheetsData() }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                            Text("T\u{00F8}m")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(Design.PillButtonStyle(isDanger: true))

                    Button(action: {
                        viewModel.exportSheetsAsCSV()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 9))
                            Text(".csv")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(Design.PillButtonStyle(isAccent: true))

                    Button(action: {
                        viewModel.copySheetsToClipboard()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 9))
                            Text("Kopier")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))
                }
                .padding(.top, 4)
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Helpers

    private func deleteRowButton(action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { action() }
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Design.subtleText.opacity(0.5))
        }
        .buttonStyle(.plain)
        .frame(width: 16)
    }
}

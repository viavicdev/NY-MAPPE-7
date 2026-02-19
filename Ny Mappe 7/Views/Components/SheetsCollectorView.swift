import SwiftUI

struct SheetsCollectorView: View {
    @ObservedObject var viewModel: StashViewModel
    @State private var isExpanded = true
    @State private var showSettings = false

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

    // MARK: - Header (clean)

    private var collectorHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "tablecells")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Design.accent)

            Text("Sheets")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Design.primaryText)

            statusPill

            Spacer()

            if viewModel.sheetsRowCount > 0 {
                Text("\(viewModel.sheetsRowCount) rad\(viewModel.sheetsRowCount == 1 ? "" : "er")")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Design.subtleText)
            }

            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Design.subtleText)
            }
            .buttonStyle(Design.InlineActionStyle())
            .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                sheetsSettingsPopover
            }

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

    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.sheetsAutoPaste ? Design.accent : Design.subtleText.opacity(0.3))
                .frame(width: 5, height: 5)
            Text("\(viewModel.sheetsColumnCount) kol")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(Design.subtleText)
            Text("\u{00B7}")
                .foregroundColor(Design.subtleText.opacity(0.3))
            Text(viewModel.sheetsAutoPaste ? "limer i \(columnLabels[viewModel.sheetsPasteColumn])" : "manuell")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(viewModel.sheetsAutoPaste ? Design.accent : Design.subtleText)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Design.buttonTint.opacity(0.5))
        .clipShape(Capsule())
    }

    // MARK: - Settings Popover

    private var sheetsSettingsPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sheets-innstillinger")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Design.primaryText)

            // Column count
            VStack(alignment: .leading, spacing: 5) {
                Text("Antall kolonner")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.primaryText)

                HStack(spacing: 4) {
                    ForEach(2...4, id: \.self) { count in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                viewModel.setSheetsColumnCount(count)
                            }
                        }) {
                            Text("\(count)")
                                .font(.system(size: 11, weight: viewModel.sheetsColumnCount == count ? .bold : .medium, design: .rounded))
                                .frame(width: 36, height: 28)
                                .background(viewModel.sheetsColumnCount == count ? Design.accent.opacity(0.15) : Design.buttonTint)
                                .foregroundColor(viewModel.sheetsColumnCount == count ? Design.accent : Design.subtleText)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // Auto-paste
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-lim fra utklipp")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Design.primaryText)
                        Text("Kopiert tekst legges automatisk i valgt kolonne")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(Design.subtleText.opacity(0.6))
                    }
                    Spacer()
                    Toggle("", isOn: $viewModel.sheetsAutoPaste)
                        .toggleStyle(.switch)
                        .scaleEffect(0.7)
                }

                if viewModel.sheetsAutoPaste {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lim-inn-kolonne")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Design.subtleText)

                        HStack(spacing: 4) {
                            ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        viewModel.sheetsPasteColumn = col
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        if viewModel.sheetsPasteColumn == col {
                                            Image(systemName: "clipboard.fill")
                                                .font(.system(size: 8))
                                        }
                                        Text(columnLabels[col])
                                            .font(.system(size: 11, weight: viewModel.sheetsPasteColumn == col ? .bold : .medium, design: .rounded))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(viewModel.sheetsPasteColumn == col ? Design.accent.opacity(0.15) : Design.buttonTint)
                                    .foregroundColor(viewModel.sheetsPasteColumn == col ? Design.accent : Design.subtleText)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Divider()

            // How it works
            VStack(alignment: .leading, spacing: 8) {
                Text("Slik fungerer det")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.primaryText)

                howToRow(step: "1", text: "Kopier tekst med \u{2318}C \u{2014} den havner automatisk i valgt kolonne")
                howToRow(step: "2", text: "Klikk i hvilken som helst celle for \u{00E5} skrive eller redigere manuelt")
                howToRow(step: "3", text: "Nye rader opprettes automatisk n\u{00E5}r du fyller inn data")
                howToRow(step: "4", text: "Trykk \u{00AB}Kopier\u{00BB} for \u{00E5} lime rett inn i Google Sheets, eller eksporter som .csv")
            }

            Divider()

            // Tips
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow.opacity(0.8))
                Text("Tips: Skru av auto-lim hvis du bare vil skrive manuelt i alle kolonner.")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(Design.subtleText.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !viewModel.openAIKey.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(Design.accent)
                    Text("AI-filnavn er aktivert \u{2014} eksporterte filer f\u{00E5}r automatisk forslag til navn.")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(Design.accent.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private func howToRow(step: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(step)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Design.accent.opacity(0.6))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Design.subtleText)
                .fixedSize(horizontal: false, vertical: true)
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

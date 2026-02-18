import SwiftUI

struct SheetsCollectorView: View {
    @ObservedObject var viewModel: StashViewModel
    @State private var isExpanded = true

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
            if viewModel.sheetsInputMode == .auto {
                fillModePicker
            }
            inputModePicker

            Spacer()

            if viewModel.sheetsRowCount > 0 {
                Text("\(viewModel.sheetsRowCount) rad\(viewModel.sheetsRowCount == 1 ? "" : "er")")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Design.subtleText)
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

    // MARK: - Fill Mode Picker

    private var fillModePicker: some View {
        HStack(spacing: 2) {
            Button(action: {
                if viewModel.sheetsFillByColumn {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.toggleSheetsFillMode()
                    }
                }
            }) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 22, height: 20)
                    .background(!viewModel.sheetsFillByColumn ? Design.accent.opacity(0.15) : Design.buttonTint)
                    .foregroundColor(!viewModel.sheetsFillByColumn ? Design.accent : Design.subtleText)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Rad for rad")

            Button(action: {
                if !viewModel.sheetsFillByColumn {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.toggleSheetsFillMode()
                    }
                }
            }) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 22, height: 20)
                    .background(viewModel.sheetsFillByColumn ? Design.accent.opacity(0.15) : Design.buttonTint)
                    .foregroundColor(viewModel.sheetsFillByColumn ? Design.accent : Design.subtleText)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Kolonne for kolonne")
        }
        .padding(2)
        .background(Design.buttonTint.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Input Mode Picker

    private var inputModePicker: some View {
        HStack(spacing: 2) {
            inputModeButton(
                mode: .auto,
                icon: "clipboard",
                label: "Auto"
            )
            .help("Alle kolonner fylles automatisk fra utklippstavlen")

            inputModeButton(
                mode: .mixed,
                icon: "keyboard.badge.ellipsis",
                label: "Miks"
            )
            .help("E\u{00E9}n kolonne fra utklipp, resten skriver du manuelt")

            inputModeButton(
                mode: .manual,
                icon: "keyboard",
                label: "Manuell"
            )
            .help("Skriv i alle kolonner manuelt")

            infoButton
        }
        .padding(2)
        .background(Design.buttonTint.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func inputModeButton(mode: StashViewModel.SheetsInputMode, icon: String, label: String) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.setSheetsInputMode(mode)
            }
        }) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(label)
                    .font(.system(size: 9, weight: viewModel.sheetsInputMode == mode ? .bold : .medium, design: .rounded))
            }
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(viewModel.sheetsInputMode == mode ? Design.accent.opacity(0.15) : Design.buttonTint)
            .foregroundColor(viewModel.sheetsInputMode == mode ? Design.accent : Design.subtleText)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    @State private var showInfoPopover = false

    private var infoButton: some View {
        Button(action: { showInfoPopover.toggle() }) {
            Image(systemName: "info.circle")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Design.subtleText.opacity(0.5))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInfoPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "clipboard", title: "Auto",
                        desc: "Kopier tekst \u{2014} alle kolonner fylles automatisk fra utklippstavlen.")
                infoRow(icon: "keyboard.badge.ellipsis", title: "Miks",
                        desc: "E\u{00E9}n kolonne fylles fra utklipp, resten skriver du selv. Trykk \u{00AB}Legg til\u{00BB} for \u{00E5} lagre raden.")
                infoRow(icon: "keyboard", title: "Manuell",
                        desc: "Skriv i alle kolonner manuelt. Trykk \u{00AB}Legg til\u{00BB} eller Enter for \u{00E5} lagre.")
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
        VStack(spacing: 6) {
            switch viewModel.sheetsInputMode {
            case .auto:
                if viewModel.sheetsFillByColumn {
                    columnModeHeaders
                    if viewModel.sheetsTotalEntries == 0 {
                        columnModeEmptyHint
                    } else {
                        columnModeRows
                        actionButtons
                    }
                } else {
                    rowModeHeaders
                    if viewModel.sheetsRows.isEmpty && viewModel.sheetsCurrentRow.isEmpty {
                        rowModeEmptyHint
                    } else {
                        rowModeCompletedRows
                        rowModeCurrentRow
                        actionButtons
                    }
                }
            case .mixed:
                mixedModeView
            case .manual:
                manualModeView
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Mixed Mode

    private var mixedModeView: some View {
        VStack(spacing: 6) {
            rowModeHeaders

            if !viewModel.sheetsRows.isEmpty {
                ForEach(Array(viewModel.sheetsRows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 4) {
                        ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                            let value = col < row.count ? row[col] : ""
                            cellView(value, filled: true)
                        }
                        deleteRowButton { viewModel.removeSheetsRow(at: index) }
                    }
                }
            }

            mixedInputRow
            addRowButton { viewModel.commitMixedRow() }

            if !viewModel.sheetsRows.isEmpty {
                actionButtons
            }
        }
    }

    private var mixedInputRow: some View {
        HStack(spacing: 4) {
            ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                if col == viewModel.sheetsPasteColumn {
                    pasteIndicatorField(col: col)
                } else {
                    editableField(col: col)
                }
            }
            pasteColumnToggle
        }
    }

    private func pasteIndicatorField(col: Int) -> some View {
        ZStack(alignment: .leading) {
            if viewModel.sheetsManualInputs[col].isEmpty {
                Text("Limer inn her\u{2026}")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(Design.accent.opacity(0.4))
                    .padding(.horizontal, 6)
            }
            TextField("", text: $viewModel.sheetsManualInputs[col])
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Design.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private func editableField(col: Int) -> some View {
        ZStack(alignment: .leading) {
            if viewModel.sheetsManualInputs[col].isEmpty {
                Text("Skriv\u{2026}")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(Design.subtleText.opacity(0.3))
                    .padding(.horizontal, 6)
            }
            TextField("", text: $viewModel.sheetsManualInputs[col], onCommit: {
                if viewModel.sheetsInputMode == .mixed {
                    viewModel.commitMixedRow()
                } else {
                    viewModel.commitManualRow()
                }
            })
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Design.borderColor, lineWidth: 0.5)
        )
    }

    private var pasteColumnToggle: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                viewModel.sheetsPasteColumn = (viewModel.sheetsPasteColumn + 1) % viewModel.sheetsColumnCount
            }
        }) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Design.accent.opacity(0.6))
        }
        .buttonStyle(.plain)
        .frame(width: 16)
        .help("Bytt hvilken kolonne som mottar utklipp (\(columnLabels[viewModel.sheetsPasteColumn]))")
    }

    private func addRowButton(action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { action() }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                Text("Legg til")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
        }
        .buttonStyle(Design.PillButtonStyle(isAccent: true))
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Manual Mode

    private var manualModeView: some View {
        VStack(spacing: 6) {
            rowModeHeaders

            if !viewModel.sheetsRows.isEmpty {
                ForEach(Array(viewModel.sheetsRows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 4) {
                        ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                            let value = col < row.count ? row[col] : ""
                            cellView(value, filled: true)
                        }
                        deleteRowButton { viewModel.removeSheetsRow(at: index) }
                    }
                }
            }

            manualInputRow
            addRowButton { viewModel.commitManualRow() }

            if !viewModel.sheetsRows.isEmpty {
                actionButtons
            }
        }
    }

    private var manualInputRow: some View {
        HStack(spacing: 4) {
            ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                editableField(col: col)
            }
            Spacer().frame(width: 16)
        }
    }

    // MARK: - Row Mode (fill row by row →)

    private var rowModeHeaders: some View {
        HStack(spacing: 4) {
            ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                Text(columnLabels[col])
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Design.subtleText.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
    }

    private var rowModeCompletedRows: some View {
        ForEach(Array(viewModel.sheetsRows.enumerated()), id: \.offset) { index, row in
            HStack(spacing: 4) {
                ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                    let value = col < row.count ? row[col] : ""
                    cellView(value, filled: true)
                }
                deleteRowButton { viewModel.removeSheetsRow(at: index) }
            }
        }
    }

    @ViewBuilder
    private var rowModeCurrentRow: some View {
        let filled = viewModel.sheetsCurrentRow.count
        if filled > 0 && filled < viewModel.sheetsColumnCount {
            HStack(spacing: 4) {
                ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                    if col < filled {
                        cellView(viewModel.sheetsCurrentRow[col], filled: true, isPartial: true)
                    } else {
                        nextIndicatorCell(isNext: col == filled)
                    }
                }
                Spacer().frame(width: 16)
            }
        }
    }

    private var rowModeEmptyHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.right.circle")
                .font(.system(size: 11))
                .foregroundColor(Design.subtleText.opacity(0.4))
            Text("Kopier tekst \u{2014} fyller \(columnLabels[0]) f\u{00F8}rst, s\u{00E5} \(columnLabels[1])")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(Design.subtleText.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Column Mode (fill column by column ↓)

    private var columnModeHeaders: some View {
        HStack(spacing: 4) {
            ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        viewModel.setSheetsActiveColumn(col)
                    }
                }) {
                    HStack(spacing: 3) {
                        Text(columnLabels[col])
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                        if col < viewModel.sheetsColumnData.count {
                            let count = viewModel.sheetsColumnData[col].count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 14, height: 14)
                                    .background(col == viewModel.sheetsActiveColumnIndex ? Design.accent : Design.subtleText.opacity(0.4))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(col == viewModel.sheetsActiveColumnIndex ? Design.accent.opacity(0.10) : Color.clear)
                    .foregroundColor(col == viewModel.sheetsActiveColumnIndex ? Design.accent : Design.subtleText.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(col == viewModel.sheetsActiveColumnIndex ? Design.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private var columnModeRows: some View {
        let maxRows = viewModel.sheetsColumnData.map { $0.count }.max() ?? 0
        return ForEach(0..<maxRows, id: \.self) { rowIdx in
            HStack(spacing: 4) {
                ForEach(0..<viewModel.sheetsColumnCount, id: \.self) { col in
                    if col < viewModel.sheetsColumnData.count && rowIdx < viewModel.sheetsColumnData[col].count {
                        cellView(viewModel.sheetsColumnData[col][rowIdx], filled: true)
                    } else {
                        emptyCell
                    }
                }
                deleteRowButton { viewModel.removeSheetsRow(at: rowIdx) }
            }
        }
    }

    private var columnModeEmptyHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 11))
                .foregroundColor(Design.subtleText.opacity(0.4))
            Text("Kopier tekst \u{2014} fyller kolonne \(columnLabels[viewModel.sheetsActiveColumnIndex]) nedover")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(Design.subtleText.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 6) {
            if viewModel.sheetsFillByColumn && viewModel.sheetsActiveColumnIndex < viewModel.sheetsColumnCount - 1 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        viewModel.advanceSheetsColumn()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                        Text("Neste: \(columnLabels[viewModel.sheetsActiveColumnIndex + 1])")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(Design.PillButtonStyle())
            }

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

    // MARK: - Shared Cell Components

    private func cellView(_ text: String, filled: Bool, isPartial: Bool = false) -> some View {
        Text(truncate(text, max: 30))
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(Design.primaryText)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(isPartial ? Design.accent.opacity(0.06) : Design.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isPartial ? Design.accent.opacity(0.2) : Design.borderColor, lineWidth: 0.5)
            )
    }

    private func nextIndicatorCell(isNext: Bool) -> some View {
        HStack(spacing: 3) {
            if isNext {
                Circle()
                    .fill(Design.accent.opacity(0.4))
                    .frame(width: 5, height: 5)
            }
            Text(isNext ? "neste" : "")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(Design.subtleText.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Design.buttonTint.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Design.borderColor.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
        )
    }

    private var emptyCell: some View {
        Text("")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(Design.buttonTint.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Design.borderColor.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            )
    }

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

    private func truncate(_ text: String, max: Int) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        if cleaned.count > max {
            return String(cleaned.prefix(max)) + "\u{2026}"
        }
        return cleaned
    }
}

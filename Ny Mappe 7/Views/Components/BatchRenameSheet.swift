import SwiftUI

struct BatchRenameSheet: View {
    @ObservedObject var viewModel: StashViewModel
    @Binding var isPresented: Bool

    @State private var prefix: String = "fil"
    @State private var startNumber: Int = 1
    @State private var padDigits: Int = 3
    @State private var separator: String = "_"

    private var previewNames: [(id: UUID, oldName: String, newName: String)] {
        let items = viewModel.selectedItems
        return items.enumerated().map { (index, item) in
            let number = startNumber + index
            let padded = String(format: "%0\(padDigits)d", number)
            let newName = "\(prefix)\(separator)\(padded).\(item.ext)"
            return (id: item.id, oldName: item.fileName, newName: newName)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(viewModel.loc.renameFiles(viewModel.selectedItemIds.count))
                .font(Design.headingFont)
                .foregroundColor(Design.primaryText)

            VStack(spacing: 10) {
                HStack {
                    Text(viewModel.loc.prefixLabel)
                        .font(Design.bodyFont)
                        .foregroundColor(Design.subtleText)
                        .frame(width: 80, alignment: .trailing)
                    TextField(viewModel.loc.prefixPlaceholder, text: $prefix)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                }

                HStack {
                    Text(viewModel.loc.separatorLabel)
                        .font(Design.bodyFont)
                        .foregroundColor(Design.subtleText)
                        .frame(width: 80, alignment: .trailing)
                    Picker("", selection: $separator) {
                        Text(viewModel.loc.underscore).tag("_")
                        Text(viewModel.loc.hyphen).tag("-")
                        Text(viewModel.loc.period).tag(".")
                        Text(viewModel.loc.space).tag(" ")
                    }
                    .frame(width: 150)
                }

                HStack {
                    Text(viewModel.loc.startNumber)
                        .font(Design.bodyFont)
                        .foregroundColor(Design.subtleText)
                        .frame(width: 80, alignment: .trailing)
                    TextField("1", value: $startNumber, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)

                    Text(viewModel.loc.digits)
                        .font(Design.bodyFont)
                        .foregroundColor(Design.subtleText)
                    Picker("", selection: $padDigits) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                    }
                    .frame(width: 60)
                }
            }

            // Preview
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.loc.preview)
                    .font(Design.captionFont)
                    .foregroundColor(Design.subtleText)

                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(previewNames, id: \.id) { item in
                            HStack(spacing: 8) {
                                Text(item.oldName)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Design.subtleText)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundColor(Design.accent)

                                Text(item.newName)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(Design.primaryText)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
            .padding()
            .background(Design.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Design.borderColor, lineWidth: 0.5)
            )

            HStack(spacing: 12) {
                Button(viewModel.loc.cancel) {
                    isPresented = false
                }
                .buttonStyle(Design.PillButtonStyle())

                Button(viewModel.loc.rename) {
                    let names = previewNames
                    viewModel.batchRename(names.map { ($0.id, $0.newName) })
                    isPresented = false
                }
                .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))
                .disabled(prefix.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 300)
    }
}

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
            Text("Gi nytt navn til \(viewModel.selectedItemIds.count) filer")
                .font(Design.headingFont)
                .foregroundColor(Design.primaryText)

            VStack(spacing: 10) {
                HStack {
                    Text("Prefiks:")
                        .font(Design.bodyFont)
                        .foregroundColor(Design.subtleText)
                        .frame(width: 80, alignment: .trailing)
                    TextField("prefiks", text: $prefix)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                }

                HStack {
                    Text("Skilletegn:")
                        .font(Design.bodyFont)
                        .foregroundColor(Design.subtleText)
                        .frame(width: 80, alignment: .trailing)
                    Picker("", selection: $separator) {
                        Text("_ (understrek)").tag("_")
                        Text("- (bindestrek)").tag("-")
                        Text(". (punktum)").tag(".")
                        Text("  (mellomrom)").tag(" ")
                    }
                    .frame(width: 150)
                }

                HStack {
                    Text("Start nr:")
                        .font(Design.bodyFont)
                        .foregroundColor(Design.subtleText)
                        .frame(width: 80, alignment: .trailing)
                    TextField("1", value: $startNumber, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)

                    Text("Siffer:")
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
                Text("Forh\u{00E5}ndsvisning:")
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
                Button("Avbryt") {
                    isPresented = false
                }
                .buttonStyle(Design.PillButtonStyle())

                Button("Gi nytt navn") {
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

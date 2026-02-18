import SwiftUI

struct SetSelectorView: View {
    @ObservedObject var viewModel: StashViewModel
    @State private var showNewSetSheet = false
    @State private var newSetName = ""
    @State private var editingSetId: UUID?
    @State private var editingName = ""

    var body: some View {
        HStack(spacing: 8) {
            // Set picker
            Menu {
                ForEach(viewModel.sets) { set in
                    Button(action: { viewModel.switchSet(set.id) }) {
                        HStack {
                            Text(set.name)
                            if set.id == viewModel.activeSetId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.activeSet?.name ?? "Ingen sett")
                        .font(Design.titleFont)
                        .foregroundColor(Design.primaryText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Design.subtleText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Design.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Design.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Design.cardCornerRadius)
                        .stroke(Design.borderColor, lineWidth: 0.5)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            // Set management
            if let activeSet = viewModel.activeSet, viewModel.sets.count > 1 {
                Menu {
                    Button("Gi nytt navn") {
                        editingSetId = activeSet.id
                        editingName = activeSet.name
                    }
                    if viewModel.sets.count > 1 {
                        Button("Slett sett", role: .destructive) {
                            viewModel.deleteSet(activeSet.id)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundColor(Design.subtleText)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Button(action: { showNewSetSheet = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .foregroundColor(Design.subtleText)
                    .frame(width: 24, height: 24)
                    .background(Design.buttonTint)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Design.buttonBorder, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("Nytt sett")
        }
        .sheet(isPresented: $showNewSetSheet) {
            newSetSheet
        }
        .sheet(item: $editingSetId) { setId in
            renameSetSheet(setId: setId)
        }
    }

    private var newSetSheet: some View {
        VStack(spacing: 16) {
            Text("Nytt sett")
                .font(Design.headingFont)
                .foregroundColor(Design.primaryText)

            TextField("Navn p\u{00E5} sett", text: $newSetName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onSubmit {
                    createSet()
                }

            HStack(spacing: 12) {
                Button("Avbryt") {
                    showNewSetSheet = false
                    newSetName = ""
                }
                .buttonStyle(Design.PillButtonStyle())

                Button("Opprett") {
                    createSet()
                }
                .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))
                .disabled(newSetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 280)
    }

    private func createSet() {
        let name = newSetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        viewModel.createSet(name: name)
        newSetName = ""
        showNewSetSheet = false
    }

    private func renameSetSheet(setId: UUID) -> some View {
        VStack(spacing: 16) {
            Text("Gi nytt navn")
                .font(Design.headingFont)
                .foregroundColor(Design.primaryText)

            TextField("Navn p\u{00E5} sett", text: $editingName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onSubmit {
                    renameSet(setId)
                }

            HStack(spacing: 12) {
                Button("Avbryt") {
                    editingSetId = nil
                }
                .buttonStyle(Design.PillButtonStyle())

                Button("Lagre") {
                    renameSet(setId)
                }
                .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))
                .disabled(editingName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 280)
    }

    private func renameSet(_ setId: UUID) {
        let name = editingName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        viewModel.renameSet(setId, to: name)
        editingSetId = nil
    }
}

extension UUID: Identifiable {
    public var id: UUID { self }
}

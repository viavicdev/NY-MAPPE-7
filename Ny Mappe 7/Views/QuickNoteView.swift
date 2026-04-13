import SwiftUI

struct QuickNoteView: View {
    @ObservedObject var viewModel: StashViewModel

    private var selectedNote: QuickNote? {
        if let id = viewModel.lastOpenedQuickNoteId {
            return viewModel.quickNotes.first(where: { $0.id == id })
        }
        return viewModel.quickNotes.first
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 130)
                Divider()
                editor
            }
            ToastOverlay(message: viewModel.toastMessage)
        }
        .background(Design.panelBackground)
        .frame(minWidth: 360, minHeight: 360)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "note.text")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Design.accent)
                Text("Notater")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                Spacer()
                Button(action: {
                    let note = viewModel.createQuickNote()
                    viewModel.lastOpenedQuickNoteId = note.id
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Design.accent)
                        .frame(width: 18, height: 18)
                        .background(Design.accent.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Nytt notat")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Design.headerSurface)
            .overlay(
                Rectangle().frame(height: 0.5).foregroundColor(Design.dividerColor),
                alignment: .bottom
            )

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(viewModel.quickNotes) { note in
                        noteRow(note)
                    }
                    if viewModel.quickNotes.isEmpty {
                        Text("Ingen notater enn\u{00E5}")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(Design.subtleText.opacity(0.6))
                            .padding(.top, 16)
                    }
                }
                .padding(6)
            }
        }
    }

    @ViewBuilder
    private func noteRow(_ note: QuickNote) -> some View {
        let isSelected = viewModel.lastOpenedQuickNoteId == note.id
        Button(action: {
            viewModel.lastOpenedQuickNoteId = note.id
            viewModel.scheduleSave()
        }) {
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(note.displayTitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(Design.primaryText)
                        .lineLimit(1)
                    Text(note.body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
                        .font(.system(size: 8, design: .rounded))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Design.accent.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? Design.accent.opacity(0.3) : Color.clear, lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteQuickNote(id: note.id)
            } label: {
                Label("Slett", systemImage: "trash")
            }
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        if let note = selectedNote {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    TextField("Tittel\u{2026}", text: Binding(
                        get: { note.title },
                        set: { viewModel.updateQuickNote(id: note.id, title: $0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Design.primaryText)

                    Spacer()

                    Button(action: {
                        viewModel.copyQuickNote(id: note.id)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                            Text("Kopier")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                    }
                    .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Design.headerSurface)
                .overlay(
                    Rectangle().frame(height: 0.5).foregroundColor(Design.dividerColor),
                    alignment: .bottom
                )

                TextEditor(text: Binding(
                    get: { note.body },
                    set: { viewModel.updateQuickNote(id: note.id, body: $0) }
                ))
                .font(.system(size: 12, design: .rounded))
                .scrollContentBackground(.hidden)
                .background(Design.panelBackground)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundColor(Design.accent.opacity(0.5))
                Text("Ingen notat valgt")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Design.subtleText)
                Button(action: {
                    let note = viewModel.createQuickNote()
                    viewModel.lastOpenedQuickNoteId = note.id
                }) {
                    Text("Lag f\u{00F8}rste notat")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .buttonStyle(Design.PillButtonStyle(isAccent: true, isSolid: true))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

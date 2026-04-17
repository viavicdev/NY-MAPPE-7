import SwiftUI

struct ActionBarView: View {
    @ObservedObject var viewModel: StashViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top divider
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Design.dividerColor)

            HStack(spacing: 8) {
                DragAllButton(viewModel: viewModel)

                // Eksport-meny (zip + filliste-formater)
                if !viewModel.currentItems.isEmpty {
                    Menu {
                        Button(action: { viewModel.exportAsZip() }) {
                            Label("Eksporter som .zip\u{2026}", systemImage: "archivebox")
                        }
                        Button(action: { viewModel.zipItems() }) {
                            Label("Zip til stash", systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button(action: { viewModel.exportFileListAsText() }) {
                            Label("Filliste (.txt)", systemImage: "doc.text")
                        }
                        Button(action: { viewModel.exportFileListAsCSV() }) {
                            Label("Filliste (.csv)", systemImage: "tablecells")
                        }
                        Button(action: { viewModel.exportFileListAsJSON() }) {
                            Label("Filliste (.json)", systemImage: "curlybraces")
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 9))
                            Text("Eksport")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(Design.subtleText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Design.buttonTint)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Design.buttonBorder, lineWidth: 0.5))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(viewModel.selectedItemIds.isEmpty ? "Eksporter alle" : "Eksporter valgte")
                }

                Spacer()

                if !viewModel.selectedItemIds.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.removeSelected()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                            Text("Fjern valgte")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(Design.PillButtonStyle(isDanger: true))
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.clearCurrentSet()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 9))
                        Text("T\u{00F8}m")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(Design.PillButtonStyle(isDanger: true))
                .disabled(viewModel.currentSetItemCount == 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

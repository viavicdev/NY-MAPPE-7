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

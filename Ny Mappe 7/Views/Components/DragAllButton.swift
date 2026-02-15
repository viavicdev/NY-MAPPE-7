import SwiftUI
import UniformTypeIdentifiers

struct DragAllButton: View {
    @ObservedObject var viewModel: StashViewModel

    var body: some View {
        let urls = viewModel.dragItems()
        let count = urls.count

        if count > 0 {
            MultiFileDragButton(
                urls: urls,
                label: viewModel.loc.dragAll(count),
                icon: "arrow.up.doc",
                helpText: viewModel.loc.dragToTransfer
            )
        }
    }
}

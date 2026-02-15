import SwiftUI

struct HeaderView: View {
    @ObservedObject var viewModel: StashViewModel
    var showFilters: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            // Stats row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Design.subtleText)
                    Text(viewModel.loc.filesCount(viewModel.currentSetItemCount))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Design.subtleText)
                }

                Text("\u{2022}")
                    .foregroundColor(Design.subtleText.opacity(0.4))

                Text(viewModel.formattedTotalSize)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.subtleText)

                Spacer()

                if !viewModel.selectedItemIds.isEmpty {
                    Text(viewModel.loc.selected(viewModel.selectedItemIds.count))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Design.accent.opacity(0.20))
                        .foregroundColor(Design.accent)
                        .clipShape(Capsule())
                }
            }

            // Import progress
            if viewModel.isImporting {
                VStack(spacing: 4) {
                    ProgressView(value: viewModel.importProgress.fraction)
                        .tint(Design.progressBlue)

                    Text(viewModel.loc.importing(viewModel.importProgress.completed, viewModel.importProgress.total))
                        .font(Design.captionFont)
                        .foregroundColor(Design.subtleText)
                }
                .transition(.opacity)
            }

            // Filter + Sort row (only in full mode)
            if showFilters {
                HStack(spacing: 6) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(FilterOption.allCases, id: \.self) { option in
                                FilterPill(
                                    label: option.rawValue,
                                    isActive: viewModel.filterOption == option
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.filterOption = option
                                        viewModel.scheduleSave()
                                    }
                                }
                            }
                        }
                    }

                    Spacer()

                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: {
                                viewModel.sortOption = option
                                if option == .manual {
                                    viewModel.initializeManualSort()
                                }
                                viewModel.scheduleSave()
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    if viewModel.sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 10))
                            Text(viewModel.sortOption.rawValue)
                                .font(Design.captionFont)
                        }
                        .foregroundColor(Design.subtleText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Design.buttonTint)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Design.buttonBorder, lineWidth: 0.5)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
    }
}

struct FilterPill: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? Design.accent.opacity(0.30) : Color.clear)
                .foregroundColor(isActive ? Design.accent : Design.subtleText)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isActive ? Design.accent.opacity(0.4) : Design.buttonBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

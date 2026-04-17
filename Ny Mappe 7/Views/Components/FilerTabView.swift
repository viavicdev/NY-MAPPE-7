import SwiftUI

struct FilerTabView: View {
    @ObservedObject var viewModel: StashViewModel

    var body: some View {
        VStack(spacing: 0) {
            subTabBar
            content
        }
    }

    // MARK: - Sub-Tab Bar

    private var subTabBar: some View {
        HStack(spacing: 0) {
            subTabButton(
                title: "Filer",
                icon: "doc.on.doc",
                customIcon: "filer",
                count: viewModel.fileCount,
                tab: .files
            )
            subTabButton(
                title: "Skjermbilde",
                icon: "camera.viewfinder",
                customIcon: "skjermbilde",
                count: viewModel.screenshotCount,
                tab: .screenshots
            )

            // View-controls for aktiv sub-tab
            switch viewModel.activeFilesTab {
            case .files:
                ViewControlsButton(
                    mode: $viewModel.filesViewMode,
                    size: $viewModel.filesViewSize,
                    onChange: { viewModel.scheduleSave() }
                )
                .padding(.trailing, 4)
            case .screenshots:
                ViewControlsButton(
                    mode: $viewModel.screenshotsViewMode,
                    size: $viewModel.screenshotsViewSize,
                    onChange: { viewModel.scheduleSave() }
                )
                .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 8)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Design.dividerColor),
            alignment: .bottom
        )
    }

    private func subTabButton(title: String, icon: String, customIcon: String? = nil, count: Int, tab: StashViewModel.FilesSubTab) -> some View {
        let isActive = viewModel.activeFilesTab == tab
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.activeFilesTab = tab
            }
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Group {
                        if let customIcon = customIcon {
                            AppIcon(customIcon)
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: 10, weight: isActive ? .medium : .regular))
                        }
                    }
                    .frame(width: 12, height: 12)

                    Text(title)
                        .font(.system(size: 10, weight: isActive ? .semibold : .medium, design: .rounded))
                        .lineLimit(1)

                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(isActive ? .white : Design.subtleText.opacity(0.7))
                            .padding(.horizontal, 3)
                            .frame(minWidth: 14, minHeight: 14)
                            .background(isActive ? Design.accent.opacity(0.7) : Design.buttonTint)
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(isActive ? Design.primaryText : Design.subtleText)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)

                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isActive ? Design.accent : Color.clear)
                    .cornerRadius(1)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 6) {
            if viewModel.currentSetItemCount > 0 && !viewModel.isLightVersion {
                HeaderView(viewModel: viewModel, showFilters: true)
                    .padding(.horizontal, 12)
                    .padding(.top, 0)
            }

            if viewModel.showError, let msg = viewModel.errorMessage {
                ErrorBanner(message: msg) {
                    withAnimation {
                        viewModel.showError = false
                    }
                }
            }

            if viewModel.activeFilesTab == .files && !viewModel.isLightVersion {
                ToolbarView(viewModel: viewModel, isFullMode: true)
                    .padding(.horizontal, 12)
                    .padding(.top, viewModel.currentSetItemCount > 0 ? 0 : 6)
            }

            if viewModel.currentItems.isEmpty && !viewModel.isImporting {
                EmptyStateView(isScreenshotTab: viewModel.activeFilesTab == .screenshots)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if viewModel.activeFilesTab == .screenshots && viewModel.isLightVersion {
                ScreenshotLightGridView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CardsGridView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if viewModel.currentSetItemCount > 0 {
                ActionBarView(viewModel: viewModel)
            }
        }
    }
}

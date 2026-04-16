import SwiftUI

struct ToolsTabView: View {
    @ObservedObject var viewModel: StashViewModel

    private var activeSubCount: Int {
        switch viewModel.activeToolsTab {
        case .screenshots: return viewModel.screenshotCount
        case .paths: return viewModel.pathCount
        case .sheets: return viewModel.sheetsRowCount
        }
    }

    private var activeSubLabel: String {
        let c = activeSubCount
        switch viewModel.activeToolsTab {
        case .screenshots: return "\(c) skjermbilde"
        case .paths: return "\(c) filsti"
        case .sheets: return "\(c) rader"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            subTabBar

            if activeSubCount > 0 {
                HStack(spacing: 4) {
                    Text(activeSubLabel)
                        .font(Design.captionFont)
                        .foregroundColor(Design.subtleText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 2)
            }

            toolsContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sub-Tab Bar

    private var subTabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                subTabButton(
                    title: "Skjermbilde",
                    icon: "camera.viewfinder",
                    customIcon: "skjermbilde",
                    count: viewModel.screenshotCount,
                    tab: .screenshots
                )
                subTabButton(
                    title: "Filsti",
                    icon: "folder",
                    customIcon: "filsti",
                    count: viewModel.pathCount,
                    tab: .paths
                )
                subTabButton(
                    title: "Tabell",
                    icon: "tablecells",
                    customIcon: "tabell",
                    count: viewModel.sheetsRowCount,
                    tab: .sheets
                )

                // View-kontroller for aktiv sub-tab (kun der det gir mening)
                switch viewModel.activeToolsTab {
                case .screenshots:
                    ViewControlsButton(
                        mode: $viewModel.screenshotsViewMode,
                        size: $viewModel.screenshotsViewSize,
                        onChange: { viewModel.scheduleSave() }
                    )
                    .padding(.trailing, 4)
                case .paths:
                    ViewControlsButton(
                        mode: $viewModel.pathsViewMode,
                        size: $viewModel.pathsViewSize,
                        hideModeToggle: true,
                        onChange: { viewModel.scheduleSave() }
                    )
                    .padding(.trailing, 4)
                case .sheets:
                    EmptyView()
                }
            }
            .padding(.horizontal, 8)

            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Design.dividerColor)
        }
        .background(Design.headerSurface.opacity(0.5))
    }

    private func subTabButton(title: String, icon: String, customIcon: String? = nil, count: Int, tab: StashViewModel.ToolsSubTab) -> some View {
        let isActive = viewModel.activeToolsTab == tab
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.activeToolsTab = tab
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
                .padding(.vertical, 7)

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

    // MARK: - Content Router

    @ViewBuilder
    private var toolsContent: some View {
        switch viewModel.activeToolsTab {
        case .screenshots:
            screenshotsContent
        case .paths:
            PathListView(viewModel: viewModel)
        case .sheets:
            sheetsContent
        }
    }

    // MARK: - Screenshots

    @ViewBuilder
    private var screenshotsContent: some View {
        if viewModel.currentItems.isEmpty && !viewModel.isImporting {
            EmptyStateView(isScreenshotTab: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if viewModel.isLightVersion {
            // Tettere 3-kolonne-grid i enkel modus, med lightbox ved tap
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

    // MARK: - Sheets

    private var sheetsContent: some View {
        VStack(spacing: 0) {
            SheetsCollectorView(viewModel: viewModel)

            if viewModel.sheetsRowCount == 0 {
                sheetsEmptyState
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !viewModel.sheetsCollectorEnabled {
                viewModel.sheetsCollectorEnabled = true
            }
        }
    }

    private var sheetsEmptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tablecells")
                .font(.system(size: 22, weight: .thin))
                .foregroundColor(Design.accent.opacity(0.4))

            Text("Kopier tekst med \u{2318}C for \u{00E5} fylle kolonner.\nLim rett inn i Google Sheets.")
                .font(Design.captionFont)
                .foregroundColor(Design.subtleText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

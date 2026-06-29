import SwiftUI

struct ToolsTabView: View {
    @ObservedObject var viewModel: StashViewModel

    private var activeSubCount: Int {
        switch viewModel.activeToolsTab {
        case .bundles: return viewModel.contextBundles.count
        case .prompts: return viewModel.promptCategories.count
        case .paths: return viewModel.pathCount
        case .shortcuts: return viewModel.finderShortcuts.count
        }
    }

    private var activeSubLabel: String {
        let c = activeSubCount
        switch viewModel.activeToolsTab {
        case .bundles: return "\(c) bundle\(c == 1 ? "" : "r")"
        case .prompts: return "\(c) kategori\(c == 1 ? "" : "er")"
        case .paths: return "\(c) filsti"
        case .shortcuts: return "\(c) snarvei\(c == 1 ? "" : "er")"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            subTabBar
            toolsContent
        }
    }

    // MARK: - Sub-Tab Bar

    private var subTabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                subTabButton(
                    title: "Bundles",
                    icon: "shippingbox",
                    customIcon: nil,
                    count: viewModel.contextBundles.count,
                    tab: .bundles
                )
                subTabButton(
                    title: "Prompts",
                    icon: "text.bubble",
                    customIcon: "prompt-bank",
                    count: viewModel.promptCategories.count,
                    tab: .prompts
                )
                subTabButton(
                    title: "Filsti",
                    icon: "folder",
                    customIcon: "filsti",
                    count: viewModel.pathCount,
                    tab: .paths
                )
                subTabButton(
                    title: "Snarveier",
                    icon: "folder.fill",
                    customIcon: nil,
                    count: viewModel.finderShortcuts.count,
                    tab: .shortcuts
                )

                // View-kontroller for aktiv sub-tab (kun der det gir mening)
                switch viewModel.activeToolsTab {
                case .paths:
                    ViewControlsButton(
                        mode: $viewModel.pathsViewMode,
                        size: $viewModel.pathsViewSize,
                        hideModeToggle: true,
                        onChange: { viewModel.scheduleSave() }
                    )
                    .padding(.trailing, 4)
                case .bundles, .prompts, .shortcuts:
                    EmptyView()
                }
            }
            .padding(.horizontal, 8)

            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Design.dividerColor)
        }
        .background(.ultraThinMaterial)
        .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Content Router

    @ViewBuilder
    private var toolsContent: some View {
        switch viewModel.activeToolsTab {
        case .bundles:
            ContextBundlesView(viewModel: viewModel)
        case .prompts:
            PromptsView(viewModel: viewModel)
        case .paths:
            PathListView(viewModel: viewModel)
        case .shortcuts:
            FinderShortcutsView(viewModel: viewModel)
        }
    }
}

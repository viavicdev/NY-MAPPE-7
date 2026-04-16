import SwiftUI

struct KontekstView: View {
    @ObservedObject var viewModel: StashViewModel

    private var activeSubCount: Int {
        switch viewModel.activeKontekstTab {
        case .bundles: return viewModel.contextBundles.count
        case .prompts: return viewModel.promptCategories.count
        }
    }

    private var activeSubLabel: String {
        let c = activeSubCount
        switch viewModel.activeKontekstTab {
        case .bundles: return "\(c) bundle\(c == 1 ? "" : "s")"
        case .prompts: return "\(c) kategori\(c == 1 ? "" : "er")"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            subTabBar
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            }
            .padding(.horizontal, 8)
        }
    }

    private func subTabButton(title: String, icon: String, customIcon: String? = nil, count: Int, tab: StashViewModel.KontekstSubTab) -> some View {
        let isActive = viewModel.activeKontekstTab == tab
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.activeKontekstTab = tab
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
    private var content: some View {
        switch viewModel.activeKontekstTab {
        case .bundles:
            ContextBundlesView(viewModel: viewModel)
        case .prompts:
            PromptsView(viewModel: viewModel)
        }
    }
}

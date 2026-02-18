import SwiftUI

struct SettingsSheet: View {
    @ObservedObject var viewModel: StashViewModel
    @Binding var forceDark: Bool?
    @Environment(\.dismiss) var dismiss

    private let clipLimits = [0, 50, 100, 200, 500, 1000]
    private let dayOptions: [Int?] = [nil, 7, 14, 30, 60, 90]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    appearanceSection
                    clipboardSection
                    screenshotSection
                    cleanupSection
                    shortcutsSection
                }
                .padding(16)
            }
        }
        .frame(width: 340, height: 420)
        .background(Design.panelBackground)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Innstillinger")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Design.subtleText)
                        .frame(width: 22, height: 22)
                        .background(Design.buttonTint)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Design.accent)
                Text("Ny Mappe (7)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                Text("v2.0")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Design.subtleText.opacity(0.5))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Design.buttonTint)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            Text("Rask filh\u{00E5}ndtering, utklippshistorikk og verkt\u{00F8}y for kreativt arbeid.")
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(Design.subtleText.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .background(Design.headerSurface)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundColor(Design.dividerColor),
            alignment: .bottom
        )
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        settingsGroup(title: "Utseende", icon: "paintbrush") {
            HStack(spacing: 6) {
                themeButton(icon: "moon.fill", label: "M\u{00F8}rk", active: forceDark == true) {
                    withAnimation(.easeInOut(duration: 0.2)) { forceDark = true }
                }
                themeButton(icon: "sun.max.fill", label: "Lys", active: forceDark == false) {
                    withAnimation(.easeInOut(duration: 0.2)) { forceDark = false }
                }
                themeButton(icon: "circle.lefthalf.filled", label: "System", active: forceDark == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { forceDark = nil }
                }
            }

            settingsToggle(
                title: viewModel.isLightVersion ? "Enkel modus" : "Full modus",
                subtitle: "Bytt mellom enkel og full visning",
                isOn: Binding(
                    get: { !viewModel.isLightVersion },
                    set: { newVal in withAnimation { viewModel.isLightVersion = !newVal } }
                )
            )
        }
    }

    // MARK: - Clipboard

    private var clipboardSection: some View {
        settingsGroup(title: "Utklipp", icon: "doc.on.clipboard") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Maks antall utklipp")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Design.primaryText)

                HStack(spacing: 4) {
                    ForEach(clipLimits, id: \.self) { limit in
                        Button(action: {
                            viewModel.maxClipboardEntries = limit
                            viewModel.scheduleSave()
                        }) {
                            Text(limit == 0 ? "\u{221E}" : "\(limit)")
                                .font(.system(size: 10, weight: viewModel.maxClipboardEntries == limit ? .bold : .medium, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(viewModel.maxClipboardEntries == limit ? Design.accent.opacity(0.15) : Design.buttonTint)
                                .foregroundColor(viewModel.maxClipboardEntries == limit ? Design.accent : Design.subtleText)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(viewModel.maxClipboardEntries == 0
                     ? "Ubegrenset (maks 500)"
                     : "Eldste slettes automatisk n\u{00E5}r grensen n\u{00E5}s")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(Design.subtleText.opacity(0.6))
            }
        }
    }

    // MARK: - Screenshots

    private var screenshotSection: some View {
        settingsGroup(title: "Skjermbilder", icon: "camera.viewfinder") {
            settingsToggle(
                title: "Lagre skjermbilder automatisk",
                subtitle: "Overvåker skrivebordet for nye skjermbilder",
                isOn: Binding(
                    get: { viewModel.saveScreenshots },
                    set: { viewModel.setSaveScreenshots($0) }
                )
            )
        }
    }

    // MARK: - Cleanup

    private var cleanupSection: some View {
        settingsGroup(title: "Auto-opprydding", icon: "clock.arrow.circlepath") {
            cleanupRow(title: "Filer", current: viewModel.autoCleanupFilesDays) {
                viewModel.autoCleanupFilesDays = $0
                viewModel.scheduleSave()
            }
            cleanupRow(title: "Utklipp", current: viewModel.autoCleanupClipboardDays) {
                viewModel.autoCleanupClipboardDays = $0
                viewModel.scheduleSave()
            }
            cleanupRow(title: "Paths", current: viewModel.autoCleanupPathsDays) {
                viewModel.autoCleanupPathsDays = $0
                viewModel.scheduleSave()
            }
        }
    }

    // MARK: - Shortcuts

    private var shortcutsSection: some View {
        settingsGroup(title: "Snarveier", icon: "keyboard") {
            VStack(spacing: 4) {
                shortcutRow("\u{2318}1 / 2 / 3", "Bytt fane")
                shortcutRow("\u{2318}F", "S\u{00F8}k i utklipp")
                shortcutRow("\u{2318}C", "Kopier valgte utklipp")
                shortcutRow("\u{2318}A", "Velg alle")
                shortcutRow("\u{2318}W", "Lukk panelet")
                shortcutRow("Esc", "Fjern valg / lukk")
                shortcutRow("Slett", "Slett valgte")
                shortcutRow("Mellomrom", "Quick Look")
                shortcutRow("Dobbeltklikk", "Kopier utklipp")
            }
        }
    }

    // MARK: - Helpers

    private func settingsGroup<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Design.accent)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Design.primaryText)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Design.borderColor, lineWidth: 0.5)
        )
    }

    private func themeButton(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(active ? Design.accent : Design.subtleText)
            .background(active ? Design.accent.opacity(0.12) : Design.buttonTint)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(active ? Design.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func settingsToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Design.primaryText)
                Text(subtitle)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(Design.subtleText.opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.7)
        }
    }

    private func cleanupRow(title: String, current: Int?, onSelect: @escaping (Int?) -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Design.primaryText)
                .frame(width: 55, alignment: .leading)

            HStack(spacing: 3) {
                ForEach(dayOptions, id: \.self) { opt in
                    Button(action: { onSelect(opt) }) {
                        Text(opt == nil ? "Aldri" : "\(opt!)d")
                            .font(.system(size: 9, weight: current == opt ? .bold : .medium, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(current == opt ? Design.accent.opacity(0.15) : Design.buttonTint)
                            .foregroundColor(current == opt ? Design.accent : Design.subtleText)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func shortcutRow(_ key: String, _ desc: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(Design.accent)
                .frame(width: 100, alignment: .leading)
            Text(desc)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Design.subtleText)
            Spacer()
        }
    }
}

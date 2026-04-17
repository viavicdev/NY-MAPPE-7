import SwiftUI
import AppKit

struct SettingsSheet: View {
    @ObservedObject var viewModel: StashViewModel
    @Binding var forceDark: Bool?
    @Environment(\.dismiss) var dismiss

    private let clipLimits = [0, 50, 100, 200, 500, 1000]
    private let dayOptions: [Int?] = [nil, 7, 14, 30, 60, 90]

    @State private var clipboardSectionExpanded = false
    @State private var cleanupSectionExpanded = false
    @State private var standardBundlesExpanded = false
    @State private var standardPromptsExpanded = false

    private struct StandardBundle {
        let name: String
        let iconName: String
        let emoji: String
    }

    private let standardBundles: [StandardBundle] = [
        .init(name: "Jobb",    iconName: "bundle-jobb",    emoji: "\u{1F4BC}"),
        .init(name: "Meg",     iconName: "bundle-meg",     emoji: "\u{1F464}"),
        .init(name: "Tech",    iconName: "bundle-tech",    emoji: "\u{1F4BB}"),
        .init(name: "Traumer", iconName: "bundle-traumer", emoji: "\u{1F9E0}")
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    appearanceSection
                    clipboardSection
                    standardBundlesSection
                    standardPromptsSection
                    screenshotSection
                    cleanupSection
                    finderShortcutsSection
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
                Text("v6.0")
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
                title: "Full modus",
                subtitle: "Av = enkel (mindre panel). P\u{00E5} = full (mer plass).",
                isOn: Binding(
                    get: { !viewModel.isLightVersion },
                    set: { newVal in withAnimation { viewModel.isLightVersion = !newVal } }
                )
            )
        }
    }

    // MARK: - Clipboard

    private var clipboardSection: some View {
        collapsibleSettingsGroup(
            title: "Utklipp",
            icon: "doc.on.clipboard",
            isExpanded: $clipboardSectionExpanded
        ) {
            VStack(alignment: .leading, spacing: 10) {
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

                settingsToggle(
                    title: "Nyeste utklipp \u{00F8}verst",
                    subtitle: "Av = eldste f\u{00F8}rst, nye legges nederst",
                    isOn: Binding(
                        get: { viewModel.clipboardNewestOnTop },
                        set: { newVal in
                            viewModel.clipboardNewestOnTop = newVal
                            viewModel.scheduleSave()
                        }
                    )
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tomme linjer mellom kopierte utklipp")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Design.primaryText)

                    HStack(spacing: 4) {
                        ForEach([0, 1, 2, 3], id: \.self) { n in
                            Button(action: {
                                viewModel.clipboardCopyBlankLines = n
                                viewModel.scheduleSave()
                            }) {
                                Text("\(n)")
                                    .font(.system(size: 10, weight: viewModel.clipboardCopyBlankLines == n ? .bold : .medium, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(viewModel.clipboardCopyBlankLines == n ? Design.accent.opacity(0.15) : Design.buttonTint)
                                    .foregroundColor(viewModel.clipboardCopyBlankLines == n ? Design.accent : Design.subtleText)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(blankLinesHint)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                }

                settingsToggle(
                    title: "Inkluder gruppenavn i kopier",
                    subtitle: "Legger GRUPPENAVN (caps) \u{00F8}verst i kopierte utklipp fra en gruppe",
                    isOn: Binding(
                        get: { viewModel.clipboardIncludeGroupHeader },
                        set: { newVal in
                            viewModel.clipboardIncludeGroupHeader = newVal
                            viewModel.scheduleSave()
                        }
                    )
                )
            }
        }
    }

    private var blankLinesHint: String {
        switch viewModel.clipboardCopyBlankLines {
        case 0: return "Ingen blank linje \u{2014} utklippene limes rett under hverandre"
        case 1: return "\u{00C9}n blank linje mellom hvert utklipp (standard)"
        case 2: return "To blanke linjer mellom hvert utklipp"
        default: return "\(viewModel.clipboardCopyBlankLines) blanke linjer mellom hvert utklipp"
        }
    }

    // MARK: - Screenshots

    private var screenshotSection: some View {
        settingsGroup(title: "Skjermbilde", icon: "camera.viewfinder") {
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
        collapsibleSettingsGroup(
            title: "Auto-opprydding",
            icon: "clock.arrow.circlepath",
            isExpanded: $cleanupSectionExpanded
        ) {
            cleanupRow(title: "Filer", current: viewModel.autoCleanupFilesDays) {
                viewModel.autoCleanupFilesDays = $0
                viewModel.scheduleSave()
            }
            cleanupRow(title: "Utklipp", current: viewModel.autoCleanupClipboardDays) {
                viewModel.autoCleanupClipboardDays = $0
                viewModel.scheduleSave()
            }
            cleanupRow(title: "Filsti", current: viewModel.autoCleanupPathsDays) {
                viewModel.autoCleanupPathsDays = $0
                viewModel.scheduleSave()
            }
        }
    }

    // MARK: - Standard bundles

    private var standardBundlesSection: some View {
        collapsibleSettingsGroup(
            title: "Standard bundles",
            icon: "shippingbox",
            isExpanded: $standardBundlesExpanded
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Klikk for \u{00E5} legge til en ferdig bundle med ikon. Du kan gi den nytt navn, slette eller endre i Verkt\u{00F8}y \u{2192} Bundles.")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(Design.subtleText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ], spacing: 6) {
                    ForEach(standardBundles, id: \.name) { preset in
                        standardBundleButton(preset)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func standardBundleButton(_ preset: StandardBundle) -> some View {
        let exists = viewModel.contextBundles.contains { $0.name.lowercased() == preset.name.lowercased() }

        Button(action: {
            guard !exists else { return }
            _ = viewModel.createContextBundle(name: preset.name, iconName: preset.iconName)
            viewModel.showToast("\(preset.name) lagt til i Bundles")
        }) {
            HStack(spacing: 6) {
                AppIcon(preset.iconName)
                    .frame(width: 14, height: 14)
                    .foregroundColor(exists ? Design.accent : Design.subtleText)
                Text(preset.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(exists ? Design.accent : Design.primaryText)
                Spacer(minLength: 0)
                Image(systemName: exists ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 10))
                    .foregroundColor(exists ? Design.accent : Design.subtleText.opacity(0.5))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(exists ? Design.accent.opacity(0.1) : Design.buttonTint)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(exists ? Design.accent.opacity(0.3) : Design.buttonBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(exists)
        .help(exists ? "\(preset.name)-bundle finnes allerede" : "Opprett \(preset.name)-bundle")
    }

    // MARK: - Standard prompts

    private struct StandardPrompt {
        let name: String
        let iconName: String?
        let emoji: String
    }

    private let standardPrompts: [StandardPrompt] = [
        .init(name: "Mest brukt", iconName: "prompt-mest-brukt", emoji: "\u{2B50}"),
        .init(name: "Kode",       iconName: nil,             emoji: "\u{1F4BB}"),
        .init(name: "Musikk",     iconName: "prompt-musikk", emoji: "\u{1F3B5}"),
        .init(name: "Regler",     iconName: "prompt-regler", emoji: "\u{1F4CF}"),
        .init(name: "Skriving",   iconName: "prompt-skriving", emoji: "\u{270D}\u{FE0F}"),
    ]

    private var standardPromptsSection: some View {
        collapsibleSettingsGroup(
            title: "Standard prompts",
            icon: "text.bubble",
            isExpanded: $standardPromptsExpanded
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Klikk for \u{00E5} legge til en ferdig prompt-kategori med eksempler. Du kan endre, gi nytt navn eller slette i Kontekst \u{2192} Prompts.")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(Design.subtleText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ], spacing: 6) {
                    ForEach(standardPrompts, id: \.name) { preset in
                        standardPromptButton(preset)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func standardPromptButton(_ preset: StandardPrompt) -> some View {
        let exists = viewModel.promptCategories.contains { $0.name.lowercased() == preset.name.lowercased() }

        Button(action: {
            if exists {
                if let cat = viewModel.promptCategories.first(where: { $0.name.lowercased() == preset.name.lowercased() }) {
                    viewModel.deletePromptCategory(id: cat.id)
                    viewModel.showToast("\(preset.name) fjernet")
                }
            } else {
                viewModel.seedSinglePromptCategory(name: preset.name)
                viewModel.showToast("\(preset.name) lagt til i Prompts")
            }
        }) {
            HStack(spacing: 6) {
                Group {
                    if let icon = preset.iconName {
                        AppIcon(icon)
                            .frame(width: 14, height: 14)
                            .foregroundColor(exists ? Design.accent : Design.subtleText)
                    } else {
                        Text(preset.emoji)
                            .font(.system(size: 12))
                    }
                }
                Text(preset.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(exists ? Design.accent : Design.primaryText)
                Spacer(minLength: 0)
                Image(systemName: exists ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 10))
                    .foregroundColor(exists ? Design.accent : Design.subtleText.opacity(0.5))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(exists ? Design.accent.opacity(0.1) : Design.buttonTint)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(exists ? Design.accent.opacity(0.3) : Design.buttonBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(exists ? "Fjern \(preset.name)-kategori" : "Opprett \(preset.name)-kategori")
    }

    // MARK: - Finder Shortcuts

    private var finderShortcutsSection: some View {
        settingsGroup(title: "Finder-snarveier", icon: "folder.fill") {
            VStack(spacing: 6) {
                if viewModel.finderShortcuts.isEmpty {
                    Text("Ingen snarveier lagt til enn\u{00E5}.")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(Design.subtleText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(viewModel.sortedFinderShortcuts) { shortcut in
                        finderShortcutEditRow(shortcut)
                    }
                }

                Button(action: addShortcutViaOpenPanel) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 10))
                        Text("Legg til mappe")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Design.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Design.accent.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Design.accent.opacity(0.3), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func finderShortcutEditRow(_ shortcut: FinderShortcut) -> some View {
        let nameBinding = Binding<String>(
            get: { shortcut.name },
            set: { viewModel.updateFinderShortcut(id: shortcut.id, name: $0) }
        )
        let emojiBinding = Binding<String>(
            get: { shortcut.emoji },
            set: {
                // Kun f\u{00F8}rste tegn som emoji
                let first = String($0.prefix(1))
                viewModel.updateFinderShortcut(id: shortcut.id, emoji: first)
            }
        )

        HStack(spacing: 6) {
            TextField("\u{1F4C1}", text: emojiBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .frame(width: 26, height: 24)
                .background(Design.buttonTint)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 1) {
                TextField("Navn", text: nameBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Design.primaryText)
                Text(shortcut.path)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Design.subtleText.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Button(action: {
                withAnimation { viewModel.removeFinderShortcut(id: shortcut.id) }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Design.subtleText.opacity(0.6))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Slett snarvei")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Design.buttonTint.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func addShortcutViaOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Velg mappe"
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.level = .floating
        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    viewModel.addFinderShortcut(url: url)
                }
            }
        }
    }

    // MARK: - Shortcuts

    private var shortcutsSection: some View {
        settingsGroup(title: "Snarveier", icon: "keyboard") {
            VStack(spacing: 4) {
                shortcutRow("\u{2325}Space", "Vis/skjul panelet (global)")
                shortcutRow("\u{2325}\u{21E7}N", "Vis/skjul Quick Notes (global)")
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

    private func collapsibleSettingsGroup<Content: View>(
        title: String,
        icon: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Design.accent)
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Design.primaryText)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
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

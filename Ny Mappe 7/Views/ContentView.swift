import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = StashViewModel()
    @State private var isDragTargeted = false
    @State private var dropPulse = false
    @State private var forceDark: Bool? = nil  // nil = follow system
    @State private var keyMonitor: Any?

    var body: some View {
        ZStack {
            Design.panelBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.isLightVersion {
                    // Simple mode: tabs at the very top, no title bar
                    tabBar
                    simpleToolbar
                } else {
                    // Full mode: title bar + tabs
                    titleBar
                    tabBar
                }

                // Set selector (full mode, all tabs)
                if !viewModel.isLightVersion {
                    SetSelectorView(viewModel: viewModel)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                }

                if viewModel.activeTab == .paths {
                    PathListView(viewModel: viewModel)
                } else if viewModel.activeTab == .clipboard {
                    ClipboardListView(viewModel: viewModel)
                } else {
                    VStack(spacing: 6) {
                        // Header (stats + filters/sorting, full mode only)
                        if viewModel.currentSetItemCount > 0 && !viewModel.isLightVersion {
                            HeaderView(viewModel: viewModel, showFilters: true)
                                .padding(.horizontal, 12)
                                .padding(.top, 0)
                        }

                        // Error banner
                        if viewModel.showError, let msg = viewModel.errorMessage {
                            ErrorBanner(message: msg) {
                                withAnimation {
                                    viewModel.showError = false
                                }
                            }
                        }

                        // Toolbar (only on files tab, full mode only)
                        if viewModel.activeTab == .files && !viewModel.isLightVersion {
                            ToolbarView(viewModel: viewModel, isFullMode: true)
                                .padding(.horizontal, 12)
                                .padding(.top, viewModel.currentSetItemCount > 0 ? 0 : 6)
                        }

                        // Cards grid or empty state
                        if viewModel.currentItems.isEmpty && !viewModel.isImporting {
                            EmptyStateView(isScreenshotTab: viewModel.activeTab == .screenshots, language: viewModel.language)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        } else {
                            CardsGridView(viewModel: viewModel)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        // Action bar
                        if viewModel.currentSetItemCount > 0 {
                            ActionBarView(viewModel: viewModel)
                        }
                    }
                }
            }

            // Animated drop zone overlay
            if isDragTargeted {
                ZStack {
                    Design.panelBackground.opacity(0.92)
                        .ignoresSafeArea()

                    RoundedRectangle(cornerRadius: Design.cornerRadius)
                        .strokeBorder(
                            Design.accent.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1.5, dash: [12, 8])
                        )
                        .padding(14)
                        .scaleEffect(dropPulse ? 1.0 : 0.97)
                        .opacity(dropPulse ? 1.0 : 0.5)

                    VStack(spacing: 14) {
                        Image(systemName: viewModel.activeTab == .paths ? "folder" : "arrow.down.circle")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundColor(Design.accent)
                            .offset(y: dropPulse ? 0 : -6)

                        Text(viewModel.activeTab == .paths ? viewModel.loc.dropToCopyPath : viewModel.loc.dropFilesHere)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(Design.accent)
                    }
                }
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        dropPulse = true
                    }
                }
                .onDisappear {
                    dropPulse = false
                }
            }
        }
        .background(
            ExternalDropZone(
                isDragTargeted: $isDragTargeted,
                onDrop: { urls in
                    if viewModel.activeTab == .paths {
                        viewModel.handlePathDrop(urls)
                    } else {
                        viewModel.importURLs(urls)
                    }
                }
            )
        )
        .preferredColorScheme(forceDark == true ? .dark : forceDark == false ? .light : nil)
        .onChange(of: viewModel.isLightVersion) { newValue in
            resizePanelForMode(light: newValue)
        }
        .onAppear {
            resizePanelForMode(light: viewModel.isLightVersion)
            installKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .sheet(isPresented: $viewModel.showBatchRenameSheet) {
            BatchRenameSheet(viewModel: viewModel, isPresented: $viewModel.showBatchRenameSheet)
        }
    }

    // MARK: - Keyboard Monitor

    private func installKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return handleKeyEvent(event) ? nil : event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd+A: Select all (context-aware per tab)
        if flags == .command && event.charactersIgnoringModifiers == "a" {
            switch viewModel.activeTab {
            case .files, .screenshots:
                viewModel.selectAll()
            case .clipboard:
                viewModel.selectAllClipboardEntries()
            case .paths:
                viewModel.selectAllPathEntries()
            }
            return true
        }

        // Cmd+V: Paste files (files/screenshots tabs)
        if flags == .command && event.charactersIgnoringModifiers == "v" {
            if viewModel.activeTab == .files || viewModel.activeTab == .screenshots {
                viewModel.importFromPasteboard()
                return true
            }
            return false
        }

        // Delete/Backspace: Remove selected
        if flags.isEmpty && (event.keyCode == 51 || event.keyCode == 117) {
            switch viewModel.activeTab {
            case .files, .screenshots:
                if !viewModel.selectedItemIds.isEmpty {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.removeSelected()
                    }
                    return true
                }
            case .clipboard:
                if !viewModel.selectedClipboardIds.isEmpty {
                    withAnimation { viewModel.removeSelectedClipboardEntries() }
                    return true
                }
            case .paths:
                if !viewModel.selectedPathIds.isEmpty {
                    withAnimation { viewModel.removeSelectedPathEntries() }
                    return true
                }
            }
            return false
        }

        // Space: Quick Look first selected file
        if flags.isEmpty && event.keyCode == 49 {
            if viewModel.activeTab == .files || viewModel.activeTab == .screenshots {
                if let first = viewModel.selectedItems.first {
                    NSWorkspace.shared.open(first.stagedURL)
                    return true
                }
            }
            return false
        }

        // Escape: Deselect or close panel
        if flags.isEmpty && event.keyCode == 53 {
            var hadSelection = false
            switch viewModel.activeTab {
            case .files, .screenshots:
                if !viewModel.selectedItemIds.isEmpty {
                    viewModel.selectedItemIds.removeAll()
                    hadSelection = true
                }
            case .clipboard:
                if !viewModel.selectedClipboardIds.isEmpty {
                    viewModel.selectedClipboardIds.removeAll()
                    hadSelection = true
                }
            case .paths:
                if !viewModel.selectedPathIds.isEmpty {
                    viewModel.selectedPathIds.removeAll()
                    hadSelection = true
                }
            }
            if !hadSelection {
                NSApplication.shared.windows
                    .first(where: { $0.title == "Ny Mappe (7)" })?
                    .orderOut(nil)
            }
            return true
        }

        return false
    }

    private func resizePanelForMode(light: Bool) {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "Ny Mappe (7)" }) else { return }
            let newHeight: CGFloat = light ? 310 : 520
            let oldFrame = window.frame
            let newY = oldFrame.maxY - newHeight
            let newFrame = NSRect(x: oldFrame.origin.x, y: newY, width: oldFrame.width, height: newHeight)
            window.setFrame(newFrame, display: true, animate: true)
        }
    }

    // MARK: - Simple Toolbar (settings + add-files + close, shown below tabs in simple mode)

    private var simpleToolbar: some View {
        HStack(spacing: 6) {
            if viewModel.activeTab == .files {
                Button(action: { addFilesFromPanel() }) {
                    Image(systemName: "doc.badge.plus")
                }
                .buttonStyle(Design.IconButtonStyle(isAccent: true))
                .help(viewModel.loc.addFiles)
            }

            settingsMenu
                .frame(width: 28, height: 28)

            // Inline stats
            if simpleStatsCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: simpleStatsIcon)
                        .font(.system(size: 10))
                        .foregroundColor(Design.subtleText)
                    Text(simpleStatsLabel)
                        .font(Design.captionFont)
                        .foregroundColor(Design.subtleText)
                    if viewModel.activeTab == .files || viewModel.activeTab == .screenshots {
                        Text("\u{2022}")
                            .foregroundColor(Design.subtleText.opacity(0.4))
                            .font(.system(size: 9))
                        Text(viewModel.formattedTotalSize)
                            .font(Design.captionFont)
                            .foregroundColor(Design.subtleText)
                    }
                }
                .padding(.leading, 4)
            }

            Spacer()

            if viewModel.activeTab == .files && !viewModel.currentItems.isEmpty {
                Menu {
                    Button(action: { viewModel.zipItems() }) {
                        Label(viewModel.loc.zipToStash, systemImage: "archivebox")
                    }
                    Button(action: { viewModel.exportAsZip() }) {
                        Label(viewModel.loc.exportAsZipEllipsis, systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "archivebox")
                        .font(.system(size: 14))
                        .frame(width: 36, height: 32)
                        .foregroundColor(Design.primaryText)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(viewModel.selectedItemIds.isEmpty ? viewModel.loc.zipAll : viewModel.loc.zipSelected)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var simpleStatsCount: Int {
        switch viewModel.activeTab {
        case .files: return viewModel.fileCount
        case .screenshots: return viewModel.screenshotCount
        case .clipboard: return viewModel.clipboardCount
        case .paths: return viewModel.pathCount
        }
    }

    private var simpleStatsIcon: String {
        switch viewModel.activeTab {
        case .files: return "doc.on.doc"
        case .screenshots: return "camera.viewfinder"
        case .clipboard: return "doc.on.clipboard"
        case .paths: return "folder"
        }
    }

    private var simpleStatsLabel: String {
        let c = simpleStatsCount
        switch viewModel.activeTab {
        case .files: return viewModel.loc.filesCount(c)
        case .screenshots: return viewModel.loc.screenshotsCount(c)
        case .clipboard: return viewModel.loc.clipsCount(c)
        case .paths: return viewModel.loc.pathsCount(c)
        }
    }

    private func addFilesFromPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.title = viewModel.loc.chooseFiles
        if panel.runModal() == .OK {
            viewModel.importURLs(panel.urls)
        }
    }

    @ViewBuilder
    private func cleanupOption(_ label: String, value: Int?, current: Int?, onSelect: @escaping (Int?) -> Void) -> some View {
        Button(action: { onSelect(value) }) {
            HStack {
                Text(label)
                if current == value { Image(systemName: "checkmark") }
            }
        }
    }

    // MARK: - Title Bar (redesigned with circular app icon)

    private var titleBar: some View {
        HStack(spacing: 12) {
            if !viewModel.isLightVersion {
                // App icon in accent circle (full mode only)
                ZStack {
                    Circle()
                        .fill(Design.accent.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Design.accent)
                }

                Text("Ny Mappe (7)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Design.primaryText)
            }

            Spacer()

            settingsMenu
                .frame(width: 28, height: 28)

            // Close panel
            Button(action: {
                NSApplication.shared.windows
                    .first(where: { $0.title == "Ny Mappe (7)" })?
                    .orderOut(nil)
            }) {
                Image(systemName: "xmark")
            }
            .buttonStyle(Design.CloseButtonStyle())
            .help(viewModel.loc.closePanel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, viewModel.isLightVersion ? 8 : 14)
        .background(Design.headerSurface)
    }

    // MARK: - Shared Settings Menu

    private var settingsMenu: some View {
        Menu {
            Toggle(isOn: Binding(
                get: { viewModel.saveScreenshots },
                set: { viewModel.setSaveScreenshots($0) }
            )) {
                Label(viewModel.loc.saveScreenshots, systemImage: "camera.viewfinder")
            }

            Divider()

            Button(action: {
                withAnimation { viewModel.isLightVersion.toggle() }
            }) {
                HStack {
                    Text(viewModel.isLightVersion ? viewModel.loc.switchToFull : viewModel.loc.switchToSimple)
                    if !viewModel.isLightVersion {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            // Language picker
            Menu(viewModel.loc.language) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Button(action: {
                        viewModel.language = lang
                        viewModel.scheduleSave()
                    }) {
                        HStack {
                            Text(lang.displayName)
                            if viewModel.language == lang { Image(systemName: "checkmark") }
                        }
                    }
                }
            }

            Divider()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { forceDark = true }
            }) {
                HStack {
                    Image(systemName: "moon.fill")
                    Text(viewModel.loc.dark)
                    if forceDark == true { Image(systemName: "checkmark") }
                }
            }
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { forceDark = false }
            }) {
                HStack {
                    Image(systemName: "sun.max.fill")
                    Text(viewModel.loc.light)
                    if forceDark == false { Image(systemName: "checkmark") }
                }
            }
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { forceDark = nil }
            }) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                    Text(viewModel.loc.followSystem)
                    if forceDark == nil { Image(systemName: "checkmark") }
                }
            }

            Divider()

            // About
            Button(action: {
                NotificationCenter.default.post(name: .showAboutPanel, object: nil)
            }) {
                Label(viewModel.loc.about, systemImage: "info.circle")
            }

            // Quit
            Button(action: {
                NSApp.terminate(nil)
            }) {
                Label(viewModel.loc.quit, systemImage: "power")
            }

            Divider()

            Menu(viewModel.loc.autoCleanup) {
                Menu(viewModel.loc.filesOlderThan) {
                    cleanupOption(viewModel.loc.never, value: nil, current: viewModel.autoCleanupFilesDays) { viewModel.autoCleanupFilesDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(7), value: 7, current: viewModel.autoCleanupFilesDays) { viewModel.autoCleanupFilesDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(14), value: 14, current: viewModel.autoCleanupFilesDays) { viewModel.autoCleanupFilesDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(30), value: 30, current: viewModel.autoCleanupFilesDays) { viewModel.autoCleanupFilesDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(60), value: 60, current: viewModel.autoCleanupFilesDays) { viewModel.autoCleanupFilesDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(90), value: 90, current: viewModel.autoCleanupFilesDays) { viewModel.autoCleanupFilesDays = $0; viewModel.scheduleSave() }
                }
                Menu(viewModel.loc.clipboardOlderThan) {
                    cleanupOption(viewModel.loc.never, value: nil, current: viewModel.autoCleanupClipboardDays) { viewModel.autoCleanupClipboardDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(7), value: 7, current: viewModel.autoCleanupClipboardDays) { viewModel.autoCleanupClipboardDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(14), value: 14, current: viewModel.autoCleanupClipboardDays) { viewModel.autoCleanupClipboardDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(30), value: 30, current: viewModel.autoCleanupClipboardDays) { viewModel.autoCleanupClipboardDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(60), value: 60, current: viewModel.autoCleanupClipboardDays) { viewModel.autoCleanupClipboardDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(90), value: 90, current: viewModel.autoCleanupClipboardDays) { viewModel.autoCleanupClipboardDays = $0; viewModel.scheduleSave() }
                }
                Menu(viewModel.loc.pathsOlderThan) {
                    cleanupOption(viewModel.loc.never, value: nil, current: viewModel.autoCleanupPathsDays) { viewModel.autoCleanupPathsDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(7), value: 7, current: viewModel.autoCleanupPathsDays) { viewModel.autoCleanupPathsDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(14), value: 14, current: viewModel.autoCleanupPathsDays) { viewModel.autoCleanupPathsDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(30), value: 30, current: viewModel.autoCleanupPathsDays) { viewModel.autoCleanupPathsDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(60), value: 60, current: viewModel.autoCleanupPathsDays) { viewModel.autoCleanupPathsDays = $0; viewModel.scheduleSave() }
                    cleanupOption(viewModel.loc.days(90), value: 90, current: viewModel.autoCleanupPathsDays) { viewModel.autoCleanupPathsDays = $0; viewModel.scheduleSave() }
                }
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(Design.subtleText)
                .background(Design.buttonTint)
                .clipShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(viewModel.loc.settings)
    }

    // MARK: - Bottom Bar (simple mode: settings + close)

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Design.dividerColor)

            HStack(spacing: 8) {
                // Settings menu
                Menu {
                    Toggle(isOn: Binding(
                        get: { viewModel.saveScreenshots },
                        set: { viewModel.setSaveScreenshots($0) }
                    )) {
                        Label(viewModel.loc.saveScreenshots, systemImage: "camera.viewfinder")
                    }

                    Divider()

                    Button(action: {
                        withAnimation { viewModel.isLightVersion.toggle() }
                    }) {
                        HStack {
                            Text(viewModel.loc.switchToFull)
                        }
                    }

                    Divider()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { forceDark = true }
                    }) {
                        HStack {
                            Image(systemName: "moon.fill")
                            Text(viewModel.loc.dark)
                            if forceDark == true { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { forceDark = false }
                    }) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                            Text(viewModel.loc.light)
                            if forceDark == false { Image(systemName: "checkmark") }
                        }
                    }
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { forceDark = nil }
                    }) {
                        HStack {
                            Image(systemName: "circle.lefthalf.filled")
                            Text(viewModel.loc.followSystem)
                            if forceDark == nil { Image(systemName: "checkmark") }
                        }
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(Design.subtleText)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                // Close
                Button(action: {
                    NSApplication.shared.windows
                        .first(where: { $0.title == "Ny Mappe (7)" })?
                        .orderOut(nil)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Design.subtleText.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Design.headerSurface)
        }
    }

    // MARK: - Tab Bar (redesigned with thick underline + red badges)

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: viewModel.loc.files, icon: "doc.on.doc", count: viewModel.fileCount, tab: .files)
            tabButton(title: viewModel.loc.screen, icon: "camera.viewfinder", count: viewModel.screenshotCount, tab: .screenshots)
            tabButton(title: viewModel.loc.clipboard, icon: "doc.on.clipboard", count: viewModel.clipboardCount, tab: .clipboard)
            tabButton(title: viewModel.loc.path, icon: "folder", count: viewModel.pathCount, tab: .paths)

            if viewModel.isLightVersion {
                Button(action: {
                    NSApplication.shared.windows
                        .first(where: { $0.title == "Ny Mappe (7)" })?
                        .orderOut(nil)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Design.subtleText.opacity(0.7))
                        .frame(width: 20, height: 20)
                        .background(Design.buttonTint)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Design.borderColor, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .help(viewModel.loc.closePanel)
                .padding(.trailing, 6)
                .padding(.bottom, 3)
            }
        }
        .padding(.leading, 2)
        .padding(.trailing, viewModel.isLightVersion ? 0 : 8)
        .background(Design.headerSurface)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Design.dividerColor),
            alignment: .bottom
        )
    }

    private func tabButton(title: String, icon: String, count: Int, tab: StashViewModel.AppTab) -> some View {
        let isActive = viewModel.activeTab == tab
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.activeTab = tab
                viewModel.selectedItemIds.removeAll()
            }
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: isActive ? .semibold : .light))
                    Text(title)
                        .font(.system(size: 11, weight: isActive ? .bold : .medium, design: .rounded))
                    if count > 0 {
                        let badgeText = count > 999 ? "999+" : "\(count)"
                        let badgeWidth: CGFloat = badgeText.count <= 2 ? 16 : CGFloat(10 + badgeText.count * 5)
                        ZStack {
                            Capsule()
                                .fill(isActive ? Design.accent : Design.badgeRed)
                                .frame(width: badgeWidth, height: 16)
                            Text(badgeText)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .foregroundColor(isActive ? Design.primaryText : Design.subtleText)

                // Thick underline indicator
                Rectangle()
                    .frame(height: Design.tabUnderlineHeight)
                    .foregroundColor(isActive ? Design.primaryText : Color.clear)
                    .cornerRadius(1.5)
                    .padding(.horizontal, 6)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - NSView-based Drop Zone

struct ExternalDropZone: NSViewRepresentable {
    @Binding var isDragTargeted: Bool
    let onDrop: ([URL]) -> Void

    func makeNSView(context: Context) -> DropReceiverNSView {
        let view = DropReceiverNSView()
        view.onTargetChanged = { targeted in
            DispatchQueue.main.async { isDragTargeted = targeted }
        }
        view.onDrop = onDrop
        view.registerForDraggedTypes([.fileURL])
        return view
    }

    func updateNSView(_ nsView: DropReceiverNSView, context: Context) {
        nsView.onDrop = onDrop
        nsView.onTargetChanged = { targeted in
            DispatchQueue.main.async { isDragTargeted = targeted }
        }
    }
}

class DropReceiverNSView: NSView {
    var onTargetChanged: ((Bool) -> Void)?
    var onDrop: (([URL]) -> Void)?

    private func isInternalDrag(_ info: NSDraggingInfo) -> Bool {
        if info.draggingSource is NSView {
            return true
        }
        return InternalDragState.isDragging
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if isInternalDrag(sender) {
            onTargetChanged?(false)
            return []
        }
        onTargetChanged?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if isInternalDrag(sender) { return [] }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetChanged?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if isInternalDrag(sender) { return false }
        onTargetChanged?(false)

        let pasteboard = sender.draggingPasteboard
        guard let items = pasteboard.pasteboardItems else { return false }

        var urls: [URL] = []
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString) {
                urls.append(url)
            }
        }

        if !urls.isEmpty {
            DispatchQueue.main.async { self.onDrop?(urls) }
            return true
        }
        return false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return !isInternalDrag(sender)
    }
}

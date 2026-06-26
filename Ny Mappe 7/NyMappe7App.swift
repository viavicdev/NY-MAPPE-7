import SwiftUI
import AppKit

// MARK: - App Entry Point (no SwiftUI @main - we manage NSApplication directly)

// We avoid SwiftUI's App protocol entirely because it doesn't play well
// with pure menu bar apps when compiled outside Xcode. Instead, we use
// a traditional NSApplication setup with NSApplicationDelegate.

enum NyMappe7App {
    static func main() {
        let app = NSApplication.shared
        let delegate = MenuBarAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)  // No Dock icon
        app.run()
    }
}

// Use @main on a simple wrapper to call our custom main()
@main
struct AppLauncher {
    static func main() {
        NyMappe7App.main()
    }
}

// MARK: - Menu Bar App Delegate

class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var quickNotePanel: FloatingPanel?
    private var globalHotkeyMonitor: Any?
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "Ny Mappe (7)")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create the floating panel (340 = enkel, 520 = full)
        let initialHeight: CGFloat = 340  // Start i enkel modus
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 388, height: initialHeight),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)
        panel.contentView = hostingView
        panel.title = "Ny Mappe (7)"
        panel.identifier = NSUserInterfaceItemIdentifier("no.klippegeni.NyMappe7.MainPanel")
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0)
                : NSColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1.0)
        })
        panel.setContentSize(NSSize(width: 388, height: initialHeight))
        panel.minSize = NSSize(width: 320, height: 280)

        // Round corners (bigger radius)
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 14
        panel.contentView?.layer?.masksToBounds = true

        // Register global hotkey: ⌥Space to toggle panel from anywhere
        registerGlobalHotkey()

        // Registrer macOS-tjeneste: h\u{00F8}yreklikk i Finder \u{2192} "Legg til i Ny Mappe (7)"
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()

        // Global Finder-import-hurtigtast via Carbon (krever IKKE Accessibility-tillatelse)
        FinderImportHotKeyManager.shared.configure {
            Task { @MainActor in
                StashViewModel.shared.importFinderSelection()
            }
        }
        FinderImportHotKeyManager.shared.update(to: StashViewModel.shared.finderImportHotkey)

        // Auto-sjekk etter oppdateringer (kort etter oppstart + hver 6. time)
        scheduleUpdateChecks()

        // Show the panel on first launch
        positionPanelBelowStatusItem()
        panel.makeKeyAndOrderFront(nil)
    }

    /// macOS-tjeneste-handler: mottar filer markert i Finder (h\u{00F8}yreklikk \u{2192} Tjenester)
    /// og legger dem i Filer-fanen. Koblet via NSServices i Info.plist.
    @objc func addFilesToStash(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>?
    ) {
        let urls = (pboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]) ?? []

        guard !urls.isEmpty else {
            error?.pointee = "Ingen filer mottatt" as NSString
            return
        }

        Task { @MainActor in
            StashViewModel.shared.activeTab = .files
            StashViewModel.shared.activeFilesTab = .files
            StashViewModel.shared.importURLs(urls)
            StashViewModel.shared.showToast("\(urls.count) lagt til i Filer")
        }
    }

    // MARK: - Global Hotkey (⌥Space)

    private func registerGlobalHotkey() {
        // Global monitor catches the hotkey when the app is NOT focused
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalHotkey(event)
        }

        // Local monitor catches the hotkey when the app IS focused
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleGlobalHotkey(event) == true {
                return nil  // Consume the event
            }
            return event
        }
    }

    @discardableResult
    private func handleGlobalHotkey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // ⌥Space (Option + Space): keyCode 49 = Space
        if flags == .option && event.keyCode == 49 {
            DispatchQueue.main.async { [weak self] in
                self?.togglePanel()
            }
            return true
        }
        // ⌥⇧N (Option + Shift + N): keyCode 45 = N
        if flags == [.option, .shift] && event.keyCode == 45 {
            DispatchQueue.main.async { [weak self] in
                self?.toggleQuickNotePanel()
            }
            return true
        }
        // (Finder-import-hurtigtasten håndteres av FinderImportHotKeyManager via Carbon,
        //  som ikke krever Accessibility-tillatelse — se applicationDidFinishLaunching.)
        return false
    }

    // MARK: - Quick Note Panel

    @MainActor @objc func toggleQuickNotePanel() {
        if let existing = quickNotePanel, existing.isVisible {
            existing.orderOut(nil)
            return
        }

        if quickNotePanel == nil {
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let width: CGFloat = 360
            let height: CGFloat = min(screen.height - 60, 640)
            let x = screen.maxX - width - 16
            let y = screen.maxY - height - 40

            let panel = FloatingPanel(
                contentRect: NSRect(x: x, y: y, width: width, height: height),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            let content = QuickNoteView(viewModel: StashViewModel.shared)
            let hosting = NSHostingView(rootView: content)
            panel.contentView = hosting
            panel.title = "Quick Notes"
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = NSColor(name: nil, dynamicProvider: { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark
                    ? NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0)
                    : NSColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1.0)
            })
            panel.setContentSize(NSSize(width: width, height: height))
            panel.minSize = NSSize(width: 320, height: 320)
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.cornerRadius = 14
            panel.contentView?.layer?.masksToBounds = true
            quickNotePanel = panel
        }

        guard let panel = quickNotePanel else { return }
        // Reposisjoner ved hver visning, i tilfelle skjerm har endret seg
        if let screen = NSScreen.main?.visibleFrame {
            let frame = panel.frame
            let x = screen.maxX - frame.width - 16
            let y = screen.maxY - frame.height - 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false) {
            showStatusMenu()
        } else {
            togglePanel()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        let show = NSMenuItem(title: "Vis/skjul panel", action: #selector(togglePanel), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        let notes = NSMenuItem(title: "Vis/skjul Quick Notes", action: #selector(toggleQuickNotePanel), keyEquivalent: "")
        notes.target = self
        menu.addItem(notes)
        menu.addItem(NSMenuItem.separator())
        let update = NSMenuItem(title: "Se etter oppdateringer\u{2026}", action: #selector(checkForUpdatesMenuAction), keyEquivalent: "")
        update.target = self
        menu.addItem(update)
        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "Lukk Ny Mappe (7)", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // reset s\u{00E5} venstreklikk fortsatt kaller action
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Auto-oppdatering

    private func scheduleUpdateChecks() {
        // Sjekk kort etter oppstart (gi appen ro til \u{00E5} starte f\u{00F8}rst)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            self?.checkForUpdates(userInitiated: false)
        }
        // Deretter hver 6. time
        updateTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            self?.checkForUpdates(userInitiated: false)
        }
    }

    @objc private func checkForUpdatesMenuAction() {
        checkForUpdates(userInitiated: true)
    }

    private func checkForUpdates(userInitiated: Bool) {
        UpdateService.shared.checkForUpdate { [weak self] status in
            guard let self = self else { return }
            guard let status = status else {
                if userInitiated {
                    self.showUpdateInfo(title: "Oppdatering", text: "Kunne ikke sjekke etter oppdateringer akkurat n\u{00E5}.")
                }
                return
            }
            if status.available {
                self.presentUpdatePrompt(status)
            } else if userInitiated {
                self.showUpdateInfo(title: "Oppdatering", text: "Du har nyeste versjon. \u{1F389}")
            }
        }
    }

    private func presentUpdatePrompt(_ status: UpdateStatus) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Ny versjon tilgjengelig"
        let changes = status.commitsBehind == 1 ? "1 ny endring" : "\(status.commitsBehind) nye endringer"
        var info = "\(changes)."
        if !status.latestMessage.isEmpty {
            info += "\n\nSiste: \(status.latestMessage)"
        }
        info += "\n\nOppdater n\u{00E5}? Appen bygges p\u{00E5} nytt og relanseres."
        alert.informativeText = info
        alert.addButton(withTitle: "Oppdater n\u{00E5}")
        alert.addButton(withTitle: "Senere")
        if alert.runModal() == .alertFirstButtonReturn {
            UpdateService.shared.applyUpdate()
            let note = NSAlert()
            note.messageText = "Oppdaterer \u{2026}"
            note.informativeText = "Appen bygges p\u{00E5} nytt og relanseres om litt. Du kan lukke denne."
            note.runModal()
        }
    }

    private func showUpdateInfo(title: String, text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }

    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            positionPanelBelowStatusItem()
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func positionPanelBelowStatusItem() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else {
            // Fallback: center on screen
            panel.center()
            return
        }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)

        let panelWidth = panel.frame.width
        let panelHeight = panel.frame.height
        let x = screenRect.midX - (panelWidth / 2)
        let y = screenRect.minY - panelHeight - 4

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stopp pollere slik at de ikke lever videre ved crash-recovery eller relaunch.
        ClipboardWatcher.shared.stopWatching()
        ScreenshotWatcher.shared.stopWatching()

        // Fjern global hotkey monitor
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalHotkeyMonitor = nil
        }
    }
}

// MARK: - Floating Panel

class FloatingPanel: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        // Float above normal windows
        self.level = .floating

        // Don't hide when app loses focus - THIS IS KEY
        self.hidesOnDeactivate = false

        self.isMovable = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

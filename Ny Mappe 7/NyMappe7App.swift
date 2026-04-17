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

        // Show the panel on first launch
        positionPanelBelowStatusItem()
        panel.makeKeyAndOrderFront(nil)
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

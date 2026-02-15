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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "Ny Mappe (7)")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create the floating panel (340 = enkel, 520 = full)
        let initialHeight: CGFloat = 340  // Start i enkel modus
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: initialHeight),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)
        panel.contentView = hostingView
        panel.title = "Ny Mappe (7)"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0)
                : NSColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1.0)
        })
        panel.setContentSize(NSSize(width: 380, height: initialHeight))
        panel.minSize = NSSize(width: 320, height: 280)

        // Round corners (bigger radius)
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 14
        panel.contentView?.layer?.masksToBounds = true

        // Show the panel on first launch
        positionPanelBelowStatusItem()
        panel.makeKeyAndOrderFront(nil)

        // Listen for "show about" notifications from SwiftUI settings menu
        NotificationCenter.default.addObserver(self, selector: #selector(showAbout), name: .showAboutPanel, object: nil)
    }

    @objc func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
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

    private func showContextMenu() {
        let loc = Loc(l: AppLanguage.current)
        let menu = NSMenu()

        let openItem = NSMenuItem(title: loc.openPanel, action: #selector(openPanel), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: loc.about, action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: loc.quit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Temporarily assign menu, click, then remove (so left-click still works)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func openPanel() {
        positionPanelBelowStatusItem()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAbout() {
        let loc = Loc(l: AppLanguage.current)

        let alert = NSAlert()
        alert.messageText = "Ny Mappe (7)"
        alert.informativeText = """
        \(loc.version) 3.1

        \(loc.aboutDescription)

        \(loc.madeBy) viavicdev
        github.com/viavicdev/ny-mappe-7
        """
        alert.alertStyle = .informational

        // Use app icon if available
        if let icon = NSImage(named: "AppIcon") {
            alert.icon = icon
        } else {
            let icon = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: nil)
            alert.icon = icon
        }

        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: loc.viewOnGithub)

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/viavicdev/ny-mappe-7") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
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
}

// MARK: - Notification for About panel

extension Notification.Name {
    static let showAboutPanel = Notification.Name("showAboutPanel")
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

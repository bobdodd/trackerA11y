import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var window: NSWindow!
    var mainViewController: MainViewController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 TrackerA11y launching...")
        
        // Create main window
        let contentRect = NSRect(x: 100, y: 100, width: 1000, height: 700)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "TrackerA11y - Accessibility Testing Platform"
        window.center()
        
        // Ensure window doesn't release when closed unless we explicitly want to quit
        window.isReleasedWhenClosed = false
        
        // Create and set main view controller
        mainViewController = MainViewController()
        window.contentViewController = mainViewController
        
        window.makeKeyAndOrderFront(nil)
        
        // Set up application menu
        setupMenuBar()
        
        print("✅ TrackerA11y native macOS app launched")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        mainViewController?.cleanup()
        print("🧹 TrackerA11y app terminated")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Only terminate if the main window is closed, not auxiliary windows
        return false
    }
    
    private func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        
        appMenu.addItem(withTitle: "About TrackerA11y", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit TrackerA11y", action: #selector(quitApplication), keyEquivalent: "q")
        
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Session menu
        let sessionMenuItem = NSMenuItem(title: "Session", action: nil, keyEquivalent: "")
        let sessionMenu = NSMenu()
        
        sessionMenu.addItem(withTitle: "Start Recording", action: #selector(startRecording), keyEquivalent: "r")
        sessionMenu.addItem(withTitle: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "s")
        sessionMenu.addItem(NSMenuItem.separator())
        sessionMenu.addItem(withTitle: "New Session", action: #selector(newSession), keyEquivalent: "n")
        sessionMenu.addItem(withTitle: "Export Session...", action: #selector(exportSession), keyEquivalent: "e")
        
        sessionMenuItem.submenu = sessionMenu
        mainMenu.addItem(sessionMenuItem)
        
        // Window menu
        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu()
        
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.close), keyEquivalent: "w")
        
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "TrackerA11y"
        alert.informativeText = "Native macOS accessibility testing platform\nVersion 1.0.0\n\nBuilt with Swift and native macOS frameworks"
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    @objc private func showPreferences() {
        mainViewController?.showPreferences()
    }
    
    @objc private func startRecording() {
        mainViewController?.startRecording()
    }
    
    @objc private func stopRecording() {
        mainViewController?.stopRecording()
    }
    
    @objc private func newSession() {
        mainViewController?.newSession()
    }
    
    @objc private func exportSession() {
        mainViewController?.exportSession()
    }
    
    @objc private func quitApplication() {
        // Properly quit the application
        NSApplication.shared.terminate(nil)
    }
}
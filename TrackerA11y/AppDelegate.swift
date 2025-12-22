import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    var window: NSWindow!
    var mainViewController: MainViewController?
    var adminWindow: NSWindow?
    
    // Menu bar status item
    var statusItem: NSStatusItem?
    var statusMenu: NSMenu?
    var recordingState: RecordingState = .stopped {
        didSet {
            updateStatusBarIcon()
        }
    }
    
    enum RecordingState {
        case stopped
        case recording
        case paused
    }

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
        
        // Set window delegate to handle close events
        window.delegate = self
        
        window.makeKeyAndOrderFront(nil)
        
        // Set up application menu
        setupMenuBar()
        
        // Set up menu bar status item
        setupStatusBarItem()
        
        print("✅ TrackerA11y native macOS app launched")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        mainViewController?.cleanup()
        
        // Clean up status bar item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        
        print("🧹 TrackerA11y app terminated")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Let individual window close handling decide app termination
        return false
    }
    
    // MARK: - NSWindowDelegate
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // If this is the main window, quit the entire app
        if sender == window {
            print("🚪 Main window closing - quitting application")
            NSApplication.shared.terminate(nil)
            return false // We handle the termination ourselves
        }
        
        // For other windows, allow normal closing
        return true
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
        sessionMenu.addItem(withTitle: "Pause Recording", action: #selector(pauseRecording), keyEquivalent: "p")
        sessionMenu.addItem(withTitle: "Resume Recording", action: #selector(resumeRecording), keyEquivalent: "")
        sessionMenu.addItem(NSMenuItem.separator())
        
        // Screenshot submenu
        let screenshotMenuItem = NSMenuItem(title: "Take Screenshot", action: nil, keyEquivalent: "")
        let screenshotMenu = NSMenu()
        screenshotMenu.addItem(withTitle: "Full Screen", action: #selector(takeFullScreenshot), keyEquivalent: "1")
        screenshotMenu.addItem(withTitle: "Select Region...", action: #selector(takeRegionScreenshot), keyEquivalent: "2")
        screenshotMenu.addItem(withTitle: "Browser Full Page", action: #selector(takeBrowserScreenshot), keyEquivalent: "3")
        screenshotMenuItem.submenu = screenshotMenu
        sessionMenu.addItem(screenshotMenuItem)
        
        sessionMenu.addItem(NSMenuItem.separator())
        sessionMenu.addItem(withTitle: "New Session", action: #selector(newSession), keyEquivalent: "n")
        sessionMenu.addItem(withTitle: "Export Session...", action: #selector(exportSession), keyEquivalent: "e")
        
        sessionMenuItem.submenu = sessionMenu
        mainMenu.addItem(sessionMenuItem)
        
        // Tools menu
        let toolsMenuItem = NSMenuItem(title: "Tools", action: nil, keyEquivalent: "")
        let toolsMenu = NSMenu()
        
        toolsMenu.addItem(withTitle: "Admin Panel...", action: #selector(showAdminPanel), keyEquivalent: "")
        
        toolsMenuItem.submenu = toolsMenu
        mainMenu.addItem(toolsMenuItem)
        
        // Window menu
        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu()
        
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.close), keyEquivalent: "w")
        
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    private func setupStatusBarItem() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else {
            print("❌ Failed to create status bar item")
            return
        }
        
        // Create status menu
        statusMenu = NSMenu()
        statusItem.menu = statusMenu
        
        // Initial setup
        updateStatusBarIcon()
        updateStatusMenu()
        
        print("✅ Menu bar status item created")
    }
    
    private func updateStatusBarIcon() {
        guard let statusItem = statusItem else { return }
        
        let button = statusItem.button
        
        switch recordingState {
        case .stopped:
            // Use a circle for stopped state
            button?.title = "●"
            button?.toolTip = "TrackerA11y - Ready to Record"
            
        case .recording:
            // Use a red circle for recording state
            button?.title = "🔴"
            button?.toolTip = "TrackerA11y - Recording Active"
            
        case .paused:
            // Use pause symbol for paused state
            button?.title = "⏸"
            button?.toolTip = "TrackerA11y - Recording Paused"
        }
        
        // Style the button
        button?.font = NSFont.systemFont(ofSize: 16)
    }
    
    private func updateStatusMenu() {
        guard let statusMenu = statusMenu else { return }
        
        // Clear existing items
        statusMenu.removeAllItems()
        
        // Add title
        let titleItem = NSMenuItem(title: "TrackerA11y", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        statusMenu.addItem(titleItem)
        statusMenu.addItem(NSMenuItem.separator())
        
        // Recording controls based on current state
        switch recordingState {
        case .stopped:
            statusMenu.addItem(withTitle: "▶️ Start Recording", action: #selector(statusBarStartRecording), keyEquivalent: "r")
            
        case .recording:
            statusMenu.addItem(withTitle: "⏸ Pause Recording", action: #selector(statusBarPauseRecording), keyEquivalent: "p")
            statusMenu.addItem(withTitle: "⏹ Stop Recording", action: #selector(statusBarStopRecording), keyEquivalent: "s")
            statusMenu.addItem(NSMenuItem.separator())
            addScreenshotSubmenu(to: statusMenu)
            
        case .paused:
            statusMenu.addItem(withTitle: "▶️ Resume Recording", action: #selector(statusBarResumeRecording), keyEquivalent: "r")
            statusMenu.addItem(withTitle: "⏹ Stop Recording", action: #selector(statusBarStopRecording), keyEquivalent: "s")
            statusMenu.addItem(NSMenuItem.separator())
            addScreenshotSubmenu(to: statusMenu)
        }
        
        statusMenu.addItem(NSMenuItem.separator())
        
        // Additional options
        statusMenu.addItem(withTitle: "📊 View Sessions", action: #selector(statusBarViewSessions), keyEquivalent: "")
        statusMenu.addItem(withTitle: "🏠 Show Main Window", action: #selector(statusBarShowMainWindow), keyEquivalent: "")
        
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(withTitle: "Quit TrackerA11y", action: #selector(statusBarQuit), keyEquivalent: "q")
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
    
    @objc private func showAdminPanel() {
        // If admin window already exists, just bring it to front
        if let existingWindow = adminWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create admin window
        let adminWindowInstance = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        adminWindowInstance.title = "Admin Panel - TrackerA11y"
        adminWindowInstance.center()
        adminWindowInstance.contentMinSize = NSSize(width: 600, height: 400)
        adminWindowInstance.isReleasedWhenClosed = false
        
        let adminViewController = AdminViewController()
        adminWindowInstance.contentViewController = adminViewController
        
        adminWindow = adminWindowInstance
        adminWindowInstance.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("🔧 Admin panel opened")
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
    
    @objc private func pauseRecording() {
        mainViewController?.pauseRecording()
    }
    
    @objc private func resumeRecording() {
        mainViewController?.resumeRecording()
    }
    
    // MARK: - Screenshot Actions
    
    @objc private func takeFullScreenshot() {
        print("📸 Menu: Full screen screenshot requested")
        mainViewController?.takeScreenshot(type: .fullScreen)
    }
    
    @objc private func takeRegionScreenshot() {
        print("📸 Menu: Region screenshot requested")
        mainViewController?.takeScreenshot(type: .region)
    }
    
    @objc private func takeBrowserScreenshot() {
        print("📸 Menu: Browser full page screenshot requested")
        mainViewController?.takeScreenshot(type: .browserFullPage)
    }
    
    private func addScreenshotSubmenu(to menu: NSMenu) {
        let screenshotMenuItem = NSMenuItem(title: "📸 Take Screenshot", action: nil, keyEquivalent: "")
        let screenshotMenu = NSMenu()
        screenshotMenu.addItem(withTitle: "Full Screen", action: #selector(statusBarFullScreenshot), keyEquivalent: "")
        screenshotMenu.addItem(withTitle: "Select Region...", action: #selector(statusBarRegionScreenshot), keyEquivalent: "")
        screenshotMenu.addItem(withTitle: "Browser Full Page", action: #selector(statusBarBrowserScreenshot), keyEquivalent: "")
        screenshotMenuItem.submenu = screenshotMenu
        menu.addItem(screenshotMenuItem)
    }
    
    @objc private func statusBarFullScreenshot() {
        print("📸 Status bar: Full screen screenshot requested")
        mainViewController?.takeScreenshot(type: .fullScreen)
    }
    
    @objc private func statusBarRegionScreenshot() {
        print("📸 Status bar: Region screenshot requested")
        mainViewController?.takeScreenshot(type: .region)
    }
    
    @objc private func statusBarBrowserScreenshot() {
        print("📸 Status bar: Browser full page screenshot requested")
        mainViewController?.takeScreenshot(type: .browserFullPage)
    }
    
    // MARK: - Status Bar Actions
    
    @objc private func statusBarStartRecording() {
        print("🎬 Status bar: Start recording requested")
        recordingState = .recording
        updateStatusMenu()
        mainViewController?.startRecording()
    }
    
    @objc private func statusBarPauseRecording() {
        print("⏸ Status bar: Pause recording requested")
        recordingState = .paused
        updateStatusMenu()
        mainViewController?.pauseRecording()
    }
    
    @objc private func statusBarResumeRecording() {
        print("▶️ Status bar: Resume recording requested")
        recordingState = .recording
        updateStatusMenu()
        mainViewController?.resumeRecording()
    }
    
    @objc private func statusBarStopRecording() {
        print("⏹ Status bar: Stop recording requested")
        recordingState = .stopped
        updateStatusMenu()
        mainViewController?.stopRecording()
        
        // Show main window so user can see their session
        print("🏠 Automatically showing main window after recording stopped")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func statusBarViewSessions() {
        print("📊 Status bar: View sessions requested")
        mainViewController?.viewSessions()
    }
    
    @objc private func statusBarShowMainWindow() {
        print("🏠 Status bar: Show main window requested")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func statusBarQuit() {
        print("🚪 Status bar: Quit requested")
        quitApplication()
    }
    
    // MARK: - Public Methods for MainViewController
    
    func updateRecordingState(_ state: RecordingState) {
        recordingState = state
        updateStatusMenu()
    }
}
import Cocoa

class MainViewController: NSViewController {
    
    // UI Elements
    private var statusLabel: NSTextField!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    private var eventCountLabel: NSTextField!
    private var sessionLabel: NSTextField!
    private var databaseStatusLabel: NSTextField!
    
    // Tracker bridge
    private var trackerBridge: TrackerBridge?
    private var isTracking = false
    private var currentSession: String?
    private var eventCount = 0
    
    // Keep references to prevent deallocation
    private var sessionWindows: [NSWindow] = []
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        setupUI()
        setupTracker()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }
    
    private func setupUI() {
        let margin: CGFloat = 40
        let spacing: CGFloat = 20
        
        // Title
        let titleLabel = NSTextField(labelWithString: "TrackerA11y")
        titleLabel.font = NSFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = NSColor.controlAccentColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Native macOS Accessibility Testing Platform")
        subtitleLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        // Status section
        let statusBox = createSectionBox(title: "Tracking Status")
        view.addSubview(statusBox)
        
        statusLabel = NSTextField(labelWithString: "Ready")
        statusLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = NSColor.systemGreen
        
        sessionLabel = NSTextField(labelWithString: "No active session")
        sessionLabel.font = NSFont.systemFont(ofSize: 12)
        sessionLabel.textColor = NSColor.secondaryLabelColor
        
        eventCountLabel = NSTextField(labelWithString: "Events captured: 0")
        eventCountLabel.font = NSFont.systemFont(ofSize: 12)
        eventCountLabel.textColor = NSColor.secondaryLabelColor
        
        let statusStack = NSStackView(views: [statusLabel, sessionLabel, eventCountLabel])
        statusStack.orientation = .vertical
        statusStack.alignment = .leading
        statusStack.spacing = 8
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusBox.addSubview(statusStack)
        
        // Control buttons
        startButton = NSButton()
        startButton.title = "Start Recording"
        startButton.bezelStyle = .rounded
        startButton.controlSize = .large
        startButton.target = self
        startButton.action = #selector(startRecording)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startButton)
        
        stopButton = NSButton()
        stopButton.title = "Stop Recording"
        stopButton.bezelStyle = .rounded
        stopButton.controlSize = .large
        stopButton.target = self
        stopButton.action = #selector(stopRecording)
        stopButton.isEnabled = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stopButton)
        
        // Progress indicator
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressIndicator)
        
        // Database status
        let dbBox = createSectionBox(title: "Database Status")
        view.addSubview(dbBox)
        
        databaseStatusLabel = NSTextField(labelWithString: "Checking...")
        databaseStatusLabel.font = NSFont.systemFont(ofSize: 14)
        databaseStatusLabel.textColor = NSColor.systemOrange
        databaseStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let viewSessionsButton = NSButton()
        viewSessionsButton.title = "View Sessions"
        viewSessionsButton.bezelStyle = .rounded
        viewSessionsButton.target = self
        viewSessionsButton.action = #selector(viewSessions)
        viewSessionsButton.translatesAutoresizingMaskIntoConstraints = false
        
        let dbStack = NSStackView(views: [databaseStatusLabel, viewSessionsButton])
        dbStack.orientation = .horizontal
        dbStack.alignment = .centerY
        dbStack.spacing = 10
        dbStack.translatesAutoresizingMaskIntoConstraints = false
        dbBox.addSubview(dbStack)
        
        // Features section
        let featuresBox = createSectionBox(title: "Accessibility Features")
        view.addSubview(featuresBox)
        
        let featuresText = """
        ✅ Focus tracking with microsecond precision
        ✅ Mouse interactions and hover detection
        ✅ Keyboard input monitoring
        ✅ Native macOS dock integration
        ✅ Browser element identification
        ✅ Window and application focus events
        ✅ Real-time event correlation
        ✅ Session-based data collection
        """
        
        let featuresLabel = NSTextField(labelWithString: featuresText)
        featuresLabel.font = NSFont.systemFont(ofSize: 12)
        featuresLabel.textColor = NSColor.labelColor
        featuresLabel.maximumNumberOfLines = 0
        featuresLabel.translatesAutoresizingMaskIntoConstraints = false
        featuresBox.addSubview(featuresLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Title
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            
            // Subtitle
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            
            // Status box
            statusBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            statusBox.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -spacing/2),
            statusBox.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: margin),
            statusBox.heightAnchor.constraint(equalToConstant: 120),
            
            // Status stack
            statusStack.leadingAnchor.constraint(equalTo: statusBox.leadingAnchor, constant: 20),
            statusStack.trailingAnchor.constraint(equalTo: statusBox.trailingAnchor, constant: -20),
            statusStack.topAnchor.constraint(equalTo: statusBox.topAnchor, constant: 40),
            
            // Database box
            dbBox.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: spacing/2),
            dbBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            dbBox.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: margin),
            dbBox.heightAnchor.constraint(equalToConstant: 120),
            
            // Database stack
            dbStack.leadingAnchor.constraint(equalTo: dbBox.leadingAnchor, constant: 20),
            dbStack.trailingAnchor.constraint(equalTo: dbBox.trailingAnchor, constant: -20),
            dbStack.topAnchor.constraint(equalTo: dbBox.topAnchor, constant: 40),
            
            // Buttons
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            startButton.topAnchor.constraint(equalTo: statusBox.bottomAnchor, constant: spacing),
            startButton.widthAnchor.constraint(equalToConstant: 150),
            
            stopButton.leadingAnchor.constraint(equalTo: startButton.trailingAnchor, constant: spacing),
            stopButton.centerYAnchor.constraint(equalTo: startButton.centerYAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 150),
            
            // Progress indicator
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressIndicator.centerYAnchor.constraint(equalTo: startButton.centerYAnchor),
            
            // Features box
            featuresBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            featuresBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            featuresBox.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: spacing),
            featuresBox.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin),
            
            // Features text
            featuresLabel.leadingAnchor.constraint(equalTo: featuresBox.leadingAnchor, constant: 20),
            featuresLabel.trailingAnchor.constraint(equalTo: featuresBox.trailingAnchor, constant: -20),
            featuresLabel.topAnchor.constraint(equalTo: featuresBox.topAnchor, constant: 40),
        ])
    }
    
    private func createSectionBox(title: String) -> NSBox {
        let box = NSBox()
        box.titlePosition = .atTop
        box.title = title
        box.boxType = .primary
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }
    
    private func setupTracker() {
        trackerBridge = TrackerBridge()
        trackerBridge?.delegate = self
        trackerBridge?.initialize()
        checkDatabaseStatus()
    }
    
    private func checkDatabaseStatus() {
        // Check MongoDB connectivity
        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mongosh")
            task.arguments = ["--quiet", "--eval", "db.runCommand('ping')"]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                DispatchQueue.main.async {
                    if task.terminationStatus == 0 {
                        self.databaseStatusLabel.stringValue = "✅ MongoDB Connected"
                        self.databaseStatusLabel.textColor = NSColor.systemGreen
                    } else {
                        self.databaseStatusLabel.stringValue = "❌ MongoDB Connection Failed"
                        self.databaseStatusLabel.textColor = NSColor.systemRed
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.databaseStatusLabel.stringValue = "⚠️ MongoDB Check Failed"
                    self.databaseStatusLabel.textColor = NSColor.systemOrange
                }
            }
        }
    }
    
    @objc func startRecording() {
        guard let tracker = trackerBridge else { return }
        
        isTracking = true
        currentSession = "session_\(Date().timeIntervalSince1970)"
        eventCount = 0
        
        tracker.startTracking(sessionId: currentSession!)
        
        updateUI()
        progressIndicator.startAnimation(nil)
        
        print("🚀 Started tracking session: \(currentSession!)")
    }
    
    @objc func stopRecording() {
        guard let tracker = trackerBridge else { return }
        
        isTracking = false
        tracker.stopTracking()
        
        updateUI()
        progressIndicator.stopAnimation(nil)
        
        print("⏹️ Stopped tracking session: \(currentSession ?? "unknown")")
    }
    
    func newSession() {
        if isTracking {
            stopRecording()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startRecording()
        }
    }
    
    func exportSession() {
        guard let session = currentSession else {
            showAlert(title: "No Session", message: "No active session to export.")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "trackera11y-\(session).json"
        savePanel.allowedContentTypes = [.json]
        
        if savePanel.runModal() == .OK {
            guard let url = savePanel.url else { return }
            
            // Export session data
            let exportData: [String: Any] = [
                "sessionId": session,
                "exportedAt": ISO8601DateFormatter().string(from: Date()),
                "eventCount": eventCount,
                "platform": "macOS",
                "version": "1.0.0"
            ]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
                try jsonData.write(to: url)
                showAlert(title: "Export Complete", message: "Session data exported to \(url.lastPathComponent)")
            } catch {
                showAlert(title: "Export Failed", message: "Failed to export session: \(error.localizedDescription)")
            }
        }
    }
    
    func showPreferences() {
        showAlert(title: "Preferences", message: "Preferences panel coming soon!")
    }
    
    @objc func viewSessions() {
        print("📊 Opening session history window...")
        
        // Create a new window to show MongoDB sessions
        let sessionWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        sessionWindow.title = "TrackerA11y - Session History"
        sessionWindow.center()
        
        let sessionViewController = SessionListViewController()
        sessionWindow.contentViewController = sessionViewController
        
        // Keep a strong reference to prevent premature deallocation
        sessionWindows.append(sessionWindow)
        
        // Set up window delegate to clean up reference when closed
        sessionWindow.delegate = self
        
        // Configure window to be independent
        sessionWindow.isReleasedWhenClosed = false  // We'll manage this manually
        sessionWindow.hidesOnDeactivate = false
        
        // Show the window
        sessionWindow.makeKeyAndOrderFront(nil)
        
        print("✅ Session history window opened")
    }
    
    private func updateUI() {
        DispatchQueue.main.async {
            if self.isTracking {
                self.statusLabel.stringValue = "Recording Active"
                self.statusLabel.textColor = NSColor.systemRed
                self.sessionLabel.stringValue = "Session: \(self.currentSession ?? "Unknown")"
                self.eventCountLabel.stringValue = "Events captured: \(self.eventCount)"
                self.startButton.isEnabled = false
                self.stopButton.isEnabled = true
            } else {
                self.statusLabel.stringValue = "Ready"
                self.statusLabel.textColor = NSColor.systemGreen
                self.sessionLabel.stringValue = "No active session"
                self.eventCountLabel.stringValue = "Events captured: 0"
                self.startButton.isEnabled = true
                self.stopButton.isEnabled = false
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    func addSessionWindow(_ window: NSWindow) {
        sessionWindows.append(window)
        window.delegate = self
        print("📊 Added session window to tracking list")
    }
    
    func cleanup() {
        if isTracking {
            stopRecording()
        }
        trackerBridge?.cleanup()
        
        // Close any session windows
        for window in sessionWindows {
            window.close()
        }
        sessionWindows.removeAll()
        
        print("🧹 MainViewController cleaned up")
    }
}

// MARK: - TrackerBridge Delegate
extension MainViewController: TrackerBridgeDelegate {
    func trackerDidCaptureEvent() {
        eventCount += 1
        updateUI()
    }
    
    func trackerDidEncounterError(_ error: String) {
        DispatchQueue.main.async {
            self.showAlert(title: "Tracker Error", message: error)
        }
    }
    
    func trackerDidInitialize() {
        print("✅ Tracker bridge initialized")
    }
}

// MARK: - NSWindowDelegate
extension MainViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Remove the window from our reference array
        if let index = sessionWindows.firstIndex(of: window) {
            sessionWindows.remove(at: index)
            print("📊 Session window closed and reference removed")
        }
    }
}
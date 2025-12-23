import Cocoa
import AVFoundation
import PDFKit

enum ScreenshotType {
    case fullScreen
    case region
    case browserFullPage
}

class MainViewController: NSViewController {
    
    // UI Elements
    private var statusLabel: NSTextField!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    private var eventCountLabel: NSTextField!
    private var sessionLabel: NSTextField!
    private var databaseStatusLabel: NSTextField!
    private var screenRecordingLabel: NSTextField!
    
    // Tracker bridge
    private var trackerBridge: TrackerBridge?
    private var isTracking = false
    private var isPaused = false
    private var currentSession: String?
    private var eventCount = 0
    
    // Screen recorder
    private var screenRecorder: ScreenRecorder?
    private var currentVideoURL: URL?
    
    // Annotation overlay
    private var annotationWindow: AnnotationOverlayWindow?
    private var annotationDrawingView: AnnotationDrawingView?
    private var annotationToolbar: AnnotationToolbar?
    private var isAnnotating = false
    
    // VoiceOver integration
    private var voiceOverIntegration: VoiceOverIntegration?
    private var isVoiceOverMonitoring = false
    private var isCapturingVoiceOverAudio = false
    private var wasVoiceOverEnabledBeforePause = false
    
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
        statusLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = NSColor.systemGreen
        
        sessionLabel = NSTextField(labelWithString: "No active session")
        sessionLabel.font = NSFont.systemFont(ofSize: 16)
        sessionLabel.textColor = NSColor.secondaryLabelColor
        
        eventCountLabel = NSTextField(labelWithString: "Events captured: 0")
        eventCountLabel.font = NSFont.systemFont(ofSize: 16)
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
        databaseStatusLabel.font = NSFont.systemFont(ofSize: 16)
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
        ✅ VoiceOver announcement tracking
        """
        
        let featuresLabel = NSTextField(labelWithString: featuresText)
        featuresLabel.font = NSFont.systemFont(ofSize: 16)
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
            progressIndicator.leadingAnchor.constraint(equalTo: stopButton.trailingAnchor, constant: spacing),
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
        setupScreenRecorder()
        setupVoiceOverIntegration()
    }
    
    private func setupVoiceOverIntegration() {
        voiceOverIntegration = VoiceOverIntegration()
        voiceOverIntegration?.delegate = self
    }
    
    private func setupScreenRecorder() {
        if #available(macOS 12.3, *) {
            screenRecorder = ScreenRecorder()
            screenRecorder?.delegate = self
            
            Task {
                let hasPermission = await screenRecorder?.requestPermissions() ?? false
                await MainActor.run {
                    if hasPermission {
                        print("✅ Screen recording permission granted")
                    } else {
                        print("⚠️ Screen recording permission not granted - open System Settings > Privacy & Security > Screen Recording")
                    }
                }
            }
        } else {
            print("⚠️ Screen recording requires macOS 12.3 or later")
        }
    }
    
    private func getSessionVideoURL(sessionId: String) -> URL? {
        let recordingsPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)"
        
        // Ensure directory exists
        do {
            try FileManager.default.createDirectory(atPath: recordingsPath, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create recordings directory: \(error)")
            return nil
        }
        
        let videoPath = "\(recordingsPath)/screen_recording.mp4"
        return URL(fileURLWithPath: videoPath)
    }
    
    @available(macOS 12.3, *)
    private func saveRecordingMetadata(sessionId: String, recorder: ScreenRecorder) {
        let recordingsPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)"
        let metadataPath = "\(recordingsPath)/metadata.json"
        
        var metadata: [String: Any] = [:]
        
        if FileManager.default.fileExists(atPath: metadataPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: metadataPath)),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            metadata = existing
        }
        
        metadata["recordingStartTimestamp"] = recorder.recordingStartTimestamp
        metadata["hasScreenRecording"] = true
        
        do {
            let data = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try data.write(to: URL(fileURLWithPath: metadataPath))
            print("📝 Saved recording metadata with timestamp: \(recorder.recordingStartTimestamp)")
        } catch {
            print("❌ Failed to save recording metadata: \(error)")
        }
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
        isPaused = false
        currentSession = "session_\(Int(Date().timeIntervalSince1970 * 1000))"
        eventCount = 0
        
        tracker.startTracking(sessionId: currentSession!)
        
        if #available(macOS 12.3, *), let recorder = screenRecorder, let sessionId = currentSession {
            if let videoURL = getSessionVideoURL(sessionId: sessionId) {
                currentVideoURL = videoURL
                Task {
                    do {
                        try await recorder.startRecording(to: videoURL)
                        await MainActor.run {
                            self.saveRecordingMetadata(sessionId: sessionId, recorder: recorder)
                        }
                    } catch {
                        print("❌ Failed to start screen recording: \(error)")
                    }
                }
            }
        }
        
        updateUI()
        progressIndicator.startAnimation(nil)
        
        // Update app delegate status
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.updateRecordingState(.recording)
        }
        
        print("🚀 Started tracking session: \(currentSession!)")
    }
    
    @objc func stopRecording() {
        guard let tracker = trackerBridge else { return }
        
        // Turn off VoiceOver if it's on
        if isVoiceOverEnabled() {
            turnOffVoiceOver()
        }
        
        isTracking = false
        isPaused = false
        tracker.stopTracking()
        
        if #available(macOS 12.3, *), let recorder = screenRecorder {
            Task {
                await recorder.stopRecording()
            }
        }
        
        updateUI()
        progressIndicator.stopAnimation(nil)
        
        // Update app delegate status
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.updateRecordingState(.stopped)
        }
        
        print("⏹️ Stopped tracking session: \(currentSession ?? "unknown")")
    }
    
    @objc func pauseRecording() {
        guard let tracker = trackerBridge, isTracking else { return }
        
        // Remember VoiceOver state and turn it off during pause
        wasVoiceOverEnabledBeforePause = isVoiceOverEnabled()
        if wasVoiceOverEnabledBeforePause {
            turnOffVoiceOver()
        }
        
        isPaused = true
        tracker.pauseTracking()
        
        if #available(macOS 12.3, *) {
            Task {
                await screenRecorder?.pauseRecording()
            }
        }
        
        updateUI()
        
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.updateRecordingState(.paused)
        }
        
        print("⏸ Paused tracking session: \(currentSession ?? "unknown")")
    }
    
    @objc func resumeRecording() {
        guard let tracker = trackerBridge, isTracking, isPaused else { return }
        
        isPaused = false
        tracker.resumeTracking()
        
        if #available(macOS 12.3, *) {
            Task {
                try? await screenRecorder?.resumeRecording()
            }
        }
        
        // Restore VoiceOver if it was on before pause
        if wasVoiceOverEnabledBeforePause {
            turnOnVoiceOver()
        }
        
        updateUI()
        
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.updateRecordingState(.recording)
        }
        
        print("▶️ Resumed tracking session: \(currentSession ?? "unknown")")
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
            if self.isTracking && !self.isPaused {
                self.statusLabel.stringValue = "Recording Active"
                self.statusLabel.textColor = NSColor.systemRed
                self.sessionLabel.stringValue = "Session: \(self.currentSession ?? "Unknown")"
                self.eventCountLabel.stringValue = "Events captured: \(self.eventCount)"
                self.startButton.isEnabled = false
                self.stopButton.isEnabled = true
            } else if self.isTracking && self.isPaused {
                self.statusLabel.stringValue = "Recording Paused"
                self.statusLabel.textColor = NSColor.systemOrange
                self.sessionLabel.stringValue = "Session: \(self.currentSession ?? "Unknown") (Paused)"
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
        print("🔧 DEBUG: MainViewController.cleanup() called, isTracking=\(isTracking), trackerBridge=\(String(describing: trackerBridge))")
        if isTracking {
            stopRecording()
        }
        
        voiceOverIntegration?.stopMonitoring()
        voiceOverIntegration?.stopAudioCapture()
        
        // Use synchronous cleanup to ensure processes terminate before app exits
        print("🔧 DEBUG: About to call trackerBridge?.cleanupSynchronously()")
        trackerBridge?.cleanupSynchronously()
        
        // Close any session windows
        for window in sessionWindows {
            window.close()
        }
        sessionWindows.removeAll()
        
        print("🧹 MainViewController cleaned up")
    }
    
    // MARK: - Edit Actions
    
    func undoEdit() {
        if let sessionDetailVC = findActiveSessionDetailViewController() {
            sessionDetailVC.undoEdit()
        } else {
            print("⚠️ No active session to undo")
        }
    }
    
    func redoEdit() {
        if let sessionDetailVC = findActiveSessionDetailViewController() {
            sessionDetailVC.redoEdit()
        } else {
            print("⚠️ No active session to redo")
        }
    }
    
    private func findActiveSessionDetailViewController() -> SessionDetailViewController? {
        if let keyWindow = NSApplication.shared.keyWindow,
           let contentVC = keyWindow.contentViewController as? SessionDetailViewController {
            return contentVC
        }
        
        for window in sessionWindows {
            if window.isKeyWindow,
               let contentVC = window.contentViewController as? SessionDetailViewController {
                return contentVC
            }
        }
        
        return nil
    }
    
    // MARK: - Screenshot Feature
    
    func takeScreenshot(type: ScreenshotType) {
        guard isTracking, let sessionId = currentSession else {
            showAlert(title: "No Active Recording", message: "Please start a recording before taking a screenshot.")
            return
        }
        
        let wasRecording = !isPaused
        
        if wasRecording {
            pauseRecording()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.captureScreenshot(type: type, sessionId: sessionId) { [weak self] imageURL in
                guard let self = self, let imageURL = imageURL else {
                    if wasRecording {
                        self?.resumeRecording()
                    }
                    return
                }
                
                self.showScreenshotDialog(imageURL: imageURL, sessionId: sessionId) { name, note in
                    self.saveScreenshotEvent(imageURL: imageURL, name: name, note: note, sessionId: sessionId, type: type)
                    
                    if wasRecording {
                        self.resumeRecording()
                    }
                }
            }
        }
    }
    
    private func captureScreenshot(type: ScreenshotType, sessionId: String, completion: @escaping (URL?) -> Void) {
        let recordingsPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)"
        let screenshotsPath = "\(recordingsPath)/screenshots"
        
        do {
            try FileManager.default.createDirectory(atPath: screenshotsPath, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create screenshots directory: \(error)")
            completion(nil)
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "screenshot_\(timestamp).png"
        let outputPath = "\(screenshotsPath)/\(filename)"
        
        switch type {
        case .fullScreen:
            captureFullScreen(outputPath: outputPath, completion: completion)
        case .region:
            captureRegion(outputPath: outputPath, completion: completion)
        case .browserFullPage:
            captureBrowserFullPage(outputPath: outputPath, completion: completion)
        }
    }
    
    private func captureFullScreen(outputPath: String, completion: @escaping (URL?) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", outputPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                print("📸 Full screen screenshot saved to: \(outputPath)")
                completion(URL(fileURLWithPath: outputPath))
            } else {
                print("❌ Screenshot failed with status: \(task.terminationStatus)")
                completion(nil)
            }
        } catch {
            print("❌ Failed to run screencapture: \(error)")
            completion(nil)
        }
    }
    
    private func captureRegion(outputPath: String, completion: @escaping (URL?) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", outputPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 && FileManager.default.fileExists(atPath: outputPath) {
                print("📸 Region screenshot saved to: \(outputPath)")
                completion(URL(fileURLWithPath: outputPath))
            } else {
                print("⚠️ Region screenshot cancelled or failed")
                completion(nil)
            }
        } catch {
            print("❌ Failed to run screencapture: \(error)")
            completion(nil)
        }
    }
    
    private func captureBrowserFullPage(outputPath: String, completion: @escaping (URL?) -> Void) {
        let detectScript = """
        tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
        end tell
        
        if frontApp is "Safari" then
            return "Safari"
        else if frontApp contains "Chrome" then
            return "Chrome"
        else
            return "NotBrowser"
        end if
        """
        
        let detectTask = Process()
        detectTask.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        detectTask.arguments = ["-e", detectScript]
        
        let detectPipe = Pipe()
        detectTask.standardOutput = detectPipe
        
        do {
            try detectTask.run()
            detectTask.waitUntilExit()
            
            let detectData = detectPipe.fileHandleForReading.readDataToEndOfFile()
            let browser = String(data: detectData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if browser == "NotBrowser" || browser.isEmpty {
                DispatchQueue.main.async {
                    self.showAlert(title: "Browser Not Focused", message: "Please focus Safari or Chrome to capture a full page screenshot.")
                    completion(nil)
                }
                return
            }
            
            if browser == "Safari" {
                captureSafariFullPage(outputPath: outputPath, completion: completion)
            } else if browser == "Chrome" {
                captureChromeFullPage(outputPath: outputPath, completion: completion)
            } else {
                self.captureFullScreen(outputPath: outputPath, completion: completion)
            }
        } catch {
            print("❌ Failed to detect browser: \(error)")
            completion(nil)
        }
    }
    
    private func captureSafariFullPage(outputPath: String, completion: @escaping (URL?) -> Void) {
        print("📸 Capturing Safari full page via Export as PDF...")
        
        let tempDir = NSTemporaryDirectory()
        let pdfPath = "\(tempDir)safari_fullpage_\(Int(Date().timeIntervalSince1970)).pdf"
        
        let script = """
        tell application "Safari"
            activate
            delay 0.3
        end tell
        
        tell application "System Events"
            tell process "Safari"
                keystroke "e" using {command down}
                delay 0.5
                
                keystroke "g" using {command down, shift down}
                delay 0.3
                keystroke "\(pdfPath)"
                delay 0.2
                keystroke return
                delay 0.3
                
                keystroke return
                delay 1.5
            end tell
        end tell
        
        return "DONE"
        """
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if FileManager.default.fileExists(atPath: pdfPath) {
                    if let pdfImage = self.renderPDFToImage(pdfPath: pdfPath) {
                        if let tiffData = pdfImage.tiffRepresentation,
                           let bitmap = NSBitmapImageRep(data: tiffData),
                           let pngData = bitmap.representation(using: .png, properties: [:]) {
                            do {
                                try pngData.write(to: URL(fileURLWithPath: outputPath))
                                try? FileManager.default.removeItem(atPath: pdfPath)
                                print("📸 Full page screenshot saved: \(outputPath)")
                                completion(URL(fileURLWithPath: outputPath))
                                return
                            } catch {
                                print("❌ Failed to save PNG: \(error)")
                            }
                        }
                    }
                    try? FileManager.default.removeItem(atPath: pdfPath)
                }
                
                print("⚠️ PDF export failed, falling back to screen capture")
                self.captureFullScreen(outputPath: outputPath, completion: completion)
            }
        } catch {
            print("❌ Safari export failed: \(error)")
            self.captureFullScreen(outputPath: outputPath, completion: completion)
        }
    }
    
    private func renderPDFToImage(pdfPath: String) -> NSImage? {
        guard let pdfDoc = PDFDocument(url: URL(fileURLWithPath: pdfPath)) else {
            print("❌ Could not load PDF")
            return nil
        }
        
        let pageCount = pdfDoc.pageCount
        guard pageCount > 0, let firstPage = pdfDoc.page(at: 0) else {
            return nil
        }
        
        let firstBounds = firstPage.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let pageWidth = firstBounds.width * scale
        
        var totalHeight: CGFloat = 0
        for i in 0..<pageCount {
            if let page = pdfDoc.page(at: i) {
                totalHeight += page.bounds(for: .mediaBox).height * scale
            }
        }
        
        let finalImage = NSImage(size: NSSize(width: pageWidth, height: totalHeight))
        finalImage.lockFocus()
        
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: pageWidth, height: totalHeight).fill()
        
        var yOffset = totalHeight
        for i in 0..<pageCount {
            if let page = pdfDoc.page(at: i) {
                let pageBounds = page.bounds(for: .mediaBox)
                let pageHeight = pageBounds.height * scale
                yOffset -= pageHeight
                
                if let cgImage = page.thumbnail(of: CGSize(width: pageWidth, height: pageHeight), for: .mediaBox).cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: pageWidth, height: pageHeight))
                    nsImage.draw(in: NSRect(x: 0, y: yOffset, width: pageWidth, height: pageHeight))
                }
            }
        }
        
        finalImage.unlockFocus()
        return finalImage
    }
    
    private func captureChromeFullPage(outputPath: String, completion: @escaping (URL?) -> Void) {
        captureSafariFullPage(outputPath: outputPath, completion: completion)
    }
    
    private func captureByScrolling(browser: String, docHeight: Int, viewHeight: Int, originalScrollY: Int, outputPath: String, completion: @escaping (URL?) -> Void) {
        let tempDir = (outputPath as NSString).deletingLastPathComponent
        let overlap = 100
        let effectiveViewHeight = viewHeight - overlap
        let numCaptures = Int(ceil(Double(docHeight) / Double(effectiveViewHeight)))
        
        print("📸 Will capture \(numCaptures) segments for \(docHeight)px page")
        
        let windowIdScript = """
        tell application "\(browser)" to id of front window
        """
        let windowIdTask = Process()
        windowIdTask.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        windowIdTask.arguments = ["-e", windowIdScript]
        let windowIdPipe = Pipe()
        windowIdTask.standardOutput = windowIdPipe
        var browserWindowId: String? = nil
        do {
            try windowIdTask.run()
            windowIdTask.waitUntilExit()
            let data = windowIdPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
                browserWindowId = output
                print("📸 Browser window ID: \(output)")
            }
        } catch {
            print("⚠️ Could not get window ID: \(error)")
        }
        
        var capturedImages: [(position: Int, image: NSImage)] = []
        var currentCapture = 0
        
        func performCapture() {
            if currentCapture >= numCaptures {
                finishCapture()
                return
            }
            
            let scrollPosition = min(currentCapture * effectiveViewHeight, max(0, docHeight - viewHeight))
            
            let scrollScript: String
            if browser == "Safari" {
                scrollScript = "tell application \"Safari\" to do JavaScript \"window.scrollTo(0, \(scrollPosition))\" in current tab of front window"
            } else {
                scrollScript = "tell application \"Google Chrome\" to execute front window's active tab javascript \"window.scrollTo(0, \(scrollPosition))\""
            }
            
            let scrollTask = Process()
            scrollTask.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            scrollTask.arguments = ["-e", scrollScript]
            
            do {
                try scrollTask.run()
                scrollTask.waitUntilExit()
            } catch {
                print("❌ Scroll failed: \(error)")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                let tempPath = "\(tempDir)/temp_scroll_\(currentCapture).png"
                
                let captureTask = Process()
                captureTask.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                if let windowId = browserWindowId {
                    captureTask.arguments = ["-x", "-o", "-l", windowId, tempPath]
                } else {
                    captureTask.arguments = ["-x", tempPath]
                }
                
                do {
                    try captureTask.run()
                    captureTask.waitUntilExit()
                    
                    if FileManager.default.fileExists(atPath: tempPath),
                       let image = NSImage(contentsOfFile: tempPath) {
                        capturedImages.append((position: scrollPosition, image: image))
                        print("📸 Captured segment \(currentCapture + 1)/\(numCaptures) at y=\(scrollPosition), size: \(image.size)")
                        try? FileManager.default.removeItem(atPath: tempPath)
                    }
                } catch {
                    print("❌ Capture failed: \(error)")
                }
                
                currentCapture += 1
                performCapture()
            }
        }
        
        func finishCapture() {
            let restoreScript: String
            if browser == "Safari" {
                restoreScript = "tell application \"Safari\" to do JavaScript \"window.scrollTo(0, \(originalScrollY))\" in current tab of front window"
            } else {
                restoreScript = "tell application \"Google Chrome\" to execute front window's active tab javascript \"window.scrollTo(0, \(originalScrollY))\""
            }
            
            let restoreTask = Process()
            restoreTask.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            restoreTask.arguments = ["-e", restoreScript]
            try? restoreTask.run()
            restoreTask.waitUntilExit()
            
            if capturedImages.isEmpty {
                print("⚠️ No images captured")
                self.captureFullScreen(outputPath: outputPath, completion: completion)
                return
            }
            
            if capturedImages.count == 1 {
                saveImage(capturedImages[0].image, to: outputPath, completion: completion)
                return
            }
            
            stitchImages(capturedImages, docHeight: docHeight, viewHeight: viewHeight, overlap: overlap, to: outputPath, completion: completion)
        }
        
        performCapture()
    }
    
    private func saveImage(_ image: NSImage, to path: String, completion: @escaping (URL?) -> Void) {
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: URL(fileURLWithPath: path))
                print("📸 Saved image to: \(path)")
                completion(URL(fileURLWithPath: path))
            } catch {
                print("❌ Failed to save: \(error)")
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }
    
    private func stitchImages(_ images: [(position: Int, image: NSImage)], docHeight: Int, viewHeight: Int, overlap: Int, to outputPath: String, completion: @escaping (URL?) -> Void) {
        guard let firstImage = images.first?.image else {
            completion(nil)
            return
        }
        
        let sortedImages = images.sorted { $0.position < $1.position }
        let imageWidth = firstImage.size.width
        let windowImageHeight = firstImage.size.height
        
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let scaledViewHeight = CGFloat(viewHeight) * scale
        let chromeHeight = windowImageHeight - scaledViewHeight
        
        print("📸 Stitching: windowHeight=\(windowImageHeight), viewportHeight=\(scaledViewHeight), chromeHeight=\(chromeHeight)")
        
        let effectiveHeight = scaledViewHeight - CGFloat(overlap) * scale
        let totalHeight = CGFloat(docHeight) * scale
        
        print("📸 Creating stitched image: \(imageWidth) x \(totalHeight)")
        
        let stitchedImage = NSImage(size: NSSize(width: imageWidth, height: totalHeight))
        stitchedImage.lockFocus()
        
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: imageWidth, height: totalHeight).fill()
        
        for (index, item) in sortedImages.enumerated() {
            let scaledPosition = CGFloat(item.position) * scale
            let yPositionInStitched = totalHeight - scaledPosition - scaledViewHeight
            
            let sourceRect = NSRect(
                x: 0,
                y: 0,
                width: imageWidth,
                height: scaledViewHeight
            )
            
            let destRect = NSRect(
                x: 0,
                y: max(0, yPositionInStitched),
                width: imageWidth,
                height: scaledViewHeight
            )
            
            print("📸 Drawing segment \(index) at y=\(destRect.origin.y), scrollPos=\(item.position)")
            
            item.image.draw(
                in: destRect,
                from: sourceRect,
                operation: .copy,
                fraction: 1.0
            )
        }
        
        stitchedImage.unlockFocus()
        
        saveImage(stitchedImage, to: outputPath, completion: completion)
    }
    
    private func showScreenshotDialog(imageURL: URL, sessionId: String, completion: @escaping (String, String?) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Save Screenshot"
            alert.informativeText = "Enter a name for this screenshot:"
            alert.alertStyle = .informational
            
            let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 180))
            
            let nameLabel = NSTextField(labelWithString: "Name:")
            nameLabel.frame = NSRect(x: 0, y: 150, width: 60, height: 20)
            containerView.addSubview(nameLabel)
            
            let nameField = NSTextField(frame: NSRect(x: 65, y: 148, width: 330, height: 24))
            nameField.placeholderString = "Screenshot name"
            containerView.addSubview(nameField)
            
            let noteLabel = NSTextField(labelWithString: "Note:")
            noteLabel.frame = NSRect(x: 0, y: 115, width: 60, height: 20)
            containerView.addSubview(noteLabel)
            
            let noteScrollView = NSScrollView(frame: NSRect(x: 65, y: 0, width: 330, height: 110))
            let noteTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 315, height: 110))
            noteTextView.isRichText = true
            noteTextView.allowsUndo = true
            noteTextView.font = NSFont.systemFont(ofSize: 13)
            noteScrollView.documentView = noteTextView
            noteScrollView.hasVerticalScroller = true
            noteScrollView.borderType = .bezelBorder
            containerView.addSubview(noteScrollView)
            
            alert.accessoryView = containerView
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel")
            
            nameField.becomeFirstResponder()
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                let name = nameField.stringValue.isEmpty ? "Screenshot" : nameField.stringValue
                let note = noteTextView.string.isEmpty ? nil : noteTextView.string
                completion(name, note)
            } else {
                try? FileManager.default.removeItem(at: imageURL)
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                    if appDelegate.recordingState == .paused {
                        self.resumeRecording()
                    }
                }
            }
        }
    }
    
    private func saveScreenshotEvent(imageURL: URL, name: String, note: String?, sessionId: String, type: ScreenshotType) {
        let screenshotsPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/screenshots.json"
        
        var screenshots: [[String: Any]] = []
        
        if FileManager.default.fileExists(atPath: screenshotsPath) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: screenshotsPath))
                if let existing = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    screenshots = existing
                }
            } catch {
                print("⚠️ Failed to load existing screenshots.json: \(error)")
            }
        }
        
        let timestamp = Date().timeIntervalSince1970 * 1_000_000
        
        var screenshotEvent: [String: Any] = [
            "type": "screenshot",
            "timestamp": timestamp,
            "source": "system",
            "data": [
                "name": name,
                "imagePath": "screenshots/\(imageURL.lastPathComponent)",
                "screenshotType": String(describing: type)
            ]
        ]
        
        if let note = note {
            var data = screenshotEvent["data"] as? [String: Any] ?? [:]
            data["note"] = note
            screenshotEvent["data"] = data
        }
        
        screenshots.append(screenshotEvent)
        
        do {
            let updatedData = try JSONSerialization.data(withJSONObject: screenshots, options: .prettyPrinted)
            try updatedData.write(to: URL(fileURLWithPath: screenshotsPath))
            print("📸 Screenshot event saved to screenshots.json: \(name)")
            
            eventCount += 1
            updateUI()
        } catch {
            print("❌ Failed to save screenshot event: \(error)")
        }
    }
    
    // MARK: - Annotation Feature
    
    func startAnnotation() {
        guard isTracking, let _ = currentSession else {
            showAlert(title: "No Active Recording", message: "Please start a recording before annotating.")
            return
        }
        
        if isAnnotating {
            return
        }
        
        isAnnotating = true
        
        annotationWindow = AnnotationOverlayWindow()
        
        let drawingView = AnnotationDrawingView(frame: annotationWindow!.contentView!.bounds)
        drawingView.autoresizingMask = [.width, .height]
        drawingView.delegate = self
        annotationWindow!.contentView?.addSubview(drawingView)
        annotationDrawingView = drawingView
        
        annotationToolbar = AnnotationToolbar()
        annotationToolbar?.drawingView = drawingView
        annotationToolbar?.onClose = { [weak self] in
            self?.stopAnnotation()
        }
        
        annotationWindow?.makeKeyAndOrderFront(nil)
        annotationToolbar?.makeKeyAndOrderFront(nil)
        
        print("🎨 Annotation mode started")
    }
    
    func stopAnnotation() {
        guard isAnnotating, let sessionId = currentSession else { return }
        
        let paths = annotationDrawingView?.getAnnotationPaths() ?? []
        let startTime = annotationDrawingView?.getAnnotationStartTime() ?? 0
        let snapshot = annotationDrawingView?.captureSnapshot()
        
        annotationWindow?.orderOut(nil)
        annotationToolbar?.orderOut(nil)
        annotationWindow = nil
        annotationToolbar = nil
        annotationDrawingView = nil
        isAnnotating = false
        
        if !paths.isEmpty {
            saveAnnotationEvent(paths: paths, startTime: startTime, snapshot: snapshot, sessionId: sessionId)
        }
        
        print("🎨 Annotation mode ended")
    }
    
    private func saveAnnotationEvent(paths: [AnnotationPath], startTime: TimeInterval, snapshot: NSImage?, sessionId: String) {
        let screenshotsPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/screenshots.json"
        let annotationsDir = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/annotations"
        
        try? FileManager.default.createDirectory(atPath: annotationsDir, withIntermediateDirectories: true)
        
        var imagePath: String? = nil
        if let snapshot = snapshot {
            let filename = "annotation_\(Int(Date().timeIntervalSince1970 * 1000)).png"
            let fullPath = "\(annotationsDir)/\(filename)"
            
            if let tiffData = snapshot.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: URL(fileURLWithPath: fullPath))
                imagePath = "annotations/\(filename)"
                print("🎨 Annotation snapshot saved: \(filename)")
            }
        }
        
        var screenshots: [[String: Any]] = []
        
        if FileManager.default.fileExists(atPath: screenshotsPath) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: screenshotsPath))
                if let existing = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    screenshots = existing
                }
            } catch {
                print("⚠️ Failed to load existing screenshots.json: \(error)")
            }
        }
        
        let pathsData: [[String: Any]] = paths.map { path in
            [
                "tool": String(describing: path.tool),
                "color": path.color.hexString,
                "strokeWidth": path.strokeWidth,
                "pointCount": path.points.count,
                "timestamp": path.timestamp
            ]
        }
        
        var annotationEvent: [String: Any] = [
            "type": "annotation",
            "timestamp": startTime * 1000,
            "source": "system",
            "data": [
                "pathCount": paths.count,
                "paths": pathsData,
                "duration": (Date().timeIntervalSince1970 * 1000) - startTime
            ]
        ]
        
        if let imagePath = imagePath {
            var data = annotationEvent["data"] as? [String: Any] ?? [:]
            data["imagePath"] = imagePath
            annotationEvent["data"] = data
        }
        
        screenshots.append(annotationEvent)
        
        do {
            let updatedData = try JSONSerialization.data(withJSONObject: screenshots, options: .prettyPrinted)
            try updatedData.write(to: URL(fileURLWithPath: screenshotsPath))
            print("🎨 Annotation event saved with \(paths.count) paths")
            
            eventCount += 1
            updateUI()
        } catch {
            print("❌ Failed to save annotation event: \(error)")
        }
    }
    
    // MARK: - VoiceOver Feature
    
    func toggleVoiceOver() {
        if isVoiceOverEnabled() {
            turnOffVoiceOver()
        } else {
            turnOnVoiceOver()
        }
    }
    
    func turnOnVoiceOver() {
        guard !isVoiceOverEnabled() else { return }
        voiceOverIntegration?.toggleVoiceOver()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startVoiceOverMonitoring()
            self.startVoiceOverAudioCapture()
        }
    }
    
    func turnOffVoiceOver() {
        guard isVoiceOverEnabled() else { return }
        
        stopVoiceOverMonitoring()
        stopVoiceOverAudioCapture()
        voiceOverIntegration?.toggleVoiceOver()
    }
    
    private func startVoiceOverMonitoring() {
        guard !isVoiceOverMonitoring else { return }
        isVoiceOverMonitoring = true
        voiceOverIntegration?.startMonitoring()
    }
    
    private func stopVoiceOverMonitoring() {
        guard isVoiceOverMonitoring else { return }
        isVoiceOverMonitoring = false
        voiceOverIntegration?.stopMonitoring()
    }
    
    func isVoiceOverMonitoringActive() -> Bool {
        return isVoiceOverMonitoring
    }
    
    func isVoiceOverEnabled() -> Bool {
        return voiceOverIntegration?.isVoiceOverEnabled ?? false
    }
    
    private func startVoiceOverAudioCapture() {
        guard isTracking, let sessionId = currentSession else { return }
        guard !isCapturingVoiceOverAudio else { return }
        
        let audioDir = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)"
        let audioPath = "\(audioDir)/voiceover_audio.caf"
        
        isCapturingVoiceOverAudio = true
        voiceOverIntegration?.startAudioCapture(outputURL: URL(fileURLWithPath: audioPath))
    }
    
    private func stopVoiceOverAudioCapture() {
        guard isCapturingVoiceOverAudio else { return }
        isCapturingVoiceOverAudio = false
        voiceOverIntegration?.stopAudioCapture()
    }
    
    func isVoiceOverAudioCaptureActive() -> Bool {
        return isCapturingVoiceOverAudio
    }
    
    private func saveVoiceOverEvent(text: String, element: [String: Any]?, timestamp: TimeInterval, eventType: String) {
        guard let sessionId = currentSession else { return }
        
        let eventsPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/voiceover_events.json"
        
        var events: [[String: Any]] = []
        
        if FileManager.default.fileExists(atPath: eventsPath) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: eventsPath))
                if let existing = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    events = existing
                }
            } catch {
                print("⚠️ Failed to load existing voiceover_events.json: \(error)")
            }
        }
        
        var eventData: [String: Any] = [
            "text": text,
            "eventType": eventType
        ]
        
        if let element = element {
            eventData["element"] = element
        }
        
        let voEvent: [String: Any] = [
            "type": "VoiceOverSpeech",
            "timestamp": timestamp,
            "source": "voiceover",
            "data": eventData
        ]
        
        events.append(voEvent)
        
        do {
            let updatedData = try JSONSerialization.data(withJSONObject: events, options: .prettyPrinted)
            try updatedData.write(to: URL(fileURLWithPath: eventsPath))
            eventCount += 1
            updateUI()
        } catch {
        }
    }
}

// MARK: - VoiceOverIntegrationDelegate
extension MainViewController: VoiceOverIntegrationDelegate {
    func voiceOverDidAnnounce(text: String, element: [String: Any]?, timestamp: TimeInterval) {
        if isTracking && isVoiceOverMonitoring {
            saveVoiceOverEvent(text: text, element: element, timestamp: timestamp, eventType: "announcement")
        }
    }
    
    func voiceOverFocusDidChange(element: [String: Any], timestamp: TimeInterval) {
        if isTracking && isVoiceOverMonitoring {
            let description = element["description"] as? String ?? element["title"] as? String ?? "Focus changed"
            saveVoiceOverEvent(text: description, element: element, timestamp: timestamp, eventType: "focus")
        }
    }
    
    func voiceOverStateDidChange(enabled: Bool) {
    }
}

// MARK: - AnnotationOverlayDelegate
extension MainViewController: AnnotationOverlayDelegate {
    func annotationDidStart() {
        print("🎨 User started drawing")
    }
    
    func annotationDidEnd(paths: [AnnotationPath], snapshot: NSImage?) {
        print("🎨 User finished drawing with \(paths.count) paths")
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

// MARK: - ScreenRecorderDelegate
@available(macOS 12.3, *)
extension MainViewController: ScreenRecorderDelegate {
    func screenRecorderDidStartRecording() {
        print("🎬 Screen recording started")
    }
    
    func screenRecorderDidStopRecording(outputURL: URL?) {
        if let url = outputURL {
            print("🎬 Screen recording saved to: \(url.path)")
        }
    }
    
    func screenRecorderDidPauseRecording(interimURL: URL?) {
        if let url = interimURL {
            print("⏸ Screen recording paused - interim video: \(url.path)")
        } else {
            print("⏸ Screen recording paused")
        }
        
        if let session = currentSession {
            NotificationCenter.default.post(
                name: NSNotification.Name("SessionDataUpdated"),
                object: nil,
                userInfo: ["sessionId": session]
            )
        }
    }
    
    func screenRecorderDidResumeRecording() {
        print("▶️ Screen recording resumed")
    }
    
    func screenRecorderDidFail(error: Error) {
        print("❌ Screen recording failed: \(error)")
        DispatchQueue.main.async {
            self.showAlert(title: "Screen Recording Error", message: error.localizedDescription)
        }
    }
}
import Cocoa

class AdminViewController: NSViewController {
    
    private var titleLabel: NSTextField!
    private var cleanupSection: NSView!
    private var corruptSessionsLabel: NSTextField!
    private var cleanupButton: NSButton!
    private var scanButton: NSButton!
    private var statusLabel: NSTextField!
    private var progressIndicator: NSProgressIndicator!
    
    private var corruptSessions: [String] = []
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scanForCorruptSessions()
    }
    
    private func setupUI() {
        let margin: CGFloat = 30
        
        // Title
        titleLabel = NSTextField(labelWithString: "Admin Panel")
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Cleanup Section
        cleanupSection = NSView()
        cleanupSection.wantsLayer = true
        cleanupSection.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        cleanupSection.layer?.cornerRadius = 10
        cleanupSection.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cleanupSection)
        
        // Section Title
        let sectionTitle = NSTextField(labelWithString: "Session Cleanup")
        sectionTitle.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        cleanupSection.addSubview(sectionTitle)
        
        // Description
        let descriptionLabel = NSTextField(wrappingLabelWithString: "Scan for and remove corrupt or incomplete sessions that have empty events.json files or missing required data.")
        descriptionLabel.font = NSFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        cleanupSection.addSubview(descriptionLabel)
        
        // Corrupt sessions count
        corruptSessionsLabel = NSTextField(labelWithString: "Scanning...")
        corruptSessionsLabel.font = NSFont.systemFont(ofSize: 16)
        corruptSessionsLabel.translatesAutoresizingMaskIntoConstraints = false
        cleanupSection.addSubview(corruptSessionsLabel)
        
        // Scan Button
        scanButton = NSButton(title: "Scan for Issues", target: self, action: #selector(scanForCorruptSessions))
        scanButton.font = NSFont.systemFont(ofSize: 14)
        scanButton.bezelStyle = .rounded
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        cleanupSection.addSubview(scanButton)
        
        // Cleanup Button
        cleanupButton = NSButton(title: "Clean Up Sessions", target: self, action: #selector(performCleanup))
        cleanupButton.font = NSFont.systemFont(ofSize: 14)
        cleanupButton.bezelStyle = .rounded
        cleanupButton.isEnabled = false
        cleanupButton.translatesAutoresizingMaskIntoConstraints = false
        cleanupSection.addSubview(cleanupButton)
        
        // Progress Indicator
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        cleanupSection.addSubview(progressIndicator)
        
        // Status Label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        cleanupSection.addSubview(statusLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            
            // Cleanup Section
            cleanupSection.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            cleanupSection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            cleanupSection.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            
            // Section Title
            sectionTitle.topAnchor.constraint(equalTo: cleanupSection.topAnchor, constant: 20),
            sectionTitle.leadingAnchor.constraint(equalTo: cleanupSection.leadingAnchor, constant: 20),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: 10),
            descriptionLabel.leadingAnchor.constraint(equalTo: cleanupSection.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: cleanupSection.trailingAnchor, constant: -20),
            
            // Corrupt sessions label
            corruptSessionsLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            corruptSessionsLabel.leadingAnchor.constraint(equalTo: cleanupSection.leadingAnchor, constant: 20),
            
            // Progress indicator
            progressIndicator.centerYAnchor.constraint(equalTo: corruptSessionsLabel.centerYAnchor),
            progressIndicator.leadingAnchor.constraint(equalTo: corruptSessionsLabel.trailingAnchor, constant: 10),
            
            // Buttons
            scanButton.topAnchor.constraint(equalTo: corruptSessionsLabel.bottomAnchor, constant: 20),
            scanButton.leadingAnchor.constraint(equalTo: cleanupSection.leadingAnchor, constant: 20),
            scanButton.widthAnchor.constraint(equalToConstant: 130),
            
            cleanupButton.centerYAnchor.constraint(equalTo: scanButton.centerYAnchor),
            cleanupButton.leadingAnchor.constraint(equalTo: scanButton.trailingAnchor, constant: 15),
            cleanupButton.widthAnchor.constraint(equalToConstant: 150),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 15),
            statusLabel.leadingAnchor.constraint(equalTo: cleanupSection.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: cleanupSection.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(equalTo: cleanupSection.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func scanForCorruptSessions() {
        progressIndicator.startAnimation(nil)
        scanButton.isEnabled = false
        corruptSessionsLabel.stringValue = "Scanning..."
        statusLabel.stringValue = ""
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let corrupt = self?.findCorruptSessions() ?? []
            
            DispatchQueue.main.async {
                self?.corruptSessions = corrupt
                self?.progressIndicator.stopAnimation(nil)
                self?.scanButton.isEnabled = true
                
                if corrupt.isEmpty {
                    self?.corruptSessionsLabel.stringValue = "✅ No corrupt sessions found"
                    self?.corruptSessionsLabel.textColor = .systemGreen
                    self?.cleanupButton.isEnabled = false
                } else {
                    self?.corruptSessionsLabel.stringValue = "⚠️ Found \(corrupt.count) corrupt session\(corrupt.count == 1 ? "" : "s")"
                    self?.corruptSessionsLabel.textColor = .systemOrange
                    self?.cleanupButton.isEnabled = true
                }
                
                // Show details
                if !corrupt.isEmpty {
                    let sessionList = corrupt.prefix(5).joined(separator: "\n  • ")
                    let moreText = corrupt.count > 5 ? "\n  ... and \(corrupt.count - 5) more" : ""
                    self?.statusLabel.stringValue = "Sessions to clean up:\n  • \(sessionList)\(moreText)"
                }
            }
        }
    }
    
    private func findCorruptSessions() -> [String] {
        guard let projectPath = findProjectPath() else {
            print("❌ Could not find project path")
            return []
        }
        
        let recordingsPath = "\(projectPath)/recordings"
        var corruptSessions: [String] = []
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: recordingsPath)
            let sessionFolders = contents.filter { $0.hasPrefix("session_") }
            
            for sessionFolder in sessionFolders {
                let sessionPath = "\(recordingsPath)/\(sessionFolder)"
                let eventsPath = "\(sessionPath)/events.json"
                
                var isCorrupt = false
                var reason = ""
                
                // Check if events.json exists
                if !FileManager.default.fileExists(atPath: eventsPath) {
                    isCorrupt = true
                    reason = "missing events.json"
                } else {
                    // Check if events.json is empty or invalid
                    do {
                        let eventsData = try Data(contentsOf: URL(fileURLWithPath: eventsPath))
                        
                        if eventsData.isEmpty {
                            isCorrupt = true
                            reason = "empty events.json"
                        } else if let eventsJson = try JSONSerialization.jsonObject(with: eventsData) as? [String: Any] {
                            // Check if events array exists and has items
                            if let events = eventsJson["events"] as? [[String: Any]] {
                                if events.isEmpty {
                                    isCorrupt = true
                                    reason = "no events recorded"
                                }
                            } else {
                                isCorrupt = true
                                reason = "missing events array"
                            }
                        } else {
                            isCorrupt = true
                            reason = "invalid JSON structure"
                        }
                    } catch {
                        isCorrupt = true
                        reason = "parse error: \(error.localizedDescription)"
                    }
                }
                
                if isCorrupt {
                    print("🔍 Corrupt session: \(sessionFolder) - \(reason)")
                    corruptSessions.append(sessionFolder)
                }
            }
        } catch {
            print("❌ Failed to scan recordings: \(error)")
        }
        
        return corruptSessions
    }
    
    @objc private func performCleanup() {
        guard !corruptSessions.isEmpty else { return }
        
        // Confirm deletion
        let alert = NSAlert()
        alert.messageText = "Clean Up Corrupt Sessions"
        alert.informativeText = "This will permanently delete \(corruptSessions.count) corrupt session\(corruptSessions.count == 1 ? "" : "s"). This action cannot be undone.\n\nAre you sure you want to continue?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        guard response == .alertFirstButtonReturn else { return }
        
        progressIndicator.startAnimation(nil)
        cleanupButton.isEnabled = false
        scanButton.isEnabled = false
        statusLabel.stringValue = "Cleaning up..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var deletedCount = 0
            var failedCount = 0
            
            guard let projectPath = self.findProjectPath() else { return }
            let recordingsPath = "\(projectPath)/recordings"
            
            for sessionFolder in self.corruptSessions {
                let sessionPath = "\(recordingsPath)/\(sessionFolder)"
                
                do {
                    try FileManager.default.removeItem(atPath: sessionPath)
                    print("🗑️ Deleted corrupt session: \(sessionFolder)")
                    deletedCount += 1
                } catch {
                    print("❌ Failed to delete \(sessionFolder): \(error)")
                    failedCount += 1
                }
            }
            
            DispatchQueue.main.async {
                self.progressIndicator.stopAnimation(nil)
                self.scanButton.isEnabled = true
                
                if failedCount == 0 {
                    self.statusLabel.stringValue = "✅ Successfully deleted \(deletedCount) corrupt session\(deletedCount == 1 ? "" : "s")"
                    self.statusLabel.textColor = .systemGreen
                    self.corruptSessions = []
                    self.corruptSessionsLabel.stringValue = "✅ No corrupt sessions found"
                    self.corruptSessionsLabel.textColor = .systemGreen
                    self.cleanupButton.isEnabled = false
                } else {
                    self.statusLabel.stringValue = "⚠️ Deleted \(deletedCount), failed to delete \(failedCount) session\(failedCount == 1 ? "" : "s")"
                    self.statusLabel.textColor = .systemOrange
                    // Re-scan to update the list
                    self.scanForCorruptSessions()
                }
            }
        }
    }
    
    private func findProjectPath() -> String? {
        let possiblePaths = [
            "/Users/bob3/Desktop/trackerA11y",
            FileManager.default.currentDirectoryPath,
            "\(FileManager.default.currentDirectoryPath)/..",
            Bundle.main.bundleURL.deletingLastPathComponent().path,
            Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().path
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: "\(path)/package.json") &&
               FileManager.default.fileExists(atPath: "\(path)/recordings") {
                return path
            }
        }
        return nil
    }
}

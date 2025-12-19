import Cocoa

class SessionListViewController: NSViewController {
    
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var sessions: [[String: Any]] = []
    private var sessionWindows: [NSWindow] = [] // Keep strong references
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
        loadSessions()
    }
    
    private func setupUI() {
        // Create table view
        tableView = NSTableView()
        tableView.headerView = NSTableHeaderView()
        tableView.rowSizeStyle = .default
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(openSession)
        tableView.target = self
        
        // Create columns
        let sessionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("session"))
        sessionColumn.title = "Session ID"
        sessionColumn.width = 200
        tableView.addTableColumn(sessionColumn)
        
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = "Created"
        dateColumn.width = 150
        tableView.addTableColumn(dateColumn)
        
        let eventsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("events"))
        eventsColumn.title = "Events"
        eventsColumn.width = 80
        tableView.addTableColumn(eventsColumn)
        
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "Status"
        statusColumn.width = 100
        tableView.addTableColumn(statusColumn)
        
        let durationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        durationColumn.title = "Duration"
        durationColumn.width = 100
        tableView.addTableColumn(durationColumn)
        
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Create refresh button
        let refreshButton = NSButton()
        refreshButton.title = "Refresh"
        refreshButton.target = self
        refreshButton.action = #selector(loadSessions)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(refreshButton)
        
        // Layout
        NSLayoutConstraint.activate([
            refreshButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            refreshButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            scrollView.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func loadSessions() {
        print("🔄 Loading sessions from recordings directory...")
        
        // Find the TrackerA11y project directory
        guard let projectPath = findProjectPath() else {
            print("❌ Could not find TrackerA11y project path")
            sessions = []
            tableView.reloadData()
            return
        }
        
        let recordingsPath = "\(projectPath)/recordings"
        print("📁 Looking for sessions in: \(recordingsPath)")
        
        DispatchQueue.global(qos: .background).async {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: recordingsPath)
                let sessionFolders = contents.filter { $0.hasPrefix("session_") }
                print("📊 Found \(sessionFolders.count) session folders")
                
                var loadedSessions: [[String: Any]] = []
                
                for sessionFolder in sessionFolders {
                    let sessionPath = "\(recordingsPath)/\(sessionFolder)"
                    let summaryPath = "\(sessionPath)/summary.txt"
                    let eventsPath = "\(sessionPath)/events.json"
                    
                    // Extract timestamp from folder name
                    let timestampStr = String(sessionFolder.dropFirst(8)) // Remove "session_"
                    guard let timestamp = Double(timestampStr) else { continue }
                    
                    let date = Date(timeIntervalSince1970: timestamp / 1000)
                    
                    // Try to read event count from events.json
                    var eventCount = 0
                    if FileManager.default.fileExists(atPath: eventsPath) {
                        do {
                            let eventsData = try Data(contentsOf: URL(fileURLWithPath: eventsPath))
                            if let eventsJson = try JSONSerialization.jsonObject(with: eventsData) as? [String: Any],
                               let events = eventsJson["events"] as? [[String: Any]] {
                                eventCount = events.count
                            }
                        } catch {
                            print("⚠️ Failed to read events.json for \(sessionFolder): \(error)")
                        }
                    }
                    
                    // Check if session has summary.txt (indicates completion)
                    let status = FileManager.default.fileExists(atPath: summaryPath) ? "completed" : "partial"
                    
                    let sessionData: [String: Any] = [
                        "sessionId": sessionFolder,
                        "startTime": timestamp,
                        "eventCount": eventCount,
                        "status": status,
                        "createdAt": ISO8601DateFormatter().string(from: date),
                        "endTime": timestamp + 30000 // Approximate end time
                    ]
                    
                    loadedSessions.append(sessionData)
                }
                
                // Sort by timestamp (newest first)
                loadedSessions.sort { session1, session2 in
                    let time1 = session1["startTime"] as? Double ?? 0
                    let time2 = session2["startTime"] as? Double ?? 0
                    return time1 > time2
                }
                
                DispatchQueue.main.async {
                    self.sessions = loadedSessions
                    self.tableView.reloadData()
                    print("✅ Loaded \(loadedSessions.count) sessions from recordings directory")
                }
                
            } catch {
                print("❌ Failed to read recordings directory: \(error)")
                DispatchQueue.main.async {
                    self.sessions = []
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    private func findProjectPath() -> String? {
        let possiblePaths = [
            "/Users/bob3/Desktop/trackerA11y",  // Most likely location
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
    
    private func parseSessions(_ output: String) {
        guard let data = output.data(using: .utf8) else {
            sessions = []
            tableView.reloadData()
            return
        }
        
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                sessions = jsonArray
            } else {
                sessions = []
            }
        } catch {
            print("Failed to parse sessions JSON:", error)
            sessions = []
        }
        
        tableView.reloadData()
        print("Loaded \(sessions.count) sessions from MongoDB")
    }
    
    @objc private func openSession() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < sessions.count else { return }
        
        let session = sessions[selectedRow]
        guard let sessionId = session["sessionId"] as? String else { return }
        
        print("📊 Opening session details for: \(sessionId)")
        
        // Create session detail window
        let detailWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        detailWindow.title = "Session Details - \(sessionId)"
        detailWindow.center()
        
        // Ensure window doesn't cause app to quit when closed
        detailWindow.isReleasedWhenClosed = false
        detailWindow.hidesOnDeactivate = false
        
        let detailViewController = SessionDetailViewController(sessionId: sessionId, sessionData: session)
        detailWindow.contentViewController = detailViewController
        
        // Keep strong reference to prevent window deallocation
        sessionWindows.append(detailWindow)
        detailWindow.delegate = self
        
        detailWindow.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Table View Data Source
extension SessionListViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return sessions.count
    }
}

// MARK: - Table View Delegate
extension SessionListViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let session = sessions[row]
        let cellView = NSTableCellView()
        
        let textField = NSTextField()
        textField.isBordered = false
        textField.isEditable = false
        textField.backgroundColor = .clear
        
        switch tableColumn?.identifier.rawValue {
        case "session":
            textField.stringValue = session["sessionId"] as? String ?? "Unknown"
        case "date":
            if let createdAt = session["createdAt"] as? [String: Any],
               let dateString = createdAt["$date"] as? String {
                let formatter = ISO8601DateFormatter()
                if let date = formatter.date(from: dateString) {
                    let displayFormatter = DateFormatter()
                    displayFormatter.dateStyle = .short
                    displayFormatter.timeStyle = .short
                    textField.stringValue = displayFormatter.string(from: date)
                } else {
                    textField.stringValue = "Invalid Date"
                }
            } else {
                textField.stringValue = "Unknown"
            }
        case "events":
            textField.stringValue = "\(session["eventCount"] as? Int ?? 0)"
        case "status":
            textField.stringValue = session["status"] as? String ?? "Unknown"
            // Color code the status
            switch textField.stringValue {
            case "completed":
                textField.textColor = .systemGreen
            case "active":
                textField.textColor = .systemBlue
            case "error":
                textField.textColor = .systemRed
            default:
                textField.textColor = .secondaryLabelColor
            }
        case "duration":
            if let endTime = session["endTime"] as? Double,
               let startTime = session["startTime"] as? Double {
                let duration = (endTime - startTime) / 1000 // Convert to seconds
                if duration < 60 {
                    textField.stringValue = String(format: "%.1fs", duration)
                } else {
                    let minutes = Int(duration) / 60
                    let seconds = Int(duration) % 60
                    textField.stringValue = "\(minutes)m \(seconds)s"
                }
            } else {
                textField.stringValue = session["status"] as? String == "active" ? "In Progress" : "Unknown"
            }
        default:
            textField.stringValue = ""
        }
        
        cellView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        return cellView
    }
}

// MARK: - NSWindowDelegate
extension SessionListViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // Remove the window from our reference array to prevent memory leaks
        if let index = sessionWindows.firstIndex(of: window) {
            sessionWindows.remove(at: index)
            print("📊 Session detail window closed and reference removed")
        }
    }
}
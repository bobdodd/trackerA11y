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
        print("🔄 Starting to load sessions from MongoDB...")
        
        // TEMPORARY: Use hardcoded test data to verify UI works
        let testSessions = """
[
  {
    "sessionId": "session_1766121152140",
    "startTime": 1766121152373,
    "eventCount": 3,
    "status": "completed",
    "createdAt": "2025-12-19T05:12:32.373Z",
    "endTime": 1766121157524
  },
  {
    "sessionId": "session_1766120932280",
    "startTime": 1766120933150,
    "eventCount": 93,
    "status": "completed",
    "createdAt": "2025-12-19T05:08:53.150Z",
    "endTime": 1766120947183
  }
]
"""
        
        // Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("📝 Using test session data for UI verification")
            self.parseSessions(testSessions)
        }
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
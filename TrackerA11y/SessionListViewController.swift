import Cocoa

struct SessionData {
    var sessionId: String
    var customName: String?
    var createdDate: Date
    var eventCount: Int
    var status: String
    var duration: TimeInterval?
    var filePath: String
    
    var displayName: String {
        return customName ?? sessionId
    }
}

class SessionListViewController: NSViewController {
    
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var searchField: NSSearchField!
    private var sortPopup: NSPopUpButton!
    private var addButton: NSButton!
    private var deleteButton: NSButton!
    private var refreshButton: NSButton!
    private var sessionsLabel: NSTextField!
    
    private var allSessions: [SessionData] = []
    private var filteredSessions: [SessionData] = []
    private var sessionWindows: [NSWindow] = []
    private var currentSortOrder: SortOrder = .dateDescending
    
    enum SortOrder {
        case nameAscending, nameDescending
        case dateAscending, dateDescending
        case eventsAscending, eventsDescending
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        setupUI()
        loadSessions()
    }
    
    private func setupUI() {
        let margin: CGFloat = 20
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Session Manager")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Sessions count label
        sessionsLabel = NSTextField(labelWithString: "0 sessions")
        sessionsLabel.font = NSFont.systemFont(ofSize: 14)
        sessionsLabel.textColor = .secondaryLabelColor
        sessionsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sessionsLabel)
        
        // Toolbar
        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        
        // Search field
        searchField = NSSearchField()
        searchField.placeholderString = "Search sessions..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(searchField)
        
        // Sort popup
        sortPopup = NSPopUpButton()
        sortPopup.addItems(withTitles: [
            "Sort by Date (Newest)",
            "Sort by Date (Oldest)", 
            "Sort by Name (A-Z)",
            "Sort by Name (Z-A)",
            "Sort by Events (Most)",
            "Sort by Events (Least)"
        ])
        sortPopup.target = self
        sortPopup.action = #selector(sortOrderChanged)
        sortPopup.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(sortPopup)
        
        // Buttons
        refreshButton = NSButton()
        refreshButton.title = "Refresh"
        refreshButton.target = self
        refreshButton.action = #selector(loadSessions)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(refreshButton)
        
        deleteButton = NSButton()
        deleteButton.title = "Delete"
        deleteButton.target = self
        deleteButton.action = #selector(deleteSelectedSessions)
        deleteButton.isEnabled = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(deleteButton)
        
        // Table view with enhanced columns
        tableView = NSTableView()
        tableView.headerView = NSTableHeaderView()
        tableView.rowSizeStyle = .default
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(editSessionName)
        tableView.target = self
        tableView.allowsMultipleSelection = true
        
        // Enhanced columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Session Name"
        nameColumn.width = 250
        nameColumn.isEditable = true
        tableView.addTableColumn(nameColumn)
        
        let createdColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("created"))
        createdColumn.title = "Created"
        createdColumn.width = 160
        tableView.addTableColumn(createdColumn)
        
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
        
        let actionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("actions"))
        actionsColumn.title = "Actions"
        actionsColumn.width = 120
        tableView.addTableColumn(actionsColumn)
        
        // Scroll view
        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            
            // Sessions count
            sessionsLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            sessionsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            
            // Toolbar
            toolbar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            toolbar.heightAnchor.constraint(equalToConstant: 30),
            
            // Search field
            searchField.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            searchField.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            searchField.widthAnchor.constraint(equalToConstant: 200),
            
            // Sort popup
            sortPopup.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 10),
            sortPopup.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            sortPopup.widthAnchor.constraint(equalToConstant: 160),
            
            // Buttons
            deleteButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            deleteButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 70),
            
            refreshButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -10),
            refreshButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 70),
            
            // Table view
            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 15),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin)
        ])
    }
    
    @objc private func loadSessions() {
        print("🔄 Loading sessions from recordings directory...")
        
        guard let projectPath = findProjectPath() else {
            print("❌ Could not find TrackerA11y project path")
            allSessions = []
            applyFiltersAndSort()
            return
        }
        
        let recordingsPath = "\(projectPath)/recordings"
        print("📁 Looking for sessions in: \(recordingsPath)")
        
        DispatchQueue.global(qos: .background).async {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: recordingsPath)
                let sessionFolders = contents.filter { $0.hasPrefix("session_") }
                print("📊 Found \(sessionFolders.count) session folders")
                
                var loadedSessions: [SessionData] = []
                
                for sessionFolder in sessionFolders {
                    let sessionPath = "\(recordingsPath)/\(sessionFolder)"
                    let summaryPath = "\(sessionPath)/summary.txt"
                    let eventsPath = "\(sessionPath)/events.json"
                    
                    // Extract timestamp from folder name
                    let timestampStr = String(sessionFolder.dropFirst(8))
                    guard let timestamp = Double(timestampStr) else { continue }
                    
                    let date = Date(timeIntervalSince1970: timestamp / 1000)
                    
                    // Try to read event count and duration from summary.txt or events.json
                    var eventCount = 0
                    var duration: TimeInterval?
                    
                    if FileManager.default.fileExists(atPath: eventsPath) {
                        do {
                            let eventsData = try Data(contentsOf: URL(fileURLWithPath: eventsPath))
                            if let eventsJson = try JSONSerialization.jsonObject(with: eventsData) as? [String: Any] {
                                if let events = eventsJson["events"] as? [[String: Any]] {
                                    eventCount = events.count
                                }
                                // Calculate duration from startTime and endTime
                                if let startTime = eventsJson["startTime"] as? Double,
                                   let endTime = eventsJson["endTime"] as? Double {
                                    // Convert from microseconds to seconds
                                    duration = (endTime - startTime) / 1000000.0
                                }
                            }
                        } catch {
                            print("⚠️ Failed to read events.json for \(sessionFolder): \(error)")
                        }
                    }
                    
                    // Check if session has summary.txt (indicates completion)
                    let status = FileManager.default.fileExists(atPath: summaryPath) ? "completed" : "partial"
                    
                    // Load custom name from metadata if exists
                    let customName = self.loadCustomSessionName(for: sessionFolder, at: sessionPath)
                    
                    let sessionData = SessionData(
                        sessionId: sessionFolder,
                        customName: customName,
                        createdDate: date,
                        eventCount: eventCount,
                        status: status,
                        duration: duration,
                        filePath: sessionPath
                    )
                    
                    loadedSessions.append(sessionData)
                }
                
                DispatchQueue.main.async {
                    self.allSessions = loadedSessions
                    self.applyFiltersAndSort()
                    print("✅ Loaded \(loadedSessions.count) sessions from recordings directory")
                }
                
            } catch {
                print("❌ Failed to read recordings directory: \(error)")
                DispatchQueue.main.async {
                    self.allSessions = []
                    self.applyFiltersAndSort()
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
    
    private func applyFiltersAndSort() {
        var filtered = allSessions
        
        // Apply search filter
        let searchText = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !searchText.isEmpty {
            filtered = filtered.filter { session in
                session.displayName.localizedCaseInsensitiveContains(searchText) ||
                session.sessionId.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        switch currentSortOrder {
        case .nameAscending:
            filtered.sort { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
        case .nameDescending:
            filtered.sort { $0.displayName.localizedCompare($1.displayName) == .orderedDescending }
        case .dateAscending:
            filtered.sort { $0.createdDate < $1.createdDate }
        case .dateDescending:
            filtered.sort { $0.createdDate > $1.createdDate }
        case .eventsAscending:
            filtered.sort { $0.eventCount < $1.eventCount }
        case .eventsDescending:
            filtered.sort { $0.eventCount > $1.eventCount }
        }
        
        filteredSessions = filtered
        
        DispatchQueue.main.async {
            self.updateSessionsLabel()
            self.tableView.reloadData()
            self.updateDeleteButtonState()
        }
    }
    
    private func updateSessionsLabel() {
        let totalCount = allSessions.count
        let filteredCount = filteredSessions.count
        
        if filteredCount == totalCount {
            sessionsLabel.stringValue = "\(totalCount) session\(totalCount == 1 ? "" : "s")"
        } else {
            sessionsLabel.stringValue = "\(filteredCount) of \(totalCount) sessions"
        }
    }
    
    private func updateDeleteButtonState() {
        deleteButton.isEnabled = tableView.selectedRowIndexes.count > 0
    }
    
    private func loadCustomSessionName(for sessionId: String, at sessionPath: String) -> String? {
        let metadataPath = "\(sessionPath)/metadata.json"
        guard FileManager.default.fileExists(atPath: metadataPath) else { return nil }
        
        do {
            let metadataData = try Data(contentsOf: URL(fileURLWithPath: metadataPath))
            if let metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
               let customName = metadata["customName"] as? String, !customName.isEmpty {
                return customName
            }
        } catch {
            print("⚠️ Failed to load custom name for \(sessionId): \(error)")
        }
        
        return nil
    }
    
    private func saveCustomSessionName(_ name: String, for sessionId: String, at sessionPath: String) {
        let metadataPath = "\(sessionPath)/metadata.json"
        
        var metadata: [String: Any] = [:]
        
        // Load existing metadata if it exists
        if FileManager.default.fileExists(atPath: metadataPath) {
            do {
                let existingData = try Data(contentsOf: URL(fileURLWithPath: metadataPath))
                if let existingMetadata = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
                    metadata = existingMetadata
                }
            } catch {
                print("⚠️ Failed to load existing metadata for \(sessionId): \(error)")
            }
        }
        
        // Update custom name
        metadata["customName"] = name.isEmpty ? nil : name
        metadata["lastModified"] = Date().timeIntervalSince1970
        
        // Save metadata
        do {
            let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try metadataData.write(to: URL(fileURLWithPath: metadataPath))
            print("✅ Saved custom name '\(name)' for session \(sessionId)")
        } catch {
            print("❌ Failed to save custom name for \(sessionId): \(error)")
        }
    }
    
    @objc private func searchFieldChanged() {
        applyFiltersAndSort()
    }
    
    @objc private func sortOrderChanged() {
        let selectedIndex = sortPopup.indexOfSelectedItem
        
        switch selectedIndex {
        case 0: currentSortOrder = .dateDescending
        case 1: currentSortOrder = .dateAscending
        case 2: currentSortOrder = .nameAscending
        case 3: currentSortOrder = .nameDescending
        case 4: currentSortOrder = .eventsDescending
        case 5: currentSortOrder = .eventsAscending
        default: currentSortOrder = .dateDescending
        }
        
        applyFiltersAndSort()
    }
    
    @objc private func deleteSelectedSessions() {
        let selectedRows = tableView.selectedRowIndexes
        guard !selectedRows.isEmpty else {
            // Show alert if no sessions are selected
            let alert = NSAlert()
            alert.messageText = "No Sessions Selected"
            alert.informativeText = "Please select one or more sessions to delete."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        let selectedSessions = selectedRows.compactMap { index in
            index < filteredSessions.count ? filteredSessions[index] : nil
        }
        
        let alert = NSAlert()
        alert.messageText = "Delete Sessions"
        
        if selectedSessions.count == 1 {
            alert.informativeText = "Are you sure you want to delete the session '\(selectedSessions[0].displayName)'? This action cannot be undone."
        } else {
            alert.informativeText = "Are you sure you want to delete \(selectedSessions.count) sessions? This action cannot be undone."
        }
        
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            performDeletion(selectedSessions)
        }
    }
    
    private func performDeletion(_ sessionsToDelete: [SessionData]) {
        var deletedCount = 0
        var failedCount = 0
        
        for session in sessionsToDelete {
            do {
                try FileManager.default.removeItem(atPath: session.filePath)
                print("🗑️ Deleted session: \(session.displayName)")
                deletedCount += 1
            } catch {
                print("❌ Failed to delete session \(session.displayName): \(error)")
                failedCount += 1
            }
        }
        
        // Show result
        if failedCount == 0 {
            print("✅ Successfully deleted \(deletedCount) session\(deletedCount == 1 ? "" : "s")")
        } else {
            let alert = NSAlert()
            alert.messageText = "Deletion Results"
            alert.informativeText = "Successfully deleted \(deletedCount) sessions. Failed to delete \(failedCount) sessions."
            alert.alertStyle = failedCount > 0 ? .warning : .informational
            alert.runModal()
        }
        
        // Reload sessions
        loadSessions()
    }
    
    @objc private func editSessionName() {
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0 && clickedRow < filteredSessions.count else { return }
        
        let session = filteredSessions[clickedRow]
        
        let alert = NSAlert()
        alert.messageText = "Rename Session"
        alert.informativeText = "Enter a new name for this session:"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = session.customName ?? ""
        textField.placeholderString = session.sessionId
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        // Make the text field first responder
        textField.becomeFirstResponder()
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            saveCustomSessionName(newName, for: session.sessionId, at: session.filePath)
            loadSessions() // Reload to reflect changes
        }
    }
    
    @objc private func openSession() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < filteredSessions.count else { return }
        
        let session = filteredSessions[selectedRow]
        print("📊 Opening session details for: \(session.displayName)")
        
        // Create session detail window
        let detailWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        detailWindow.title = "Session Details - \(session.displayName)"
        detailWindow.center()
        
        // Ensure window doesn't cause app to quit when closed
        detailWindow.isReleasedWhenClosed = false
        detailWindow.hidesOnDeactivate = false
        
        // Convert SessionData to dictionary format for compatibility
        let sessionDict: [String: Any] = [
            "sessionId": session.sessionId,
            "customName": session.customName ?? NSNull(),
            "createdAt": ["$date": ISO8601DateFormatter().string(from: session.createdDate)],
            "eventCount": session.eventCount,
            "status": session.status,
            "duration": session.duration ?? NSNull(),
            "filePath": session.filePath
        ]
        
        let detailViewController = SessionDetailViewController(sessionId: session.sessionId, sessionData: sessionDict)
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
        return filteredSessions.count
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        return false
    }
    
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        return false
    }
}

// MARK: - Table View Delegate
extension SessionListViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredSessions.count else { return nil }
        
        let session = filteredSessions[row]
        
        switch tableColumn?.identifier.rawValue {
        case "name":
            let cellView = NSTableCellView()
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = true
            textField.backgroundColor = .clear
            textField.stringValue = session.displayName
            textField.target = self
            textField.action = #selector(sessionNameChanged(_:))
            textField.tag = row
            
            cellView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            return cellView
            
        case "created":
            let cellView = NSTableCellView()
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            textField.stringValue = dateFormatter.string(from: session.createdDate)
            
            cellView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            return cellView
            
        case "events":
            let cellView = NSTableCellView()
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.alignment = .center
            textField.stringValue = "\(session.eventCount)"
            
            cellView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            return cellView
            
        case "status":
            let cellView = NSTableCellView()
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.stringValue = session.status.capitalized
            
            // Color code the status
            switch session.status {
            case "completed":
                textField.textColor = .systemGreen
            case "active", "recording":
                textField.textColor = .systemBlue
            case "error", "failed":
                textField.textColor = .systemRed
            case "partial":
                textField.textColor = .systemOrange
            default:
                textField.textColor = .secondaryLabelColor
            }
            
            cellView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            return cellView
            
        case "duration":
            let cellView = NSTableCellView()
            
            let textField = NSTextField()
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.alignment = .center
            
            if let duration = session.duration {
                if duration < 60 {
                    textField.stringValue = String(format: "%.1fs", duration)
                } else {
                    let minutes = Int(duration) / 60
                    let seconds = Int(duration) % 60
                    textField.stringValue = "\(minutes)m \(seconds)s"
                }
            } else {
                textField.stringValue = session.status == "active" ? "In Progress" : "--"
                textField.textColor = .secondaryLabelColor
            }
            
            cellView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])
            
            return cellView
            
        case "actions":
            let cellView = NSView()
            
            let viewButton = NSButton()
            viewButton.title = "View"
            viewButton.target = self
            viewButton.action = #selector(viewSession(_:))
            viewButton.tag = row
            viewButton.bezelStyle = .rounded
            viewButton.setButtonType(.momentaryPushIn)
            
            let deleteButton = NSButton()
            deleteButton.title = "Delete"
            deleteButton.target = self
            deleteButton.action = #selector(deleteSession(_:))
            deleteButton.tag = row
            deleteButton.bezelStyle = .rounded
            deleteButton.setButtonType(.momentaryPushIn)
            
            cellView.addSubview(viewButton)
            cellView.addSubview(deleteButton)
            
            viewButton.translatesAutoresizingMaskIntoConstraints = false
            deleteButton.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                viewButton.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
                viewButton.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                viewButton.widthAnchor.constraint(equalToConstant: 50),
                
                deleteButton.leadingAnchor.constraint(equalTo: viewButton.trailingAnchor, constant: 5),
                deleteButton.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                deleteButton.widthAnchor.constraint(equalToConstant: 50)
            ])
            
            return cellView
            
        default:
            return nil
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateDeleteButtonState()
    }
    
    @objc private func sessionNameChanged(_ sender: NSTextField) {
        let row = sender.tag
        guard row < filteredSessions.count else { return }
        
        let session = filteredSessions[row]
        let newName = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        saveCustomSessionName(newName, for: session.sessionId, at: session.filePath)
        loadSessions() // Reload to reflect changes
    }
    
    @objc private func viewSession(_ sender: NSButton) {
        let row = sender.tag
        guard row < filteredSessions.count else { return }
        
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        openSession()
    }
    
    @objc private func deleteSession(_ sender: NSButton) {
        let row = sender.tag
        guard row < filteredSessions.count else { return }
        
        let session = filteredSessions[row]
        
        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Delete Session"
        alert.informativeText = "Are you sure you want to delete the session '\(session.displayName)'? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            performDeletion([session])
        }
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
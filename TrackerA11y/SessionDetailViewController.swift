import Cocoa

class SessionDetailViewController: NSViewController {
    
    private let sessionId: String
    private let sessionData: [String: Any]
    private var events: [[String: Any]] = []
    
    // UI Elements
    private var tabView: NSTabView!
    private var textView: NSTextView!
    private var timelineView: TimelineView!
    private var loadingIndicator: NSProgressIndicator!
    
    init(sessionId: String, sessionData: [String: Any]) {
        self.sessionId = sessionId
        self.sessionData = sessionData
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        print("🚀 loadView called for session: \(sessionId)")
        print("🚀 sessionData has \(sessionData.count) keys: \(Array(sessionData.keys))")
        
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        print("🚀 About to call setupUI()")
        setupUI()
        print("🚀 About to call loadSessionEvents()")
        loadSessionEvents()
        print("🚀 loadView completed")
    }
    
    private func setupUI() {
        print("📋 setupUI started")
        
        // Create tab view
        tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)
        print("📋 Created and added tabView")
        
        // Session Info Tab
        print("📋 Creating Session Info tab...")
        let infoTab = NSTabViewItem()
        infoTab.label = "Session Info"
        let infoView = createSessionInfoView()
        infoTab.view = infoView
        tabView.addTabViewItem(infoTab)
        print("📋 Added Session Info tab")
        
        // Text Log Tab
        print("📋 Creating Event Log tab...")
        let textTab = NSTabViewItem()
        textTab.label = "Event Log"
        let logView = createTextLogView()
        textTab.view = logView
        tabView.addTabViewItem(textTab)
        print("📋 Added Event Log tab")
        
        // Timeline Tab
        print("📋 Creating Timeline tab...")
        let timelineTab = NSTabViewItem()
        timelineTab.label = "Timeline"
        let timelineTabView = createTimelineView()
        timelineTab.view = timelineTabView
        tabView.addTabViewItem(timelineTab)
        print("📋 Added Timeline tab")
        
        // Loading indicator
        loadingIndicator = NSProgressIndicator()
        loadingIndicator.style = .spinning
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        // Layout
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        loadingIndicator.startAnimation(nil)
        print("📋 setupUI completed with \(tabView.numberOfTabViewItems) tabs")
    }
    
    private func createSessionInfoView() -> NSView {
        print("📋 createSessionInfoView called")
        let containerView = NSView()
        
        // Format the actual session information - EXACTLY like the working debug version
        var infoText = "SESSION INFORMATION\n\nSession ID: \(sessionId)\n\n"
        
        if let status = sessionData["status"] as? String {
            infoText += "Status: \(status.uppercased())\n"
        }
        
        if let eventCount = sessionData["eventCount"] as? Int {
            infoText += "Event Count: \(eventCount)\n"
        }
        
        if let startTime = sessionData["startTime"] as? Double,
           let endTime = sessionData["endTime"] as? Double {
            let duration = (endTime - startTime) / 1000
            infoText += "Duration: \(String(format: "%.1f seconds", duration))\n"
        }
        
        if let createdAt = sessionData["createdAt"] as? String {
            infoText += "Created: \(createdAt)\n"
        }
        
        infoText += "\nData keys: \(Array(sessionData.keys))\n"
        infoText += "\nThis should definitely be visible!"
        
        // Use EXACTLY the same approach as the working debug version
        let infoLabel = NSTextField(labelWithString: infoText)
        infoLabel.font = NSFont.systemFont(ofSize: 14)
        infoLabel.textColor = NSColor.labelColor
        infoLabel.backgroundColor = NSColor.clear
        infoLabel.alignment = .left
        infoLabel.lineBreakMode = .byWordWrapping
        infoLabel.maximumNumberOfLines = 0
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            infoLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -20)
        ])
        
        print("📋 Created session info view - SHOULD BE VISIBLE")
        return containerView
    }
    
    private func createTextLogView() -> NSView {
        print("📝 createTextLogView called")
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        
        // Create the label that will be updated with event data
        let eventLabel = NSTextField(labelWithString: "Loading event data...")
        eventLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        eventLabel.textColor = NSColor.labelColor
        eventLabel.backgroundColor = NSColor.clear
        eventLabel.alignment = .left
        eventLabel.lineBreakMode = .byWordWrapping
        eventLabel.maximumNumberOfLines = 0
        eventLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(eventLabel)
        
        NSLayoutConstraint.activate([
            eventLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            eventLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            eventLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            eventLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -20)
        ])
        
        // Store the label for direct updates using a constant key
        let eventLabelKey = UnsafeMutablePointer<Int8>.allocate(capacity: 1)
        objc_setAssociatedObject(containerView, eventLabelKey, eventLabel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Also store the key for lookup
        objc_setAssociatedObject(containerView, "eventLabelKey", eventLabelKey, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        print("📝 Created event log view with updateable label")
        return containerView
    }
    
    private func createTimelineView() -> NSView {
        print("📊 createTimelineView called")
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Create the actual timeline view
        timelineView = TimelineView()
        timelineView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(timelineView)
        
        NSLayoutConstraint.activate([
            timelineView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            timelineView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            timelineView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            timelineView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10)
        ])
        
        print("📊 Created timeline view with actual TimelineView component")
        return containerView
    }
    
    private func loadSessionEvents() {
        print("🔄 Starting to load session events for: \(sessionId)")
        
        // Load actual session data from the recordings directory
        let recordingsPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/events.json"
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                print("🔄 Loading session data from: \(recordingsPath)")
                let data = try Data(contentsOf: URL(fileURLWithPath: recordingsPath))
                
                // Parse the session file (which contains sessionId, events array, etc.)
                guard let sessionJson = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let eventsArray = sessionJson["events"] as? [[String: Any]] else {
                    print("❌ Failed to parse session file structure")
                    DispatchQueue.main.async {
                        self.events = []
                        self.loadingIndicator.stopAnimation(nil)
                        self.loadingIndicator.isHidden = true
                        self.updateTextLog()
                        self.updateTimeline()
                    }
                    return
                }
                
                print("✅ Successfully loaded \(eventsArray.count) events from file")
                
                DispatchQueue.main.async {
                    self.events = eventsArray
                    self.loadingIndicator.stopAnimation(nil)
                    self.loadingIndicator.isHidden = true
                    self.updateTextLog()
                    self.updateTimeline()
                }
                
            } catch {
                print("❌ Failed to load session events from file: \(error)")
                
                // Fallback: try to load from MongoDB as before (commented out for now)
                DispatchQueue.main.async {
                    self.events = []
                    self.loadingIndicator.stopAnimation(nil)
                    self.loadingIndicator.isHidden = true
                    self.updateTextLog()
                    self.updateTimeline()
                }
            }
        }
    }
    
    private func parseAndDisplayEvents(_ output: String) {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedOutput.isEmpty else {
            print("Empty JSON output received")
            events = []
            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimation(nil)
                self.loadingIndicator.isHidden = true
                self.updateTextLog()
                self.updateTimeline()
            }
            return
        }
        
        guard let data = trimmedOutput.data(using: .utf8) else {
            print("Failed to convert JSON string to data")
            events = []
            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimation(nil)
                self.loadingIndicator.isHidden = true
                self.updateTextLog()
                self.updateTimeline()
            }
            return
        }
        
        print("Parsing JSON output (length: \(trimmedOutput.count))")
        print("JSON preview:", String(trimmedOutput.prefix(200)))
        
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                events = jsonArray
                print("✅ Successfully loaded \(events.count) events for session \(sessionId)")
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimation(nil)
                    self.loadingIndicator.isHidden = true
                    self.updateTextLog()
                    self.updateTimeline()
                }
            } else {
                // Check if it's an error response
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = jsonObject["error"] as? String {
                    print("❌ MongoDB error received:", error)
                } else {
                    print("❌ JSON was not an array, it was:", type(of: try JSONSerialization.jsonObject(with: data)))
                }
                events = []
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimation(nil)
                    self.loadingIndicator.isHidden = true
                    self.updateTextLog()
                    self.updateTimeline()
                }
            }
        } catch {
            print("❌ Failed to parse JSON:", error)
            print("Raw output was:", String(trimmedOutput.prefix(500)))
            events = []
            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimation(nil)
                self.loadingIndicator.isHidden = true
                self.updateTextLog()
                self.updateTimeline()
            }
        }
    }
    
    private func updateTextLog() {
        print("📝 updateTextLog called with \(events.count) events")
        
        var logText = "EVENT LOG\n"
        logText += "=========\n\n"
        logText += "Session ID: \(sessionId)\n"
        logText += "Total Events: \(events.count)\n\n"
        
        if events.isEmpty {
            logText += "No events found for this session.\n"
            logText += "This could mean:\n"
            logText += "• The session recorded no events\n"
            logText += "• There was an issue connecting to MongoDB\n"
            logText += "• The session ID doesn't match any records\n"
        } else {
            for (index, event) in events.enumerated() {
                if let timestamp = event["timestamp"] as? Double,
                   let source = event["source"] as? String,
                   let type = event["type"] as? String {
                    
                    let time = formatTimestamp(timestamp)
                    let eventData = formatEventData(event["data"] as? [String: Any] ?? [:])
                    
                    logText += String(format: "%04d | %@ | %@ | %@ | %@\n",
                                    index + 1, time, source.uppercased(), type, eventData)
                } else {
                    logText += String(format: "%04d | Invalid event format: %@\n", 
                                    index + 1, String(describing: event))
                }
            }
        }
        
        print("📝 Generated log text (\(logText.count) characters):")
        print(String(logText.prefix(200)))
        
        // Find the event log tab and update its label
        guard let eventLogTab = tabView.tabViewItems.first(where: { $0.label == "Event Log" }) else {
            print("📝 ❌ Could not find Event Log tab")
            return
        }
        
        guard let containerView = eventLogTab.view else {
            print("📝 ❌ Event Log tab has no view")
            return
        }
        
        guard let eventLabelKey = objc_getAssociatedObject(containerView, "eventLabelKey") as? UnsafeMutablePointer<Int8>,
              let eventLabel = objc_getAssociatedObject(containerView, eventLabelKey) as? NSTextField else {
            print("📝 ❌ Could not find event label in container view")
            print("📝 ❌ Container view subviews: \(containerView.subviews.count)")
            
            // Fallback: try to find the label directly in subviews
            if let foundLabel = containerView.subviews.first(where: { $0 is NSTextField }) as? NSTextField {
                print("📝 ⚡ Found label via subview search, updating directly")
                foundLabel.stringValue = logText
                foundLabel.needsDisplay = true
                containerView.needsDisplay = true
                return
            }
            return
        }
        
        print("📝 ⚡ Updating event label with \(logText.count) characters")
        eventLabel.stringValue = logText
        print("📝 ✅ Successfully updated event log label")
        
        // Force the view to refresh
        eventLabel.needsDisplay = true
        containerView.needsDisplay = true
    }
    
    private func updateTimeline() {
        timelineView.setEvents(events)
    }
    
    private func formatTimestamp(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1_000_000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func formatEventData(_ data: [String: Any]) -> String {
        if let appName = data["applicationName"] as? String {
            return "App: \(appName)"
        }
        if let interactionType = data["interactionType"] as? String {
            if let coords = data["coordinates"] as? [String: Any],
               let x = coords["x"] as? Double,
               let y = coords["y"] as? Double {
                return "\(interactionType) at (\(Int(x)),\(Int(y)))"
            }
            return interactionType
        }
        if let key = data["key"] as? String {
            return "Key: \(key)"
        }
        return String(describing: data).prefix(50).description
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .medium
        return displayFormatter.string(from: date)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        if duration < 60 {
            return String(format: "%.1f seconds", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
    
    @objc private func filterEvents(_ sender: NSSearchField) {
        // TODO: Implement event filtering
        print("Filtering events with: \(sender.stringValue)")
    }
    
    @objc private func exportEventLog() {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(sessionId)_events.txt"
        savePanel.allowedContentTypes = [.plainText]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try textView.string.write(to: url, atomically: true, encoding: .utf8)
                print("✅ Event log exported to \(url.lastPathComponent)")
            } catch {
                print("❌ Failed to export log:", error)
            }
        }
    }
}

// MARK: - Timeline View
class TimelineView: NSView {
    private var events: [[String: Any]] = []
    private var startTime: Double = 0
    private var endTime: Double = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setEvents(_ events: [[String: Any]]) {
        self.events = events
        
        if let firstTimestamp = events.first?["timestamp"] as? Double,
           let lastTimestamp = events.last?["timestamp"] as? Double {
            startTime = firstTimestamp
            endTime = lastTimestamp
        }
        
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard !events.isEmpty else {
            // Draw empty state
            let text = "No events to display"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let size = text.size(withAttributes: attributes)
            let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
            text.draw(at: point, withAttributes: attributes)
            return
        }
        
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        
        // Draw timeline background
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        
        // Calculate timeline dimensions
        let margin: CGFloat = 40
        let timelineRect = NSRect(
            x: margin,
            y: margin,
            width: bounds.width - 2 * margin,
            height: bounds.height - 2 * margin
        )
        
        // Group events by type
        var eventsByType: [String: [CGFloat]] = [:]
        let duration = endTime - startTime
        
        for event in events {
            guard let timestamp = event["timestamp"] as? Double,
                  let source = event["source"] as? String else { continue }
            
            let relativeTime = (timestamp - startTime) / duration
            let x = timelineRect.minX + relativeTime * timelineRect.width
            
            if eventsByType[source] == nil {
                eventsByType[source] = []
            }
            eventsByType[source]?.append(x)
        }
        
        // Draw events
        let colors: [String: NSColor] = [
            "focus": .systemBlue,
            "interaction": .systemGreen,
            "system": .systemOrange,
            "custom": .systemPurple
        ]
        
        let trackHeight = timelineRect.height / CGFloat(eventsByType.count)
        var trackIndex: CGFloat = 0
        
        for (eventType, positions) in eventsByType {
            let color = colors[eventType] ?? .systemGray
            let trackY = timelineRect.minY + trackIndex * trackHeight
            
            // Draw track background
            color.withAlphaComponent(0.1).setFill()
            NSRect(x: timelineRect.minX, y: trackY, width: timelineRect.width, height: trackHeight).fill()
            
            // Draw event markers
            color.setFill()
            for x in positions {
                let eventRect = NSRect(x: x - 2, y: trackY + 5, width: 4, height: trackHeight - 10)
                eventRect.fill()
            }
            
            // Draw track label
            let label = eventType.uppercased()
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.labelColor
            ]
            label.draw(at: NSPoint(x: 5, y: trackY + trackHeight/2 - 5), withAttributes: labelAttributes)
            
            trackIndex += 1
        }
        
        // Draw time axis
        NSColor.labelColor.setStroke()
        let timePath = NSBezierPath()
        timePath.move(to: NSPoint(x: timelineRect.minX, y: timelineRect.maxY + 20))
        timePath.line(to: NSPoint(x: timelineRect.maxX, y: timelineRect.maxY + 20))
        timePath.lineWidth = 1
        timePath.stroke()
        
        // Draw time labels
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let startDate = Date(timeIntervalSince1970: startTime / 1_000_000)
        let endDate = Date(timeIntervalSince1970: endTime / 1_000_000)
        
        let startLabel = timeFormatter.string(from: startDate)
        let endLabel = timeFormatter.string(from: endDate)
        
        let timeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        startLabel.draw(at: NSPoint(x: timelineRect.minX, y: timelineRect.maxY + 25), withAttributes: timeAttributes)
        endLabel.draw(at: NSPoint(x: timelineRect.maxX - 60, y: timelineRect.maxY + 25), withAttributes: timeAttributes)
        
        context?.restoreGState()
    }
}
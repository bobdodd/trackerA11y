import Cocoa
import ObjectiveC
import AVFoundation
import AVKit

class FlippedClipView: NSClipView {
    override var isFlipped: Bool { return true }
}

class TagsNotesCellView: NSView {
    weak var viewController: SessionDetailViewController?
    var eventIndex: Int = -1
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if let event = NSApp.currentEvent, event.type == .rightMouseDown {
            return self
        }
        return hit
    }
    
    override func rightMouseDown(with event: NSEvent) {
        guard let vc = viewController, eventIndex >= 0 else {
            super.rightMouseDown(with: event)
            return
        }
        let menu = vc.createTagsNotesContextMenu(for: eventIndex)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let vc = viewController, eventIndex >= 0 else {
            return super.menu(for: event)
        }
        return vc.createTagsNotesContextMenu(for: eventIndex)
    }
}

class SessionDetailViewController: NSViewController {
    
    private let sessionId: String
    private let sessionData: [String: Any]
    private var events: [[String: Any]] = []
    private var sessionMetadata: [String: Any] = [:]
    
    // UI Elements
    private var tabView: NSTabView!
    private var textView: NSTextView!
    private var timelineView: EnhancedTimelineView!
    private var loadingIndicator: NSProgressIndicator!
    
    // Enhanced Tab Components
    private var sessionNameField: NSTextField!
    private var sessionTagsField: NSTextField!
    private var sessionNotesView: NSTextView!
    private var eventFilterField: NSSearchField!
    private var eventTypeFilter: NSPopUpButton!
    private var eventTableView: NSTableView!
    private var statsContainer: NSView!
    
    // Direct references to overview UI elements for reliable updates
    private var statusValueField: NSTextField?
    private var eventsValueField: NSTextField?
    private var durationValueField: NSTextField?
    private var statsContainerView: NSView?
    private var breakdownContainerView: NSView?
    
    // Direct references to professional cards for reliable updates
    private var metricsCardContainer: NSView?
    private var statusCardContainer: NSView?
    private var eventAnalyticsCardContainer: NSView?
    private var timelineCardContainer: NSView?
    private var insightsCardContainer: NSView?
    
    // Session Statistics
    private var sessionStats = SessionStats()
    
    // Simple tab labels for direct data display
    private var simpleOverviewLabel: NSTextField?
    private var simpleEventsLabel: NSTextField?
    private var simpleTimelineLabel: NSTextField?
    
    // Events tab table view and filters
    private var eventsTableView: NSTableView?
    private var eventsCountLabel: NSTextField?
    private var eventsDetailPanel: NSScrollView?
    private var eventsDetailTextView: NSTextView?
    private var eventsDetailStackView: NSStackView?
    private var eventsSearchField: NSSearchField?
    private var sourceFilterPopup: NSPopUpButton?
    private var typeFilterButton: NSButton?
    private var tagFilterButton: NSButton?
    private var selectedTypes: Set<String> = []
    private var selectedTags: Set<String> = []
    private var filteredEvents: [[String: Any]] = []
    private var eventTags: [Int: Set<String>] = [:]  // Maps event index to tags
    private var eventNotes: [Int: Data] = [:]  // Maps event index to RTF data
    private var allTags: Set<String> = ["Important", "Bug", "Question", "Follow-up", "Resolved"]
    private var allTypes: Set<String> = []
    private var pendingMarkers: [String: [String: Any]] = [:]  // Markers to insert after events load
    private var sessionStartTimestamp: Double = 0  // First event timestamp for relative time display
    
    // Video player for Timeline tab
    private var videoPlayerView: AVPlayerView?
    private var videoPlayer: AVPlayer?
    private var videoTimeObserver: Any?
    private var timelineScrollView: NSScrollView?
    private var isVideoSyncEnabled: Bool = true
    private var isSyncingFromVideo: Bool = false
    private var isSyncingFromTimeline: Bool = false
    private var videoStartTimestamp: Double = 0  // Recording start timestamp from metadata
    private var lastPlayheadTimestamp: Double = 0  // Track playhead position for direction detection
    private var lastAutoShownEventTimestamp: Double = 0  // Track last event shown during playback
    private var isUserSelectedEvent: Bool = false  // True when user clicked an event (disables auto-update until playback)
    private var isVideoPlaying: Bool = false  // Track if video is actively playing
    private var pauseGaps: [(start: Double, end: Double, duration: Double)] = []  // Pause gaps for video/event time conversion
    private var screenshotWindows: [NSWindow] = []  // Keep references to screenshot viewer windows
    private var screenshotPaths: [Int: String] = [:]  // Map button tag to screenshot path
    private var scrollViewRefs: [Int: NSScrollView] = [:]  // Map button tag to scroll view
    
    private var currentNotePanel: NSPanel?
    private var currentNoteTextView: NSTextView?
    private var currentNoteEventIndex: Int = -1
    private var pendingNoteRTFData: Data?
    private var pendingMarkerEventIndex: Int?
    
    init(sessionId: String, sessionData: [String: Any]) {
        self.sessionId = sessionId
        self.sessionData = sessionData
        print("🔍 SessionDetailViewController init with sessionId: \(sessionId)")
        print("🔍 SessionData keys: \(Array(sessionData.keys))")
        print("🔍 EventCount from sessionData: \(sessionData["eventCount"] ?? "nil")")
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let observer = videoTimeObserver, let player = videoPlayer {
            player.removeTimeObserver(observer)
        }
        videoPlayer?.removeObserver(self, forKeyPath: "rate")
        NotificationCenter.default.removeObserver(self)
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view.autoresizingMask = [.width, .height]
        
        // Load recordingStartTimestamp from metadata FIRST - this is the datum (00:00:00)
        loadRecordingStartTimestamp()
        
        setupUI()
        loadSessionEvents()
        loadSessionMetadata()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionDataUpdated(_:)),
            name: NSNotification.Name("SessionDataUpdated"),
            object: nil
        )
    }
    
    @objc private func handleSessionDataUpdated(_ notification: Notification) {
        guard let updatedSessionId = notification.userInfo?["sessionId"] as? String,
              updatedSessionId == sessionId else { return }
        
        print("🔄 Session data updated, refreshing view...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadRecordingStartTimestamp()
            self.loadSessionEvents()
            self.loadSessionMetadata()
            self.reloadVideo()
        }
    }
    
    private func reloadVideo() {
        let videoPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/screen_recording.mp4"
        let videoURL = URL(fileURLWithPath: videoPath)
        
        guard FileManager.default.fileExists(atPath: videoPath) else {
            print("⚠️ Video file not found for reload: \(videoPath)")
            return
        }
        
        let newItem = AVPlayerItem(url: videoURL)
        videoPlayer?.replaceCurrentItem(with: newItem)
        print("🎬 Video reloaded: \(videoPath)")
    }
    
    private func setupUI() {
        // Create enhanced tab view first
        tabView = NSTabView()
        tabView.tabViewType = .topTabsBezelBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)
        
        // Enhanced Session Overview Tab
        let overviewTab = NSTabViewItem()
        overviewTab.label = "📊 Overview"
        overviewTab.view = createEnhancedOverviewView()
        tabView.addTabViewItem(overviewTab)
        
        // Enhanced Events Analysis Tab
        let eventsTab = NSTabViewItem()
        eventsTab.label = "📝 Events"
        eventsTab.view = createEnhancedEventsView()
        tabView.addTabViewItem(eventsTab)
        
        // Enhanced Timeline Visualization Tab
        let timelineTab = NSTabViewItem()
        timelineTab.label = "📈 Timeline"
        timelineTab.view = createEnhancedTimelineView()
        tabView.addTabViewItem(timelineTab)
        
        // Loading indicator
        loadingIndicator = NSProgressIndicator()
        loadingIndicator.style = .spinning
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        // Simple layout - tabView fills the entire view, anchored to top
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        loadingIndicator.startAnimation(nil)
    }
    
    // Removed complex header setup - simplified approach
    
    // MARK: - Card-Based Overview Tab (Flexbox-style with NSStackView)
    
    private func createEnhancedOverviewView() -> NSView {
        // Main vertical stack (like flex-direction: column)
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 12
        mainStack.alignment = .centerX
        mainStack.distribution = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        
        // Row 1: Header (full width)
        let headerCard = createProfessionalHeaderCard()
        mainStack.addArrangedSubview(headerCard)
        
        // Row 2: Metrics + Status (side by side)
        let row1Stack = NSStackView()
        row1Stack.orientation = .horizontal
        row1Stack.spacing = 12
        row1Stack.distribution = .fillEqually
        row1Stack.translatesAutoresizingMaskIntoConstraints = false
        
        let metricsCard = createKeyMetricsCard()
        let statusCard = createSessionStatusCard()
        row1Stack.addArrangedSubview(metricsCard)
        row1Stack.addArrangedSubview(statusCard)
        mainStack.addArrangedSubview(row1Stack)
        
        // Row 3: Event Analytics + Timeline (side by side, analytics wider)
        let row2Stack = NSStackView()
        row2Stack.orientation = .horizontal
        row2Stack.spacing = 12
        row2Stack.distribution = .fill
        row2Stack.translatesAutoresizingMaskIntoConstraints = false
        
        let eventAnalyticsCard = createEventAnalyticsCard()
        let timelineCard = createTimelineOverviewCard()
        row2Stack.addArrangedSubview(eventAnalyticsCard)
        row2Stack.addArrangedSubview(timelineCard)
        mainStack.addArrangedSubview(row2Stack)
        
        // Row 4: AI Insights (full width)
        let insightsCard = createSessionInsightsCard()
        mainStack.addArrangedSubview(insightsCard)
        
        // Row 5: Actions (full width)
        let actionsCard = createSessionActionsCard()
        mainStack.addArrangedSubview(actionsCard)
        
        // Wrap in scroll view for smaller windows
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .controlBackgroundColor
        scrollView.drawsBackground = true
        
        let clipView = NSClipView()
        clipView.documentView = mainStack
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        
        // Constraints for stack view width to match scroll view
        NSLayoutConstraint.activate([
            mainStack.widthAnchor.constraint(equalTo: clipView.widthAnchor),
            
            // Row widths fill parent
            row1Stack.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -32),
            row2Stack.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -32),
            headerCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -32),
            insightsCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -32),
            actionsCard.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -32),
            
            // Analytics card gets 60% width in row2
            eventAnalyticsCard.widthAnchor.constraint(equalTo: row2Stack.widthAnchor, multiplier: 0.58)
        ])
        
        return scrollView
    }
    
    private func createStyledSessionInfoCard() -> NSView {
        let card = createStyledCard(title: "📋 Session Information", titleColor: .systemBlue)
        
        // Create grid layout for session info
        let gridView = NSView()
        gridView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(gridView)
        
        // Session ID row
        let sessionIdRow = createInfoRow("Session ID", sessionId, icon: "🆔")
        gridView.addSubview(sessionIdRow)
        
        // Status row (will be updated)
        let statusRow = createInfoRow("Status", "Loading...", icon: "📊")
        gridView.addSubview(statusRow)
        if let valueField = objc_getAssociatedObject(statusRow, "valueField") as? NSTextField {
            statusValueField = valueField
        }
        
        // Events row (will be updated)
        let eventsRow = createInfoRow("Events", "Loading...", icon: "📝")
        gridView.addSubview(eventsRow)
        if let valueField = objc_getAssociatedObject(eventsRow, "valueField") as? NSTextField {
            eventsValueField = valueField
        }
        
        // Duration row (will be updated)
        let durationRow = createInfoRow("Duration", "Calculating...", icon: "⏱️")
        gridView.addSubview(durationRow)
        if let valueField = objc_getAssociatedObject(durationRow, "valueField") as? NSTextField {
            durationValueField = valueField
        }
        
        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: card.topAnchor, constant: 50),
            gridView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            gridView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            gridView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -15),
            
            sessionIdRow.topAnchor.constraint(equalTo: gridView.topAnchor),
            sessionIdRow.leadingAnchor.constraint(equalTo: gridView.leadingAnchor),
            sessionIdRow.trailingAnchor.constraint(equalTo: gridView.centerXAnchor, constant: -10),
            sessionIdRow.heightAnchor.constraint(equalToConstant: 30),
            
            statusRow.topAnchor.constraint(equalTo: gridView.topAnchor),
            statusRow.leadingAnchor.constraint(equalTo: gridView.centerXAnchor, constant: 10),
            statusRow.trailingAnchor.constraint(equalTo: gridView.trailingAnchor),
            statusRow.heightAnchor.constraint(equalToConstant: 30),
            
            eventsRow.topAnchor.constraint(equalTo: sessionIdRow.bottomAnchor, constant: 15),
            eventsRow.leadingAnchor.constraint(equalTo: gridView.leadingAnchor),
            eventsRow.trailingAnchor.constraint(equalTo: gridView.centerXAnchor, constant: -10),
            eventsRow.heightAnchor.constraint(equalToConstant: 30),
            
            durationRow.topAnchor.constraint(equalTo: statusRow.bottomAnchor, constant: 15),
            durationRow.leadingAnchor.constraint(equalTo: gridView.centerXAnchor, constant: 10),
            durationRow.trailingAnchor.constraint(equalTo: gridView.trailingAnchor),
            durationRow.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Store references for updates
        objc_setAssociatedObject(card, "statusRow", statusRow, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(card, "eventsRow", eventsRow, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(card, "durationRow", durationRow, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return card
    }
    
    private func createStyledStatisticsCard() -> NSView {
        let card = createStyledCard(title: "📈 Quick Stats", titleColor: .systemGreen)
        
        let statsContainer = NSView()
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statsContainer)
        
        NSLayoutConstraint.activate([
            statsContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 50),
            statsContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            statsContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            statsContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -15)
        ])
        
        objc_setAssociatedObject(card, "statsContainer", statsContainer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return card
    }
    
    private func createStyledEventBreakdownCard() -> NSView {
        let card = createStyledCard(title: "📊 Event Breakdown", titleColor: .systemPurple)
        
        let breakdownContainer = NSView()
        breakdownContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(breakdownContainer)
        
        NSLayoutConstraint.activate([
            breakdownContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 50),
            breakdownContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            breakdownContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            breakdownContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -15)
        ])
        
        objc_setAssociatedObject(card, "breakdownContainer", breakdownContainer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return card
    }
    
    // MARK: - Professional Card Components
    
    private func createProfessionalHeaderCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.controlAccentColor.withAlphaComponent(0.1))
        card.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        // Session icon and title
        let iconLabel = NSTextField(labelWithString: "📊")
        iconLabel.font = NSFont.systemFont(ofSize: 32)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconLabel)
        
        let titleLabel = NSTextField(labelWithString: "Session Overview")
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = NSColor.controlAccentColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: sessionId)
        subtitleLabel.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = NSColor.secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(subtitleLabel)
        
        // Quick status indicator
        let statusIndicator = createStatusIndicator()
        card.addSubview(statusIndicator)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 90),
            
            iconLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            iconLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -16),
            
            statusIndicator.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            statusIndicator.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 120),
            statusIndicator.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return card
    }
    
    private func createKeyMetricsCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.systemBlue.withAlphaComponent(0.05))
        card.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        let titleLabel = NSTextField(labelWithString: "📈 Key Metrics")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = NSColor.systemBlue
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // Metrics container using stack view for auto-sizing
        let metricsContainer = NSStackView()
        metricsContainer.orientation = .vertical
        metricsContainer.spacing = 8
        metricsContainer.alignment = .leading
        metricsContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(metricsContainer)
        
        // Store direct reference for reliable updates
        self.metricsCardContainer = metricsContainer
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            metricsContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            metricsContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            metricsContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            metricsContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
    
    private func createSessionStatusCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.systemGreen.withAlphaComponent(0.05))
        card.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        let titleLabel = NSTextField(labelWithString: "⚡ Session Status")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = NSColor.systemGreen
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // Status container using stack view
        let statusContainer = NSStackView()
        statusContainer.orientation = .vertical
        statusContainer.spacing = 8
        statusContainer.alignment = .leading
        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statusContainer)
        
        // Store direct reference
        self.statusCardContainer = statusContainer
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            statusContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            statusContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            statusContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            statusContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
    
    private func createEventAnalyticsCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.systemPurple.withAlphaComponent(0.05))
        card.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        let titleLabel = NSTextField(labelWithString: "📊 Event Analytics")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = NSColor.systemPurple
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // Analytics container using stack view
        let analyticsContainer = NSStackView()
        analyticsContainer.orientation = .vertical
        analyticsContainer.spacing = 6
        analyticsContainer.alignment = .leading
        analyticsContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(analyticsContainer)
        
        // Store direct reference
        self.eventAnalyticsCardContainer = analyticsContainer
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            analyticsContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            analyticsContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            analyticsContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            analyticsContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
    
    private func createTimelineOverviewCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.systemOrange.withAlphaComponent(0.05))
        card.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        let titleLabel = NSTextField(labelWithString: "⏱️ Timeline")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = NSColor.systemOrange
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // Timeline container using stack view
        let timelineContainer = NSStackView()
        timelineContainer.orientation = .vertical
        timelineContainer.spacing = 6
        timelineContainer.alignment = .leading
        timelineContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(timelineContainer)
        
        // Store direct reference
        self.timelineCardContainer = timelineContainer
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            timelineContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            timelineContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            timelineContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            timelineContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
    
    private func createSessionInsightsCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.systemTeal.withAlphaComponent(0.05))
        card.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        let titleLabel = NSTextField(labelWithString: "🧠 AI Insights")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = NSColor.systemTeal
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // Insights container using stack view
        let insightsContainer = NSStackView()
        insightsContainer.orientation = .vertical
        insightsContainer.spacing = 6
        insightsContainer.alignment = .leading
        insightsContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(insightsContainer)
        
        // Store direct reference
        self.insightsCardContainer = insightsContainer
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            insightsContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            insightsContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            insightsContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            insightsContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
    
    private func createSessionActionsCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.controlBackgroundColor)
        
        let actionsStack = NSStackView()
        actionsStack.orientation = .horizontal
        actionsStack.spacing = 16
        actionsStack.alignment = .centerY
        actionsStack.distribution = .fillEqually
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(actionsStack)
        
        // Action buttons with 16px+ text
        let exportButton = createActionButton("📤 Export Session", color: .systemBlue)
        let shareButton = createActionButton("🔗 Share", color: .systemGreen)
        let duplicateButton = createActionButton("📋 Duplicate", color: .systemOrange)
        let deleteButton = createActionButton("🗑️ Delete", color: .systemRed)
        
        actionsStack.addArrangedSubview(exportButton)
        actionsStack.addArrangedSubview(shareButton)
        actionsStack.addArrangedSubview(duplicateButton)
        actionsStack.addArrangedSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            actionsStack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            actionsStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            actionsStack.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 20),
            actionsStack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -20)
        ])
        
        return card
    }
    
    private func createModernCard(bgColor: NSColor) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = bgColor.cgColor
        card.layer?.cornerRadius = 16
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        
        // Enhanced shadow for depth
        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOpacity = 0.08
        card.layer?.shadowOffset = CGSize(width: 0, height: 4)
        card.layer?.shadowRadius = 12
        
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }
    
    private func createStatusIndicator() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let statusDot = NSView()
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 6
        statusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(statusDot)
        
        let statusLabel = NSTextField(labelWithString: "Active")
        statusLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textColor = NSColor.systemGreen
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statusDot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 12),
            statusDot.heightAnchor.constraint(equalToConstant: 12),
            
            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            statusLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        // Store references for updates
        objc_setAssociatedObject(container, "statusDot", statusDot, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(container, "statusLabel", statusLabel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return container
    }
    
    private func createActionButton(_ title: String, color: NSColor) -> NSButton {
        let button = NSButton()
        button.title = title
        button.bezelStyle = .rounded
        button.wantsLayer = true
        button.layer?.backgroundColor = color.withAlphaComponent(0.1).cgColor
        button.layer?.cornerRadius = 8
        button.layer?.borderWidth = 1
        button.layer?.borderColor = color.withAlphaComponent(0.3).cgColor
        button.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return button
    }
    
    private func createStyledCard(title: String, titleColor: NSColor) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Add subtle shadow
        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOpacity = 0.1
        card.layer?.shadowOffset = CGSize(width: 0, height: 2)
        card.layer?.shadowRadius = 4
        
        card.translatesAutoresizingMaskIntoConstraints = false
        
        // Title with colored accent - ensure 16px+ size
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = titleColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20)
        ])
        
        return card
    }
    
    private func createInfoRow(_ label: String, _ value: String, icon: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon
        let iconLabel = NSTextField(labelWithString: icon)
        iconLabel.font = NSFont.systemFont(ofSize: 16)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconLabel)
        
        // Label
        let labelField = NSTextField(labelWithString: label)
        labelField.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        labelField.textColor = .secondaryLabelColor
        labelField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(labelField)
        
        // Value
        let valueField = NSTextField(labelWithString: value)
        valueField.font = NSFont.systemFont(ofSize: 18, weight: .regular)
        valueField.textColor = .labelColor
        valueField.lineBreakMode = .byTruncatingTail
        valueField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueField)
        
        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 20),
            
            labelField.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            labelField.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            labelField.widthAnchor.constraint(lessThanOrEqualToConstant: 80),
            
            valueField.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            valueField.topAnchor.constraint(equalTo: labelField.bottomAnchor, constant: 2),
            valueField.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Store reference to value field for updates
        objc_setAssociatedObject(container, "valueField", valueField, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return container
    }
    
    private func createSessionInfoCard() -> NSView {
        let card = createCard(title: "Session Information")
        
        let infoStack = NSStackView()
        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 8
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Session details
        infoStack.addArrangedSubview(createInfoRow("Session ID:", sessionId, isMonospace: true))
        
        if let status = sessionData["status"] as? String {
            let statusView = createInfoRow("Status:", status.capitalized)
            infoStack.addArrangedSubview(statusView)
        }
        
        if let eventCount = sessionData["eventCount"] as? Int {
            infoStack.addArrangedSubview(createInfoRow("Total Events:", "\(eventCount)"))
        }
        
        if let duration = sessionData["duration"] as? Double {
            let durationStr = duration < 60 ? String(format: "%.1fs", duration) : String(format: "%.1fm", duration / 60)
            infoStack.addArrangedSubview(createInfoRow("Duration:", durationStr))
        }
        
        if let createdAt = sessionData["createdAt"] as? [String: Any],
           let dateString = createdAt["$date"] as? String {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.timeStyle = .short
                infoStack.addArrangedSubview(createInfoRow("Created:", displayFormatter.string(from: date)))
            }
        }
        
        card.addSubview(infoStack)
        NSLayoutConstraint.activate([
            infoStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 40),
            infoStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            infoStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            infoStack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -20)
        ])
        
        return card
    }
    
    private func createSessionStatsCard() -> NSView {
        let card = createCard(title: "Session Statistics")
        statsContainer = card
        
        let placeholderLabel = NSTextField(labelWithString: "Loading statistics...")
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        
        return card
    }
    
    private func createSessionNotesCard() -> NSView {
        let card = createCard(title: "Session Notes")
        
        sessionNotesView = NSTextView()
        sessionNotesView.font = NSFont.systemFont(ofSize: 16)
        sessionNotesView.isEditable = true
        sessionNotesView.textContainer?.lineFragmentPadding = 10
        
        let notesScrollView = NSScrollView()
        notesScrollView.documentView = sessionNotesView
        notesScrollView.hasVerticalScroller = true
        notesScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(notesScrollView)
        
        NSLayoutConstraint.activate([
            notesScrollView.topAnchor.constraint(equalTo: card.topAnchor, constant: 40),
            notesScrollView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 15),
            notesScrollView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -15),
            notesScrollView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -15)
        ])
        
        return card
    }
    
    private func createSessionTagsCard() -> NSView {
        let card = createCard(title: "Session Tags")
        
        sessionTagsField = NSTextField()
        sessionTagsField.placeholderString = "Add tags (comma separated)"
        sessionTagsField.translatesAutoresizingMaskIntoConstraints = false
        
        let addButton = NSButton()
        addButton.title = "Add Tag"
        addButton.target = self
        addButton.action = #selector(addSessionTag)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(sessionTagsField)
        card.addSubview(addButton)
        
        NSLayoutConstraint.activate([
            sessionTagsField.topAnchor.constraint(equalTo: card.topAnchor, constant: 50),
            sessionTagsField.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            sessionTagsField.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -10),
            
            addButton.topAnchor.constraint(equalTo: card.topAnchor, constant: 50),
            addButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            addButton.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        return card
    }
    
    // MARK: - Simple Events Tab
    
    private func createEnhancedEventsView() -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Header with title and count
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 16
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "📝 Event Log")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.backgroundColor = .clear
        headerStack.addArrangedSubview(titleLabel)
        
        let countLabel = NSTextField(labelWithString: "0 events")
        countLabel.font = NSFont.systemFont(ofSize: 16)
        countLabel.textColor = .secondaryLabelColor
        countLabel.isBordered = false
        countLabel.isEditable = false
        countLabel.backgroundColor = .clear
        headerStack.addArrangedSubview(countLabel)
        self.eventsCountLabel = countLabel
        
        // Spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerStack.addArrangedSubview(spacer)
        
        // Add Marker at Timecode button
        let addMarkerBtn = NSButton(title: "🚩 Add Marker at Timecode...", target: self, action: #selector(showAddMarkerAtTimecodeDialog(_:)))
        addMarkerBtn.bezelStyle = .rounded
        addMarkerBtn.font = NSFont.systemFont(ofSize: 13)
        headerStack.addArrangedSubview(addMarkerBtn)
        
        containerView.addSubview(headerStack)
        
        // Filter toolbar
        let filterToolbar = createEventsFilterToolbar()
        containerView.addSubview(filterToolbar)
        
        // Create table view
        let tableView = NSTableView()
        tableView.rowSizeStyle = .medium
        tableView.rowHeight = 28
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        
        // Define columns
        let indexColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("index"))
        indexColumn.title = "#"
        indexColumn.width = 50
        indexColumn.minWidth = 40
        tableView.addTableColumn(indexColumn)
        
        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = "Time"
        timeColumn.width = 120
        timeColumn.minWidth = 100
        tableView.addTableColumn(timeColumn)
        
        let sourceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("source"))
        sourceColumn.title = "Source"
        sourceColumn.width = 90
        sourceColumn.minWidth = 70
        tableView.addTableColumn(sourceColumn)
        
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.width = 130
        typeColumn.minWidth = 90
        tableView.addTableColumn(typeColumn)
        
        let tagsNotesColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tagsnotes"))
        tagsNotesColumn.title = "Tags / Notes"
        tagsNotesColumn.width = 150
        tagsNotesColumn.minWidth = 100
        tableView.addTableColumn(tagsNotesColumn)
        
        let detailsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("details"))
        detailsColumn.title = "Summary"
        detailsColumn.width = 200
        detailsColumn.minWidth = 120
        tableView.addTableColumn(detailsColumn)
        
        // Apply custom header cells for 16px font
        for column in tableView.tableColumns {
            let headerCell = EventsTableHeaderCell(textCell: column.title)
            column.headerCell = headerCell
        }
        
        // Set header height
        if let headerView = tableView.headerView {
            headerView.frame.size.height = 30
        }
        
        // Store reference
        self.eventsTableView = tableView
        
        // Wrap table in scroll view
        let tableScrollView = NSScrollView()
        tableScrollView.documentView = tableView
        tableScrollView.hasVerticalScroller = true
        tableScrollView.hasHorizontalScroller = true
        tableScrollView.autohidesScrollers = true
        tableScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create details panel on right side
        let detailPanel = createEventsDetailPanel()
        detailPanel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(tableScrollView)
        containerView.addSubview(detailPanel)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            filterToolbar.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            filterToolbar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            filterToolbar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            tableScrollView.topAnchor.constraint(equalTo: filterToolbar.bottomAnchor, constant: 12),
            tableScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            tableScrollView.trailingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: -12),
            tableScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            detailPanel.topAnchor.constraint(equalTo: filterToolbar.bottomAnchor, constant: 12),
            detailPanel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            detailPanel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            detailPanel.widthAnchor.constraint(equalToConstant: 320)
        ])
        
        return containerView
    }
    
    private func createEventsDetailPanel() -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        panel.layer?.cornerRadius = 8
        panel.layer?.borderWidth = 1
        panel.layer?.borderColor = NSColor.separatorColor.cgColor
        
        let titleLabel = NSTextField(labelWithString: "Event Details")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.backgroundColor = .clear
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentView.drawsBackground = false
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        
        let clipView = NSClipView()
        clipView.documentView = stackView
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        scrollView.documentView = stackView
        
        panel.addSubview(scrollView)
        
        self.eventsDetailPanel = scrollView
        self.eventsDetailStackView = stackView
        
        let placeholderLabel = NSTextField(labelWithString: "Select an event to view details")
        placeholderLabel.font = NSFont.systemFont(ofSize: 16)
        placeholderLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -4),
            scrollView.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -8),
            
            stackView.topAnchor.constraint(equalTo: clipView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20)
        ])
        
        return panel
    }
    
    private func createDetailCard(title: String, icon: String? = nil) -> (container: NSView, contentStack: NSStackView) {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 10
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        if let iconStr = icon {
            let iconLabel = NSTextField(labelWithString: iconStr)
            iconLabel.font = NSFont.systemFont(ofSize: 18)
            headerStack.addArrangedSubview(iconLabel)
        }
        
        let titleField = NSTextField(labelWithString: title)
        titleField.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleField.textColor = .labelColor
        headerStack.addArrangedSubview(titleField)
        
        card.addSubview(headerStack)
        
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(separator)
        
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            headerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            
            separator.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 10),
            separator.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            separator.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            
            contentStack.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        
        return (card, contentStack)
    }
    
    private func createDetailRow(label: String, value: String, valueColor: NSColor = .labelColor, monospace: Bool = false) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        
        let labelField = NSTextField(labelWithString: label + ":")
        labelField.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        labelField.textColor = .secondaryLabelColor
        labelField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        labelField.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        row.addArrangedSubview(labelField)
        
        let valueField = NSTextField(wrappingLabelWithString: value)
        valueField.font = monospace ? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular) : NSFont.systemFont(ofSize: 16)
        valueField.textColor = valueColor
        valueField.lineBreakMode = .byWordWrapping
        valueField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(valueField)
        
        return row
    }
    
    private func createTagPill(text: String, color: NSColor) -> NSView {
        let pill = NSView()
        pill.wantsLayer = true
        pill.layer?.backgroundColor = color.withAlphaComponent(0.2).cgColor
        pill.layer?.cornerRadius = 12
        pill.translatesAutoresizingMaskIntoConstraints = false
        
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            pill.widthAnchor.constraint(equalTo: label.widthAnchor, constant: 20),
            pill.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        return pill
    }
    
    private func createEventsFilterToolbar() -> NSView {
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 12
        toolbar.alignment = .centerY
        toolbar.distribution = .fill
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        // Search field
        let searchField = NSSearchField()
        searchField.placeholderString = "Search events..."
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.target = self
        searchField.action = #selector(eventsSearchChanged(_:))
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        self.eventsSearchField = searchField
        toolbar.addArrangedSubview(searchField)
        
        // Source filter
        let sourceLabel = NSTextField(labelWithString: "Source:")
        sourceLabel.font = NSFont.systemFont(ofSize: 14)
        toolbar.addArrangedSubview(sourceLabel)
        
        let sourcePopup = NSPopUpButton()
        sourcePopup.font = NSFont.systemFont(ofSize: 14)
        sourcePopup.addItems(withTitles: ["All Sources", "Interaction", "Focus", "System"])
        sourcePopup.target = self
        sourcePopup.action = #selector(sourceFilterChanged(_:))
        self.sourceFilterPopup = sourcePopup
        toolbar.addArrangedSubview(sourcePopup)
        
        // Type filter (multi-select)
        let typeButton = NSButton(title: "Types: All", target: self, action: #selector(showTypeFilterMenu(_:)))
        typeButton.font = NSFont.systemFont(ofSize: 14)
        typeButton.bezelStyle = .rounded
        self.typeFilterButton = typeButton
        toolbar.addArrangedSubview(typeButton)
        
        // Tag filter (multi-select)
        let tagButton = NSButton(title: "Tags: All", target: self, action: #selector(showTagFilterMenu(_:)))
        tagButton.font = NSFont.systemFont(ofSize: 14)
        tagButton.bezelStyle = .rounded
        self.tagFilterButton = tagButton
        toolbar.addArrangedSubview(tagButton)
        
        // Clear filters button
        let clearButton = NSButton(title: "Clear Filters", target: self, action: #selector(clearEventsFilters(_:)))
        clearButton.font = NSFont.systemFont(ofSize: 14)
        clearButton.bezelStyle = .rounded
        toolbar.addArrangedSubview(clearButton)
        
        // Flexible spacer at end
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        toolbar.addArrangedSubview(spacer)
        
        return toolbar
    }
    
    @objc private func eventsSearchChanged(_ sender: NSSearchField) {
        applyEventsFilters()
    }
    
    @objc private func sourceFilterChanged(_ sender: NSPopUpButton) {
        applyEventsFilters()
    }
    
    @objc private func showTypeFilterMenu(_ sender: NSButton) {
        let menu = NSMenu(title: "Select Types")
        
        let allItem = NSMenuItem(title: "All Types", action: #selector(toggleAllTypes(_:)), keyEquivalent: "")
        allItem.target = self
        allItem.state = selectedTypes.isEmpty ? .on : .off
        menu.addItem(allItem)
        menu.addItem(NSMenuItem.separator())
        
        for type in allTypes.sorted() {
            let item = NSMenuItem(title: type, action: #selector(toggleTypeFilter(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = type
            item.state = selectedTypes.contains(type) ? .on : .off
            menu.addItem(item)
        }
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
    
    @objc private func toggleAllTypes(_ sender: NSMenuItem) {
        selectedTypes.removeAll()
        updateTypeFilterButtonTitle()
        applyEventsFilters()
    }
    
    @objc private func toggleTypeFilter(_ sender: NSMenuItem) {
        guard let type = sender.representedObject as? String else { return }
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
        updateTypeFilterButtonTitle()
        applyEventsFilters()
    }
    
    @objc private func showTagFilterMenu(_ sender: NSButton) {
        let menu = NSMenu(title: "Select Tags")
        
        let allItem = NSMenuItem(title: "All Tags", action: #selector(toggleAllTags(_:)), keyEquivalent: "")
        allItem.target = self
        allItem.state = selectedTags.isEmpty ? .on : .off
        menu.addItem(allItem)
        menu.addItem(NSMenuItem.separator())
        
        for tag in allTags.sorted() {
            let item = NSMenuItem(title: tag, action: #selector(toggleTagFilter(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tag
            item.state = selectedTags.contains(tag) ? .on : .off
            menu.addItem(item)
        }
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
    
    @objc private func toggleAllTags(_ sender: NSMenuItem) {
        selectedTags.removeAll()
        updateTagFilterButtonTitle()
        applyEventsFilters()
    }
    
    @objc private func toggleTagFilter(_ sender: NSMenuItem) {
        guard let tag = sender.representedObject as? String else { return }
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        updateTagFilterButtonTitle()
        applyEventsFilters()
    }
    
    private func updateTypeFilterButtonTitle() {
        if selectedTypes.isEmpty {
            typeFilterButton?.title = "Types: All"
        } else if selectedTypes.count == 1 {
            typeFilterButton?.title = "Types: \(selectedTypes.first!)"
        } else {
            typeFilterButton?.title = "Types: \(selectedTypes.count) selected"
        }
    }
    
    private func updateTagFilterButtonTitle() {
        if selectedTags.isEmpty {
            tagFilterButton?.title = "Tags: All"
        } else if selectedTags.count == 1 {
            tagFilterButton?.title = "Tags: \(selectedTags.first!)"
        } else {
            tagFilterButton?.title = "Tags: \(selectedTags.count) selected"
        }
    }
    
    @objc private func clearEventsFilters(_ sender: NSButton) {
        eventsSearchField?.stringValue = ""
        sourceFilterPopup?.selectItem(at: 0)
        selectedTypes.removeAll()
        selectedTags.removeAll()
        updateTypeFilterButtonTitle()
        updateTagFilterButtonTitle()
        applyEventsFilters()
    }
    
    @objc private func tagSelectedEvents(_ sender: NSButton) {
        guard let tableView = eventsTableView else { return }
        let selectedRows = tableView.selectedRowIndexes
        guard !selectedRows.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No Events Selected"
            alert.informativeText = "Please select one or more events to tag."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Show tag selection menu
        let menu = NSMenu(title: "Select Tag")
        for tag in allTags.sorted() {
            let item = NSMenuItem(title: tag, action: #selector(applyTagToSelection(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tag
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let customItem = NSMenuItem(title: "Add Custom Tag...", action: #selector(addCustomTag(_:)), keyEquivalent: "")
        customItem.target = self
        menu.addItem(customItem)
        
        // Show menu at button location
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
    
    @objc private func addNoteToSelectedEvent(_ sender: NSButton) {
        guard let tableView = eventsTableView else { return }
        let selectedRows = tableView.selectedRowIndexes
        guard selectedRows.count == 1, let selectedRow = selectedRows.first else {
            let alert = NSAlert()
            alert.messageText = "Select One Event"
            alert.informativeText = "Please select exactly one event to add or edit a note."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        let originalIndex = getOriginalEventIndex(for: selectedRow)
        showNoteEditor(for: originalIndex, fromTimeline: false)
    }
    
    private func showNoteEditor(for eventIndex: Int, fromTimeline: Bool) {
        let event = events[eventIndex]
        let eventType = event["type"] as? String ?? "Unknown"
        let hasExistingNote = eventNotes[eventIndex] != nil
        
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Note for Event: \(eventType)"
        window.center()
        
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.autoresizingMask = [.width, .height]
        
        let ribbonHeight: CGFloat = 36
        let ribbon = NSStackView(frame: NSRect(x: 0, y: contentView.bounds.height - ribbonHeight, width: contentView.bounds.width, height: ribbonHeight))
        ribbon.orientation = .horizontal
        ribbon.spacing = 4
        ribbon.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        ribbon.autoresizingMask = [.width, .minYMargin]
        ribbon.wantsLayer = true
        ribbon.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let fontPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        fontPopup.addItems(withTitles: ["System", "Helvetica", "Times", "Courier", "Georgia", "Verdana"])
        fontPopup.font = NSFont.systemFont(ofSize: 11)
        fontPopup.target = self
        fontPopup.action = #selector(noteFontChanged(_:))
        ribbon.addArrangedSubview(fontPopup)
        
        let sizePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        sizePopup.addItems(withTitles: ["10", "11", "12", "14", "16", "18", "20", "24", "28", "32", "36", "48"])
        sizePopup.selectItem(withTitle: "14")
        sizePopup.font = NSFont.systemFont(ofSize: 11)
        sizePopup.target = self
        sizePopup.action = #selector(noteSizeChanged(_:))
        ribbon.addArrangedSubview(sizePopup)
        
        let sep1 = NSBox()
        sep1.boxType = .separator
        sep1.widthAnchor.constraint(equalToConstant: 1).isActive = true
        ribbon.addArrangedSubview(sep1)
        
        let boldBtn = NSButton(title: "B", target: self, action: #selector(noteToggleBold(_:)))
        boldBtn.font = NSFont.boldSystemFont(ofSize: 13)
        boldBtn.bezelStyle = .texturedRounded
        boldBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(boldBtn)
        
        let italicBtn = NSButton(title: "I", target: self, action: #selector(noteToggleItalic(_:)))
        italicBtn.font = NSFont(name: "Times-Italic", size: 13) ?? NSFont.systemFont(ofSize: 13)
        italicBtn.bezelStyle = .texturedRounded
        italicBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(italicBtn)
        
        let underlineBtn = NSButton(title: "U", target: self, action: #selector(noteToggleUnderline(_:)))
        underlineBtn.bezelStyle = .texturedRounded
        underlineBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(underlineBtn)
        
        let strikeBtn = NSButton(title: "S", target: self, action: #selector(noteToggleStrikethrough(_:)))
        strikeBtn.bezelStyle = .texturedRounded
        strikeBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(strikeBtn)
        
        let sep2 = NSBox()
        sep2.boxType = .separator
        sep2.widthAnchor.constraint(equalToConstant: 1).isActive = true
        ribbon.addArrangedSubview(sep2)
        
        let textColorBtn = NSButton(title: "A", target: self, action: #selector(noteTextColor(_:)))
        textColorBtn.bezelStyle = .texturedRounded
        textColorBtn.contentTintColor = .systemRed
        textColorBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(textColorBtn)
        
        let highlightBtn = NSButton(title: "H", target: self, action: #selector(noteHighlight(_:)))
        highlightBtn.bezelStyle = .texturedRounded
        highlightBtn.wantsLayer = true
        highlightBtn.layer?.backgroundColor = NSColor.systemYellow.cgColor
        highlightBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(highlightBtn)
        
        let sep3 = NSBox()
        sep3.boxType = .separator
        sep3.widthAnchor.constraint(equalToConstant: 1).isActive = true
        ribbon.addArrangedSubview(sep3)
        
        let leftBtn = NSButton(image: NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "Left")!, target: self, action: #selector(noteAlignLeft(_:)))
        leftBtn.bezelStyle = .texturedRounded
        leftBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(leftBtn)
        
        let centerBtn = NSButton(image: NSImage(systemSymbolName: "text.aligncenter", accessibilityDescription: "Center")!, target: self, action: #selector(noteAlignCenter(_:)))
        centerBtn.bezelStyle = .texturedRounded
        centerBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(centerBtn)
        
        let rightBtn = NSButton(image: NSImage(systemSymbolName: "text.alignright", accessibilityDescription: "Right")!, target: self, action: #selector(noteAlignRight(_:)))
        rightBtn.bezelStyle = .texturedRounded
        rightBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(rightBtn)
        
        let sep4 = NSBox()
        sep4.boxType = .separator
        sep4.widthAnchor.constraint(equalToConstant: 1).isActive = true
        ribbon.addArrangedSubview(sep4)
        
        let bulletBtn = NSButton(image: NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Bullets")!, target: self, action: #selector(noteInsertBullet(_:)))
        bulletBtn.bezelStyle = .texturedRounded
        bulletBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(bulletBtn)
        
        let numberBtn = NSButton(image: NSImage(systemSymbolName: "list.number", accessibilityDescription: "Numbers")!, target: self, action: #selector(noteInsertNumber(_:)))
        numberBtn.bezelStyle = .texturedRounded
        numberBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(numberBtn)
        
        let ribbonSpacer = NSView()
        ribbonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        ribbon.addArrangedSubview(ribbonSpacer)
        
        contentView.addSubview(ribbon)
        
        let scrollView = NSScrollView(frame: NSRect(x: 12, y: 60, width: contentView.bounds.width - 24, height: contentView.bounds.height - ribbonHeight - 72))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: scrollView.bounds.width - 20, height: scrollView.bounds.height))
        textView.autoresizingMask = [.width]
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        
        currentNoteTextView = textView
        
        if let existingNote = eventNotes[eventIndex] {
            if let attrString = NSAttributedString(rtf: existingNote, documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attrString)
            }
        }
        
        scrollView.documentView = textView
        contentView.addSubview(scrollView)
        
        let buttonBar = NSStackView(frame: NSRect(x: 12, y: 12, width: contentView.bounds.width - 24, height: 36))
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 12
        buttonBar.autoresizingMask = [.width, .maxYMargin]
        
        if hasExistingNote {
            let deleteBtn = NSButton(title: "Delete Note", target: self, action: #selector(deleteNoteAction(_:)))
            deleteBtn.bezelStyle = .rounded
            deleteBtn.contentTintColor = .systemRed
            buttonBar.addArrangedSubview(deleteBtn)
        }
        
        let btnSpacer = NSView()
        btnSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        buttonBar.addArrangedSubview(btnSpacer)
        
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancelNoteAction(_:)))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        buttonBar.addArrangedSubview(cancelBtn)
        
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(saveNoteAction(_:)))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        buttonBar.addArrangedSubview(saveBtn)
        
        contentView.addSubview(buttonBar)
        window.contentView = contentView
        
        currentNotePanel = nil
        currentNoteEventIndex = eventIndex
        pendingNoteRTFData = nil
        
        window.makeFirstResponder(textView)
        
        let response = NSApp.runModal(for: window)
        
        window.orderOut(nil)
        
        if response == .OK {
            if let rtfData = pendingNoteRTFData {
                eventNotes[eventIndex] = rtfData
                saveTags()
                eventsTableView?.reloadData()
            }
        } else if response == .abort {
            eventNotes.removeValue(forKey: eventIndex)
            saveTags()
            eventsTableView?.reloadData()
        }
        
        currentNoteTextView = nil
        pendingNoteRTFData = nil
    }
    
    @objc private func noteFontChanged(_ sender: NSPopUpButton) {
        guard let textView = currentNoteTextView, let fontName = sender.titleOfSelectedItem else { return }
        let range = textView.selectedRange()
        if range.length > 0 {
            let currentFont = textView.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: 14)
            let newFont: NSFont
            if fontName == "System" {
                newFont = NSFont.systemFont(ofSize: currentFont.pointSize)
            } else {
                newFont = NSFont(name: fontName, size: currentFont.pointSize) ?? currentFont
            }
            textView.textStorage?.addAttribute(.font, value: newFont, range: range)
        }
    }
    
    @objc private func noteSizeChanged(_ sender: NSPopUpButton) {
        guard let textView = currentNoteTextView, let sizeStr = sender.titleOfSelectedItem, let size = Double(sizeStr) else { return }
        let range = textView.selectedRange()
        if range.length > 0 {
            let currentFont = textView.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: 14)
            let newFont = NSFont(descriptor: currentFont.fontDescriptor, size: CGFloat(size)) ?? currentFont
            textView.textStorage?.addAttribute(.font, value: newFont, range: range)
        }
    }
    
    @objc private func noteToggleBold(_ sender: NSButton) {
        guard let textView = currentNoteTextView else { return }
        let range = textView.selectedRange()
        if range.length > 0 {
            let currentFont = textView.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: 14)
            let newFont = NSFontManager.shared.convert(currentFont, toHaveTrait: currentFont.fontDescriptor.symbolicTraits.contains(.bold) ? .unboldFontMask : .boldFontMask)
            textView.textStorage?.addAttribute(.font, value: newFont, range: range)
        }
    }
    
    @objc private func noteToggleItalic(_ sender: NSButton) {
        guard let textView = currentNoteTextView else { return }
        let range = textView.selectedRange()
        if range.length > 0 {
            let currentFont = textView.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: 14)
            let newFont = NSFontManager.shared.convert(currentFont, toHaveTrait: currentFont.fontDescriptor.symbolicTraits.contains(.italic) ? .unitalicFontMask : .italicFontMask)
            textView.textStorage?.addAttribute(.font, value: newFont, range: range)
        }
    }
    
    @objc private func noteToggleUnderline(_ sender: NSButton) {
        guard let textView = currentNoteTextView else { return }
        let range = textView.selectedRange()
        if range.length > 0 {
            let current = textView.textStorage?.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
            textView.textStorage?.addAttribute(.underlineStyle, value: current == 0 ? NSUnderlineStyle.single.rawValue : 0, range: range)
        }
    }
    
    @objc private func noteToggleStrikethrough(_ sender: NSButton) {
        guard let textView = currentNoteTextView else { return }
        let range = textView.selectedRange()
        if range.length > 0 {
            let current = textView.textStorage?.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
            textView.textStorage?.addAttribute(.strikethroughStyle, value: current == 0 ? NSUnderlineStyle.single.rawValue : 0, range: range)
        }
    }
    
    @objc private func noteTextColor(_ sender: NSButton) {
        guard let textView = currentNoteTextView else { return }
        NSColorPanel.shared.setTarget(self)
        NSColorPanel.shared.setAction(#selector(noteColorPanelChanged(_:)))
        NSColorPanel.shared.orderFront(nil)
    }
    
    @objc private func noteColorPanelChanged(_ sender: NSColorPanel) {
        guard let textView = currentNoteTextView else { return }
        let range = textView.selectedRange()
        if range.length > 0 {
            textView.textStorage?.addAttribute(.foregroundColor, value: sender.color, range: range)
        }
    }
    
    @objc private func noteHighlight(_ sender: NSButton) {
        guard let textView = currentNoteTextView else { return }
        let range = textView.selectedRange()
        if range.length > 0 {
            let current = textView.textStorage?.attribute(.backgroundColor, at: range.location, effectiveRange: nil) as? NSColor
            textView.textStorage?.addAttribute(.backgroundColor, value: current == nil ? NSColor.systemYellow : NSColor.clear, range: range)
        }
    }
    
    @objc private func noteAlignLeft(_ sender: NSButton) {
        currentNoteTextView?.alignLeft(nil)
    }
    
    @objc private func noteAlignCenter(_ sender: NSButton) {
        currentNoteTextView?.alignCenter(nil)
    }
    
    @objc private func noteAlignRight(_ sender: NSButton) {
        currentNoteTextView?.alignRight(nil)
    }
    
    @objc private func noteInsertBullet(_ sender: NSButton) {
        guard let textView = currentNoteTextView else { return }
        let range = textView.selectedRange()
        textView.insertText("• ", replacementRange: NSRange(location: range.location, length: 0))
    }
    
    @objc private func noteInsertNumber(_ sender: NSButton) {
        guard let textView = currentNoteTextView else { return }
        let range = textView.selectedRange()
        textView.insertText("1. ", replacementRange: NSRange(location: range.location, length: 0))
    }
    
    @objc private func saveNoteAction(_ sender: NSButton) {
        if let textView = currentNoteTextView,
           let storage = textView.textStorage {
            pendingNoteRTFData = storage.rtf(from: NSRange(location: 0, length: storage.length), documentAttributes: [:])
        }
        NSApp.stopModal(withCode: .OK)
    }
    
    @objc private func cancelNoteAction(_ sender: NSButton) {
        NSApp.stopModal(withCode: .cancel)
    }
    
    @objc private func deleteNoteAction(_ sender: NSButton) {
        NSApp.stopModal(withCode: .abort)
    }
    
    @objc private func applyTagToSelection(_ sender: NSMenuItem) {
        guard let tag = sender.representedObject as? String,
              let tableView = eventsTableView else { return }
        
        for index in tableView.selectedRowIndexes {
            let originalIndex = getOriginalEventIndex(for: index)
            if eventTags[originalIndex] == nil {
                eventTags[originalIndex] = Set<String>()
            }
            eventTags[originalIndex]?.insert(tag)
        }
        saveTags()
        tableView.reloadData()
    }
    
    @objc private func addCustomTag(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Add Custom Tag"
        alert.informativeText = "Enter a name for the new tag:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.font = NSFont.systemFont(ofSize: 14)
        alert.accessoryView = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let newTag = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newTag.isEmpty {
                allTags.insert(newTag)
                
                // Apply to selected events
                if let tableView = eventsTableView {
                    for index in tableView.selectedRowIndexes {
                        let originalIndex = getOriginalEventIndex(for: index)
                        if eventTags[originalIndex] == nil {
                            eventTags[originalIndex] = Set<String>()
                        }
                        eventTags[originalIndex]?.insert(newTag)
                    }
                    tableView.reloadData()
                }
                saveTags()
            }
        }
    }
    
    private func getOriginalEventIndex(for filteredIndex: Int) -> Int {
        if filteredEvents.isEmpty || filteredEvents.count == events.count {
            return filteredIndex
        }
        let filteredEvent = filteredEvents[filteredIndex]
        if let timestamp = filteredEvent["timestamp"] as? Double {
            for (index, event) in events.enumerated() {
                if let eventTimestamp = event["timestamp"] as? Double, eventTimestamp == timestamp {
                    return index
                }
            }
        }
        return filteredIndex
    }
    
    private func createTagsNotesCellView(for eventIndex: Int, row: Int) -> NSView {
        let cellView = TagsNotesCellView()
        cellView.eventIndex = eventIndex
        cellView.viewController = self
        
        let tags = eventTags[eventIndex] ?? Set<String>()
        let hasNote = eventNotes[eventIndex] != nil
        
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        if hasNote {
            let noteLabel = NSTextField(labelWithString: "📝")
            noteLabel.font = NSFont.systemFont(ofSize: 12)
            stackView.addArrangedSubview(noteLabel)
        }
        
        for tag in tags.sorted() {
            let badge = NSTextField(labelWithString: tag)
            badge.font = NSFont.systemFont(ofSize: 11)
            badge.textColor = .systemPurple
            badge.backgroundColor = NSColor.systemPurple.withAlphaComponent(0.15)
            badge.drawsBackground = true
            badge.isBordered = false
            badge.isEditable = false
            badge.wantsLayer = true
            badge.layer?.cornerRadius = 3
            stackView.addArrangedSubview(badge)
        }
        
        if tags.isEmpty && !hasNote {
            let placeholder = NSTextField(labelWithString: "—")
            placeholder.font = NSFont.systemFont(ofSize: 12)
            placeholder.textColor = .tertiaryLabelColor
            stackView.addArrangedSubview(placeholder)
        }
        
        cellView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: cellView.trailingAnchor, constant: -4),
            stackView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        return cellView
    }
    
    func createTagsNotesContextMenu(for eventIndex: Int) -> NSMenu {
        let tags = eventTags[eventIndex] ?? Set<String>()
        let hasNote = eventNotes[eventIndex] != nil
        let event = eventIndex < events.count ? events[eventIndex] : nil
        let isMarkerEvent = event?["type"] as? String == "marker"
        return createTagsNotesContextMenuInternal(for: eventIndex, tags: tags, hasNote: hasNote, isMarkerEvent: isMarkerEvent)
    }
    
    private func createTagsNotesContextMenuInternal(for eventIndex: Int, tags: Set<String>, hasNote: Bool, isMarkerEvent: Bool) -> NSMenu {
        let menu = NSMenu()
        
        // Marker section - only show "Add Marker" for non-marker events
        if isMarkerEvent {
            let editMarkerItem = NSMenuItem(title: "Edit Marker...", action: #selector(editMarkerAction(_:)), keyEquivalent: "")
            editMarkerItem.target = self
            editMarkerItem.representedObject = eventIndex
            menu.addItem(editMarkerItem)
            
            let deleteMarkerItem = NSMenuItem(title: "Delete Marker", action: #selector(deleteMarkerAction(_:)), keyEquivalent: "")
            deleteMarkerItem.target = self
            deleteMarkerItem.representedObject = eventIndex
            menu.addItem(deleteMarkerItem)
        } else {
            let addMarkerItem = NSMenuItem(title: "Add Marker...", action: #selector(addMarkerAction(_:)), keyEquivalent: "")
            addMarkerItem.target = self
            addMarkerItem.representedObject = eventIndex
            menu.addItem(addMarkerItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Note section
        if hasNote {
            let editNoteItem = NSMenuItem(title: "Edit Note...", action: #selector(tagsNotesEditNote(_:)), keyEquivalent: "")
            editNoteItem.target = self
            editNoteItem.representedObject = eventIndex
            menu.addItem(editNoteItem)
            
            let deleteNoteItem = NSMenuItem(title: "Delete Note", action: #selector(tagsNotesDeleteNote(_:)), keyEquivalent: "")
            deleteNoteItem.target = self
            deleteNoteItem.representedObject = eventIndex
            menu.addItem(deleteNoteItem)
        } else {
            let addNoteItem = NSMenuItem(title: "Add Note...", action: #selector(tagsNotesAddNote(_:)), keyEquivalent: "")
            addNoteItem.target = self
            addNoteItem.representedObject = eventIndex
            menu.addItem(addNoteItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Tag section
        if !tags.isEmpty {
            let removeTagsMenu = NSMenu()
            for tag in tags.sorted() {
                let removeItem = NSMenuItem(title: tag, action: #selector(tagsNotesRemoveTag(_:)), keyEquivalent: "")
                removeItem.target = self
                removeItem.representedObject = ["tag": tag, "eventIndex": eventIndex]
                removeTagsMenu.addItem(removeItem)
            }
            let removeTagsItem = NSMenuItem(title: "Remove Tag", action: nil, keyEquivalent: "")
            removeTagsItem.submenu = removeTagsMenu
            menu.addItem(removeTagsItem)
        }
        
        let addTagMenu = NSMenu()
        let existingTags = tags
        var hasAvailableTags = false
        for tag in allTags.sorted() {
            if !existingTags.contains(tag) {
                let item = NSMenuItem(title: tag, action: #selector(tagsNotesAddTag(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = ["tag": tag, "eventIndex": eventIndex]
                addTagMenu.addItem(item)
                hasAvailableTags = true
            }
        }
        if !hasAvailableTags {
            let item = NSMenuItem(title: "(All tags applied)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            addTagMenu.addItem(item)
        }
        addTagMenu.addItem(NSMenuItem.separator())
        let newTagItem = NSMenuItem(title: "New Tag...", action: #selector(tagsNotesNewTag(_:)), keyEquivalent: "")
        newTagItem.target = self
        newTagItem.representedObject = eventIndex
        addTagMenu.addItem(newTagItem)
        
        let addTagItem = NSMenuItem(title: "Add Tag", action: nil, keyEquivalent: "")
        addTagItem.submenu = addTagMenu
        menu.addItem(addTagItem)
        
        return menu
    }
    
    @objc private func tagsNotesAddNote(_ sender: NSMenuItem) {
        guard let eventIndex = sender.representedObject as? Int else { return }
        showNoteEditor(for: eventIndex, fromTimeline: false)
    }
    
    @objc private func tagsNotesEditNote(_ sender: NSMenuItem) {
        guard let eventIndex = sender.representedObject as? Int else { return }
        showNoteEditor(for: eventIndex, fromTimeline: false)
    }
    
    @objc private func tagsNotesDeleteNote(_ sender: NSMenuItem) {
        guard let eventIndex = sender.representedObject as? Int else { return }
        eventNotes.removeValue(forKey: eventIndex)
        saveTags()
        eventsTableView?.reloadData()
    }
    
    @objc private func tagsNotesAddTag(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let tag = info["tag"] as? String,
              let eventIndex = info["eventIndex"] as? Int else { return }
        
        if eventTags[eventIndex] == nil {
            eventTags[eventIndex] = Set<String>()
        }
        eventTags[eventIndex]?.insert(tag)
        saveTags()
        eventsTableView?.reloadData()
    }
    
    @objc private func tagsNotesRemoveTag(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let tag = info["tag"] as? String,
              let eventIndex = info["eventIndex"] as? Int else { return }
        
        eventTags[eventIndex]?.remove(tag)
        if eventTags[eventIndex]?.isEmpty == true {
            eventTags.removeValue(forKey: eventIndex)
        }
        saveTags()
        eventsTableView?.reloadData()
    }
    
    @objc private func tagsNotesNewTag(_ sender: NSMenuItem) {
        guard let eventIndex = sender.representedObject as? Int else { return }
        
        let alert = NSAlert()
        alert.messageText = "New Tag"
        alert.informativeText = "Enter a name for the new tag:"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = textField
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let newTag = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newTag.isEmpty {
                allTags.insert(newTag)
                if eventTags[eventIndex] == nil {
                    eventTags[eventIndex] = Set<String>()
                }
                eventTags[eventIndex]?.insert(newTag)
                saveTags()
                eventsTableView?.reloadData()
            }
        }
    }
    
    @objc private func addMarkerAction(_ sender: NSMenuItem) {
        guard let eventIndex = sender.representedObject as? Int else { return }
        showMarkerEditor(for: eventIndex, existingMarkerIndex: nil)
    }
    
    @objc private func editMarkerAction(_ sender: NSMenuItem) {
        guard let eventIndex = sender.representedObject as? Int else { return }
        if events[eventIndex]["type"] as? String == "marker" {
            showMarkerEditor(for: eventIndex, existingMarkerIndex: eventIndex)
        }
    }
    
    @objc private func deleteMarkerAction(_ sender: NSMenuItem) {
        guard let eventIndex = sender.representedObject as? Int else { return }
        if events[eventIndex]["type"] as? String == "marker" {
            events.remove(at: eventIndex)
            shiftTagsAndNotesAfterDelete(at: eventIndex)
            applyEventsFilters()
            saveTags()
            eventsTableView?.reloadData()
            updateTimelineWithCurrentEvents()
        }
    }
    
    private func showMarkerEditor(for eventIndex: Int, existingMarkerIndex: Int?) {
        var existingName: String = ""
        var existingNoteData: Data? = nil
        
        if let markerIdx = existingMarkerIndex, markerIdx < events.count {
            let markerEvent = events[markerIdx]
            existingName = markerEvent["markerName"] as? String ?? ""
            if let noteBase64 = markerEvent["markerNote"] as? String {
                existingNoteData = Data(base64Encoded: noteBase64)
            }
        }
        
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = existingMarkerIndex != nil ? "Edit Marker" : "Add Marker"
        window.center()
        
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.autoresizingMask = [.width, .height]
        
        let nameLabel = NSTextField(labelWithString: "Marker Name:")
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.frame = NSRect(x: 12, y: contentView.bounds.height - 32, width: 100, height: 20)
        nameLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(nameLabel)
        
        let nameField = NSTextField(frame: NSRect(x: 120, y: contentView.bounds.height - 34, width: contentView.bounds.width - 132, height: 24))
        nameField.font = NSFont.systemFont(ofSize: 14)
        nameField.stringValue = existingName
        nameField.placeholderString = "Enter marker name..."
        nameField.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(nameField)
        
        let noteLabel = NSTextField(labelWithString: "Note (optional):")
        noteLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        noteLabel.frame = NSRect(x: 12, y: contentView.bounds.height - 60, width: 150, height: 20)
        noteLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(noteLabel)
        
        let ribbonHeight: CGFloat = 36
        let ribbon = NSStackView(frame: NSRect(x: 0, y: contentView.bounds.height - 60 - ribbonHeight - 4, width: contentView.bounds.width, height: ribbonHeight))
        ribbon.orientation = .horizontal
        ribbon.spacing = 4
        ribbon.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        ribbon.autoresizingMask = [.width, .minYMargin]
        ribbon.wantsLayer = true
        ribbon.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let fontPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        fontPopup.addItems(withTitles: ["System", "Helvetica", "Times", "Courier", "Georgia", "Verdana"])
        fontPopup.font = NSFont.systemFont(ofSize: 11)
        fontPopup.target = self
        fontPopup.action = #selector(noteFontChanged(_:))
        ribbon.addArrangedSubview(fontPopup)
        
        let sizePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        sizePopup.addItems(withTitles: ["10", "11", "12", "14", "16", "18", "20", "24", "28", "32", "36", "48"])
        sizePopup.selectItem(withTitle: "14")
        sizePopup.font = NSFont.systemFont(ofSize: 11)
        sizePopup.target = self
        sizePopup.action = #selector(noteSizeChanged(_:))
        ribbon.addArrangedSubview(sizePopup)
        
        let sep1 = NSBox()
        sep1.boxType = .separator
        sep1.widthAnchor.constraint(equalToConstant: 1).isActive = true
        ribbon.addArrangedSubview(sep1)
        
        let boldBtn = NSButton(title: "B", target: self, action: #selector(noteToggleBold(_:)))
        boldBtn.font = NSFont.boldSystemFont(ofSize: 13)
        boldBtn.bezelStyle = .texturedRounded
        boldBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(boldBtn)
        
        let italicBtn = NSButton(title: "I", target: self, action: #selector(noteToggleItalic(_:)))
        italicBtn.font = NSFont(name: "Times-Italic", size: 13) ?? NSFont.systemFont(ofSize: 13)
        italicBtn.bezelStyle = .texturedRounded
        italicBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(italicBtn)
        
        let underlineBtn = NSButton(title: "U", target: self, action: #selector(noteToggleUnderline(_:)))
        underlineBtn.bezelStyle = .texturedRounded
        underlineBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(underlineBtn)
        
        let strikeBtn = NSButton(title: "S", target: self, action: #selector(noteToggleStrikethrough(_:)))
        strikeBtn.bezelStyle = .texturedRounded
        strikeBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(strikeBtn)
        
        let sep2 = NSBox()
        sep2.boxType = .separator
        sep2.widthAnchor.constraint(equalToConstant: 1).isActive = true
        ribbon.addArrangedSubview(sep2)
        
        let textColorBtn = NSButton(title: "A", target: self, action: #selector(noteTextColor(_:)))
        textColorBtn.bezelStyle = .texturedRounded
        textColorBtn.contentTintColor = .systemRed
        textColorBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(textColorBtn)
        
        let highlightBtn = NSButton(title: "H", target: self, action: #selector(noteHighlight(_:)))
        highlightBtn.bezelStyle = .texturedRounded
        highlightBtn.wantsLayer = true
        highlightBtn.layer?.backgroundColor = NSColor.systemYellow.cgColor
        highlightBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(highlightBtn)
        
        let sep3 = NSBox()
        sep3.boxType = .separator
        sep3.widthAnchor.constraint(equalToConstant: 1).isActive = true
        ribbon.addArrangedSubview(sep3)
        
        let leftBtn = NSButton(image: NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "Left")!, target: self, action: #selector(noteAlignLeft(_:)))
        leftBtn.bezelStyle = .texturedRounded
        leftBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(leftBtn)
        
        let centerBtn = NSButton(image: NSImage(systemSymbolName: "text.aligncenter", accessibilityDescription: "Center")!, target: self, action: #selector(noteAlignCenter(_:)))
        centerBtn.bezelStyle = .texturedRounded
        centerBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(centerBtn)
        
        let rightBtn = NSButton(image: NSImage(systemSymbolName: "text.alignright", accessibilityDescription: "Right")!, target: self, action: #selector(noteAlignRight(_:)))
        rightBtn.bezelStyle = .texturedRounded
        rightBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(rightBtn)
        
        let sep4 = NSBox()
        sep4.boxType = .separator
        sep4.widthAnchor.constraint(equalToConstant: 1).isActive = true
        ribbon.addArrangedSubview(sep4)
        
        let bulletBtn = NSButton(image: NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Bullets")!, target: self, action: #selector(noteInsertBullet(_:)))
        bulletBtn.bezelStyle = .texturedRounded
        bulletBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(bulletBtn)
        
        let numberBtn = NSButton(image: NSImage(systemSymbolName: "list.number", accessibilityDescription: "Numbers")!, target: self, action: #selector(noteInsertNumber(_:)))
        numberBtn.bezelStyle = .texturedRounded
        numberBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(numberBtn)
        
        let ribbonSpacer = NSView()
        ribbonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        ribbon.addArrangedSubview(ribbonSpacer)
        
        contentView.addSubview(ribbon)
        
        let scrollView = NSScrollView(frame: NSRect(x: 12, y: 60, width: contentView.bounds.width - 24, height: contentView.bounds.height - 60 - ribbonHeight - 4 - 72))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: scrollView.bounds.width - 20, height: scrollView.bounds.height))
        textView.autoresizingMask = [.width]
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        
        currentNoteTextView = textView
        
        if let existingNote = existingNoteData,
           let attrString = NSAttributedString(rtf: existingNote, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attrString)
        }
        
        scrollView.documentView = textView
        contentView.addSubview(scrollView)
        
        let buttonBar = NSStackView(frame: NSRect(x: 12, y: 12, width: contentView.bounds.width - 24, height: 36))
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 12
        buttonBar.autoresizingMask = [.width, .maxYMargin]
        
        if existingMarkerIndex != nil {
            let deleteBtn = NSButton(title: "Delete Marker", target: self, action: #selector(deleteMarkerFromEditor(_:)))
            deleteBtn.bezelStyle = .rounded
            deleteBtn.contentTintColor = .systemRed
            deleteBtn.tag = eventIndex
            buttonBar.addArrangedSubview(deleteBtn)
        }
        
        let btnSpacer = NSView()
        btnSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        buttonBar.addArrangedSubview(btnSpacer)
        
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(markerEditorCancel(_:)))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        buttonBar.addArrangedSubview(cancelBtn)
        
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(markerEditorSave(_:)))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        buttonBar.addArrangedSubview(saveBtn)
        
        contentView.addSubview(buttonBar)
        window.contentView = contentView
        
        window.makeFirstResponder(nameField)
        
        pendingMarkerEventIndex = eventIndex
        
        let response = NSApp.runModal(for: window)
        
        window.orderOut(nil)
        
        if response == .OK {
            let markerName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !markerName.isEmpty {
                var noteBase64: String? = nil
                if let storage = textView.textStorage, storage.length > 0,
                   let noteData = storage.rtf(from: NSRange(location: 0, length: storage.length), documentAttributes: [:]) {
                    noteBase64 = noteData.base64EncodedString()
                }
                
                if let markerIdx = existingMarkerIndex {
                    events[markerIdx]["markerName"] = markerName
                    events[markerIdx]["markerNote"] = noteBase64 as Any
                } else {
                    let referenceEvent = events[eventIndex]
                    let timestamp = referenceEvent["timestamp"] as? Double ?? 0
                    let markerEvent: [String: Any] = [
                        "source": "editor",
                        "type": "marker",
                        "timestamp": timestamp,
                        "markerName": markerName,
                        "markerNote": noteBase64 as Any,
                        "referenceEventIndex": eventIndex
                    ]
                    events.insert(markerEvent, at: eventIndex)
                    shiftTagsAndNotesAfterInsert(at: eventIndex)
                }
                applyEventsFilters()
                saveTags()
                eventsTableView?.reloadData()
                updateTimelineWithCurrentEvents()
            }
        } else if response == .abort {
            if let markerIdx = existingMarkerIndex {
                events.remove(at: markerIdx)
                shiftTagsAndNotesAfterDelete(at: markerIdx)
                applyEventsFilters()
                saveTags()
                eventsTableView?.reloadData()
                updateTimelineWithCurrentEvents()
            }
        }
        
        currentNoteTextView = nil
        pendingMarkerEventIndex = nil
    }
    
    @objc private func deleteMarkerFromEditor(_ sender: NSButton) {
        NSApp.stopModal(withCode: .abort)
    }
    
    @objc private func markerEditorCancel(_ sender: NSButton) {
        NSApp.stopModal(withCode: .cancel)
    }
    
    @objc private func markerEditorSave(_ sender: NSButton) {
        NSApp.stopModal(withCode: .OK)
    }
    
    @objc private func showAddMarkerAtTimecodeDialog(_ sender: Any) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 520),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Add Marker at Timecode"
        window.center()
        
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.autoresizingMask = [.width, .height]
        
        let timecodeLabel = NSTextField(labelWithString: "Timecode (HH:MM:SS.mmm):")
        timecodeLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        timecodeLabel.frame = NSRect(x: 12, y: contentView.bounds.height - 32, width: 180, height: 20)
        timecodeLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(timecodeLabel)
        
        let timecodeField = NSTextField(frame: NSRect(x: 200, y: contentView.bounds.height - 34, width: 150, height: 24))
        timecodeField.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        timecodeField.placeholderString = "00:01:23.456"
        timecodeField.autoresizingMask = [.minYMargin]
        contentView.addSubview(timecodeField)
        
        let nameLabel = NSTextField(labelWithString: "Marker Name:")
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.frame = NSRect(x: 12, y: contentView.bounds.height - 66, width: 180, height: 20)
        nameLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(nameLabel)
        
        let nameField = NSTextField(frame: NSRect(x: 200, y: contentView.bounds.height - 68, width: contentView.bounds.width - 212, height: 24))
        nameField.font = NSFont.systemFont(ofSize: 14)
        nameField.placeholderString = "Enter marker name..."
        nameField.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(nameField)
        
        let noteLabel = NSTextField(labelWithString: "Note (optional):")
        noteLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        noteLabel.frame = NSRect(x: 12, y: contentView.bounds.height - 100, width: 150, height: 20)
        noteLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(noteLabel)
        
        let ribbonHeight: CGFloat = 36
        let ribbon = NSStackView(frame: NSRect(x: 0, y: contentView.bounds.height - 100 - ribbonHeight - 4, width: contentView.bounds.width, height: ribbonHeight))
        ribbon.orientation = .horizontal
        ribbon.spacing = 4
        ribbon.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        ribbon.autoresizingMask = [.width, .minYMargin]
        ribbon.wantsLayer = true
        ribbon.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let fontPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        fontPopup.addItems(withTitles: ["System", "Helvetica", "Times", "Courier", "Georgia", "Verdana"])
        fontPopup.font = NSFont.systemFont(ofSize: 11)
        fontPopup.target = self
        fontPopup.action = #selector(noteFontChanged(_:))
        ribbon.addArrangedSubview(fontPopup)
        
        let sizePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        sizePopup.addItems(withTitles: ["10", "11", "12", "14", "16", "18", "20", "24", "28", "32", "36", "48"])
        sizePopup.selectItem(withTitle: "14")
        sizePopup.font = NSFont.systemFont(ofSize: 11)
        sizePopup.target = self
        sizePopup.action = #selector(noteSizeChanged(_:))
        ribbon.addArrangedSubview(sizePopup)
        
        let sep1 = NSBox()
        sep1.boxType = .separator
        sep1.widthAnchor.constraint(equalToConstant: 1).isActive = true
        ribbon.addArrangedSubview(sep1)
        
        let boldBtn = NSButton(title: "B", target: self, action: #selector(noteToggleBold(_:)))
        boldBtn.font = NSFont.boldSystemFont(ofSize: 13)
        boldBtn.bezelStyle = .texturedRounded
        boldBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(boldBtn)
        
        let italicBtn = NSButton(title: "I", target: self, action: #selector(noteToggleItalic(_:)))
        italicBtn.font = NSFont(name: "Times-Italic", size: 13) ?? NSFont.systemFont(ofSize: 13)
        italicBtn.bezelStyle = .texturedRounded
        italicBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(italicBtn)
        
        let underlineBtn = NSButton(title: "U", target: self, action: #selector(noteToggleUnderline(_:)))
        underlineBtn.bezelStyle = .texturedRounded
        underlineBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        ribbon.addArrangedSubview(underlineBtn)
        
        let ribbonSpacer = NSView()
        ribbonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        ribbon.addArrangedSubview(ribbonSpacer)
        
        contentView.addSubview(ribbon)
        
        let scrollView = NSScrollView(frame: NSRect(x: 12, y: 60, width: contentView.bounds.width - 24, height: contentView.bounds.height - 100 - ribbonHeight - 4 - 72))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: scrollView.bounds.width - 20, height: scrollView.bounds.height))
        textView.autoresizingMask = [.width]
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        
        currentNoteTextView = textView
        
        scrollView.documentView = textView
        contentView.addSubview(scrollView)
        
        let buttonBar = NSStackView(frame: NSRect(x: 12, y: 12, width: contentView.bounds.width - 24, height: 36))
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 12
        buttonBar.autoresizingMask = [.width, .maxYMargin]
        
        let btnSpacer = NSView()
        btnSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        buttonBar.addArrangedSubview(btnSpacer)
        
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(timecodeMarkerCancel(_:)))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        buttonBar.addArrangedSubview(cancelBtn)
        
        let saveBtn = NSButton(title: "Add Marker", target: self, action: #selector(timecodeMarkerSave(_:)))
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        buttonBar.addArrangedSubview(saveBtn)
        
        contentView.addSubview(buttonBar)
        window.contentView = contentView
        
        window.makeFirstResponder(timecodeField)
        
        let response = NSApp.runModal(for: window)
        window.orderOut(nil)
        
        if response == .OK {
            let timecodeStr = timecodeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let markerName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !markerName.isEmpty else { return }
            guard let timestamp = parseTimecode(timecodeStr) else {
                let alert = NSAlert()
                alert.messageText = "Invalid Timecode"
                alert.informativeText = "Please enter timecode in format HH:MM:SS.mmm (e.g., 00:01:23.456)"
                alert.alertStyle = .warning
                alert.runModal()
                return
            }
            
            var noteBase64: String? = nil
            if let storage = textView.textStorage, storage.length > 0,
               let noteData = storage.rtf(from: NSRange(location: 0, length: storage.length), documentAttributes: [:]) {
                noteBase64 = noteData.base64EncodedString()
            }
            
            insertMarkerAtTimecode(timestamp: timestamp, name: markerName, noteBase64: noteBase64)
        }
        
        currentNoteTextView = nil
    }
    
    @objc private func timecodeMarkerCancel(_ sender: NSButton) {
        NSApp.stopModal(withCode: .cancel)
    }
    
    @objc private func timecodeMarkerSave(_ sender: NSButton) {
        NSApp.stopModal(withCode: .OK)
    }
    
    private func parseTimecode(_ timecode: String) -> Double? {
        let parts = timecode.split(separator: ":")
        guard parts.count == 3 else { return nil }
        
        guard let hours = Int(parts[0]) else { return nil }
        guard let minutes = Int(parts[1]) else { return nil }
        
        let secondsParts = parts[2].split(separator: ".")
        guard let seconds = Int(secondsParts[0]) else { return nil }
        
        var milliseconds = 0
        if secondsParts.count > 1 {
            let msStr = String(secondsParts[1])
            let paddedMs = msStr.padding(toLength: 3, withPad: "0", startingAt: 0)
            milliseconds = Int(paddedMs.prefix(3)) ?? 0
        }
        
        guard let firstEvent = events.first,
              let firstTimestamp = firstEvent["timestamp"] as? Double else { return nil }
        
        let offsetMs = Double(hours * 3600000 + minutes * 60000 + seconds * 1000 + milliseconds)
        return firstTimestamp + (offsetMs * 1000)
    }
    
    private func insertMarkerAtTimecode(timestamp: Double, name: String, noteBase64: String?) {
        print("🚩 insertMarkerAtTimecode - timestamp: \(timestamp), name: \(name)")
        print("🚩 events.count before: \(events.count)")
        
        var insertIndex = events.count
        for (index, event) in events.enumerated() {
            if let eventTimestamp = event["timestamp"] as? Double, eventTimestamp >= timestamp {
                insertIndex = index
                break
            }
        }
        
        print("🚩 Inserting at index: \(insertIndex)")
        
        let markerEvent: [String: Any] = [
            "source": "editor",
            "type": "marker",
            "timestamp": timestamp,
            "markerName": name,
            "markerNote": noteBase64 as Any
        ]
        
        events.insert(markerEvent, at: insertIndex)
        shiftTagsAndNotesAfterInsert(at: insertIndex)
        
        print("🚩 events.count after: \(events.count)")
        
        filteredEvents = events
        saveTags()
        
        print("🚩 filteredEvents.count: \(filteredEvents.count)")
        print("🚩 Reloading table view... eventsTableView is \(eventsTableView == nil ? "nil" : "not nil")")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.eventsTableView?.reloadData()
            self.updateTimelineWithCurrentEvents()
            self.eventsCountLabel?.stringValue = "\(self.events.count) events"
            print("🚩 Table reloaded on main thread, rows: \(self.eventsTableView?.numberOfRows ?? -1)")
        }
        print("🚩 Done inserting marker")
    }
    
    private func applyEventsFilters() {
        let searchText = eventsSearchField?.stringValue.lowercased() ?? ""
        let sourceFilter = sourceFilterPopup?.titleOfSelectedItem ?? "All Sources"
        
        filteredEvents = events.enumerated().filter { (index, event) in
            // Source filter
            if sourceFilter != "All Sources" {
                let source = (event["source"] as? String ?? "").lowercased()
                if source != sourceFilter.lowercased() {
                    return false
                }
            }
            
            // Type filter (multi-select)
            if !selectedTypes.isEmpty {
                let type = event["type"] as? String ?? ""
                if !selectedTypes.contains(type) {
                    return false
                }
            }
            
            // Tag filter (multi-select)
            if !selectedTags.isEmpty {
                let tags = eventTags[index] ?? Set<String>()
                if tags.isDisjoint(with: selectedTags) {
                    return false
                }
            }
            
            // Text search
            if !searchText.isEmpty {
                let source = (event["source"] as? String ?? "").lowercased()
                let type = (event["type"] as? String ?? "").lowercased()
                let details = formatEventData(event["data"] as? [String: Any] ?? [:]).lowercased()
                let tags = (eventTags[index] ?? Set<String>()).joined(separator: " ").lowercased()
                
                if !source.contains(searchText) && !type.contains(searchText) && 
                   !details.contains(searchText) && !tags.contains(searchText) {
                    return false
                }
            }
            
            return true
        }.map { $0.1 }
        
        // Update count label
        if filteredEvents.count == events.count {
            eventsCountLabel?.stringValue = "\(events.count) events"
        } else {
            eventsCountLabel?.stringValue = "\(filteredEvents.count) of \(events.count) events"
        }
        
        eventsTableView?.reloadData()
    }
    
    private func populateTypeFilter() {
        allTypes.removeAll()
        for event in events {
            if let type = event["type"] as? String {
                allTypes.insert(type)
            }
        }
    }
    
    private func populateTagFilter() {
    }
    
    private func populateTimelineTagFilter() {
    }
    
    // Custom header cell for events table with 16px font - left aligned to match content
    private class EventsTableHeaderCell: NSTableHeaderCell {
        override init(textCell: String) {
            super.init(textCell: textCell)
            self.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
            self.alignment = .left
        }
        
        required init(coder: NSCoder) {
            super.init(coder: coder)
            self.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
            self.alignment = .left
        }
        
        override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
            NSColor.controlBackgroundColor.setFill()
            cellFrame.fill()
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: NSColor.headerTextColor
            ]
            
            let attributedString = NSAttributedString(string: stringValue, attributes: attributes)
            let textSize = attributedString.size()
            let yPosition = (cellFrame.height - textSize.height) / 2
            // Left align with same 8px padding as content cells
            let textRect = NSRect(x: cellFrame.origin.x + 8, y: cellFrame.origin.y + yPosition, width: cellFrame.width - 16, height: textSize.height)
            attributedString.draw(in: textRect)
        }
    }
    
    private func createEventsToolbar() -> NSView {
        let toolbar = NSView()
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        // Search field
        eventFilterField = NSSearchField()
        eventFilterField.placeholderString = "Filter events..."
        eventFilterField.target = self
        eventFilterField.action = #selector(filterEvents)
        eventFilterField.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(eventFilterField)
        
        // Event type filter
        eventTypeFilter = NSPopUpButton()
        eventTypeFilter.addItems(withTitles: [
            "All Events",
            "Focus Changes",
            "User Interactions", 
            "System Events",
            "Custom Events"
        ])
        eventTypeFilter.target = self
        eventTypeFilter.action = #selector(filterByEventType)
        eventTypeFilter.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(eventTypeFilter)
        
        // Export button
        let exportEventsButton = NSButton()
        exportEventsButton.title = "Export Events"
        exportEventsButton.target = self
        exportEventsButton.action = #selector(exportEventLog)
        exportEventsButton.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(exportEventsButton)
        
        // Event count label
        let eventCountLabel = NSTextField(labelWithString: "0 events")
        eventCountLabel.textColor = .secondaryLabelColor
        eventCountLabel.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(eventCountLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            eventFilterField.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 20),
            eventFilterField.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            eventFilterField.widthAnchor.constraint(equalToConstant: 200),
            
            eventTypeFilter.leadingAnchor.constraint(equalTo: eventFilterField.trailingAnchor, constant: 10),
            eventTypeFilter.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            eventTypeFilter.widthAnchor.constraint(equalToConstant: 150),
            
            exportEventsButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -20),
            exportEventsButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            
            eventCountLabel.trailingAnchor.constraint(equalTo: exportEventsButton.leadingAnchor, constant: -20),
            eventCountLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor)
        ])
        
        // Store reference for updates
        objc_setAssociatedObject(toolbar, "eventCountLabel", eventCountLabel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return toolbar
    }
    
    // MARK: - Simple Timeline Tab
    
    private func createEnhancedTimelineView() -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Header with title
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.spacing = 16
        headerStack.alignment = .centerY
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "📈 Event Timeline")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.backgroundColor = .clear
        headerStack.addArrangedSubview(titleLabel)
        
        let timeRangeLabel = NSTextField(labelWithString: "")
        timeRangeLabel.font = NSFont.systemFont(ofSize: 16)
        timeRangeLabel.textColor = .secondaryLabelColor
        timeRangeLabel.isBordered = false
        timeRangeLabel.isEditable = false
        timeRangeLabel.backgroundColor = .clear
        headerStack.addArrangedSubview(timeRangeLabel)
        self.timelineRangeLabel = timeRangeLabel
        
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerStack.addArrangedSubview(spacer)
        
        // Sync toggle button
        let syncButton = NSButton(checkboxWithTitle: "Sync Video", target: self, action: #selector(toggleVideoSync(_:)))
        syncButton.state = .on
        syncButton.font = NSFont.systemFont(ofSize: 13)
        headerStack.addArrangedSubview(syncButton)
        
        // Add Marker at Timecode button
        let addMarkerBtn = NSButton(title: "🚩 Add Marker at Timecode...", target: self, action: #selector(showAddMarkerAtTimecodeDialog(_:)))
        addMarkerBtn.bezelStyle = .rounded
        addMarkerBtn.font = NSFont.systemFont(ofSize: 13)
        headerStack.addArrangedSubview(addMarkerBtn)
        
        containerView.addSubview(headerStack)
        
        // Video player section (top half)
        let videoContainer = createVideoPlayerContainer()
        containerView.addSubview(videoContainer)
        
        // Controls toolbar
        let controlsToolbar = createTimelineControlsToolbar()
        containerView.addSubview(controlsToolbar)
        
        // Legend
        let legendView = createTimelineLegend()
        containerView.addSubview(legendView)
        
        // Timeline visualization
        let timeline = EnhancedTimelineView(frame: .zero)
        timeline.translatesAutoresizingMaskIntoConstraints = false
        timeline.wantsLayer = true
        timeline.layer?.cornerRadius = 8
        timeline.layer?.borderWidth = 1
        timeline.layer?.borderColor = NSColor.separatorColor.cgColor
        timeline.onEventSelected = { [weak self] event in
            self?.isUserSelectedEvent = true
            self?.updateTimelineInfo(with: event)
        }
        timeline.onEventRightClicked = { [weak self] event, eventIndex, nsEvent in
            self?.showTimelineEventContextMenu(event: event, eventIndex: eventIndex, nsEvent: nsEvent)
        }
        timeline.onPlayheadDragged = { [weak self] timestamp in
            guard let self = self else { return }
            let isMovingForward = timestamp >= self.lastPlayheadTimestamp
            self.lastPlayheadTimestamp = timestamp
            self.seekVideoToTimestamp(timestamp)
            self.scrollTimelineToKeepPlayheadVisible(timestamp: timestamp, movingForward: isMovingForward)
        }
        timeline.onZoomChanged = { [weak self] in
            guard let self = self else { return }
            if let timestamp = self.timelineView?.playheadTimestamp {
                self.scrollTimelineToKeepPlayheadVisible(timestamp: timestamp, movingForward: true)
            }
        }
        
        // Set video start timestamp as datum IMMEDIATELY
        print("🎬 VC videoStartTimestamp: \(videoStartTimestamp)")
        if videoStartTimestamp > 0 {
            timeline.setVideoStartTime(videoStartTimestamp)
        } else {
            print("⚠️ videoStartTimestamp is 0!")
        }
        
        self.timelineView = timeline
        
        // Wrap timeline in scroll view for horizontal scrolling
        let scrollView = NSScrollView()
        scrollView.documentView = timeline
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        self.timelineScrollView = scrollView
        containerView.addSubview(scrollView)
        
        // Observe scroll changes to sync video
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(timelineScrollViewDidScroll(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: scrollView
        )
        
        // Event detail panel (right side)
        let detailPanel = createTimelineDetailPanel()
        containerView.addSubview(detailPanel)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Video container takes top portion (larger to give more space for video)
            videoContainer.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            videoContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            videoContainer.trailingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: -12),
            videoContainer.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.6),
            
            controlsToolbar.topAnchor.constraint(equalTo: videoContainer.bottomAnchor, constant: 8),
            controlsToolbar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            controlsToolbar.trailingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: -12),
            
            legendView.topAnchor.constraint(equalTo: controlsToolbar.bottomAnchor, constant: 8),
            legendView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            legendView.trailingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: -12),
            legendView.heightAnchor.constraint(equalToConstant: 24),
            
            // Timeline takes remaining bottom portion
            scrollView.topAnchor.constraint(equalTo: legendView.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: detailPanel.leadingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            timeline.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.widthAnchor),
            timeline.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            detailPanel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            detailPanel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            detailPanel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            detailPanel.widthAnchor.constraint(equalToConstant: 280)
        ])
        
        // Load video if available
        loadSessionVideo()
        
        return containerView
    }
    
    private func createVideoPlayerContainer() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        container.layer?.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Video player view
        let playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.controlsStyle = .inline
        playerView.showsFullScreenToggleButton = true
        self.videoPlayerView = playerView
        container.addSubview(playerView)
        
        // "No video" placeholder label
        let noVideoLabel = NSTextField(labelWithString: "No screen recording available for this session")
        noVideoLabel.font = NSFont.systemFont(ofSize: 14)
        noVideoLabel.textColor = .secondaryLabelColor
        noVideoLabel.alignment = .center
        noVideoLabel.translatesAutoresizingMaskIntoConstraints = false
        noVideoLabel.tag = 999  // Tag for easy removal when video loads
        container.addSubview(noVideoLabel)
        
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: container.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            noVideoLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            noVideoLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
    
    private func loadSessionVideo() {
        let videoPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/screen_recording.mp4"
        let videoURL = URL(fileURLWithPath: videoPath)
        
        guard FileManager.default.fileExists(atPath: videoPath) else {
            print("📹 No screen recording found at: \(videoPath)")
            return
        }
        
        print("📹 Loading screen recording: \(videoPath)")
        
        // Remove "no video" placeholder
        if let placeholder = videoPlayerView?.superview?.viewWithTag(999) {
            placeholder.removeFromSuperview()
        }
        
        // Set timeline to use recordingStartTimestamp as datum
        timelineView?.setVideoStartTime(videoStartTimestamp)
        
        // Create player
        let player = AVPlayer(url: videoURL)
        self.videoPlayer = player
        videoPlayerView?.player = player
        
        // Add periodic time observer to sync timeline with video
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        videoTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.videoTimeDidChange(time)
        }
        
        // Observe play/pause state to know when video is actively playing
        player.addObserver(self, forKeyPath: "rate", options: [.new], context: nil)
        
        // Set initial playhead position at video start (time 0)
        timelineView?.setPlayheadTimestamp(videoStartTimestamp)
        
        print("📹 Screen recording loaded successfully")
    }
    
    private func loadRecordingStartTimestamp() {
        // Load recordingStartTimestamp from metadata - this is the datum (00:00:00) for all times
        let metadataPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/metadata.json"
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: metadataPath)),
              let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let recordingStart = metadata["recordingStartTimestamp"] as? Double else {
            print("⚠️ No recordingStartTimestamp in metadata for session \(sessionId)")
            return
        }
        
        videoStartTimestamp = recordingStart
        print("📹 Recording start timestamp (datum 00:00:00): \(recordingStart)")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate", let player = object as? AVPlayer {
            let wasPlaying = isVideoPlaying
            isVideoPlaying = player.rate > 0
            
            // When playback starts, re-enable auto-update of event details
            if isVideoPlaying && !wasPlaying {
                isUserSelectedEvent = false
                lastAutoShownEventTimestamp = 0
            }
        }
    }
    
    private func videoTimeDidChange(_ time: CMTime) {
        let videoSeconds = time.seconds
        
        // Calculate event timestamp from video time
        // Must account for pause gaps: merged video is continuous, but events have gaps
        let eventTimestamp = videoTimeToEventTimestamp(videoSeconds)
        
        // Determine playback direction
        let isMovingForward = eventTimestamp >= lastPlayheadTimestamp
        lastPlayheadTimestamp = eventTimestamp
        
        // Always update playhead position
        timelineView?.setPlayheadTimestamp(eventTimestamp)
        
        // Auto-show event details during playback (if not user-selected)
        if isVideoPlaying && !isUserSelectedEvent {
            autoShowEventAtTimestamp(eventTimestamp)
        }
        
        // Only scroll if sync is enabled and we're not already syncing from timeline
        guard isVideoSyncEnabled, !isSyncingFromTimeline else { return }
        
        isSyncingFromVideo = true
        defer { isSyncingFromVideo = false }
        
        // Scroll timeline to keep playhead visible at appropriate position
        scrollTimelineToKeepPlayheadVisible(timestamp: eventTimestamp, movingForward: isMovingForward)
    }
    
    private func autoShowEventAtTimestamp(_ timestamp: Double) {
        // Find the most recent event at or before the current timestamp
        var mostRecentEvent: [String: Any]? = nil
        var mostRecentTimestamp: Double = 0
        
        for event in events {
            guard let eventTimestamp = event["timestamp"] as? Double else { continue }
            
            // Only consider events at or before the playhead
            if eventTimestamp <= timestamp && eventTimestamp > mostRecentTimestamp {
                mostRecentTimestamp = eventTimestamp
                mostRecentEvent = event
            }
        }
        
        // Only update if we found an event and it's different from the last shown
        if let event = mostRecentEvent, mostRecentTimestamp != lastAutoShownEventTimestamp {
            lastAutoShownEventTimestamp = mostRecentTimestamp
            updateTimelineInfo(with: event)
        }
    }
    
    private func scrollTimelineToKeepPlayheadVisible(timestamp: Double, movingForward: Bool) {
        guard let scrollView = timelineScrollView,
              let timeline = timelineView else { return }
        
        // Get playhead X position from timeline view
        guard let playheadX = timeline.getPlayheadXPosition() else { return }
        
        let visibleRect = scrollView.contentView.bounds
        let visibleWidth = visibleRect.width
        let currentScrollX = visibleRect.origin.x
        
        // Target position: 75% when moving forward, 25% when moving backward
        let targetViewRatio = movingForward ? 0.75 : 0.25
        let targetViewX = visibleWidth * targetViewRatio
        
        // Check if playhead is outside the visible area or needs repositioning
        let playheadViewX = playheadX - currentScrollX
        
        // Define margins - only scroll if playhead is near edges or outside
        let leftMargin = visibleWidth * 0.1
        let rightMargin = visibleWidth * 0.9
        
        let needsScroll = playheadViewX < leftMargin || playheadViewX > rightMargin
        
        if needsScroll {
            // Calculate scroll to put playhead at target position
            let targetScrollX = playheadX - targetViewX
            let maxScroll = max(0, timeline.frame.width - visibleWidth)
            let clampedScrollX = max(0, min(maxScroll, targetScrollX))
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                scrollView.contentView.setBoundsOrigin(NSPoint(x: clampedScrollX, y: 0))
            }
        }
    }
    
    private func scrollTimelineToTimestamp(_ timestamp: Double) {
        guard let scrollView = timelineScrollView,
              let timeline = timelineView,
              !events.isEmpty else { return }
        
        let firstTimestamp = events.first?["timestamp"] as? Double ?? sessionStartTimestamp
        let lastTimestamp = events.last?["timestamp"] as? Double ?? firstTimestamp
        let timeRange = lastTimestamp - firstTimestamp
        
        guard timeRange > 0 else { return }
        
        let relativePosition = (timestamp - firstTimestamp) / timeRange
        let clampedPosition = max(0, min(1, relativePosition))
        
        let contentWidth = timeline.frame.width
        let visibleWidth = scrollView.contentView.bounds.width
        let maxScroll = max(0, contentWidth - visibleWidth)
        
        let targetX = clampedPosition * maxScroll
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            context.allowsImplicitAnimation = true
            scrollView.contentView.setBoundsOrigin(NSPoint(x: targetX, y: 0))
        }
    }
    
    @objc private func timelineScrollViewDidScroll(_ notification: Notification) {
        // Scrollbar no longer drives video - playhead cursor does that instead
    }
    
    private func syncVideoToScrollPosition() {
        guard let scrollView = timelineScrollView,
              let timeline = timelineView,
              let player = videoPlayer,
              !events.isEmpty else { return }
        
        // Calculate what timestamp the scroll position represents
        let contentWidth = timeline.frame.width
        let visibleWidth = scrollView.contentView.bounds.width
        let maxScroll = max(1, contentWidth - visibleWidth)
        let currentScroll = scrollView.contentView.bounds.origin.x
        
        let scrollRatio = currentScroll / maxScroll
        let clampedRatio = max(0, min(1, scrollRatio))
        
        // Map scroll ratio to timestamp
        let firstTimestamp = events.first?["timestamp"] as? Double ?? sessionStartTimestamp
        let lastTimestamp = events.last?["timestamp"] as? Double ?? firstTimestamp
        let timeRange = lastTimestamp - firstTimestamp
        
        let targetTimestamp = firstTimestamp + (clampedRatio * timeRange)
        
        // Convert timestamp to video time
        let videoSeconds = (targetTimestamp - videoStartTimestamp) / 1_000_000  // Convert from microseconds
        
        guard videoSeconds >= 0 else { return }
        
        let targetTime = CMTime(seconds: videoSeconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func syncVideoToEvent(_ event: [String: Any]) {
        guard isVideoSyncEnabled,
              let player = videoPlayer,
              let eventTimestamp = event["timestamp"] as? Double else { return }
        
        // Convert event timestamp to video time (accounting for pause gaps)
        let videoSeconds = eventTimestampToVideoTime(eventTimestamp)
        
        guard videoSeconds >= 0 else { return }
        
        let targetTime = CMTime(seconds: videoSeconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func seekVideoToTimestamp(_ timestamp: Double) {
        guard let player = videoPlayer else { return }
        
        // Convert event timestamp to video time (accounting for pause gaps)
        let videoSeconds = eventTimestampToVideoTime(timestamp)
        
        guard videoSeconds >= 0 else { return }
        
        let targetTime = CMTime(seconds: videoSeconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func videoTimeToEventTimestamp(_ videoSeconds: Double) -> Double {
        let baseTimestamp = videoStartTimestamp + (videoSeconds * 1_000_000)
        
        guard !pauseGaps.isEmpty else { return baseTimestamp }
        
        let sortedGaps = pauseGaps.sorted { $0.start < $1.start }
        var adjustedTimestamp = baseTimestamp
        var accumulatedPauseDuration: Double = 0
        
        for gap in sortedGaps {
            let gapStartInVideoTime = (gap.start - videoStartTimestamp - accumulatedPauseDuration) / 1_000_000
            
            if videoSeconds >= gapStartInVideoTime {
                adjustedTimestamp += gap.duration
                accumulatedPauseDuration += gap.duration
            } else {
                break
            }
        }
        
        return adjustedTimestamp
    }
    
    private func eventTimestampToVideoTime(_ timestamp: Double) -> Double {
        guard !pauseGaps.isEmpty else {
            return (timestamp - videoStartTimestamp) / 1_000_000
        }
        
        let sortedGaps = pauseGaps.sorted { $0.start < $1.start }
        var totalPauseBefore: Double = 0
        
        for gap in sortedGaps {
            if gap.end <= timestamp {
                totalPauseBefore += gap.duration
            } else if gap.start < timestamp {
                break
            }
        }
        
        return (timestamp - videoStartTimestamp - totalPauseBefore) / 1_000_000
    }
    
    @objc private func toggleVideoSync(_ sender: NSButton) {
        isVideoSyncEnabled = sender.state == .on
    }
    
    private var timelineRangeLabel: NSTextField?
    private var timelineDetailLabel: NSTextField?
    private var timelineDetailStackView: NSStackView?
    private var timelineZoomSlider: NSSlider?
    private var timelineSourceFilters: [String: Bool] = ["interaction": true, "focus": true, "system": true]
    private var timelineSearchField: NSSearchField?
    private var timelineTypeFilterButton: NSButton?
    private var timelineTagFilterButton: NSButton?
    private var timelineSelectedTypes: Set<String> = []
    private var timelineSelectedTags: Set<String> = []
    private var timelineFilteredEvents: [[String: Any]] = []
    
    private func createTimelineControlsToolbar() -> NSView {
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 8
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Row 1: Zoom and source filters
        let row1 = NSStackView()
        row1.orientation = .horizontal
        row1.spacing = 12
        row1.alignment = .centerY
        
        let zoomLabel = NSTextField(labelWithString: "Zoom:")
        zoomLabel.font = NSFont.systemFont(ofSize: 14)
        row1.addArrangedSubview(zoomLabel)
        
        let zoomOutButton = NSButton(title: "−", target: self, action: #selector(zoomTimelineOut))
        zoomOutButton.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        zoomOutButton.bezelStyle = .rounded
        zoomOutButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        row1.addArrangedSubview(zoomOutButton)
        
        let zoomSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 100.0, target: self, action: #selector(timelineZoomChanged(_:)))
        zoomSlider.widthAnchor.constraint(equalToConstant: 100).isActive = true
        self.timelineZoomSlider = zoomSlider
        row1.addArrangedSubview(zoomSlider)
        
        let zoomInButton = NSButton(title: "+", target: self, action: #selector(zoomTimelineIn))
        zoomInButton.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        zoomInButton.bezelStyle = .rounded
        zoomInButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        row1.addArrangedSubview(zoomInButton)
        
        let resetButton = NSButton(title: "Reset", target: self, action: #selector(resetTimelineZoom))
        resetButton.font = NSFont.systemFont(ofSize: 14)
        resetButton.bezelStyle = .rounded
        row1.addArrangedSubview(resetButton)
        
        let sep1 = NSBox()
        sep1.boxType = .separator
        sep1.widthAnchor.constraint(equalToConstant: 1).isActive = true
        sep1.heightAnchor.constraint(equalToConstant: 20).isActive = true
        row1.addArrangedSubview(sep1)
        
        let showLabel = NSTextField(labelWithString: "Show:")
        showLabel.font = NSFont.systemFont(ofSize: 14)
        row1.addArrangedSubview(showLabel)
        
        let interactionCheck = NSButton(checkboxWithTitle: "Interaction", target: self, action: #selector(timelineFilterChanged(_:)))
        interactionCheck.font = NSFont.systemFont(ofSize: 14)
        interactionCheck.state = .on
        interactionCheck.tag = 1
        row1.addArrangedSubview(interactionCheck)
        
        let focusCheck = NSButton(checkboxWithTitle: "Focus", target: self, action: #selector(timelineFilterChanged(_:)))
        focusCheck.font = NSFont.systemFont(ofSize: 14)
        focusCheck.state = .on
        focusCheck.tag = 2
        row1.addArrangedSubview(focusCheck)
        
        let systemCheck = NSButton(checkboxWithTitle: "System", target: self, action: #selector(timelineFilterChanged(_:)))
        systemCheck.font = NSFont.systemFont(ofSize: 14)
        systemCheck.state = .on
        systemCheck.tag = 3
        row1.addArrangedSubview(systemCheck)
        
        let spacer1 = NSView()
        spacer1.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row1.addArrangedSubview(spacer1)
        
        mainStack.addArrangedSubview(row1)
        
        // Row 2: Search, type filter, tag filter, and tag button
        let row2 = NSStackView()
        row2.orientation = .horizontal
        row2.spacing = 12
        row2.alignment = .centerY
        
        let searchField = NSSearchField()
        searchField.placeholderString = "Search events..."
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.target = self
        searchField.action = #selector(timelineSearchChanged(_:))
        searchField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        self.timelineSearchField = searchField
        row2.addArrangedSubview(searchField)
        
        let typeButton = NSButton(title: "Types: All", target: self, action: #selector(showTimelineTypeFilterMenu(_:)))
        typeButton.font = NSFont.systemFont(ofSize: 14)
        typeButton.bezelStyle = .rounded
        self.timelineTypeFilterButton = typeButton
        row2.addArrangedSubview(typeButton)
        
        let tagButton = NSButton(title: "Tags: All", target: self, action: #selector(showTimelineTagFilterMenu(_:)))
        tagButton.font = NSFont.systemFont(ofSize: 14)
        tagButton.bezelStyle = .rounded
        self.timelineTagFilterButton = tagButton
        row2.addArrangedSubview(tagButton)
        
        let clearButton = NSButton(title: "Clear Filters", target: self, action: #selector(clearTimelineFilters(_:)))
        clearButton.font = NSFont.systemFont(ofSize: 14)
        clearButton.bezelStyle = .rounded
        row2.addArrangedSubview(clearButton)
        
        let sep2 = NSBox()
        sep2.boxType = .separator
        sep2.widthAnchor.constraint(equalToConstant: 1).isActive = true
        sep2.heightAnchor.constraint(equalToConstant: 20).isActive = true
        row2.addArrangedSubview(sep2)
        
        let tagSelectedButton = NSButton(title: "Tag Selected", target: self, action: #selector(tagSelectedTimelineEvent(_:)))
        tagSelectedButton.font = NSFont.systemFont(ofSize: 14)
        tagSelectedButton.bezelStyle = .rounded
        row2.addArrangedSubview(tagSelectedButton)
        
        let spacer2 = NSView()
        spacer2.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row2.addArrangedSubview(spacer2)
        
        mainStack.addArrangedSubview(row2)
        
        return mainStack
    }
    
    @objc private func timelineSearchChanged(_ sender: NSSearchField) {
        applyTimelineFilters()
    }
    
    @objc private func showTimelineTypeFilterMenu(_ sender: NSButton) {
        let menu = NSMenu(title: "Select Types")
        
        let allItem = NSMenuItem(title: "All Types", action: #selector(toggleAllTimelineTypes(_:)), keyEquivalent: "")
        allItem.target = self
        allItem.state = timelineSelectedTypes.isEmpty ? .on : .off
        menu.addItem(allItem)
        menu.addItem(NSMenuItem.separator())
        
        for type in allTypes.sorted() {
            let item = NSMenuItem(title: type, action: #selector(toggleTimelineTypeFilter(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = type
            item.state = timelineSelectedTypes.contains(type) ? .on : .off
            menu.addItem(item)
        }
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
    
    @objc private func toggleAllTimelineTypes(_ sender: NSMenuItem) {
        timelineSelectedTypes.removeAll()
        updateTimelineTypeFilterButtonTitle()
        applyTimelineFilters()
    }
    
    @objc private func toggleTimelineTypeFilter(_ sender: NSMenuItem) {
        guard let type = sender.representedObject as? String else { return }
        if timelineSelectedTypes.contains(type) {
            timelineSelectedTypes.remove(type)
        } else {
            timelineSelectedTypes.insert(type)
        }
        updateTimelineTypeFilterButtonTitle()
        applyTimelineFilters()
    }
    
    @objc private func showTimelineTagFilterMenu(_ sender: NSButton) {
        let menu = NSMenu(title: "Select Tags")
        
        let allItem = NSMenuItem(title: "All Tags", action: #selector(toggleAllTimelineTags(_:)), keyEquivalent: "")
        allItem.target = self
        allItem.state = timelineSelectedTags.isEmpty ? .on : .off
        menu.addItem(allItem)
        menu.addItem(NSMenuItem.separator())
        
        for tag in allTags.sorted() {
            let item = NSMenuItem(title: tag, action: #selector(toggleTimelineTagFilter(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tag
            item.state = timelineSelectedTags.contains(tag) ? .on : .off
            menu.addItem(item)
        }
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
    
    @objc private func toggleAllTimelineTags(_ sender: NSMenuItem) {
        timelineSelectedTags.removeAll()
        updateTimelineTagFilterButtonTitle()
        applyTimelineFilters()
    }
    
    @objc private func toggleTimelineTagFilter(_ sender: NSMenuItem) {
        guard let tag = sender.representedObject as? String else { return }
        if timelineSelectedTags.contains(tag) {
            timelineSelectedTags.remove(tag)
        } else {
            timelineSelectedTags.insert(tag)
        }
        updateTimelineTagFilterButtonTitle()
        applyTimelineFilters()
    }
    
    private func updateTimelineTypeFilterButtonTitle() {
        if timelineSelectedTypes.isEmpty {
            timelineTypeFilterButton?.title = "Types: All"
        } else if timelineSelectedTypes.count == 1 {
            timelineTypeFilterButton?.title = "Types: \(timelineSelectedTypes.first!)"
        } else {
            timelineTypeFilterButton?.title = "Types: \(timelineSelectedTypes.count) selected"
        }
    }
    
    private func updateTimelineTagFilterButtonTitle() {
        if timelineSelectedTags.isEmpty {
            timelineTagFilterButton?.title = "Tags: All"
        } else if timelineSelectedTags.count == 1 {
            timelineTagFilterButton?.title = "Tags: \(timelineSelectedTags.first!)"
        } else {
            timelineTagFilterButton?.title = "Tags: \(timelineSelectedTags.count) selected"
        }
    }
    
    @objc private func clearTimelineFilters(_ sender: NSButton) {
        timelineSearchField?.stringValue = ""
        timelineSelectedTypes.removeAll()
        timelineSelectedTags.removeAll()
        updateTimelineTypeFilterButtonTitle()
        updateTimelineTagFilterButtonTitle()
        timelineSourceFilters = ["interaction": true, "focus": true, "system": true]
        applyTimelineFilters()
    }
    
    private var selectedTimelineEvent: [String: Any]?
    
    @objc private func tagSelectedTimelineEvent(_ sender: NSButton) {
        guard let event = selectedTimelineEvent,
              let timestamp = event["timestamp"] as? Double else {
            let alert = NSAlert()
            alert.messageText = "No Event Selected"
            alert.informativeText = "Click on an event in the timeline to select it, then use Tag Selected."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        let menu = NSMenu(title: "Select Tag")
        for tag in allTags.sorted() {
            let item = NSMenuItem(title: tag, action: #selector(applyTagToTimelineEvent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tag
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let customItem = NSMenuItem(title: "Add Custom Tag...", action: #selector(addCustomTagFromTimeline(_:)), keyEquivalent: "")
        customItem.target = self
        menu.addItem(customItem)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
    
    @objc private func addNoteToTimelineEvent(_ sender: NSButton) {
        guard let event = selectedTimelineEvent,
              let timestamp = event["timestamp"] as? Double else {
            let alert = NSAlert()
            alert.messageText = "No Event Selected"
            alert.informativeText = "Click on an event in the timeline to select it, then use Add Note."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        let originalIndex = findEventIndex(byTimestamp: timestamp)
        if originalIndex >= 0 {
            showNoteEditor(for: originalIndex, fromTimeline: true)
        }
    }
    
    @objc private func applyTagToTimelineEvent(_ sender: NSMenuItem) {
        guard let tag = sender.representedObject as? String,
              let event = selectedTimelineEvent,
              let timestamp = event["timestamp"] as? Double else { return }
        
        let originalIndex = findEventIndex(byTimestamp: timestamp)
        if originalIndex >= 0 {
            if eventTags[originalIndex] == nil {
                eventTags[originalIndex] = Set<String>()
            }
            eventTags[originalIndex]?.insert(tag)
            saveTags()
            applyTimelineFilters()
            eventsTableView?.reloadData()
        }
    }
    
    @objc private func addCustomTagFromTimeline(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Add Custom Tag"
        alert.informativeText = "Enter a name for the new tag:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.font = NSFont.systemFont(ofSize: 14)
        alert.accessoryView = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let newTag = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newTag.isEmpty {
                allTags.insert(newTag)
                
                if let event = selectedTimelineEvent,
                   let timestamp = event["timestamp"] as? Double {
                    let originalIndex = findEventIndex(byTimestamp: timestamp)
                    if originalIndex >= 0 {
                        if eventTags[originalIndex] == nil {
                            eventTags[originalIndex] = Set<String>()
                        }
                        eventTags[originalIndex]?.insert(newTag)
                        applyTimelineFilters()
                        eventsTableView?.reloadData()
                    }
                }
                saveTags()
            }
        }
    }
    
    private func findEventIndex(byTimestamp timestamp: Double) -> Int {
        for (index, event) in events.enumerated() {
            if let eventTimestamp = event["timestamp"] as? Double, eventTimestamp == timestamp {
                return index
            }
        }
        return -1
    }
    
    private func applyTimelineFilters() {
        let searchText = timelineSearchField?.stringValue.lowercased() ?? ""
        let noTypeFilter = timelineSelectedTypes.isEmpty
        let noTagFilter = timelineSelectedTags.isEmpty
        
        timelineFilteredEvents = events.enumerated().filter { (index, event) in
            guard let source = event["source"] as? String else { return false }
            if !(timelineSourceFilters[source] ?? true) {
                return false
            }
            
            if !noTypeFilter {
                let type = event["type"] as? String ?? ""
                if !timelineSelectedTypes.contains(type) {
                    return false
                }
            }
            
            if !noTagFilter {
                let tags = eventTags[index] ?? Set<String>()
                if tags.isDisjoint(with: timelineSelectedTags) {
                    return false
                }
            }
            
            if !searchText.isEmpty {
                let type = (event["type"] as? String ?? "").lowercased()
                let details = formatEventData(event["data"] as? [String: Any] ?? [:]).lowercased()
                let tags = (eventTags[index] ?? Set<String>()).joined(separator: " ").lowercased()
                
                if !source.contains(searchText) && !type.contains(searchText) && 
                   !details.contains(searchText) && !tags.contains(searchText) {
                    return false
                }
            }
            
            return true
        }.map { (index, event) -> [String: Any] in
            var eventWithIndex = event
            eventWithIndex["_originalIndex"] = index
            return eventWithIndex
        }
        
        let eventsForTimeline: [[String: Any]]
        if timelineFilteredEvents.isEmpty && searchText.isEmpty && noTypeFilter && noTagFilter {
            eventsForTimeline = events.enumerated().compactMap { (index, event) -> [String: Any]? in
                guard let source = event["source"] as? String, timelineSourceFilters[source] ?? true else { return nil }
                var eventWithIndex = event
                eventWithIndex["_originalIndex"] = index
                return eventWithIndex
            }
        } else {
            eventsForTimeline = timelineFilteredEvents
        }
        timelineView?.setEvents(eventsForTimeline)
        
        let total = events.count
        let showing = timelineFilteredEvents.isEmpty && searchText.isEmpty && noTypeFilter && noTagFilter 
            ? events.filter { event in
                guard let source = event["source"] as? String else { return false }
                return timelineSourceFilters[source] ?? true
            }.count 
            : timelineFilteredEvents.count
        
        if showing == total {
            timelineRangeLabel?.stringValue = formatTimelineRangeLabel()
        } else {
            timelineRangeLabel?.stringValue = "\(formatTimelineRangeLabel()) - Showing \(showing) of \(total)"
        }
    }
    
    private func formatTimelineRangeLabel() -> String {
        guard let firstTimestamp = events.first?["timestamp"] as? Double,
              let lastTimestamp = events.last?["timestamp"] as? Double else {
            return "No events"
        }
        
        let startDate = Date(timeIntervalSince1970: firstTimestamp / 1_000_000)
        let endDate = Date(timeIntervalSince1970: lastTimestamp / 1_000_000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        let duration = (lastTimestamp - firstTimestamp) / 1_000_000.0
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate)) (\(String(format: "%.1f", duration))s)"
    }
    
    private func populateTimelineTypeFilter() {
    }
    
    private func createTimelineLegend() -> NSView {
        let legend = NSStackView()
        legend.orientation = .horizontal
        legend.spacing = 20
        legend.alignment = .centerY
        legend.translatesAutoresizingMaskIntoConstraints = false
        
        let sources: [(String, NSColor)] = [
            ("Interaction", .systemGreen),
            ("Focus", .systemBlue),
            ("System", .systemOrange),
            ("Marker", .systemRed)
        ]
        
        for (name, color) in sources {
            let itemStack = NSStackView()
            itemStack.orientation = .horizontal
            itemStack.spacing = 6
            
            let colorBox = NSView()
            colorBox.wantsLayer = true
            colorBox.layer?.backgroundColor = color.cgColor
            colorBox.layer?.cornerRadius = 3
            colorBox.translatesAutoresizingMaskIntoConstraints = false
            colorBox.widthAnchor.constraint(equalToConstant: 14).isActive = true
            colorBox.heightAnchor.constraint(equalToConstant: 14).isActive = true
            itemStack.addArrangedSubview(colorBox)
            
            let label = NSTextField(labelWithString: name)
            label.font = NSFont.systemFont(ofSize: 14)
            label.textColor = .secondaryLabelColor
            itemStack.addArrangedSubview(label)
            
            legend.addArrangedSubview(itemStack)
        }
        
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        legend.addArrangedSubview(spacer)
        
        return legend
    }
    
    private func createTimelineDetailPanel() -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor
        panel.layer?.cornerRadius = 8
        panel.layer?.borderWidth = 1
        panel.layer?.borderColor = NSColor.separatorColor.cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Event Details")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.backgroundColor = .clear
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)
        
        let detailLabel = NSTextField(labelWithString: "Select an event from the timeline or Events tab to view details")
        detailLabel.font = NSFont.systemFont(ofSize: 14)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.isBordered = false
        detailLabel.isEditable = false
        detailLabel.backgroundColor = .clear
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 0
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(detailLabel)
        self.timelineDetailLabel = detailLabel
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let clipView = FlippedClipView()
        clipView.drawsBackground = false
        
        let scrollView = NSScrollView()
        scrollView.contentView = clipView
        scrollView.documentView = stackView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isHidden = true
        panel.addSubview(scrollView)
        self.timelineDetailStackView = stackView
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            detailLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -8),
            
            stackView.topAnchor.constraint(equalTo: clipView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -16)
        ])
        
        return panel
    }
    
    @objc private func timelineZoomChanged(_ sender: NSSlider) {
        timelineView?.setZoom(CGFloat(sender.doubleValue))
    }
    
    @objc private func timelineFilterChanged(_ sender: NSButton) {
        let sources = ["", "interaction", "focus", "system"]
        if sender.tag > 0 && sender.tag < sources.count {
            timelineSourceFilters[sources[sender.tag]] = sender.state == .on
        }
        applyTimelineFilters()
    }
    
    @objc private func toggleEventDetails(_ sender: NSButton) {
        timelineView?.showEventDetails = sender.state == .on
        timelineView?.needsDisplay = true
    }
    
    private func createTimelineControls() -> NSView {
        let controlsView = NSView()
        controlsView.wantsLayer = true
        controlsView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        
        // Zoom controls
        let zoomInButton = NSButton()
        zoomInButton.title = "Zoom In"
        zoomInButton.target = self
        zoomInButton.action = #selector(zoomTimelineIn)
        zoomInButton.translatesAutoresizingMaskIntoConstraints = false
        controlsView.addSubview(zoomInButton)
        
        let zoomOutButton = NSButton()
        zoomOutButton.title = "Zoom Out"
        zoomOutButton.target = self
        zoomOutButton.action = #selector(zoomTimelineOut)
        zoomOutButton.translatesAutoresizingMaskIntoConstraints = false
        controlsView.addSubview(zoomOutButton)
        
        let resetZoomButton = NSButton()
        resetZoomButton.title = "Reset Zoom"
        resetZoomButton.target = self
        resetZoomButton.action = #selector(resetTimelineZoom)
        resetZoomButton.translatesAutoresizingMaskIntoConstraints = false
        controlsView.addSubview(resetZoomButton)
        
        // Timeline options
        let showDetailsCheckbox = NSButton(checkboxWithTitle: "Show Event Details", target: self, action: #selector(toggleEventDetails))
        showDetailsCheckbox.state = .on
        showDetailsCheckbox.translatesAutoresizingMaskIntoConstraints = false
        controlsView.addSubview(showDetailsCheckbox)
        
        // Layout
        NSLayoutConstraint.activate([
            zoomInButton.leadingAnchor.constraint(equalTo: controlsView.leadingAnchor, constant: 20),
            zoomInButton.centerYAnchor.constraint(equalTo: controlsView.centerYAnchor),
            
            zoomOutButton.leadingAnchor.constraint(equalTo: zoomInButton.trailingAnchor, constant: 10),
            zoomOutButton.centerYAnchor.constraint(equalTo: controlsView.centerYAnchor),
            
            resetZoomButton.leadingAnchor.constraint(equalTo: zoomOutButton.trailingAnchor, constant: 10),
            resetZoomButton.centerYAnchor.constraint(equalTo: controlsView.centerYAnchor),
            
            showDetailsCheckbox.trailingAnchor.constraint(equalTo: controlsView.trailingAnchor, constant: -20),
            showDetailsCheckbox.centerYAnchor.constraint(equalTo: controlsView.centerYAnchor)
        ])
        
        return controlsView
    }
    
    private func createTimelineInfoPanel() -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        panel.layer?.cornerRadius = 8
        panel.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Timeline Information")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)
        
        let infoLabel = NSTextField(labelWithString: "Click on timeline events to see details here")
        infoLabel.font = NSFont.systemFont(ofSize: 16)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.lineBreakMode = .byWordWrapping
        infoLabel.maximumNumberOfLines = 0
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -15),
            
            infoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            infoLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 15),
            infoLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -15),
            infoLabel.bottomAnchor.constraint(lessThanOrEqualTo: panel.bottomAnchor, constant: -15)
        ])
        
        // Store reference for updates
        objc_setAssociatedObject(panel, "timelineInfoLabel", infoLabel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return panel
    }
    
    private func loadSessionEvents() {
        let recordingsPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/events.json"
        
        print("🔍 Loading session events from: \(recordingsPath)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: recordingsPath))
                
                guard let sessionJson = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ Failed to parse events.json as dictionary")
                    DispatchQueue.main.async {
                        self.events = []
                        self.finishLoading()
                    }
                    return
                }
                
                // Try to get events from the JSON structure
                var eventsArray: [[String: Any]] = []
                var pauseGapsArray: [(start: Double, end: Double, duration: Double)] = []
                
                if let directEvents = sessionJson["events"] as? [[String: Any]] {
                    eventsArray = directEvents
                    print("✅ Found \(eventsArray.count) events in 'events' key")
                } else {
                    // Try to parse as a direct array if the main parsing fails
                    do {
                        if let eventsData = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                            eventsArray = eventsData
                            print("✅ Found \(eventsArray.count) events as direct array")
                        } else {
                            print("❌ No events array found in JSON structure")
                            print("JSON keys: \(Array(sessionJson.keys))")
                        }
                    } catch {
                        print("❌ Could not parse as direct events array either")
                    }
                }
                
                // Extract pause gaps from metadata
                if let metadata = sessionJson["metadata"] as? [String: Any],
                   let pauseGaps = metadata["pauseGaps"] as? [[String: Any]] {
                    for gap in pauseGaps {
                        if let start = gap["start"] as? Double,
                           let end = gap["end"] as? Double,
                           let duration = gap["duration"] as? Double {
                            pauseGapsArray.append((start: start, end: end, duration: duration))
                        }
                    }
                    print("✅ Found \(pauseGapsArray.count) pause gaps")
                }
                
                let eventsStartTime = sessionJson["startTime"] as? Double
                
                // Load screenshots.json and merge with events
                let screenshotsPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(self.sessionId)/screenshots.json"
                if FileManager.default.fileExists(atPath: screenshotsPath) {
                    do {
                        let screenshotsData = try Data(contentsOf: URL(fileURLWithPath: screenshotsPath))
                        if let screenshotEvents = try JSONSerialization.jsonObject(with: screenshotsData) as? [[String: Any]] {
                            eventsArray.append(contentsOf: screenshotEvents)
                            print("✅ Loaded \(screenshotEvents.count) screenshot events from screenshots.json")
                        }
                    } catch {
                        print("⚠️ Failed to load screenshots.json: \(error)")
                    }
                }
                
                DispatchQueue.main.async {
                    self.events = eventsArray.sorted { 
                        ($0["timestamp"] as? Double ?? 0) < ($1["timestamp"] as? Double ?? 0)
                    }
                    if let firstTimestamp = self.events.first?["timestamp"] as? Double {
                        self.sessionStartTimestamp = firstTimestamp
                    }
                    
                    // Adjust videoStartTimestamp to align with when events actually started
                    // This accounts for Node.js startup delay
                    if let eventsStart = eventsStartTime, eventsStart > self.videoStartTimestamp {
                        let startupDelay = eventsStart - self.videoStartTimestamp
                        print("📹 Adjusting video start by \(startupDelay / 1_000_000)s for Node.js startup delay")
                        self.videoStartTimestamp = eventsStart
                        self.timelineView?.setVideoStartTime(eventsStart)
                    }
                    
                    // Store pause gaps for video/event time conversion
                    self.pauseGaps = pauseGapsArray
                    
                    // Set pause gaps on timeline
                    if !pauseGapsArray.isEmpty {
                        self.timelineView?.setPauseGaps(pauseGapsArray)
                    }
                    
                    // Set initial playhead position
                    // If session is paused, start at beginning of last segment (where we left off)
                    // Otherwise start at the beginning
                    let isPaused = (sessionJson["metadata"] as? [String: Any])?["status"] as? String == "paused"
                    if isPaused, let lastGap = pauseGapsArray.last {
                        let lastSegmentStart = lastGap.end
                        self.timelineView?.setPlayheadTimestamp(lastSegmentStart)
                        // Also seek video to this position
                        let videoTime = self.eventTimestampToVideoTime(lastSegmentStart)
                        if videoTime >= 0 {
                            let targetTime = CMTime(seconds: videoTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                            self.videoPlayer?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
                        }
                        print("📍 Paused session - starting at last segment: \(lastSegmentStart)")
                    } else {
                        self.timelineView?.setPlayheadTimestamp(self.videoStartTimestamp)
                    }
                    
                    self.finishLoading()
                }
                
            } catch {
                print("❌ Failed to load events.json: \(error)")
                DispatchQueue.main.async {
                    self.events = []
                    self.finishLoading()
                }
            }
        }
    }
    
    private func loadSessionMetadata() {
        let metadataPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/metadata.json"
        
        if FileManager.default.fileExists(atPath: metadataPath) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: metadataPath))
                if let metadata = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    sessionMetadata = metadata
                    updateUIWithMetadata()
                }
            } catch {
                print("Failed to load metadata: \(error)")
            }
        }
        loadTags()
    }
    
    private func loadTags() {
        let tagsPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/tags.json"
        
        if FileManager.default.fileExists(atPath: tagsPath) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: tagsPath))
                if let tagsDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let eventTagsDict = tagsDict["eventTags"] as? [String: [String]] {
                        eventTags = [:]
                        for (key, tags) in eventTagsDict {
                            if let index = Int(key) {
                                eventTags[index] = Set(tags)
                            }
                        }
                    }
                    if let customTags = tagsDict["customTags"] as? [String] {
                        allTags = allTags.union(Set(customTags))
                    }
                    if let notesDict = tagsDict["eventNotes"] as? [String: String] {
                        eventNotes = [:]
                        for (key, base64String) in notesDict {
                            if let index = Int(key), let noteData = Data(base64Encoded: base64String) {
                                eventNotes[index] = noteData
                            }
                        }
                    }
                    if let markersDict = tagsDict["eventMarkers"] as? [String: [String: Any]] {
                        pendingMarkers = markersDict
                    }
                    populateTagFilter()
                    populateTimelineTagFilter()
                }
            } catch {
                print("Failed to load tags: \(error)")
            }
        }
    }
    
    private func insertMarkerEvent(_ marker: [String: Any], beforeIndex index: Int) {
        var adjustedIndex = index
        for i in 0..<index {
            if events[i]["type"] as? String == "marker" {
                adjustedIndex += 1
            }
        }
        if adjustedIndex > events.count {
            adjustedIndex = events.count
        }
        events.insert(marker, at: adjustedIndex)
        shiftTagsAndNotesAfterInsert(at: adjustedIndex)
    }
    
    private func shiftTagsAndNotesAfterInsert(at insertIndex: Int) {
        var newTags: [Int: Set<String>] = [:]
        var newNotes: [Int: Data] = [:]
        for (idx, tags) in eventTags {
            if idx >= insertIndex {
                newTags[idx + 1] = tags
            } else {
                newTags[idx] = tags
            }
        }
        for (idx, note) in eventNotes {
            if idx >= insertIndex {
                newNotes[idx + 1] = note
            } else {
                newNotes[idx] = note
            }
        }
        eventTags = newTags
        eventNotes = newNotes
    }
    
    private func shiftTagsAndNotesAfterDelete(at deleteIndex: Int) {
        var newTags: [Int: Set<String>] = [:]
        var newNotes: [Int: Data] = [:]
        for (idx, tags) in eventTags {
            if idx > deleteIndex {
                newTags[idx - 1] = tags
            } else if idx < deleteIndex {
                newTags[idx] = tags
            }
        }
        for (idx, note) in eventNotes {
            if idx > deleteIndex {
                newNotes[idx - 1] = note
            } else if idx < deleteIndex {
                newNotes[idx] = note
            }
        }
        eventTags = newTags
        eventNotes = newNotes
    }
    
    private func saveTags() {
        let tagsPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/tags.json"
        
        var eventTagsDict: [String: [String]] = [:]
        for (index, tags) in eventTags {
            eventTagsDict[String(index)] = Array(tags)
        }
        
        var eventNotesDict: [String: String] = [:]
        for (index, noteData) in eventNotes {
            eventNotesDict[String(index)] = noteData.base64EncodedString()
        }
        
        var eventMarkersDict: [String: [String: Any]] = [:]
        for (index, event) in events.enumerated() {
            if event["type"] as? String == "marker" {
                let name = event["markerName"] as? String ?? "Marker"
                var markerData: [String: Any] = ["name": name]
                if let noteBase64 = event["markerNote"] as? String {
                    markerData["note"] = noteBase64
                }
                if let refIndex = event["referenceEventIndex"] as? Int {
                    eventMarkersDict[String(refIndex)] = markerData
                } else {
                    eventMarkersDict[String(index)] = markerData
                }
            }
        }
        
        let defaultTags: Set<String> = ["Important", "Bug", "Question", "Follow-up", "Resolved"]
        let customTags = Array(allTags.subtracting(defaultTags))
        
        let tagsDict: [String: Any] = [
            "eventTags": eventTagsDict,
            "eventNotes": eventNotesDict,
            "eventMarkers": eventMarkersDict,
            "customTags": customTags
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: tagsDict, options: .prettyPrinted)
            try data.write(to: URL(fileURLWithPath: tagsPath))
        } catch {
            print("Failed to save tags: \(error)")
        }
    }
    
    private func updateTimelineWithCurrentEvents() {
        let eventsWithIndices = events.enumerated().map { (index, event) -> [String: Any] in
            var eventWithIndex = event
            eventWithIndex["_originalIndex"] = index
            return eventWithIndex
        }
        timelineView?.setEvents(eventsWithIndices)
        timelineView?.needsDisplay = true
    }
    
    private func finishLoading() {
        print("🔄 Finishing loading with \(events.count) events")
        loadingIndicator.stopAnimation(nil)
        loadingIndicator.isHidden = true
        
        processPendingMarkers()
        
        filteredEvents = events
        populateTypeFilter()
        eventsCountLabel?.stringValue = "\(events.count) events"
        
        calculateSessionStats()
        updateAllViews()
        
        print("✅ Loading complete - UI updated")
    }
    
    private func processPendingMarkers() {
        print("🔖 processPendingMarkers called - pendingMarkers count: \(pendingMarkers.count), events count: \(events.count)")
        guard !pendingMarkers.isEmpty else { 
            print("🔖 No pending markers to process")
            return 
        }
        
        let sortedKeys = pendingMarkers.keys.compactMap { Int($0) }.sorted()
        print("🔖 Processing markers for indices: \(sortedKeys)")
        for index in sortedKeys {
            guard let markerData = pendingMarkers[String(index)],
                  let name = markerData["name"] as? String,
                  index < events.count else { 
                print("🔖 Skipping marker at index \(index) - events.count=\(events.count)")
                continue 
            }
            
            let referenceEvent = events[index]
            let timestamp = referenceEvent["timestamp"] as? Double ?? 0
            var noteBase64: String? = nil
            if let nb = markerData["note"] as? String {
                noteBase64 = nb
            }
            let markerEvent: [String: Any] = [
                "source": "editor",
                "type": "marker",
                "timestamp": timestamp,
                "markerName": name,
                "markerNote": noteBase64 as Any,
                "referenceEventIndex": index
            ]
            print("🔖 Inserting marker '\(name)' at index \(index)")
            insertMarkerEvent(markerEvent, beforeIndex: index)
        }
        print("🔖 After processing, events count: \(events.count)")
        pendingMarkers = [:]
    }
    
    private func updateAllViews() {
        updateOverviewCards()
        updateSimpleEventsTab()
        updateSimpleTimelineTab()
    }
    
    // MARK: - Card Update Methods with Direct Data References
    
    private func updateOverviewCards() {
        print("🔄 updateOverviewCards called - events count: \(events.count)")
        
        // Update Key Metrics Card
        updateMetricsCard()
        
        // Update Session Status Card
        updateStatusCard()
        
        // Update Event Analytics Card
        updateEventAnalyticsCard()
        
        // Update Timeline Card
        updateTimelineCard()
        
        // Update Insights Card
        updateInsightsCard()
    }
    
    private func updateMetricsCard() {
        guard let container = metricsCardContainer as? NSStackView else { return }
        container.arrangedSubviews.forEach { container.removeArrangedSubview($0); $0.removeFromSuperview() }
        
        var duration = 0.0
        var rate = 0.0
        
        if events.count > 1,
           let firstTimestamp = events.first?["timestamp"] as? Double,
           let lastTimestamp = events.last?["timestamp"] as? Double {
            duration = (lastTimestamp - firstTimestamp) / 1_000_000.0
            rate = Double(events.count) / max(duration, 0.1)
        }
        
        let eventsLabel = createMetricLabel("📊 Total Events: \(events.count)", size: 18)
        let rateLabel = createMetricLabel("⚡ Rate: \(String(format: "%.1f", rate))/sec", size: 18)
        
        container.addArrangedSubview(eventsLabel)
        container.addArrangedSubview(rateLabel)
    }
    
    private func updateStatusCard() {
        guard let container = statusCardContainer as? NSStackView else { return }
        container.arrangedSubviews.forEach { container.removeArrangedSubview($0); $0.removeFromSuperview() }
        
        let status = sessionData["status"] as? String ?? "Unknown"
        var duration = 0.0
        
        if events.count > 1,
           let firstTimestamp = events.first?["timestamp"] as? Double,
           let lastTimestamp = events.last?["timestamp"] as? Double {
            duration = (lastTimestamp - firstTimestamp) / 1_000_000.0
        }
        
        // Status row with dot
        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .centerY
        
        let statusDot = NSView()
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 6
        statusDot.layer?.backgroundColor = (status.lowercased() == "active" ? NSColor.systemGreen : NSColor.systemRed).cgColor
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.widthAnchor.constraint(equalToConstant: 12).isActive = true
        statusDot.heightAnchor.constraint(equalToConstant: 12).isActive = true
        
        let statusLabel = createMetricLabel("Status: \(status.capitalized)", size: 18, color: .labelColor)
        statusRow.addArrangedSubview(statusDot)
        statusRow.addArrangedSubview(statusLabel)
        
        let durationLabel = createMetricLabel("⏱️ Duration: \(String(format: "%.1f", duration))s", size: 18, color: .labelColor)
        
        container.addArrangedSubview(statusRow)
        container.addArrangedSubview(durationLabel)
    }
    
    private func updateEventAnalyticsCard() {
        guard let container = eventAnalyticsCardContainer as? NSStackView else { return }
        container.arrangedSubviews.forEach { container.removeArrangedSubview($0); $0.removeFromSuperview() }
        
        var typeCounts: [String: Int] = [:]
        for event in events {
            let eventType = event["type"] as? String ?? "unknown"
            typeCounts[eventType, default: 0] += 1
        }
        
        let sortedTypes = typeCounts.sorted { $0.value > $1.value }
        
        for (type, count) in sortedTypes.prefix(5) {
            let percentage = Double(count) / Double(max(events.count, 1)) * 100
            let label = createMetricLabel("• \(type.capitalized): \(count) (\(String(format: "%.0f", percentage))%)", size: 16)
            container.addArrangedSubview(label)
        }
    }
    
    private func updateTimelineCard() {
        guard let container = timelineCardContainer as? NSStackView else { return }
        container.arrangedSubviews.forEach { container.removeArrangedSubview($0); $0.removeFromSuperview() }
        
        var sourceCounts: [String: Int] = [:]
        for event in events {
            let source = event["source"] as? String ?? "unknown"
            sourceCounts[source, default: 0] += 1
        }
        
        for (source, count) in sourceCounts.sorted(by: { $0.value > $1.value }) {
            let percentage = Double(count) / Double(max(events.count, 1)) * 100
            let emoji = source == "interaction" ? "👆" : source == "focus" ? "🎯" : source == "system" ? "⚙️" : "📌"
            let label = createMetricLabel("\(emoji) \(source.capitalized): \(count) (\(String(format: "%.0f", percentage))%)", size: 16)
            container.addArrangedSubview(label)
        }
    }
    
    private func updateInsightsCard() {
        guard let container = insightsCardContainer as? NSStackView else { return }
        container.arrangedSubviews.forEach { container.removeArrangedSubview($0); $0.removeFromSuperview() }
        
        var insights: [(String, String)] = []
        
        // Generate insights based on data
        if events.count > 100 {
            insights.append(("⚡", "High Activity - Very interactive session"))
        } else if events.count > 50 {
            insights.append(("📊", "Moderate Activity - Normal interaction level"))
        } else {
            insights.append(("🔍", "Low Activity - Limited interactions captured"))
        }
        
        var duration = 0.0
        if events.count > 1,
           let firstTimestamp = events.first?["timestamp"] as? Double,
           let lastTimestamp = events.last?["timestamp"] as? Double {
            duration = (lastTimestamp - firstTimestamp) / 1_000_000.0
        }
        
        if duration < 30 {
            insights.append(("⚡", "Quick Session - Brief duration"))
        } else if duration > 300 {
            insights.append(("⏱️", "Extended Session - Long duration"))
        }
        
        if events.count > 50 {
            insights.append(("📊", "Data Rich - Many events captured"))
        }
        
        for (emoji, text) in insights.prefix(3) {
            let label = createMetricLabel("\(emoji) \(text)", size: 16, color: .systemGreen)
            container.addArrangedSubview(label)
        }
    }
    
    private func createMetricLabel(_ text: String, size: CGFloat, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func updateSimpleEventsTab() {
        print("🔄 updateSimpleEventsTab called - events count: \(events.count)")
        
        // Update count label
        eventsCountLabel?.stringValue = "\(events.count) events"
        
        // Reload table view
        eventsTableView?.reloadData()
    }
    
    private func updateSimpleTimelineTab() {
        guard !events.isEmpty else {
            timelineRangeLabel?.stringValue = "No events"
            return
        }
        
        // Populate type filter dropdown
        populateTimelineTypeFilter()
        
        // Update time range label
        timelineRangeLabel?.stringValue = formatTimelineRangeLabel()
        
        // Update the visual timeline with original indices
        let eventsWithIndices = events.enumerated().map { (index, event) -> [String: Any] in
            var eventWithIndex = event
            eventWithIndex["_originalIndex"] = index
            return eventWithIndex
        }
        timelineView?.setEvents(eventsWithIndices)
    }
    
    private func updateOverviewTab() {
        print("🔄 Updating overview tab with \(events.count) events")
        
        // Update all cards using direct references
        if metricsCardContainer != nil {
            updateProfessionalMetricsCard(view)
        }
        if statusCardContainer != nil {
            updateProfessionalStatusCard()
        }
        if eventAnalyticsCardContainer != nil {
            updateProfessionalEventAnalyticsCard()
        }
        if timelineCardContainer != nil {
            updateProfessionalTimelineCard()
        }
        if insightsCardContainer != nil {
            updateProfessionalInsightsCard()
        }
        
        print("✅ Overview tab updated")
    }
    
    // MARK: - Professional Card Update Methods
    
    private func updateProfessionalHeaderCard(_ card: NSView) {
        // Header is static, already displays session info
        print("✅ Header card updated - static content")
    }
    
    private func updateProfessionalMetricsCard(_ card: NSView) {
        print("🔍 updateProfessionalMetricsCard called")
        print("🔍 Events count: \(events.count)")
        
        // Use direct reference instead of objc_getAssociatedObject
        guard let container = metricsCardContainer else { 
            print("❌ metricsCardContainer is nil")
            return 
        }
        
        print("📊 Found container, updating content")
        
        // Clear existing content
        container.subviews.forEach { $0.removeFromSuperview() }
        
        // Use events.count directly
        let totalEvents = events.count
        let duration = getDurationFromEvents()
        
        let contentText: String
        if duration > 0 {
            let rate = Double(totalEvents) / duration
            contentText = "📝 Total Events: \(totalEvents)\n⚡ Rate: \(String(format: "%.1f/sec", rate))"
        } else {
            contentText = "📝 Total Events: \(totalEvents)\n⚡ Rate: N/A"
        }
        
        print("📊 Creating label with text: \(contentText)")
        
        let metricsLabel = NSTextField(labelWithString: contentText)
        metricsLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        metricsLabel.textColor = NSColor.labelColor
        metricsLabel.backgroundColor = NSColor.clear
        metricsLabel.isBordered = false
        metricsLabel.isEditable = false
        metricsLabel.lineBreakMode = .byWordWrapping
        metricsLabel.maximumNumberOfLines = 0
        metricsLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(metricsLabel)
        
        NSLayoutConstraint.activate([
            metricsLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            metricsLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        print("✅ Metrics card updated with \(totalEvents) events")
    }
    
    private func getDurationFromEvents() -> Double {
        guard events.count > 1,
              let firstTimestamp = events.first?["timestamp"] as? TimeInterval,
              let lastTimestamp = events.last?["timestamp"] as? TimeInterval else {
            return 0
        }
        return (lastTimestamp - firstTimestamp) / 1000000.0 // Convert microseconds to seconds
    }
    
    private func updateProfessionalStatusCard() {
        guard let container = statusCardContainer else { return }
        
        // Clear existing content
        container.subviews.forEach { $0.removeFromSuperview() }
        
        // Use events.count directly
        let totalEvents = events.count
        let duration = getDurationFromEvents()
        
        let status = totalEvents > 0 ? "Active" : "No Events"
        let statusColor = totalEvents > 0 ? NSColor.systemGreen : NSColor.systemRed
        
        let durationStr: String
        if duration > 0 {
            if duration < 60 {
                durationStr = String(format: "%.1fs", duration)
            } else {
                durationStr = String(format: "%.1fm", duration / 60)
            }
        } else {
            durationStr = "N/A"
        }
        
        let contentText = "🟢 Status: \(status)\n⏱️ Duration: \(durationStr)"
        
        let statusLabel = NSTextField(labelWithString: contentText)
        statusLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        statusLabel.textColor = statusColor
        statusLabel.backgroundColor = NSColor.clear
        statusLabel.isBordered = false
        statusLabel.isEditable = false
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }
    
    private func updateProfessionalEventAnalyticsCard() {
        guard let container = eventAnalyticsCardContainer else { return }
        
        // Clear existing content
        container.subviews.forEach { $0.removeFromSuperview() }
        
        // Calculate event type counts directly from events
        var eventTypeCounts: [String: Int] = [:]
        for event in events {
            if let type = event["type"] as? String {
                eventTypeCounts[type, default: 0] += 1
            }
        }
        
        if eventTypeCounts.isEmpty {
            let noDataLabel = NSTextField(labelWithString: "No event data available")
            noDataLabel.font = NSFont.systemFont(ofSize: 18)
            noDataLabel.textColor = NSColor.secondaryLabelColor
            noDataLabel.alignment = .center
            noDataLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(noDataLabel)
            
            NSLayoutConstraint.activate([
                noDataLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                noDataLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            return
        }
        
        // Build text for top event types
        let sortedTypes = eventTypeCounts.sorted { $0.value > $1.value }
        var contentLines: [String] = []
        for (type, count) in sortedTypes.prefix(4) {
            let percentage = Int(Double(count) / Double(events.count) * 100)
            let cleanedType = type.replacingOccurrences(of: "_", with: " ").capitalized
            contentLines.append("• \(cleanedType): \(count) (\(percentage)%)")
        }
        
        let analyticsLabel = NSTextField(labelWithString: contentLines.joined(separator: "\n"))
        analyticsLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        analyticsLabel.textColor = NSColor.labelColor
        analyticsLabel.backgroundColor = NSColor.clear
        analyticsLabel.isBordered = false
        analyticsLabel.isEditable = false
        analyticsLabel.lineBreakMode = .byWordWrapping
        analyticsLabel.maximumNumberOfLines = 0
        analyticsLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(analyticsLabel)
        
        NSLayoutConstraint.activate([
            analyticsLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            analyticsLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            analyticsLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
    
    private func updateProfessionalTimelineCard() {
        guard let container = timelineCardContainer else { return }
        
        // Clear existing content
        container.subviews.forEach { $0.removeFromSuperview() }
        
        // Calculate source counts directly from events
        var sourceTypeCounts: [String: Int] = [:]
        for event in events {
            if let source = event["source"] as? String {
                sourceTypeCounts[source, default: 0] += 1
            }
        }
        
        if sourceTypeCounts.isEmpty {
            let noDataLabel = NSTextField(labelWithString: "No timeline data")
            noDataLabel.font = NSFont.systemFont(ofSize: 16)
            noDataLabel.textColor = NSColor.secondaryLabelColor
            noDataLabel.alignment = .center
            noDataLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(noDataLabel)
            
            NSLayoutConstraint.activate([
                noDataLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                noDataLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            return
        }
        
        // Build text for source breakdown
        let sortedSources = sourceTypeCounts.sorted { $0.value > $1.value }
        var contentLines: [String] = []
        for (source, count) in sortedSources {
            let percentage = Int(Double(count) / Double(events.count) * 100)
            let icon = getIconForSource(source)
            contentLines.append("\(icon) \(source.capitalized): \(count) (\(percentage)%)")
        }
        
        let timelineLabel = NSTextField(labelWithString: contentLines.joined(separator: "\n"))
        timelineLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        timelineLabel.textColor = NSColor.labelColor
        timelineLabel.backgroundColor = NSColor.clear
        timelineLabel.isBordered = false
        timelineLabel.isEditable = false
        timelineLabel.lineBreakMode = .byWordWrapping
        timelineLabel.maximumNumberOfLines = 0
        timelineLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(timelineLabel)
        
        NSLayoutConstraint.activate([
            timelineLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            timelineLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            timelineLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
    
    private func updateProfessionalInsightsCard() {
        guard let container = insightsCardContainer else { return }
        
        // Clear existing content
        container.subviews.forEach { $0.removeFromSuperview() }
        
        // Generate insights directly from events
        var insightLines: [String] = []
        let totalEvents = events.count
        let duration = getDurationFromEvents()
        
        if totalEvents > 0 && duration > 0 {
            let rate = Double(totalEvents) / duration
            if rate > 2.0 {
                insightLines.append("⚡ High Activity - Very interactive session")
            } else if rate < 0.5 {
                insightLines.append("😴 Low Activity - Minimal interactions")
            } else {
                insightLines.append("👍 Balanced - Good interaction rate")
            }
        }
        
        if duration > 0 {
            if duration > 300 {
                insightLines.append("⏳ Extended Session - Long duration")
            } else if duration < 30 {
                insightLines.append("⚡ Quick Session - Brief duration")
            }
        }
        
        if totalEvents > 50 {
            insightLines.append("📊 Data Rich - Many events captured")
        }
        
        if insightLines.isEmpty {
            insightLines.append("📝 Session recorded successfully")
        }
        
        let insightsLabel = NSTextField(labelWithString: insightLines.joined(separator: "\n"))
        insightsLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        insightsLabel.textColor = NSColor.systemTeal
        insightsLabel.backgroundColor = NSColor.clear
        insightsLabel.isBordered = false
        insightsLabel.isEditable = false
        insightsLabel.lineBreakMode = .byWordWrapping
        insightsLabel.maximumNumberOfLines = 0
        insightsLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(insightsLabel)
        
        NSLayoutConstraint.activate([
            insightsLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            insightsLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
    }
    
    // MARK: - Professional Card Helper Methods (16px+ text)
    
    private func createProfessionalMetricRow(_ icon: String, _ label: String, _ value: String, _ color: NSColor) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = NSTextField(labelWithString: icon)
        iconLabel.font = NSFont.systemFont(ofSize: 32)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconLabel)
        
        let titleLabel = NSTextField(labelWithString: label)
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = NSColor.secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        valueLabel.textColor = color
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            iconLabel.topAnchor.constraint(equalTo: container.topAnchor),
            iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 16),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 16),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createEventProgressRow(title: String, count: Int, percentage: Double) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let countLabel = NSTextField(labelWithString: "\(count)")
        countLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        countLabel.textColor = getColorForEventType(title)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(countLabel)
        
        let percentLabel = NSTextField(labelWithString: "(\(Int(percentage))%)")
        percentLabel.font = NSFont.systemFont(ofSize: 16)
        percentLabel.textColor = NSColor.secondaryLabelColor
        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(percentLabel)
        
        // Progress bar
        let progressBg = NSView()
        progressBg.wantsLayer = true
        progressBg.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        progressBg.layer?.cornerRadius = 4
        progressBg.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(progressBg)
        
        let progressFill = NSView()
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = getColorForEventType(title).cgColor
        progressFill.layer?.cornerRadius = 4
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressBg.addSubview(progressFill)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            countLabel.topAnchor.constraint(equalTo: container.topAnchor),
            countLabel.trailingAnchor.constraint(equalTo: percentLabel.leadingAnchor, constant: -8),
            
            percentLabel.topAnchor.constraint(equalTo: container.topAnchor),
            percentLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            progressBg.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            progressBg.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            progressBg.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            progressBg.heightAnchor.constraint(equalToConstant: 8),
            progressBg.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            progressFill.topAnchor.constraint(equalTo: progressBg.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBg.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBg.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBg.widthAnchor, multiplier: min(percentage / 100.0, 1.0))
        ])
        
        return container
    }
    
    private func createSourceRow(source: String, count: Int, percentage: Int) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = NSTextField(labelWithString: getIconForSource(source))
        iconLabel.font = NSFont.systemFont(ofSize: 16)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconLabel)
        
        let sourceLabel = NSTextField(labelWithString: source.capitalized)
        sourceLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        sourceLabel.textColor = NSColor.labelColor
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sourceLabel)
        
        let countLabel = NSTextField(labelWithString: "\(count) (\(percentage)%)")
        countLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        countLabel.textColor = getColorForSource(source)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(countLabel)
        
        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            sourceLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            sourceLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            countLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        return container
    }
    
    private func createInsightBadge(_ insight: Insight) -> NSView {
        let badgeView = NSView()
        badgeView.wantsLayer = true
        badgeView.layer?.backgroundColor = insight.color.withAlphaComponent(0.1).cgColor
        badgeView.layer?.cornerRadius = 12
        badgeView.layer?.borderWidth = 1
        badgeView.layer?.borderColor = insight.color.withAlphaComponent(0.3).cgColor
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = NSTextField(labelWithString: insight.icon)
        iconLabel.font = NSFont.systemFont(ofSize: 24)
        iconLabel.alignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeView.addSubview(iconLabel)
        
        let titleLabel = NSTextField(labelWithString: insight.title)
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = insight.color
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeView.addSubview(titleLabel)
        
        let descLabel = NSTextField(labelWithString: insight.description)
        descLabel.font = NSFont.systemFont(ofSize: 16)
        descLabel.textColor = NSColor.secondaryLabelColor
        descLabel.alignment = .center
        descLabel.maximumNumberOfLines = 2
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeView.addSubview(descLabel)
        
        NSLayoutConstraint.activate([
            iconLabel.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 16),
            iconLabel.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -12),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 12),
            descLabel.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -12),
            descLabel.bottomAnchor.constraint(equalTo: badgeView.bottomAnchor, constant: -16)
        ])
        
        return badgeView
    }
    
    // MARK: - Data Processing Methods
    
    private func getIconForSource(_ source: String) -> String {
        switch source.lowercased() {
        case "focus": return "👁️"
        case "system": return "⚙️"
        case "interaction": return "👆"
        case "recording": return "📹"
        default: return "📊"
        }
    }
    
    private func getColorForSource(_ source: String) -> NSColor {
        switch source.lowercased() {
        case "focus": return .systemBlue
        case "system": return .systemGray
        case "interaction": return .systemGreen
        case "recording": return .systemPurple
        default: return .systemOrange
        }
    }
    
    private func generateInsights() -> [Insight] {
        var insights: [Insight] = []
        
        // Activity level insight
        if sessionStats.totalEvents > 0 && sessionStats.duration > 0 {
            let rate = Double(sessionStats.totalEvents) / sessionStats.duration
            if rate > 2.0 {
                insights.append(Insight(
                    icon: "⚡",
                    title: "High Activity",
                    description: "Very interactive session",
                    color: .systemOrange
                ))
            } else if rate < 0.5 {
                insights.append(Insight(
                    icon: "😴",
                    title: "Low Activity", 
                    description: "Minimal interactions",
                    color: .systemBlue
                ))
            } else {
                insights.append(Insight(
                    icon: "👍",
                    title: "Balanced",
                    description: "Good interaction rate", 
                    color: .systemGreen
                ))
            }
        }
        
        // Most common event insight
        if let mostCommon = sessionStats.eventTypeCounts.max(by: { $0.value < $1.value }) {
            let percentage = Double(mostCommon.value) / Double(sessionStats.totalEvents) * 100
            if percentage > 60 {
                insights.append(Insight(
                    icon: "🎯",
                    title: "Focused",
                    description: "\(mostCommon.key) dominates",
                    color: .systemPurple
                ))
            }
        }
        
        // Duration insight
        if sessionStats.duration > 0 {
            if sessionStats.duration > 300 { // 5 minutes
                insights.append(Insight(
                    icon: "⏳",
                    title: "Extended",
                    description: "Long session",
                    color: .systemTeal
                ))
            } else if sessionStats.duration < 30 { // 30 seconds
                insights.append(Insight(
                    icon: "⚡",
                    title: "Brief",
                    description: "Quick session",
                    color: .systemYellow
                ))
            }
        }
        
        return insights
    }
    
    
    struct Insight {
        let icon: String
        let title: String
        let description: String
        let color: NSColor
    }
    
    private func updateSessionInfoCard(_ card: NSView) {
        print("🔄 Updating session info card with \(events.count) events")
        
        // Use sessionData directly as fallback if events loading failed
        let eventCount = events.isEmpty ? (sessionData["eventCount"] as? Int ?? 0) : events.count
        let status = eventCount == 0 ? "No Events" : "Active"
        
        // Update status
        if let statusRow = objc_getAssociatedObject(card, "statusRow") as? NSView,
           let valueField = objc_getAssociatedObject(statusRow, "valueField") as? NSTextField {
            valueField.stringValue = status
            valueField.textColor = eventCount == 0 ? .systemRed : .systemGreen
            print("✅ Updated status to: \(status)")
        } else {
            print("❌ Could not find status row or value field")
        }
        
        // Update events count
        if let eventsRow = objc_getAssociatedObject(card, "eventsRow") as? NSView,
           let valueField = objc_getAssociatedObject(eventsRow, "valueField") as? NSTextField {
            valueField.stringValue = "\(eventCount) events"
            print("✅ Updated events count to: \(eventCount)")
        } else {
            print("❌ Could not find events row or value field")
        }
        
        // Update duration - try sessionData first, then calculated stats
        if let durationRow = objc_getAssociatedObject(card, "durationRow") as? NSView,
           let valueField = objc_getAssociatedObject(durationRow, "valueField") as? NSTextField {
            
            var durationStr = "N/A"
            
            // Try duration from sessionData first
            if let duration = sessionData["duration"] as? Double, duration > 0 {
                durationStr = duration < 60 ? 
                    String(format: "%.1fs", duration) : 
                    String(format: "%.1fm", duration / 60)
            } else if sessionStats.duration > 0 {
                durationStr = sessionStats.duration < 60 ? 
                    String(format: "%.1fs", sessionStats.duration) : 
                    String(format: "%.1fm", sessionStats.duration / 60)
            }
            
            valueField.stringValue = durationStr
            print("✅ Updated duration to: \(durationStr)")
        } else {
            print("❌ Could not find duration row or value field")
        }
    }
    
    // Legacy method - replaced by professional cards
    private func updateStatisticsCard(_ card: NSView) {
        print("⚠️ Legacy updateStatisticsCard called - using professional cards instead")
    }
    
    // Legacy method - replaced by professional cards  
    private func updateEventBreakdownCard(_ card: NSView) {
        print("⚠️ Legacy updateEventBreakdownCard called - using professional cards instead")
    }
    
    private func createStatRow(_ label: String, _ value: String, color: NSColor) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        labelField.textColor = .secondaryLabelColor
        labelField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(labelField)
        
        let valueField = NSTextField(labelWithString: value)
        valueField.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        valueField.textColor = color
        valueField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueField)
        
        NSLayoutConstraint.activate([
            labelField.topAnchor.constraint(equalTo: container.topAnchor),
            labelField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            valueField.topAnchor.constraint(equalTo: labelField.bottomAnchor, constant: 2),
            valueField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            valueField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueField.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return container
    }
    
    private func createProgressRow(title: String, count: Int, percentage: Double, color: NSColor) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let countLabel = NSTextField(labelWithString: "\(count)")
        countLabel.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        countLabel.textColor = .secondaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(countLabel)
        
        // Progress bar background
        let progressBg = NSView()
        progressBg.wantsLayer = true
        progressBg.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        progressBg.layer?.cornerRadius = 2
        progressBg.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(progressBg)
        
        // Progress bar fill
        let progressFill = NSView()
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = color.cgColor
        progressFill.layer?.cornerRadius = 2
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressBg.addSubview(progressFill)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: countLabel.leadingAnchor, constant: -10),
            
            countLabel.topAnchor.constraint(equalTo: container.topAnchor),
            countLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            countLabel.widthAnchor.constraint(equalToConstant: 35),
            
            progressBg.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            progressBg.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            progressBg.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            progressBg.heightAnchor.constraint(equalToConstant: 6),
            progressBg.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            progressFill.topAnchor.constraint(equalTo: progressBg.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBg.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBg.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBg.widthAnchor, multiplier: min(percentage / 100.0, 1.0)),
            
            container.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        return container
    }
    
    private func getColorForEventType(_ type: String) -> NSColor {
        switch type.lowercased() {
        case let t where t.contains("focus"):
            return .systemBlue
        case let t where t.contains("interaction"):
            return .systemGreen
        case let t where t.contains("recording"):
            return .systemPurple
        case let t where t.contains("application"):
            return .systemOrange
        default:
            return .systemGray
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
                self.updateEventTable()
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
                self.updateEventTable()
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
                    self.updateEventTable()
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
                    self.updateEventTable()
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
                self.updateEventTable()
                self.updateTimeline()
            }
        }
    }
    
    private func updateEventTable() {
        eventTableView?.reloadData()
        updateEventCount()
    }
    
    private func updateEventCount() {
        guard let eventsTab = tabView.tabViewItems.first(where: { $0.label.contains("Events") }),
              let containerView = eventsTab.view,
              let toolbar = containerView.subviews.first,
              let eventCountLabel = objc_getAssociatedObject(toolbar, "eventCountLabel") as? NSTextField else { return }
        
        let count = events.count
        eventCountLabel.stringValue = "\(count) event\(count == 1 ? "" : "s")"
    }
    
    private func updateTimeline() {
        let eventsWithIndices = events.enumerated().map { (index, event) -> [String: Any] in
            var eventWithIndex = event
            eventWithIndex["_originalIndex"] = index
            return eventWithIndex
        }
        timelineView?.setEvents(eventsWithIndices)
    }
    
    private func formatTimestamp(_ timestamp: Double) -> String {
        let relativeSeconds = (timestamp - videoStartTimestamp) / 1_000_000.0
        let totalSeconds = Int(relativeSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let ms = Int((relativeSeconds - Double(totalSeconds)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, ms)
    }
    
    private func formatDuration(_ microseconds: Double) -> String {
        let totalSeconds = microseconds / 1_000_000.0
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        let tenths = Int((totalSeconds - Double(Int(totalSeconds))) * 10)
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%d", hours, minutes, seconds, tenths)
        } else if minutes > 0 {
            return String(format: "%d:%02d.%d", minutes, seconds, tenths)
        } else {
            return String(format: "%d.%d seconds", seconds, tenths)
        }
    }
    
    private func formatEventData(_ data: [String: Any]) -> String {
        if let appName = data["applicationName"] as? String {
            return "App: \(appName)"
        }
        
        if let interactionType = data["interactionType"] as? String {
            // For focus change events, show the focused element details
            if interactionType == "focus_change" {
                if let inputData = data["inputData"] as? [String: Any],
                   let focusedElement = inputData["focusedElement"] as? [String: Any] {
                    let label = focusedElement["label"] as? String ?? ""
                    let title = focusedElement["title"] as? String ?? ""
                    let roleDesc = focusedElement["roleDescription"] as? String ?? ""
                    let role = (focusedElement["role"] as? String ?? "").replacingOccurrences(of: "AX", with: "")
                    let displayName = !label.isEmpty ? label : (!title.isEmpty ? title : roleDesc)
                    if !displayName.isEmpty {
                        return "Focus → \(displayName) [\(role)]"
                    }
                    return "Focus → [\(role)]"
                }
                return "Focus → (unknown)"
            }
            
            // For key events, show the key pressed
            if interactionType == "key" {
                if let inputData = data["inputData"] as? [String: Any],
                   let key = inputData["key"] as? String {
                    let modifiers = inputData["modifiers"] as? [String] ?? []
                    if modifiers.isEmpty {
                        return "Key: \(key)"
                    } else {
                        return "Key: \(modifiers.joined(separator: "+"))+\(key)"
                    }
                }
                return "key"
            }
            
            // For clicks and other interactions, show element info if available
            var elementInfo = ""
            if let target = data["target"] as? [String: Any],
               let element = target["element"] as? [String: Any] {
                let title = element["title"] as? String ?? ""
                let label = element["label"] as? String ?? ""
                elementInfo = !title.isEmpty ? title : label
            }
            if elementInfo.isEmpty, let inputData = data["inputData"] as? [String: Any] {
                let elementTitle = inputData["elementTitle"] as? String ?? ""
                let elementLabel = inputData["elementLabel"] as? String ?? ""
                elementInfo = !elementTitle.isEmpty ? elementTitle : elementLabel
            }
            
            // Return element info if we have it (before checking coordinates)
            if !elementInfo.isEmpty {
                return "\(interactionType): \(elementInfo)"
            }
            
            // Fall back to coordinates if no element info
            if let coords = data["coordinates"] as? [String: Any] {
                let x = (coords["x"] as? Double) ?? Double(coords["x"] as? String ?? "") ?? 0
                let y = (coords["y"] as? Double) ?? Double(coords["y"] as? String ?? "") ?? 0
                if x != 0 || y != 0 {
                    return "\(interactionType) at (\(Int(x)),\(Int(y)))"
                }
            }
            
            return interactionType
        }
        
        // Element focus changed events
        if let role = data["role"] as? String {
            let title = data["title"] as? String ?? ""
            let desc = data["description"] as? String ?? ""
            let elementName = !title.isEmpty ? title : (!desc.isEmpty ? desc : role)
            return "Focus: \(elementName)"
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
    
    // MARK: - Helper Methods
    
    private func createCard(title: String) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = 8
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20)
        ])
        
        return card
    }
    
    private func createInfoRow(_ label: String, _ value: String, isMonospace: Bool = false) -> NSView {
        let container = NSView()
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        labelField.textColor = .secondaryLabelColor
        labelField.translatesAutoresizingMaskIntoConstraints = false
        
        let valueField = NSTextField(labelWithString: value)
        valueField.font = isMonospace ? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular) : NSFont.systemFont(ofSize: 16)
        valueField.textColor = .labelColor
        valueField.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(labelField)
        container.addSubview(valueField)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 18),
            
            labelField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelField.widthAnchor.constraint(equalToConstant: 100),
            
            valueField.leadingAnchor.constraint(equalTo: labelField.trailingAnchor, constant: 10),
            valueField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueField.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        return container
    }
    
    private func setupEventTableColumns() {
        // Timestamp column
        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("timestamp"))
        timeColumn.title = "Time"
        timeColumn.width = 100
        eventTableView.addTableColumn(timeColumn)
        
        // Source column
        let sourceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("source"))
        sourceColumn.title = "Source"
        sourceColumn.width = 80
        eventTableView.addTableColumn(sourceColumn)
        
        // Event type column
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Event Type"
        typeColumn.width = 150
        eventTableView.addTableColumn(typeColumn)
        
        // Details column
        let detailsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("details"))
        detailsColumn.title = "Details"
        detailsColumn.width = 300
        eventTableView.addTableColumn(detailsColumn)
    }
    
    private func calculateSessionStats() {
        print("🔄 Calculating session stats for \(events.count) events")
        
        sessionStats = SessionStats()
        sessionStats.totalEvents = events.count
        
        var eventTypeCounts: [String: Int] = [:]
        var sourceTypeCounts: [String: Int] = [:]
        var timestamps: [Double] = []
        
        for (index, event) in events.enumerated() {
            // Debug first few events
            if index < 3 {
                print("🔍 Event \(index): \(event)")
            }
            
            if let type = event["type"] as? String {
                eventTypeCounts[type, default: 0] += 1
            } else {
                print("⚠️ Event \(index) missing 'type' field")
            }
            
            if let source = event["source"] as? String {
                sourceTypeCounts[source, default: 0] += 1
            } else {
                print("⚠️ Event \(index) missing 'source' field")
            }
            
            if let timestamp = event["timestamp"] as? Double {
                timestamps.append(timestamp)
            }
        }
        
        sessionStats.eventTypeCounts = eventTypeCounts
        sessionStats.sourceTypeCounts = sourceTypeCounts
        
        print("📊 Final event type counts: \(eventTypeCounts)")
        print("📊 Final source type counts: \(sourceTypeCounts)")
        
        // Calculate duration from timestamps
        if !timestamps.isEmpty {
            let sortedTimestamps = timestamps.sorted()
            let startTime = sortedTimestamps.first!
            let endTime = sortedTimestamps.last!
            sessionStats.duration = (endTime - startTime) / 1_000_000 // Convert microseconds to seconds
            print("📊 Calculated duration: \(sessionStats.duration) seconds")
        } else if let firstEvent = events.first, let lastEvent = events.last,
                  let startTime = firstEvent["timestamp"] as? Double,
                  let endTime = lastEvent["timestamp"] as? Double {
            sessionStats.duration = (endTime - startTime) / 1_000_000 // Convert to seconds
            print("📊 Fallback duration calculation: \(sessionStats.duration) seconds")
        }
        
        print("✅ Session stats calculation complete")
    }
    
    private func updateStatsView() {
        guard let statsCard = statsContainer else { return }
        
        // Clear existing content
        statsCard.subviews.forEach { $0.removeFromSuperview() }
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Session Statistics")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        statsCard.addSubview(titleLabel)
        
        // Stats stack
        let statsStack = NSStackView()
        statsStack.orientation = .vertical
        statsStack.alignment = .leading
        statsStack.spacing = 6
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        statsCard.addSubview(statsStack)
        
        // Add stats
        statsStack.addArrangedSubview(createInfoRow("Total Events:", "\(sessionStats.totalEvents)"))
        
        if sessionStats.duration > 0 {
            let durationStr = sessionStats.duration < 60 ? String(format: "%.1fs", sessionStats.duration) : String(format: "%.1fm", sessionStats.duration / 60)
            statsStack.addArrangedSubview(createInfoRow("Duration:", durationStr))
        }
        
        // Top event types
        if !sessionStats.eventTypeCounts.isEmpty {
            let sortedTypes = sessionStats.eventTypeCounts.sorted { $0.value > $1.value }.prefix(3)
            for (type, count) in sortedTypes {
                statsStack.addArrangedSubview(createInfoRow("\(type.capitalized):", "\(count)"))
            }
        }
        
        // Layout
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: statsCard.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: 20),
            
            statsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            statsStack.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: 20),
            statsStack.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: -20)
        ])
    }
    
    private func updateUIWithMetadata() {
        // Update session name if available
        if let customName = sessionMetadata["customName"] as? String, !customName.isEmpty {
            // Update window title or session name field if needed
        }
    }
    
    private func updateNotesFromMetadata() {
        if let notes = sessionMetadata["notes"] as? String {
            sessionNotesView?.string = notes
        }
    }
    
    private func updateTagsFromMetadata() {
        if let tags = sessionMetadata["tags"] as? [String] {
            sessionTagsField?.stringValue = tags.joined(separator: ", ")
        }
    }
    
    // MARK: - Action Methods
    
    @objc private func exportSession() {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(sessionId)_export.json"
        savePanel.allowedContentTypes = [.json]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let exportData: [String: Any] = [
                    "sessionId": sessionId,
                    "sessionData": sessionData,
                    "events": events,
                    "metadata": sessionMetadata,
                    "stats": [
                        "totalEvents": sessionStats.totalEvents,
                        "duration": sessionStats.duration,
                        "eventTypeCounts": sessionStats.eventTypeCounts,
                        "sourceTypeCounts": sessionStats.sourceTypeCounts
                    ]
                ]
                
                let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
                try jsonData.write(to: url)
            } catch {
                print("Failed to export session: \(error)")
            }
        }
    }
    
    @objc private func shareSession() {
        // Implement session sharing functionality
        print("Share session: \(sessionId)")
    }
    
    @objc private func addSessionTag() {
        guard let newTags = sessionTagsField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
              !newTags.isEmpty else { return }
        
        let tags = newTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Save to metadata
        sessionMetadata["tags"] = tags
        saveSessionMetadata()
        
        // Clear field
        sessionTagsField?.stringValue = ""
    }
    
    @objc private func filterEvents(_ sender: NSSearchField) {
        // Implement event filtering
        updateEventTable()
    }
    
    @objc private func filterByEventType(_ sender: NSPopUpButton) {
        // Implement filtering by event type
        updateEventTable()
    }
    
    @objc private func exportEventLog() {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(sessionId)_events.csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            var csvContent = "Timestamp,Source,Type,Details\n"
            
            for event in events {
                let timestamp = event["timestamp"] as? Double ?? 0
                let source = event["source"] as? String ?? ""
                let type = event["type"] as? String ?? ""
                let details = formatEventData(event["data"] as? [String: Any] ?? [:])
                
                csvContent += "\(timestamp),\(source),\(type),\"\(details)\"\n"
            }
            
            do {
                try csvContent.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to export events: \(error)")
            }
        }
    }
    
    @objc private func zoomTimelineIn() {
        timelineView?.zoomIn()
        if let currentZoom = timelineView?.currentZoom {
            timelineZoomSlider?.doubleValue = Double(currentZoom)
        }
    }
    
    @objc private func zoomTimelineOut() {
        timelineView?.zoomOut()
        if let currentZoom = timelineView?.currentZoom {
            timelineZoomSlider?.doubleValue = Double(currentZoom)
        }
    }
    
    @objc private func resetTimelineZoom() {
        timelineView?.resetZoom()
        timelineZoomSlider?.doubleValue = 1.0
    }
    
    private func saveSessionMetadata() {
        let metadataPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/metadata.json"
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sessionMetadata, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: metadataPath))
        } catch {
            print("Failed to save metadata: \(error)")
        }
    }
}

// MARK: - SessionStats
struct SessionStats {
    var totalEvents: Int = 0
    var duration: Double = 0
    var eventTypeCounts: [String: Int] = [:]
    var sourceTypeCounts: [String: Int] = [:]
}

// MARK: - Table View Data Source & Delegate
extension SessionDetailViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredEvents.isEmpty && events.isEmpty ? 0 : (filteredEvents.isEmpty ? events.count : filteredEvents.count)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let sourceEvents = filteredEvents.isEmpty ? events : filteredEvents
        guard row < sourceEvents.count else { return nil }
        
        let event = sourceEvents[row]
        let cellView = NSTableCellView()
        
        let textField = NSTextField()
        textField.isBordered = false
        textField.isEditable = false
        textField.backgroundColor = .clear
        textField.font = NSFont.systemFont(ofSize: 16)
        textField.lineBreakMode = .byTruncatingTail
        
        switch tableColumn?.identifier.rawValue {
        case "index":
            textField.stringValue = "\(row + 1)"
            textField.alignment = .left
            
        case "time", "timestamp":
            if let timestamp = event["timestamp"] as? Double {
                textField.stringValue = formatTimestamp(timestamp)
                textField.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            }
            
        case "source":
            let source = event["source"] as? String ?? "unknown"
            let eventType = event["type"] as? String ?? ""
            textField.stringValue = source.capitalized
            
            switch source {
            case "interaction":
                textField.textColor = .systemBlue
            case "focus":
                textField.textColor = .systemOrange
            case "system":
                textField.textColor = .systemGray
            case "editor":
                if eventType == "marker" {
                    textField.textColor = .systemRed
                    textField.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
                } else {
                    textField.textColor = .systemPurple
                }
            default:
                textField.textColor = .labelColor
            }
            
        case "type":
            let eventType = event["type"] as? String ?? "unknown"
            textField.stringValue = eventType
            if eventType == "marker" {
                textField.textColor = .systemRed
                textField.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
            }
            
        case "tagsnotes":
            let originalIndex = getOriginalEventIndex(for: row)
            return createTagsNotesCellView(for: originalIndex, row: row)
            
        case "details":
            let eventType = event["type"] as? String ?? ""
            if eventType == "marker" {
                let markerName = event["markerName"] as? String ?? ""
                textField.stringValue = markerName
                textField.textColor = .systemRed
                textField.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
            } else {
                textField.stringValue = formatEventData(event["data"] as? [String: Any] ?? [:])
                textField.textColor = .secondaryLabelColor
            }
            
        default:
            textField.stringValue = ""
        }
        
        cellView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 28
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let selectedRow = tableView.selectedRow
        let sourceEvents = filteredEvents.isEmpty ? events : filteredEvents
        if selectedRow >= 0 && selectedRow < sourceEvents.count {
            let event = sourceEvents[selectedRow]
            updateTimelineInfo(with: event)
            updateEventsDetailPanel(with: event, index: selectedRow)
        } else {
            clearEventsDetailPanel()
        }
    }
    
    private func clearEventsDetailPanel() {
        guard let stackView = eventsDetailStackView else { return }
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let placeholderLabel = NSTextField(labelWithString: "Select an event to view details")
        placeholderLabel.font = NSFont.systemFont(ofSize: 16)
        placeholderLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(placeholderLabel)
    }
    
    private func updateEventsDetailPanel(with event: [String: Any], index: Int) {
        guard let stackView = eventsDetailStackView else { return }
        
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let eventType = event["type"] as? String ?? "unknown"
        let isMarkerEvent = eventType.lowercased() == "marker"
        let isPauseEvent = eventType == "recording_paused"
        let isResumeEvent = eventType == "recording_resumed"
        
        if isPauseEvent || isResumeEvent {
            let icon = isPauseEvent ? "⏸" : "▶️"
            let title = isPauseEvent ? "Recording Paused" : "Recording Resumed"
            let (pauseCard, pauseContent) = createDetailCard(title: title, icon: icon)
            
            if let timestamp = event["timestamp"] as? Double {
                pauseContent.addArrangedSubview(createDetailRow(label: "Time", value: formatTimestamp(timestamp), valueColor: .systemBlue))
            }
            
            if let data = event["data"] as? [String: Any] {
                if isPauseEvent {
                    if let reason = data["reason"] as? String {
                        pauseContent.addArrangedSubview(createDetailRow(label: "Reason", value: reason.replacingOccurrences(of: "_", with: " ").capitalized))
                    }
                } else {
                    if let pauseDuration = data["pauseDuration"] as? Double {
                        pauseContent.addArrangedSubview(createDetailRow(label: "Pause Duration", value: formatDuration(pauseDuration), valueColor: .systemYellow))
                    }
                    
                    if let totalPaused = data["totalPausedDuration"] as? Double {
                        pauseContent.addArrangedSubview(createDetailRow(label: "Total Paused", value: formatDuration(totalPaused), valueColor: .secondaryLabelColor))
                    }
                }
            }
            
            stackView.addArrangedSubview(pauseCard)
            pauseCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        } else if isMarkerEvent {
            let (markerCard, markerContent) = createDetailCard(title: "Marker", icon: "🚩")
            
            if let markerName = event["markerName"] as? String, !markerName.isEmpty {
                markerContent.addArrangedSubview(createDetailRow(label: "Name", value: markerName, valueColor: .systemOrange))
            }
            
            if let timestamp = event["timestamp"] as? Double {
                markerContent.addArrangedSubview(createDetailRow(label: "Time", value: formatTimestamp(timestamp)))
            }
            
            if let noteBase64 = event["markerNote"] as? String,
               let noteData = Data(base64Encoded: noteBase64),
               let noteString = extractPlainTextFromRTF(noteData) {
                let noteLabel = NSTextField(labelWithString: "Note:")
                noteLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
                noteLabel.textColor = .secondaryLabelColor
                markerContent.addArrangedSubview(noteLabel)
                
                let noteValue = NSTextField(wrappingLabelWithString: noteString)
                noteValue.font = NSFont.systemFont(ofSize: 16)
                noteValue.textColor = .labelColor
                markerContent.addArrangedSubview(noteValue)
            }
            
            stackView.addArrangedSubview(markerCard)
            markerCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        } else {
            let (headerCard, headerContent) = createDetailCard(title: "Event #\(index + 1)", icon: "📋")
            
            if let timestamp = event["timestamp"] as? Double {
                headerContent.addArrangedSubview(createDetailRow(label: "Time", value: formatTimestamp(timestamp), valueColor: .systemBlue))
            }
            
            if let source = event["source"] as? String {
                let sourceColor: NSColor = source.lowercased() == "interaction" ? .systemGreen : .systemPurple
                headerContent.addArrangedSubview(createDetailRow(label: "Source", value: source.uppercased(), valueColor: sourceColor))
            }
            
            let displayType = eventType.replacingOccurrences(of: "_", with: " ").capitalized
            headerContent.addArrangedSubview(createDetailRow(label: "Type", value: displayType))
            
            let originalIndex = findEventIndex(byTimestamp: event["timestamp"] as? Double ?? 0)
            if originalIndex >= 0 {
                let tags = eventTags[originalIndex] ?? Set<String>()
                if !tags.isEmpty {
                    let tagsRow = NSStackView()
                    tagsRow.orientation = .horizontal
                    tagsRow.spacing = 6
                    tagsRow.alignment = .centerY
                    
                    let tagsLabel = NSTextField(labelWithString: "Tags:")
                    tagsLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
                    tagsLabel.textColor = .secondaryLabelColor
                    tagsRow.addArrangedSubview(tagsLabel)
                    
                    for tag in tags.sorted() {
                        tagsRow.addArrangedSubview(createTagPill(text: tag, color: .systemTeal))
                    }
                    headerContent.addArrangedSubview(tagsRow)
                }
            }
            
            stackView.addArrangedSubview(headerCard)
            headerCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            
            if let data = event["data"] as? [String: Any] {
                buildFocusEventCards(data, into: stackView)
            }
        }
        
        eventsDetailPanel?.documentView?.scroll(.zero)
    }
    
    private func buildFocusEventCards(_ data: [String: Any], into stackView: NSStackView) {
        let inputData = data["inputData"] as? [String: Any]
        let browserElement = inputData?["browserElement"] as? [String: Any]
        let focusedElement = inputData?["focusedElement"] as? [String: Any]
        let interactionType = data["interactionType"] as? String ?? ""
        let isFocusChange = interactionType == "focus_change"
        let isMouseEvent = ["click", "mouse_down", "mouse_up", "hover", "hover_end"].contains(interactionType)
        
        if browserElement != nil {
            let (elementCard, elementContent) = createDetailCard(title: "Browser Element", icon: "🌐")
            
            if isFocusChange {
                let trigger = inputData?["trigger"] as? String ?? "unknown"
                let key = inputData?["key"] as? String
                let modifiers = inputData?["modifiers"] as? [String] ?? []
                
                if let key = key {
                    let modStr = modifiers.isEmpty ? "" : "\(modifiers.joined(separator: "+"))+"
                    elementContent.addArrangedSubview(createDetailRow(label: "Trigger", value: "\(trigger) (\(modStr)\(key))", valueColor: .systemOrange))
                } else {
                    elementContent.addArrangedSubview(createDetailRow(label: "Trigger", value: trigger))
                }
            } else if isMouseEvent {
                let button = inputData?["button"] as? Int ?? 0
                let clickCount = inputData?["clickCount"] as? Int ?? 1
                let buttonName = button == 0 ? "Left" : button == 1 ? "Right" : "Middle"
                elementContent.addArrangedSubview(createDetailRow(label: "Button", value: "\(buttonName) (\(clickCount)x)", valueColor: .systemOrange))
            }
            
            if let browser = browserElement {
                let tagName = browser["tagName"] as? String ?? ""
                let role = browser["role"] as? String ?? focusedElement?["role"] as? String ?? ""
                let cleanRole = role.replacingOccurrences(of: "AX", with: "")
                elementContent.addArrangedSubview(createDetailRow(label: "Element", value: "<\(tagName.lowercased())> [\(cleanRole)]", monospace: true))
                
                if let id = browser["id"] as? String, !id.isEmpty {
                    elementContent.addArrangedSubview(createDetailRow(label: "ID", value: "#\(id)", valueColor: .systemBlue, monospace: true))
                }
                if let className = browser["className"] as? String, !className.isEmpty {
                    elementContent.addArrangedSubview(createDetailRow(label: "Class", value: ".\(className.replacingOccurrences(of: " ", with: " ."))", valueColor: .systemGreen, monospace: true))
                }
                if let xpath = browser["xpath"] as? String, !xpath.isEmpty {
                    elementContent.addArrangedSubview(createDetailRow(label: "XPath", value: xpath, monospace: true))
                }
                if let ariaLabel = browser["ariaLabel"] as? String, !ariaLabel.isEmpty {
                    elementContent.addArrangedSubview(createDetailRow(label: "ARIA Label", value: ariaLabel))
                }
                if let textContent = browser["textContent"] as? String, !textContent.isEmpty {
                    let truncated = textContent.count > 80 ? String(textContent.prefix(80)) + "..." : textContent
                    elementContent.addArrangedSubview(createDetailRow(label: "Text", value: truncated))
                }
                if let href = browser["href"] as? String, !href.isEmpty {
                    elementContent.addArrangedSubview(createDetailRow(label: "Link", value: href, valueColor: .linkColor, monospace: true))
                }
                
                if let bounds = browser["bounds"] as? [String: Any] {
                    let x = bounds["screenX"] as? Int ?? bounds["x"] as? Int ?? 0
                    let y = bounds["screenY"] as? Int ?? bounds["y"] as? Int ?? 0
                    let w = bounds["width"] as? Int ?? 0
                    let h = bounds["height"] as? Int ?? 0
                    elementContent.addArrangedSubview(createDetailRow(label: "Position", value: "(\(x), \(y))  \(w) × \(h)", monospace: true))
                }
                
                stackView.addArrangedSubview(elementCard)
                elementCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
                
                if let pageTitle = browser["pageTitle"] as? String, !pageTitle.isEmpty,
                   let parentURL = browser["parentURL"] as? String {
                    let (pageCard, pageContent) = createDetailCard(title: "Page", icon: "🌐")
                    pageContent.addArrangedSubview(createDetailRow(label: "Title", value: pageTitle))
                    pageContent.addArrangedSubview(createDetailRow(label: "URL", value: parentURL, valueColor: .linkColor, monospace: true))
                    stackView.addArrangedSubview(pageCard)
                    pageCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
                }
                
                if let browserCtx = inputData?["browserContext"] as? [String: Any] {
                    let (ctxCard, ctxContent) = createDetailCard(title: "Browser Context", icon: "🖥️")
                    if let name = browserCtx["name"] as? String, !name.isEmpty {
                        ctxContent.addArrangedSubview(createDetailRow(label: "Browser", value: name, valueColor: .systemPurple))
                    }
                    if let windowId = browserCtx["windowId"] as? Int {
                        ctxContent.addArrangedSubview(createDetailRow(label: "Window", value: "\(windowId)", monospace: true))
                    }
                    if let tabIndex = browserCtx["tabIndex"] as? Int {
                        ctxContent.addArrangedSubview(createDetailRow(label: "Tab", value: "\(tabIndex)", monospace: true))
                    }
                    if let tabTitle = browserCtx["tabTitle"] as? String, !tabTitle.isEmpty {
                        ctxContent.addArrangedSubview(createDetailRow(label: "Tab Title", value: tabTitle))
                    }
                    if let incognito = browserCtx["incognito"] as? Bool, incognito {
                        ctxContent.addArrangedSubview(createDetailRow(label: "Private", value: "Yes", valueColor: .systemOrange))
                    }
                    stackView.addArrangedSubview(ctxCard)
                    ctxCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
                }
                
                if let allAttrs = browser["allAttributes"] as? [String: Any], !allAttrs.isEmpty {
                    let keyAttrs = ["tabindex", "aria-label", "aria-labelledby", "aria-describedby", "role"]
                    let keyAttrValues = keyAttrs.compactMap { key -> (String, String)? in
                        guard let val = allAttrs[key] as? String, !val.isEmpty else { return nil }
                        return (key, val)
                    }
                    if !keyAttrValues.isEmpty {
                        let (keyAttrsCard, keyAttrsContent) = createDetailCard(title: "Key Attributes", icon: "♿")
                        for (key, val) in keyAttrValues {
                            keyAttrsContent.addArrangedSubview(createDetailRow(label: key, value: val, monospace: true))
                        }
                        stackView.addArrangedSubview(keyAttrsCard)
                        keyAttrsCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
                    }
                    
                    let skipKeys = Set(["id", "class", "role", "tabindex", "aria-label", "aria-labelledby", "aria-describedby"])
                    let filteredAttrs = allAttrs.filter { !skipKeys.contains($0.key.lowercased()) && ($0.value as? String)?.isEmpty == false }
                    if !filteredAttrs.isEmpty {
                        let (attrsCard, attrsContent) = createDetailCard(title: "Other Attributes", icon: "📝")
                        for (key, value) in filteredAttrs.sorted(by: { $0.key < $1.key }) {
                            if let strVal = value as? String, !strVal.isEmpty {
                                attrsContent.addArrangedSubview(createDetailRow(label: key, value: strVal, monospace: true))
                            }
                        }
                        stackView.addArrangedSubview(attrsCard)
                        attrsCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
                    }
                }
                
                if let styles = browser["computedStyles"] as? [String: Any], !styles.isEmpty {
                    let keyStyles = ["display", "color", "backgroundColor", "fontSize", "fontWeight",
                                     "border", "outline", "cursor", "opacity", "position", "zIndex"]
                    let filteredStyles = keyStyles.compactMap { key -> (String, String)? in
                        guard let val = styles[key] as? String, !val.isEmpty, val != "none", val != "normal", val != "auto" else { return nil }
                        return (key, val)
                    }
                    if !filteredStyles.isEmpty {
                        let (stylesCard, stylesContent) = createDetailCard(title: "Key Styles", icon: "🎨")
                        for (key, val) in filteredStyles {
                            stylesContent.addArrangedSubview(createDetailRow(label: key, value: val, monospace: true))
                        }
                        stackView.addArrangedSubview(stylesCard)
                        stylesCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
                    }
                }
            }
            return
        } else if isFocusChange, let native = focusedElement {
            let (elementCard, elementContent) = createDetailCard(title: "Native Element", icon: "🎯")
            
            let trigger = inputData?["trigger"] as? String ?? "unknown"
            let key = inputData?["key"] as? String
            let modifiers = inputData?["modifiers"] as? [String] ?? []
            
            if let key = key {
                let modStr = modifiers.isEmpty ? "" : "\(modifiers.joined(separator: "+"))+"
                elementContent.addArrangedSubview(createDetailRow(label: "Trigger", value: "\(trigger) (\(modStr)\(key))", valueColor: .systemOrange))
            } else {
                elementContent.addArrangedSubview(createDetailRow(label: "Trigger", value: trigger))
            }
            
            let role = native["role"] as? String ?? ""
            let cleanRole = role.replacingOccurrences(of: "AX", with: "")
            let label = native["label"] as? String ?? native["title"] as? String ?? ""
            elementContent.addArrangedSubview(createDetailRow(label: "Element", value: label.isEmpty ? "(no label)" : label))
            elementContent.addArrangedSubview(createDetailRow(label: "Role", value: cleanRole, valueColor: .systemPurple))
            
            if let domId = native["domId"] as? String, !domId.isEmpty {
                elementContent.addArrangedSubview(createDetailRow(label: "ID", value: "#\(domId)", valueColor: .systemBlue, monospace: true))
            }
            if let domClassList = native["domClassList"] as? String, !domClassList.isEmpty {
                elementContent.addArrangedSubview(createDetailRow(label: "Class", value: ".\(domClassList.replacingOccurrences(of: " ", with: " ."))", valueColor: .systemGreen, monospace: true))
            }
            if let roleDesc = native["roleDescription"] as? String, !roleDesc.isEmpty {
                elementContent.addArrangedSubview(createDetailRow(label: "Role Description", value: roleDesc))
            }
            
            if let bounds = native["bounds"] as? [String: Any] {
                let x = bounds["x"] as? Int ?? 0
                let y = bounds["y"] as? Int ?? 0
                let w = bounds["width"] as? Int ?? 0
                let h = bounds["height"] as? Int ?? 0
                elementContent.addArrangedSubview(createDetailRow(label: "Position", value: "(\(x), \(y))  \(w) × \(h)", monospace: true))
            }
            
            stackView.addArrangedSubview(elementCard)
            elementCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            
            if let docTitle = native["documentTitle"] as? String, !docTitle.isEmpty {
                let (pageCard, pageContent) = createDetailCard(title: "Page", icon: "🌐")
                pageContent.addArrangedSubview(createDetailRow(label: "Title", value: docTitle))
                if let docURL = native["documentURL"] as? String, !docURL.isEmpty {
                    pageContent.addArrangedSubview(createDetailRow(label: "URL", value: docURL, valueColor: .linkColor, monospace: true))
                }
                if let appName = native["applicationName"] as? String, !appName.isEmpty {
                    pageContent.addArrangedSubview(createDetailRow(label: "App", value: appName))
                }
                stackView.addArrangedSubview(pageCard)
                pageCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            }
            return
        }
        
        let (dataCard, dataContent) = createDetailCard(title: "Data", icon: "📊")
        buildGenericDataRows(data, into: dataContent, skipKeys: ["browserElement", "focusedElement"])
        stackView.addArrangedSubview(dataCard)
        dataCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }
    
    private func buildGenericDataRows(_ data: [String: Any], into stack: NSStackView, skipKeys: Set<String> = [], indent: Int = 0) {
        let sortedKeys = data.keys.sorted()
        
        for key in sortedKeys {
            if skipKeys.contains(key) { continue }
            
            let value = data[key]
            let displayKey = key.replacingOccurrences(of: "_", with: " ").capitalized
            
            if let dictValue = value as? [String: Any] {
                if key == "inputData" {
                    buildGenericDataRows(dictValue, into: stack, skipKeys: skipKeys, indent: indent)
                } else {
                    let sectionLabel = NSTextField(labelWithString: displayKey)
                    sectionLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
                    sectionLabel.textColor = .secondaryLabelColor
                    stack.addArrangedSubview(sectionLabel)
                    buildGenericDataRows(dictValue, into: stack, indent: indent + 1)
                }
            } else if let arrayValue = value as? [[String: Any]] {
                stack.addArrangedSubview(createDetailRow(label: displayKey, value: "[\(arrayValue.count) items]"))
            } else if let stringArray = value as? [String], !stringArray.isEmpty {
                stack.addArrangedSubview(createDetailRow(label: displayKey, value: stringArray.joined(separator: ", ")))
            } else if let stringValue = value as? String, !stringValue.isEmpty {
                let truncated = stringValue.count > 100 ? String(stringValue.prefix(100)) + "..." : stringValue
                stack.addArrangedSubview(createDetailRow(label: displayKey, value: truncated))
            } else if let numberValue = value as? NSNumber {
                if CFGetTypeID(numberValue) == CFBooleanGetTypeID() {
                    stack.addArrangedSubview(createDetailRow(label: displayKey, value: numberValue.boolValue ? "Yes" : "No", valueColor: numberValue.boolValue ? .systemGreen : .systemRed))
                } else {
                    stack.addArrangedSubview(createDetailRow(label: displayKey, value: "\(numberValue)"))
                }
            }
        }
    }
    
    private func formatFocusEventData(_ data: [String: Any]) -> String {
        var result = ""
        let inputData = data["inputData"] as? [String: Any]
        let browserElement = inputData?["browserElement"] as? [String: Any]
        let focusedElement = inputData?["focusedElement"] as? [String: Any]
        let isFocusChange = (data["interactionType"] as? String) == "focus_change"
        
        if isFocusChange && (browserElement != nil || focusedElement != nil) {
            result += "\n───────────────────────────────\n"
            result += "ELEMENT\n"
            result += "───────────────────────────────\n"
            
            let trigger = inputData?["trigger"] as? String ?? "unknown"
            let key = inputData?["key"] as? String
            let modifiers = inputData?["modifiers"] as? [String] ?? []
            
            if let key = key {
                let modStr = modifiers.isEmpty ? "" : "\(modifiers.joined(separator: "+"))+"
                result += "Trigger: \(trigger) (\(modStr)\(key))\n"
            } else {
                result += "Trigger: \(trigger)\n"
            }
            
            if let browser = browserElement {
                let tagName = browser["tagName"] as? String ?? ""
                let role = browser["role"] as? String ?? focusedElement?["role"] as? String ?? ""
                let cleanRole = role.replacingOccurrences(of: "AX", with: "")
                result += "Element: <\(tagName.lowercased())> [\(cleanRole)]\n"
                
                if let id = browser["id"] as? String, !id.isEmpty {
                    result += "ID: \(id)\n"
                }
                if let className = browser["className"] as? String, !className.isEmpty {
                    result += "Class: \(className)\n"
                }
                if let xpath = browser["xpath"] as? String, !xpath.isEmpty {
                    result += "XPath: \(xpath)\n"
                }
                if let ariaLabel = browser["ariaLabel"] as? String, !ariaLabel.isEmpty {
                    result += "ARIA Label: \(ariaLabel)\n"
                }
                if let textContent = browser["textContent"] as? String, !textContent.isEmpty {
                    let truncated = textContent.count > 80 ? String(textContent.prefix(80)) + "..." : textContent
                    result += "Text: \(truncated)\n"
                }
                if let href = browser["href"] as? String, !href.isEmpty {
                    result += "Link: \(href)\n"
                }
                
                if let pageTitle = browser["pageTitle"] as? String, !pageTitle.isEmpty {
                    result += "\n───────────────────────────────\n"
                    result += "PAGE\n"
                    result += "───────────────────────────────\n"
                    result += "Title: \(pageTitle)\n"
                }
                if let parentURL = browser["parentURL"] as? String, !parentURL.isEmpty {
                    result += "URL: \(parentURL)\n"
                }
                
                if let bounds = browser["bounds"] as? [String: Any] {
                    let x = bounds["screenX"] as? Int ?? bounds["x"] as? Int ?? 0
                    let y = bounds["screenY"] as? Int ?? bounds["y"] as? Int ?? 0
                    let w = bounds["width"] as? Int ?? 0
                    let h = bounds["height"] as? Int ?? 0
                    result += "Position: (\(x), \(y)) Size: \(w)×\(h)\n"
                }
                
                if let allAttrs = browser["allAttributes"] as? [String: Any], !allAttrs.isEmpty {
                    let keyAttrs = ["tabindex", "aria-label", "aria-labelledby", "aria-describedby", "role"]
                    let keyAttrValues = keyAttrs.compactMap { key -> (String, String)? in
                        guard let val = allAttrs[key] as? String, !val.isEmpty else { return nil }
                        return (key, val)
                    }
                    if !keyAttrValues.isEmpty {
                        result += "\n───────────────────────────────\n"
                        result += "KEY ATTRIBUTES\n"
                        result += "───────────────────────────────\n"
                        for (key, val) in keyAttrValues {
                            result += "\(key): \(val)\n"
                        }
                    }
                    
                    let skipKeys = Set(["id", "class", "role", "tabindex", "aria-label", "aria-labelledby", "aria-describedby"])
                    let otherAttrs = allAttrs.filter { !skipKeys.contains($0.key.lowercased()) && ($0.value as? String)?.isEmpty == false }
                    if !otherAttrs.isEmpty {
                        result += "\n───────────────────────────────\n"
                        result += "OTHER ATTRIBUTES\n"
                        result += "───────────────────────────────\n"
                        for (key, value) in otherAttrs.sorted(by: { $0.key < $1.key }) {
                            if let strVal = value as? String, !strVal.isEmpty {
                                result += "\(key): \(strVal)\n"
                            }
                        }
                    }
                }
                
                if let styles = browser["computedStyles"] as? [String: Any], !styles.isEmpty {
                    result += "\n───────────────────────────────\n"
                    result += "KEY STYLES\n"
                    result += "───────────────────────────────\n"
                    let keyStyles = ["display", "color", "backgroundColor", "fontSize", "fontWeight", 
                                     "border", "outline", "cursor", "opacity", "position", "zIndex"]
                    for styleKey in keyStyles {
                        if let val = styles[styleKey] as? String, !val.isEmpty, val != "none", val != "normal", val != "auto" {
                            result += "\(styleKey): \(val)\n"
                        }
                    }
                }
            } else if let native = focusedElement {
                let role = native["role"] as? String ?? ""
                let cleanRole = role.replacingOccurrences(of: "AX", with: "")
                let label = native["label"] as? String ?? native["title"] as? String ?? ""
                result += "Element: \(label.isEmpty ? "(no label)" : label) [\(cleanRole)]\n"
                
                if let domId = native["domId"] as? String, !domId.isEmpty {
                    result += "ID: \(domId)\n"
                }
                if let domClassList = native["domClassList"] as? String, !domClassList.isEmpty {
                    result += "Class: \(domClassList)\n"
                }
                if let roleDesc = native["roleDescription"] as? String, !roleDesc.isEmpty {
                    result += "Role Description: \(roleDesc)\n"
                }
                
                if let docTitle = native["documentTitle"] as? String, !docTitle.isEmpty {
                    result += "\n───────────────────────────────\n"
                    result += "PAGE\n"
                    result += "───────────────────────────────\n"
                    result += "Title: \(docTitle)\n"
                }
                if let docURL = native["documentURL"] as? String, !docURL.isEmpty {
                    result += "URL: \(docURL)\n"
                }
                
                if let appName = native["applicationName"] as? String, !appName.isEmpty {
                    result += "App: \(appName)\n"
                }
                
                if let bounds = native["bounds"] as? [String: Any] {
                    let x = bounds["x"] as? Int ?? 0
                    let y = bounds["y"] as? Int ?? 0
                    let w = bounds["width"] as? Int ?? 0
                    let h = bounds["height"] as? Int ?? 0
                    result += "Position: (\(x), \(y)) Size: \(w)×\(h)\n"
                }
            }
            
            return result
        }
        
        result += "\n───────────────────────────────\n"
        result += "DATA\n"
        result += "───────────────────────────────\n"
        result += formatEventDataForDetailPanel(data)
        return result
    }
    
    private func formatEventDataForDetailPanel(_ data: [String: Any], indent: Int = 0) -> String {
        var result = ""
        let indentStr = String(repeating: "  ", count: indent)
        
        let skipKeys = Set(["browserElement", "focusedElement"])
        let sortedKeys = data.keys.sorted()
        
        for key in sortedKeys {
            if skipKeys.contains(key) { continue }
            
            let value = data[key]
            let displayKey = key.replacingOccurrences(of: "_", with: " ").capitalized
            
            if let dictValue = value as? [String: Any] {
                if key == "inputData" {
                    result += formatEventDataForDetailPanel(dictValue, indent: indent)
                } else {
                    result += "\(indentStr)\(displayKey):\n"
                    result += formatEventDataForDetailPanel(dictValue, indent: indent + 1)
                }
            } else if let arrayValue = value as? [[String: Any]] {
                result += "\(indentStr)\(displayKey): [\(arrayValue.count) items]\n"
                for (i, item) in arrayValue.prefix(3).enumerated() {
                    result += "\(indentStr)  [\(i)]:\n"
                    result += formatEventDataForDetailPanel(item, indent: indent + 2)
                }
                if arrayValue.count > 3 {
                    result += "\(indentStr)  ... and \(arrayValue.count - 3) more\n"
                }
            } else if let stringArray = value as? [String] {
                if stringArray.isEmpty {
                    continue
                } else {
                    result += "\(indentStr)\(displayKey): \(stringArray.joined(separator: ", "))\n"
                }
            } else if let stringValue = value as? String {
                if stringValue.isEmpty {
                    continue
                } else if stringValue.count > 100 {
                    result += "\(indentStr)\(displayKey): \(stringValue.prefix(100))...\n"
                } else {
                    result += "\(indentStr)\(displayKey): \(stringValue)\n"
                }
            } else if let numberValue = value as? NSNumber {
                if CFGetTypeID(numberValue) == CFBooleanGetTypeID() {
                    let boolVal = numberValue.boolValue
                    if key.lowercased().contains("enabled") || key.lowercased().contains("required") ||
                       key.lowercased().contains("expanded") || key.lowercased().contains("selected") {
                        if boolVal {
                            result += "\(indentStr)\(displayKey): Yes\n"
                        }
                    } else {
                        result += "\(indentStr)\(displayKey): \(boolVal ? "Yes" : "No")\n"
                    }
                } else {
                    result += "\(indentStr)\(displayKey): \(numberValue)\n"
                }
            } else if value is NSNull {
                continue
            } else if let anyValue = value {
                result += "\(indentStr)\(displayKey): \(anyValue)\n"
            }
        }
        
        return result
    }
    
    private func updateTimelineInfo(with event: [String: Any]) {
        selectedTimelineEvent = event
        
        let eventType = event["type"] as? String ?? ""
        let isMarkerEvent = eventType.lowercased() == "marker"
        let isPauseEvent = eventType == "recording_paused"
        let isResumeEvent = eventType == "recording_resumed"
        
        print("🔍 updateTimelineInfo - eventType: '\(eventType)', isMarker: \(isMarkerEvent), keys: \(event.keys)")
        
        if let stackView = timelineDetailStackView {
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            if isPauseEvent || isResumeEvent {
                timelineDetailLabel?.isHidden = true
                timelineDetailLabel?.superview?.subviews.first(where: { $0 is NSScrollView })?.isHidden = false
                
                let icon = isPauseEvent ? "⏸" : "▶️"
                let title = isPauseEvent ? "Recording Paused" : "Recording Resumed"
                let (pauseCard, pauseContent) = createDetailCard(title: title, icon: icon)
                
                if let timestamp = event["timestamp"] as? Double {
                    pauseContent.addArrangedSubview(createDetailRow(label: "Time", value: formatTimestamp(timestamp), valueColor: .systemBlue))
                }
                
                if let data = event["data"] as? [String: Any] {
                    if isPauseEvent {
                        if let reason = data["reason"] as? String {
                            pauseContent.addArrangedSubview(createDetailRow(label: "Reason", value: reason.replacingOccurrences(of: "_", with: " ").capitalized))
                        }
                    } else {
                        if let pauseDuration = data["pauseDuration"] as? Double {
                            pauseContent.addArrangedSubview(createDetailRow(label: "Pause Duration", value: formatDuration(pauseDuration), valueColor: .systemYellow))
                        }
                        
                        if let totalPaused = data["totalPausedDuration"] as? Double {
                            pauseContent.addArrangedSubview(createDetailRow(label: "Total Paused", value: formatDuration(totalPaused), valueColor: .secondaryLabelColor))
                        }
                    }
                }
                
                stackView.addArrangedSubview(pauseCard)
                pauseCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            } else if isMarkerEvent {
                timelineDetailLabel?.isHidden = true
                timelineDetailLabel?.superview?.subviews.first(where: { $0 is NSScrollView })?.isHidden = false
                
                let (markerCard, markerContent) = createDetailCard(title: "Marker", icon: "🚩")
                if let markerName = event["markerName"] as? String, !markerName.isEmpty {
                    markerContent.addArrangedSubview(createDetailRow(label: "Name", value: markerName, valueColor: .systemOrange))
                }
                if let timestamp = event["timestamp"] as? Double {
                    markerContent.addArrangedSubview(createDetailRow(label: "Time", value: formatTimestamp(timestamp)))
                }
                if let noteBase64 = event["markerNote"] as? String,
                   let noteData = Data(base64Encoded: noteBase64),
                   let noteString = extractPlainTextFromRTF(noteData) {
                    markerContent.addArrangedSubview(createDetailRow(label: "Note", value: noteString))
                }
                stackView.addArrangedSubview(markerCard)
                markerCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            } else if eventType == "screenshot" {
                timelineDetailLabel?.isHidden = true
                timelineDetailLabel?.superview?.subviews.first(where: { $0 is NSScrollView })?.isHidden = false
                
                let (screenshotCard, screenshotContent) = createDetailCard(title: "Screenshot", icon: "📸")
                
                if let data = event["data"] as? [String: Any] {
                    if let name = data["name"] as? String {
                        screenshotContent.addArrangedSubview(createDetailRow(label: "Name", value: name, valueColor: .systemPink))
                    }
                    if let screenshotType = data["screenshotType"] as? String {
                        let typeDisplay = screenshotType.replacingOccurrences(of: "ScreenshotType.", with: "")
                            .replacingOccurrences(of: "fullScreen", with: "Full Screen")
                            .replacingOccurrences(of: "region", with: "Selected Region")
                            .replacingOccurrences(of: "browserFullPage", with: "Browser Full Page")
                        screenshotContent.addArrangedSubview(createDetailRow(label: "Type", value: typeDisplay))
                    }
                    
                    if let timestamp = event["timestamp"] as? Double {
                        screenshotContent.addArrangedSubview(createDetailRow(label: "Time", value: formatTimestamp(timestamp)))
                    }
                    
                    if let note = data["note"] as? String, !note.isEmpty {
                        screenshotContent.addArrangedSubview(createDetailRow(label: "Note", value: note))
                    }
                    
                    if let imagePath = data["imagePath"] as? String {
                        let fullPath = "/Users/bob3/Desktop/trackerA11y/recordings/\(sessionId)/\(imagePath)"
                        if FileManager.default.fileExists(atPath: fullPath),
                           let image = NSImage(contentsOfFile: fullPath) {
                            let thumbnailView = createScreenshotThumbnail(image: image, fullPath: fullPath)
                            screenshotContent.addArrangedSubview(thumbnailView)
                        }
                    }
                }
                
                stackView.addArrangedSubview(screenshotCard)
                screenshotCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            } else if let data = event["data"] as? [String: Any] {
                timelineDetailLabel?.isHidden = true
                timelineDetailLabel?.superview?.subviews.first(where: { $0 is NSScrollView })?.isHidden = false
                
                let (headerCard, headerContent) = createDetailCard(title: "Event", icon: "📋")
                if let timestamp = event["timestamp"] as? Double {
                    headerContent.addArrangedSubview(createDetailRow(label: "Time", value: formatTimestamp(timestamp)))
                    let originalIndex = findEventIndex(byTimestamp: timestamp)
                    if originalIndex >= 0 {
                        let tags = eventTags[originalIndex] ?? Set<String>()
                        if !tags.isEmpty {
                            headerContent.addArrangedSubview(createDetailRow(label: "Tags", value: tags.sorted().joined(separator: ", "), valueColor: .systemBlue))
                        }
                    }
                }
                if let source = event["source"] as? String {
                    headerContent.addArrangedSubview(createDetailRow(label: "Source", value: source.capitalized))
                }
                if let type = event["type"] as? String {
                    headerContent.addArrangedSubview(createDetailRow(label: "Type", value: type.replacingOccurrences(of: "_", with: " ").capitalized, valueColor: .systemPurple))
                }
                stackView.addArrangedSubview(headerCard)
                headerCard.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
                
                buildFocusEventCards(data, into: stackView)
            } else {
                timelineDetailLabel?.isHidden = false
                timelineDetailLabel?.superview?.subviews.first(where: { $0 is NSScrollView })?.isHidden = true
                timelineDetailLabel?.stringValue = "No detailed data available"
            }
        }
    }
    
    private func extractPlainTextFromRTF(_ rtfData: Data) -> String? {
        if let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            return attributedString.string
        }
        return nil
    }
    
    private func createScreenshotThumbnail(image: NSImage, fullPath: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        imageView.layer?.borderWidth = 1
        imageView.layer?.borderColor = NSColor.separatorColor.cgColor
        container.addSubview(imageView)
        
        let buttonTag = screenshotPaths.count
        screenshotPaths[buttonTag] = fullPath
        
        let openButton = NSButton(title: "Open Full Size", target: self, action: #selector(openScreenshotFullSize(_:)))
        openButton.bezelStyle = .rounded
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.tag = buttonTag
        container.addSubview(openButton)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 120),
            
            openButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            openButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            openButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        
        container.heightAnchor.constraint(equalToConstant: 160).isActive = true
        
        return container
    }
    
    @objc private func openScreenshotFullSize(_ sender: NSButton) {
        guard let fullPath = screenshotPaths[sender.tag],
              let image = NSImage(contentsOfFile: fullPath) else {
            print("❌ Could not find screenshot path for tag \(sender.tag)")
            return
        }
        
        let imageSize = image.size
        let maxWidth: CGFloat = 1200
        let maxHeight: CGFloat = 800
        
        var windowWidth = imageSize.width
        var windowHeight = imageSize.height
        
        if windowWidth > maxWidth {
            let scale = maxWidth / windowWidth
            windowWidth = maxWidth
            windowHeight *= scale
        }
        if windowHeight > maxHeight {
            let scale = maxHeight / windowHeight
            windowHeight = maxHeight
            windowWidth *= scale
        }
        
        windowWidth = max(400, windowWidth)
        windowHeight = max(300, windowHeight)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight + 40),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        let filename = (fullPath as NSString).lastPathComponent
        window.title = "Screenshot: \(filename)"
        window.center()
        window.isReleasedWhenClosed = false
        
        let contentView = NSView()
        contentView.wantsLayer = true
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 10.0
        
        let imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = NSRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
        
        scrollView.documentView = imageView
        contentView.addSubview(scrollView)
        
        let toolbar = NSView()
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toolbar)
        
        let zoomLabel = NSTextField(labelWithString: "Zoom:")
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(zoomLabel)
        
        let windowTag = screenshotWindows.count
        scrollViewRefs[windowTag] = scrollView
        screenshotPaths[windowTag + 10000] = fullPath  // Offset to avoid collision with thumbnail buttons
        
        let fitButton = NSButton(title: "Fit", target: self, action: #selector(screenshotFitToWindow(_:)))
        fitButton.bezelStyle = .rounded
        fitButton.translatesAutoresizingMaskIntoConstraints = false
        fitButton.tag = windowTag
        toolbar.addSubview(fitButton)
        
        let actualButton = NSButton(title: "100%", target: self, action: #selector(screenshotActualSize(_:)))
        actualButton.bezelStyle = .rounded
        actualButton.translatesAutoresizingMaskIntoConstraints = false
        actualButton.tag = windowTag
        toolbar.addSubview(actualButton)
        
        let saveButton = NSButton(title: "Save As...", target: self, action: #selector(screenshotSaveAs(_:)))
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.tag = windowTag + 10000
        toolbar.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 40),
            
            zoomLabel.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 12),
            zoomLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            
            fitButton.leadingAnchor.constraint(equalTo: zoomLabel.trailingAnchor, constant: 8),
            fitButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            
            actualButton.leadingAnchor.constraint(equalTo: fitButton.trailingAnchor, constant: 8),
            actualButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            
            saveButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -12),
            saveButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            
            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        window.contentView = contentView
        screenshotWindows.append(window)
        window.makeKeyAndOrderFront(nil)
    }
    
    @objc private func screenshotFitToWindow(_ sender: NSButton) {
        guard let scrollView = scrollViewRefs[sender.tag] else { return }
        scrollView.magnification = scrollView.minMagnification
    }
    
    @objc private func screenshotActualSize(_ sender: NSButton) {
        guard let scrollView = scrollViewRefs[sender.tag] else { return }
        scrollView.magnification = 1.0
    }
    
    @objc private func screenshotSaveAs(_ sender: NSButton) {
        guard let imagePath = screenshotPaths[sender.tag] else { return }
        
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = (imagePath as NSString).lastPathComponent
        savePanel.allowedContentTypes = [.png]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try FileManager.default.copyItem(atPath: imagePath, toPath: url.path)
                print("📸 Screenshot saved to: \(url.path)")
            } catch {
                print("❌ Failed to save screenshot: \(error)")
            }
        }
    }
    
    private func showTimelineEventContextMenu(event: [String: Any], eventIndex: Int, nsEvent: NSEvent) {
        let menu = createTagsNotesContextMenu(for: eventIndex)
        
        if let timelineView = self.timelineView {
            NSMenu.popUpContextMenu(menu, with: nsEvent, for: timelineView)
        }
    }
    
    private func formatEventDataDetailed(_ data: [String: Any]) -> String {
        var details: [String] = []
        
        for (key, value) in data {
            if let stringValue = value as? String {
                details.append("\(key): \(stringValue)")
            } else if let numberValue = value as? NSNumber {
                details.append("\(key): \(numberValue)")
            } else if let dictValue = value as? [String: Any] {
                details.append("\(key): {\(dictValue.count) items}")
            } else {
                details.append("\(key): \(String(describing: value))")
            }
        }
        
        return details.joined(separator: "\n")
    }
}

// MARK: - Enhanced Timeline View
class EnhancedTimelineView: NSView {
    private var events: [[String: Any]] = []
    private var startTime: Double = 0
    private var endTime: Double = 0
    private var videoStartTime: Double? = nil  // Video recording start timestamp
    private var zoomLevel: CGFloat = 1.0
    private var panOffset: CGFloat = 0
    var showEventDetails = true
    
    private var eventRects: [(rect: NSRect, event: [String: Any], eventIndex: Int)] = []
    private var hoveredEventIndex: Int? = nil
    var onEventSelected: (([String: Any]) -> Void)?
    var onEventRightClicked: (([String: Any], Int, NSEvent) -> Void)?
    
    // Playhead for video sync
    private var playheadPosition: Double? = nil  // Timestamp of current video position
    var showPlayhead: Bool = true
    private var isDraggingPlayhead: Bool = false
    var onPlayheadDragged: ((Double) -> Void)?  // Callback when playhead is dragged (timestamp)
    var onZoomChanged: (() -> Void)?  // Callback when zoom changes
    
    // Edge panning state for playhead dragging
    private var lastDragLocation: NSPoint?
    private var lastDragTime: Date?
    private var lastDragTimestamp: Double = 0  // Last playhead timestamp during drag
    private var dragTimestampVelocity: Double = 0  // Microseconds per second of real time
    private var edgePanTimer: Timer?
    private var edgePanDirection: CGFloat = 0  // -1 for left, 1 for right, 0 for none
    private var edgePanStartTime: Date?
    
    // Pause gaps - periods where recording was paused
    private var pauseGaps: [(start: Double, end: Double, duration: Double)] = []
    
    // Folded timeline: collapses pause gaps to small markers
    private var foldPauses: Bool = true
    private let pauseMarkerWidth: CGFloat = 12  // Width of collapsed pause marker
    
    var currentZoom: CGFloat {
        return zoomLevel
    }
    
    func setZoom(_ level: CGFloat) {
        zoomLevel = max(0.5, min(level, 100.0))
        updateFrameForZoom()
        invalidateIntrinsicContentSize()
        needsDisplay = true
        onZoomChanged?()
    }
    
    override var intrinsicContentSize: NSSize {
        guard let scrollView = enclosingScrollView else {
            return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }
        let baseWidth = scrollView.contentSize.width
        let zoomedWidth = baseWidth * zoomLevel
        return NSSize(width: zoomedWidth, height: NSView.noIntrinsicMetric)
    }
    
    private func updateFrameForZoom() {
        guard let scrollView = enclosingScrollView else { return }
        let baseWidth = scrollView.contentSize.width
        let zoomedWidth = baseWidth * zoomLevel
        let newFrame = NSRect(x: 0, y: 0, width: zoomedWidth, height: bounds.height)
        frame = newFrame
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setEvents(_ events: [[String: Any]]) {
        self.events = events.sorted { 
            ($0["timestamp"] as? Double ?? 0) < ($1["timestamp"] as? Double ?? 0)
        }
        
        let timestamps = self.events.compactMap { $0["timestamp"] as? Double }
        
        // For endTime, exclude system events like recording_ended to avoid huge gaps
        let userEventTimestamps = self.events.compactMap { event -> Double? in
            let eventType = event["type"] as? String ?? ""
            if eventType == "recording_ended" || eventType == "initial_focus" || eventType == "initial_state" {
                return nil
            }
            return event["timestamp"] as? Double
        }
        
        if let maxTime = timestamps.max() {
            if let videoStart = videoStartTime {
                startTime = videoStart
                print("🎬 setEvents using videoStartTime: \(videoStart)")
            } else if let minTime = timestamps.min() {
                startTime = minTime
                print("⚠️ setEvents using first event: \(minTime)")
            }
            // Use last user event for endTime, or fall back to absolute max
            endTime = userEventTimestamps.max() ?? maxTime
            print("🎬 setEvents: startTime=\(startTime), endTime=\(endTime)")
        }
        
        needsDisplay = true
    }
    
    func setVideoStartTime(_ timestamp: Double) {
        print("🎬 EnhancedTimelineView.setVideoStartTime: \(timestamp)")
        videoStartTime = timestamp
        startTime = timestamp
        needsDisplay = true
    }
    
    func setPauseGaps(_ gaps: [(start: Double, end: Double, duration: Double)]) {
        self.pauseGaps = gaps
        needsDisplay = true
    }
    
    private func getEffectiveDuration() -> Double {
        guard foldPauses else { return endTime - startTime }
        let totalPauseDuration = pauseGaps.reduce(0.0) { $0 + $1.duration }
        return max(1, (endTime - startTime) - totalPauseDuration)
    }
    
    private func getPauseDurationBefore(_ timestamp: Double) -> Double {
        guard foldPauses else { return 0 }
        var totalPause: Double = 0
        for gap in pauseGaps {
            if timestamp > gap.end {
                totalPause += gap.duration
            } else if timestamp > gap.start {
                totalPause += (timestamp - gap.start)
            }
        }
        return totalPause
    }
    
    private func timestampToFoldedX(_ timestamp: Double, in timelineRect: NSRect) -> CGFloat {
        let effectiveDuration = getEffectiveDuration()
        guard effectiveDuration > 0 else { return timelineRect.minX }
        
        if foldPauses && !pauseGaps.isEmpty {
            let totalMarkerWidth = CGFloat(pauseGaps.count) * pauseMarkerWidth
            let contentWidth = timelineRect.width - totalMarkerWidth
            let sortedGaps = pauseGaps.sorted { $0.start < $1.start }
            
            var currentX = timelineRect.minX
            var previousGapEnd = startTime
            
            for gap in sortedGaps {
                let segmentDuration = gap.start - previousGapEnd
                let segmentWidth = contentWidth * CGFloat(segmentDuration / effectiveDuration)
                
                if timestamp < gap.start {
                    let progressInSegment = (timestamp - previousGapEnd) / segmentDuration
                    return currentX + segmentWidth * CGFloat(progressInSegment)
                }
                
                if timestamp >= gap.start && timestamp < gap.end {
                    return currentX + segmentWidth
                }
                
                currentX += segmentWidth + pauseMarkerWidth
                previousGapEnd = gap.end
            }
            
            let finalSegmentDuration = endTime - previousGapEnd
            if finalSegmentDuration > 0 {
                let progressInFinal = (timestamp - previousGapEnd) / finalSegmentDuration
                let finalSegmentWidth = contentWidth * CGFloat(finalSegmentDuration / effectiveDuration)
                return currentX + finalSegmentWidth * CGFloat(min(1.0, progressInFinal))
            }
            
            return currentX
        } else {
            let duration = max(endTime - startTime, 1)
            let relativeTime = (timestamp - startTime) / duration
            return timelineRect.minX + CGFloat(relativeTime) * timelineRect.width
        }
    }
    
    private func foldedXToTimestamp(_ x: CGFloat, in timelineRect: NSRect) -> Double {
        let effectiveDuration = getEffectiveDuration()
        guard effectiveDuration > 0 else { return startTime }
        
        if foldPauses && !pauseGaps.isEmpty {
            let totalMarkerWidth = CGFloat(pauseGaps.count) * pauseMarkerWidth
            let contentWidth = timelineRect.width - totalMarkerWidth
            let sortedGaps = pauseGaps.sorted { $0.start < $1.start }
            
            var currentX = timelineRect.minX
            var currentEventTime = startTime
            var previousGapEnd = startTime
            
            for (index, gap) in sortedGaps.enumerated() {
                let segmentDuration = gap.start - previousGapEnd
                let segmentWidth = contentWidth * CGFloat(segmentDuration / effectiveDuration)
                let segmentEndX = currentX + segmentWidth
                
                if x < segmentEndX {
                    let progressInSegment = (x - currentX) / segmentWidth
                    return currentEventTime + segmentDuration * Double(progressInSegment)
                }
                
                currentEventTime = gap.start
                
                if x < segmentEndX + pauseMarkerWidth {
                    return gap.start
                }
                
                currentX = segmentEndX + pauseMarkerWidth
                currentEventTime = gap.end
                previousGapEnd = gap.end
            }
            
            let finalSegmentDuration = endTime - previousGapEnd
            let finalSegmentWidth = contentWidth * CGFloat(finalSegmentDuration / effectiveDuration)
            
            if finalSegmentWidth > 0 {
                let progressInFinal = min(1.0, max(0, (x - currentX) / finalSegmentWidth))
                return currentEventTime + finalSegmentDuration * Double(progressInFinal)
            }
            
            return endTime
        } else {
            let duration = max(endTime - startTime, 1)
            let relativeX = (x - timelineRect.minX) / timelineRect.width
            return startTime + relativeX * duration
        }
    }
    
    func zoomIn() {
        zoomLevel = min(zoomLevel * 1.5, 100.0)
        updateFrameForZoom()
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }
    
    func zoomOut() {
        zoomLevel = max(zoomLevel / 1.5, 0.5)
        updateFrameForZoom()
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }
    
    func resetZoom() {
        zoomLevel = 1.0
        panOffset = 0
        updateFrameForZoom()
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }
    
    func setPlayheadTimestamp(_ timestamp: Double?) {
        playheadPosition = timestamp
        needsDisplay = true
    }
    
    var playheadTimestamp: Double? {
        return playheadPosition
    }
    
    func getPlayheadXPosition() -> CGFloat? {
        guard let position = playheadPosition, endTime > startTime else { return nil }
        
        let leftMargin: CGFloat = 20
        let rightMargin: CGFloat = 20
        let topMargin: CGFloat = 50
        let bottomMargin: CGFloat = 20
        
        let timelineRect = NSRect(
            x: leftMargin,
            y: bottomMargin,
            width: bounds.width - leftMargin - rightMargin,
            height: bounds.height - topMargin - bottomMargin
        )
        
        return timestampToFoldedX(position, in: timelineRect)
    }
    
    func getTimeRange() -> (start: Double, end: Double) {
        return (startTime, endTime)
    }
    
    override func mouseDown(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)
        
        // Double-click anywhere on timeline moves playhead to that position
        if event.clickCount == 2 {
            updatePlayheadFromMouseLocation(locationInView)
            return
        }
        
        // Check if clicking on an event first (takes priority over scrub area)
        for (index, eventRect) in eventRects.enumerated() {
            if eventRect.rect.contains(locationInView) {
                onEventSelected?(eventRect.event)
                hoveredEventIndex = index
                needsDisplay = true
                return
            }
        }
        
        // Check if clicking near the playhead or in the playhead drag area (top portion)
        if isClickOnPlayhead(locationInView) || isClickInScrubArea(locationInView) {
            isDraggingPlayhead = true
            lastDragLocation = locationInView
            lastDragTime = Date()
            lastDragTimestamp = playheadPosition ?? startTime
            dragTimestampVelocity = 0
            updatePlayheadFromMouseLocation(locationInView)
            return
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if isDraggingPlayhead {
            let locationInView = convert(event.locationInWindow, from: nil)
            
            // Calculate current timestamp from mouse position
            let leftMargin: CGFloat = 20
            let timelineWidth = bounds.width - leftMargin - 20
            let relativeX = (locationInView.x - leftMargin) / timelineWidth
            let clampedRelativeX = max(0, min(1, relativeX))
            let duration = endTime - startTime
            let currentTimestamp = startTime + (Double(clampedRelativeX) * duration)
            
            // Calculate timestamp velocity (microseconds per second of real time)
            if let lastTime = lastDragTime {
                let timeDelta = Date().timeIntervalSince(lastTime)
                if timeDelta > 0.001 {  // Avoid division by very small numbers
                    let timestampDelta = abs(currentTimestamp - lastDragTimestamp)
                    dragTimestampVelocity = timestampDelta / timeDelta
                }
            }
            lastDragLocation = locationInView
            lastDragTime = Date()
            lastDragTimestamp = currentTimestamp
            
            // Check if we're at the edge of the visible area
            guard let scrollView = enclosingScrollView else {
                updatePlayheadFromMouseLocation(locationInView)
                return
            }
            
            let visibleRect = scrollView.contentView.bounds
            let mouseInWindow = event.locationInWindow
            let scrollViewFrame = scrollView.convert(scrollView.bounds, to: nil)
            let locationInScrollViewX = mouseInWindow.x - scrollViewFrame.minX
            
            let edgeThreshold: CGFloat = 30
            let leftEdge = edgeThreshold
            let rightEdge = visibleRect.width - edgeThreshold
            
            if locationInScrollViewX < leftEdge && visibleRect.origin.x > 0 {
                // Start left edge panning (only if we can scroll left)
                if edgePanDirection != -1 {
                    edgePanDirection = -1
                    edgePanStartTime = Date()
                    startEdgePanning()
                }
            } else if locationInScrollViewX > rightEdge && visibleRect.origin.x < bounds.width - visibleRect.width {
                // Start right edge panning (only if we can scroll right)
                if edgePanDirection != 1 {
                    edgePanDirection = 1
                    edgePanStartTime = Date()
                    startEdgePanning()
                }
            } else {
                // Not at edge or can't scroll further, stop panning and update normally
                stopEdgePanning()
                updatePlayheadFromMouseLocation(locationInView)
            }
        }
    }
    
    private func startEdgePanning() {
        edgePanTimer?.invalidate()
        edgePanTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.performEdgePan()
        }
    }
    
    private func stopEdgePanning() {
        edgePanTimer?.invalidate()
        edgePanTimer = nil
        edgePanDirection = 0
        edgePanStartTime = nil
    }
    
    private func performEdgePan() {
        guard edgePanDirection != 0, endTime > startTime else { return }
        guard let currentPosition = playheadPosition else { return }
        
        // Use the actual timestamp velocity - microseconds per second of real time
        let baseTimestampVelocity = dragTimestampVelocity
        
        // After 3 seconds, gradually ramp up to 50% faster over the next 3 seconds
        var speedMultiplier: Double = 1.0
        if let panStartTime = edgePanStartTime {
            let elapsed = Date().timeIntervalSince(panStartTime)
            if elapsed > 3.0 {
                // Start ramping after 3 seconds, reach 1.5x after 6 seconds total
                let rampElapsed = elapsed - 3.0
                let rampProgress = min(rampElapsed / 3.0, 1.0)  // 0 to 1 over 3 seconds
                speedMultiplier = 1.0 + (0.5 * rampProgress)  // 1.0 to 1.5
            }
        }
        
        // Calculate timestamp change per frame (60fps)
        let timestampDeltaPerFrame = baseTimestampVelocity * speedMultiplier / 60.0
        
        // Update playhead timestamp
        let newTimestamp: Double
        if edgePanDirection < 0 {
            newTimestamp = max(startTime, currentPosition - timestampDeltaPerFrame)
        } else {
            newTimestamp = min(endTime, currentPosition + timestampDeltaPerFrame)
        }
        
        playheadPosition = newTimestamp
        lastDragTimestamp = newTimestamp
        needsDisplay = true
        onPlayheadDragged?(newTimestamp)
        
        // Scroll to keep playhead visible
        guard let scrollView = enclosingScrollView else { return }
        
        let leftMargin: CGFloat = 20
        let timelineWidth = bounds.width - leftMargin - 20
        let duration = endTime - startTime
        let relativePosition = (newTimestamp - startTime) / duration
        let playheadX = leftMargin + CGFloat(relativePosition) * timelineWidth
        
        // Calculate scroll to keep playhead at edge
        let visibleWidth = scrollView.contentView.bounds.width
        let edgeThreshold: CGFloat = 30
        let targetScrollX: CGFloat
        if edgePanDirection < 0 {
            targetScrollX = playheadX - edgeThreshold
        } else {
            targetScrollX = playheadX - visibleWidth + edgeThreshold
        }
        
        let maxScroll = max(0, bounds.width - visibleWidth)
        let clampedScrollX = max(0, min(maxScroll, targetScrollX))
        scrollView.contentView.setBoundsOrigin(NSPoint(x: clampedScrollX, y: 0))
    }
    
    override func mouseUp(with event: NSEvent) {
        isDraggingPlayhead = false
        stopEdgePanning()
        lastDragLocation = nil
        lastDragTime = nil
    }
    
    private func isClickOnPlayhead(_ location: NSPoint) -> Bool {
        guard let position = playheadPosition, endTime > startTime else { return false }
        
        let leftMargin: CGFloat = 20
        let rightMargin: CGFloat = 20
        let timelineWidth = bounds.width - leftMargin - rightMargin
        let duration = endTime - startTime
        
        let relativePosition = (position - startTime) / duration
        guard relativePosition >= 0 && relativePosition <= 1 else { return false }
        
        let playheadX = leftMargin + CGFloat(relativePosition) * timelineWidth
        
        return abs(location.x - playheadX) < 10
    }
    
    private func isClickInScrubArea(_ location: NSPoint) -> Bool {
        // The scrub area is the top portion where the time axis and playhead handle are
        let topMargin: CGFloat = 50
        return location.y > bounds.height - topMargin
    }
    
    private func updatePlayheadFromMouseLocation(_ location: NSPoint) {
        let leftMargin: CGFloat = 20
        let rightMargin: CGFloat = 20
        let topMargin: CGFloat = 50
        let bottomMargin: CGFloat = 20
        
        let timelineRect = NSRect(
            x: leftMargin,
            y: bottomMargin,
            width: bounds.width - leftMargin - rightMargin,
            height: bounds.height - topMargin - bottomMargin
        )
        
        guard timelineRect.width > 0, endTime > startTime else { return }
        
        let clampedX = max(timelineRect.minX, min(timelineRect.maxX, location.x))
        let newTimestamp = foldedXToTimestamp(clampedX, in: timelineRect)
        
        playheadPosition = max(startTime, min(endTime, newTimestamp))
        needsDisplay = true
        
        onPlayheadDragged?(playheadPosition!)
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)
        
        for eventRect in eventRects {
            if eventRect.rect.contains(locationInView) {
                onEventRightClicked?(eventRect.event, eventRect.eventIndex, event)
                return
            }
        }
        super.rightMouseDown(with: event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)
        
        var newHoveredIndex: Int? = nil
        for (index, eventRect) in eventRects.enumerated() {
            if eventRect.rect.contains(locationInView) {
                newHoveredIndex = index
                break
            }
        }
        
        if newHoveredIndex != hoveredEventIndex {
            hoveredEventIndex = newHoveredIndex
            needsDisplay = true
        }
        
        if hoveredEventIndex != nil {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        hoveredEventIndex = nil
        NSCursor.arrow.set()
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        eventRects.removeAll()
        
        guard !events.isEmpty else {
            drawEmptyState()
            return
        }
        
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        
        drawTimelineBackground()
        drawEventTracks()
        drawPlayhead()
        drawTimeAxis()
        drawHoveredEventTooltip()
        
        context?.restoreGState()
    }
    
    private func drawEmptyState() {
        let text = "No events to display"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attributes)
    }
    
    private func drawTimelineBackground() {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        
        NSColor.separatorColor.setStroke()
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 0.5
        
        let stepCount = 10
        for i in 0...stepCount {
            let x = bounds.minX + CGFloat(i) * bounds.width / CGFloat(stepCount)
            gridPath.move(to: NSPoint(x: x, y: bounds.minY))
            gridPath.line(to: NSPoint(x: x, y: bounds.maxY))
        }
        
        gridPath.stroke()
    }
    
    private func drawEventTracks() {
        let leftMargin: CGFloat = 20
        let rightMargin: CGFloat = 20
        let topMargin: CGFloat = 50
        let bottomMargin: CGFloat = 20
        
        let timelineRect = NSRect(
            x: leftMargin,
            y: bottomMargin,
            width: bounds.width - leftMargin - rightMargin,
            height: bounds.height - topMargin - bottomMargin
        )
        
        let duration = max(endTime - startTime, 1)
        
        NSColor.windowBackgroundColor.withAlphaComponent(0.5).setFill()
        NSRect(x: timelineRect.minX, y: timelineRect.minY, width: timelineRect.width, height: timelineRect.height).fill()
        
        NSColor.separatorColor.setStroke()
        let baselinePath = NSBezierPath()
        let baselineY = timelineRect.minY + timelineRect.height * 0.5
        baselinePath.move(to: NSPoint(x: timelineRect.minX, y: baselineY))
        baselinePath.line(to: NSPoint(x: timelineRect.maxX, y: baselineY))
        baselinePath.lineWidth = 1
        baselinePath.stroke()
        
        let sourceColors: [String: NSColor] = [
            "interaction": .systemGreen,
            "focus": .systemBlue,
            "system": .systemOrange
        ]
        
        let typeColors: [String: NSColor] = [
            "mousedown": .systemGreen,
            "mouseup": .systemGreen,
            "mousemove": NSColor.systemGreen.withAlphaComponent(0.6),
            "click": .systemTeal,
            "dblclick": .systemTeal,
            "keydown": .systemIndigo,
            "keyup": .systemIndigo,
            "keypress": .systemIndigo,
            "scroll": .systemMint,
            "wheel": .systemMint,
            "focus": .systemBlue,
            "blur": .systemBlue,
            "focusin": .systemBlue,
            "focusout": .systemBlue,
            "resize": .systemOrange,
            "visibilitychange": .systemOrange,
            "load": .systemYellow,
            "unload": .systemYellow,
            "error": .systemRed,
            "input": .systemPurple,
            "change": .systemPurple,
            "screenshot": .systemPink
        ]
        
        let markerColor: NSColor = .systemRed
        
        let normalHeight = timelineRect.height * 0.5
        let markerBarHeight = timelineRect.height * 0.85
        let barWidth: CGFloat = 4  // Fixed width - timeline stretches, not events
        let spacing: CGFloat = 2
        
        var drawnPositions: [Double: CGFloat] = [:]
        
        for (index, event) in events.enumerated() {
            guard let timestamp = event["timestamp"] as? Double else { continue }
            
            var baseX = timestampToFoldedX(timestamp, in: timelineRect)
            
            let originalIndex = event["_originalIndex"] as? Int ?? index
            
            let source = event["source"] as? String ?? "unknown"
            let eventType = event["type"] as? String ?? "unknown"
            let isMarkerEvent = eventType == "marker"
            let isScreenshotEvent = eventType == "screenshot"
            
            if let existingX = drawnPositions[timestamp] {
                baseX = existingX + barWidth + spacing
            }
            drawnPositions[timestamp] = baseX
            
            let eventColor: NSColor
            let barHeight: CGFloat
            
            if isMarkerEvent {
                eventColor = markerColor
                barHeight = markerBarHeight
            } else if isScreenshotEvent {
                eventColor = .systemPink
                barHeight = markerBarHeight
            } else if let typeColor = typeColors[eventType] {
                eventColor = typeColor
                barHeight = normalHeight
            } else if let sourceColor = sourceColors[source] {
                eventColor = sourceColor
                barHeight = normalHeight
            } else {
                eventColor = .systemGray
                barHeight = normalHeight
            }
            
            let barRect = NSRect(
                x: baseX - barWidth / 2,
                y: baselineY - barHeight / 2,
                width: barWidth,
                height: barHeight
            )
            
            let isHovered = hoveredEventIndex != nil && eventRects.count == hoveredEventIndex
            
            if isHovered {
                eventColor.withAlphaComponent(1.0).setFill()
                NSColor.white.setStroke()
                let path = NSBezierPath(roundedRect: barRect.insetBy(dx: -2, dy: -2), xRadius: 3, yRadius: 3)
                path.fill()
                path.lineWidth = 2
                path.stroke()
            } else {
                eventColor.withAlphaComponent(0.85).setFill()
                let path = NSBezierPath(roundedRect: barRect, xRadius: 2, yRadius: 2)
                path.fill()
            }
            
            if isMarkerEvent, let markerName = event["markerName"] as? String {
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: max(9, 10 * zoomLevel / 2), weight: .medium),
                    .foregroundColor: NSColor.white
                ]
                let labelSize = markerName.size(withAttributes: labelAttrs)
                let labelRect = NSRect(
                    x: baseX - labelSize.width / 2 - 3,
                    y: barRect.maxY + 4,
                    width: labelSize.width + 6,
                    height: labelSize.height + 2
                )
                markerColor.withAlphaComponent(0.9).setFill()
                NSBezierPath(roundedRect: labelRect, xRadius: 3, yRadius: 3).fill()
                markerName.draw(at: NSPoint(x: labelRect.minX + 3, y: labelRect.minY + 1), withAttributes: labelAttrs)
            }
            
            if isScreenshotEvent {
                let screenshotName = (event["data"] as? [String: Any])?["name"] as? String ?? "Screenshot"
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: max(9, 10 * zoomLevel / 2), weight: .medium),
                    .foregroundColor: NSColor.white
                ]
                let labelSize = screenshotName.size(withAttributes: labelAttrs)
                let labelRect = NSRect(
                    x: baseX - labelSize.width / 2 - 3,
                    y: barRect.maxY + 4,
                    width: labelSize.width + 6,
                    height: labelSize.height + 2
                )
                NSColor.systemPink.withAlphaComponent(0.9).setFill()
                NSBezierPath(roundedRect: labelRect, xRadius: 3, yRadius: 3).fill()
                screenshotName.draw(at: NSPoint(x: labelRect.minX + 3, y: labelRect.minY + 1), withAttributes: labelAttrs)
            }
            
            let clickableRect = barRect.insetBy(dx: -4, dy: -4)
            eventRects.append((rect: clickableRect, event: event, eventIndex: originalIndex))
        }
        
        drawPauseGaps(in: timelineRect, duration: duration)
    }
    
    private func drawPauseGaps(in timelineRect: NSRect, duration: Double) {
        guard !pauseGaps.isEmpty else { return }
        
        let baselineY = timelineRect.minY + timelineRect.height * 0.5
        let sortedGaps = pauseGaps.sorted { $0.start < $1.start }
        
        for gap in sortedGaps {
            let markerX = timestampToFoldedX(gap.start, in: timelineRect)
            
            let markerRect = NSRect(
                x: markerX - pauseMarkerWidth / 2,
                y: timelineRect.minY,
                width: pauseMarkerWidth,
                height: timelineRect.height
            )
            
            NSColor.systemYellow.withAlphaComponent(0.3).setFill()
            markerRect.fill()
            
            NSColor.systemYellow.withAlphaComponent(0.8).setStroke()
            let leftLine = NSBezierPath()
            leftLine.move(to: NSPoint(x: markerRect.minX, y: timelineRect.minY))
            leftLine.line(to: NSPoint(x: markerRect.minX, y: timelineRect.maxY))
            leftLine.lineWidth = 1.5
            leftLine.stroke()
            
            let rightLine = NSBezierPath()
            rightLine.move(to: NSPoint(x: markerRect.maxX, y: timelineRect.minY))
            rightLine.line(to: NSPoint(x: markerRect.maxX, y: timelineRect.maxY))
            rightLine.lineWidth = 1.5
            rightLine.stroke()
            
            let pauseIcon = "⏸"
            let pauseAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: NSColor.systemYellow
            ]
            let iconSize = pauseIcon.size(withAttributes: pauseAttrs)
            pauseIcon.draw(at: NSPoint(x: markerX - iconSize.width / 2, y: baselineY - iconSize.height / 2), withAttributes: pauseAttrs)
            
            let durationSecs = gap.duration / 1_000_000
            let durationText: String
            if durationSecs >= 60 {
                let mins = Int(durationSecs) / 60
                let secs = Int(durationSecs) % 60
                durationText = "\(mins)m\(secs)s"
            } else {
                durationText = String(format: "%.1fs", durationSecs)
            }
            let durationAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let durationSize = durationText.size(withAttributes: durationAttrs)
            durationText.draw(at: NSPoint(x: markerX - durationSize.width / 2, y: markerRect.maxY + 2), withAttributes: durationAttrs)
        }
    }
    
    private func drawPlayhead() {
        guard showPlayhead, let position = playheadPosition else { return }
        guard endTime > startTime else { return }
        
        let leftMargin: CGFloat = 20
        let rightMargin: CGFloat = 20
        let topMargin: CGFloat = 50
        let bottomMargin: CGFloat = 20
        
        let timelineRect = NSRect(
            x: leftMargin,
            y: bottomMargin,
            width: bounds.width - leftMargin - rightMargin,
            height: bounds.height - topMargin - bottomMargin
        )
        
        let playheadX = timestampToFoldedX(position, in: timelineRect)
        
        // Draw playhead line
        NSColor.systemRed.setStroke()
        let playheadPath = NSBezierPath()
        playheadPath.move(to: NSPoint(x: playheadX, y: bottomMargin))
        playheadPath.line(to: NSPoint(x: playheadX, y: bounds.height - topMargin))
        playheadPath.lineWidth = 2
        playheadPath.stroke()
        
        // Draw playhead triangle at top
        NSColor.systemRed.setFill()
        let trianglePath = NSBezierPath()
        let triangleY = bounds.height - topMargin
        trianglePath.move(to: NSPoint(x: playheadX, y: triangleY + 12))
        trianglePath.line(to: NSPoint(x: playheadX - 6, y: triangleY + 2))
        trianglePath.line(to: NSPoint(x: playheadX + 6, y: triangleY + 2))
        trianglePath.close()
        trianglePath.fill()
        
        // Draw current time label - use videoStartTime as datum if available
        let datum = videoStartTime ?? startTime
        let timeInSeconds = (position - datum) / 1_000_000  // Convert from microseconds
        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        let millis = Int((timeInSeconds - Double(Int(timeInSeconds))) * 1000)
        let timeString = String(format: "%02d:%02d.%03d", minutes, seconds, millis)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let labelSize = timeString.size(withAttributes: labelAttrs)
        let labelRect = NSRect(
            x: playheadX - labelSize.width / 2 - 4,
            y: triangleY + 14,
            width: labelSize.width + 8,
            height: labelSize.height + 4
        )
        
        NSColor.systemRed.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4).fill()
        timeString.draw(at: NSPoint(x: labelRect.minX + 4, y: labelRect.minY + 2), withAttributes: labelAttrs)
    }
    
    private func drawLegend(in timelineRect: NSRect) {
        let legendItems: [(String, NSColor)] = [
            ("Interaction", .systemGreen),
            ("Focus", .systemBlue),
            ("System", .systemOrange),
            ("Marker", .systemRed)
        ]
        
        let legendY = timelineRect.maxY + 10
        var legendX: CGFloat = timelineRect.minX
        
        for (label, color) in legendItems {
            let swatchRect = NSRect(x: legendX, y: legendY, width: 12, height: 12)
            color.setFill()
            NSBezierPath(roundedRect: swatchRect, xRadius: 2, yRadius: 2).fill()
            
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let labelSize = label.size(withAttributes: labelAttrs)
            label.draw(at: NSPoint(x: legendX + 16, y: legendY), withAttributes: labelAttrs)
            
            legendX += 16 + labelSize.width + 20
        }
    }
    
    private func drawTimeAxis() {
        let leftMargin: CGFloat = 20
        let rightMargin: CGFloat = 20
        let topMargin: CGFloat = 50
        
        let axisY = bounds.height - topMargin + 10
        
        NSColor.separatorColor.setStroke()
        let axisPath = NSBezierPath()
        axisPath.move(to: NSPoint(x: leftMargin, y: axisY))
        axisPath.line(to: NSPoint(x: bounds.width - rightMargin, y: axisY))
        axisPath.lineWidth = 1
        axisPath.stroke()
        
        let timeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        let effectiveDuration = getEffectiveDuration()
        let effectiveDurationSeconds = effectiveDuration / 1_000_000
        
        let startLabel = "0:00"
        startLabel.draw(at: NSPoint(x: leftMargin, y: axisY + 5), withAttributes: timeAttributes)
        
        let endLabel = formatRelativeTime(effectiveDurationSeconds)
        let endLabelSize = endLabel.size(withAttributes: timeAttributes)
        endLabel.draw(at: NSPoint(x: bounds.width - rightMargin - endLabelSize.width, y: axisY + 5), withAttributes: timeAttributes)
        
        let timelineWidth = bounds.width - leftMargin - rightMargin
        let totalMarkerWidth = foldPauses ? CGFloat(pauseGaps.count) * pauseMarkerWidth : 0
        let contentWidth = timelineWidth - totalMarkerWidth
        let targetSpacing: CGFloat = 100
        let markerCount = max(3, Int(contentWidth / targetSpacing))
        
        for i in 1..<markerCount {
            let progress = CGFloat(i) / CGFloat(markerCount)
            let markerX = leftMargin + progress * contentWidth
            
            guard markerX < bounds.width - rightMargin - 40 else { continue }
            
            let tickPath = NSBezierPath()
            tickPath.move(to: NSPoint(x: markerX, y: axisY - 3))
            tickPath.line(to: NSPoint(x: markerX, y: axisY + 3))
            tickPath.lineWidth = 1
            tickPath.stroke()
            
            let relativeSeconds = Double(progress) * effectiveDurationSeconds
            let markerLabel = formatRelativeTime(relativeSeconds)
            let labelSize = markerLabel.size(withAttributes: timeAttributes)
            markerLabel.draw(at: NSPoint(x: markerX - labelSize.width/2, y: axisY + 5), withAttributes: timeAttributes)
        }
    }
    
    private func formatRelativeTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let tenths = Int((seconds - Double(Int(seconds))) * 10)
        return String(format: "%02d:%02d:%02d.%d", hours, mins, secs, tenths)
    }
    
    private func drawHoveredEventTooltip() {
        guard let hoveredIndex = hoveredEventIndex,
              hoveredIndex < eventRects.count else { return }
        
        let eventData = eventRects[hoveredIndex]
        let event = eventData.event
        let rect = eventData.rect
        
        var tooltipText = ""
        if let type = event["type"] as? String {
            tooltipText = type.replacingOccurrences(of: "_", with: " ")
        }
        if let timestamp = event["timestamp"] as? Double {
            let date = Date(timeIntervalSince1970: timestamp / 1_000_000)
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            tooltipText += "\n" + formatter.string(from: date)
        }
        
        let tooltipAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.white
        ]
        let tooltipSize = tooltipText.size(withAttributes: tooltipAttributes)
        let padding: CGFloat = 8
        let tooltipRect = NSRect(
            x: rect.midX - tooltipSize.width/2 - padding,
            y: rect.maxY + 5,
            width: tooltipSize.width + padding * 2,
            height: tooltipSize.height + padding * 2
        )
        
        NSColor.black.withAlphaComponent(0.85).setFill()
        let tooltipPath = NSBezierPath(roundedRect: tooltipRect, xRadius: 6, yRadius: 6)
        tooltipPath.fill()
        
        tooltipText.draw(
            at: NSPoint(x: tooltipRect.minX + padding, y: tooltipRect.minY + padding),
            withAttributes: tooltipAttributes
        )
    }
}

// MARK: - Legacy Timeline View (for compatibility)
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
            let text = "No events to display"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 18),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let size = text.size(withAttributes: attributes)
            let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
            text.draw(at: point, withAttributes: attributes)
            return
        }
        
        // Simple timeline drawing for legacy compatibility
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        
        let margin: CGFloat = 20
        let duration = endTime - startTime
        
        for event in events {
            guard let timestamp = event["timestamp"] as? Double else { continue }
            
            let relativeTime = (timestamp - startTime) / duration
            let x = margin + relativeTime * (bounds.width - 2 * margin)
            
            NSColor.systemBlue.setFill()
            NSRect(x: x - 2, y: bounds.height / 2 - 5, width: 4, height: 10).fill()
        }
    }
}


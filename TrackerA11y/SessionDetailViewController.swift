import Cocoa

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
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view.autoresizingMask = [.width, .height]
        
        setupUI()
        loadSessionEvents()
        loadSessionMetadata()
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
    
    private func createEnhancedOverviewView() -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Content view that will hold all cards (no scroll view - content should fit)
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentView)
        
        // Header with session title and quick actions
        let headerCard = createProfessionalHeaderCard()
        contentView.addSubview(headerCard)
        
        // First row: Key metrics cards
        let metricsCard = createKeyMetricsCard()
        let statusCard = createSessionStatusCard()
        contentView.addSubview(metricsCard)
        contentView.addSubview(statusCard)
        
        // Second row: Detailed analytics
        let eventAnalyticsCard = createEventAnalyticsCard()
        let timelineCard = createTimelineOverviewCard()
        contentView.addSubview(eventAnalyticsCard)
        contentView.addSubview(timelineCard)
        
        // Third row: Full-width insights
        let insightsCard = createSessionInsightsCard()
        contentView.addSubview(insightsCard)
        
        // Action buttons card
        let actionsCard = createSessionActionsCard()
        contentView.addSubview(actionsCard)
        
        // Layout constraints - compact spacing, content fills container
        NSLayoutConstraint.activate([
            // Content view fills container
            contentView.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Header card
            headerCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            headerCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            headerCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            headerCard.heightAnchor.constraint(equalToConstant: 90),
            
            // First row: Key metrics (side by side) - compact
            metricsCard.topAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: 8),
            metricsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            metricsCard.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.48, constant: -18),
            metricsCard.heightAnchor.constraint(equalToConstant: 100),
            
            statusCard.topAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: 8),
            statusCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            statusCard.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.48, constant: -18),
            statusCard.heightAnchor.constraint(equalToConstant: 100),
            
            // Second row: Analytics (side by side) - compact
            eventAnalyticsCard.topAnchor.constraint(equalTo: metricsCard.bottomAnchor, constant: 8),
            eventAnalyticsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            eventAnalyticsCard.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.58, constant: -18),
            eventAnalyticsCard.heightAnchor.constraint(equalToConstant: 140),
            
            timelineCard.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: 8),
            timelineCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            timelineCard.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.38, constant: -18),
            timelineCard.heightAnchor.constraint(equalToConstant: 140),
            
            // Third row: Full-width insights - compact
            insightsCard.topAnchor.constraint(equalTo: eventAnalyticsCard.bottomAnchor, constant: 8),
            insightsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            insightsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            insightsCard.heightAnchor.constraint(equalToConstant: 100),
            
            // Actions card at bottom - compact
            actionsCard.topAnchor.constraint(equalTo: insightsCard.bottomAnchor, constant: 8),
            actionsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            actionsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            actionsCard.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // Store references for updates
        objc_setAssociatedObject(containerView, "headerCard", headerCard, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(containerView, "metricsCard", metricsCard, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(containerView, "statusCard", statusCard, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(containerView, "eventAnalyticsCard", eventAnalyticsCard, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(containerView, "timelineCard", timelineCard, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(containerView, "insightsCard", insightsCard, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return containerView
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
            iconLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            iconLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 16),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            
            statusIndicator.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            statusIndicator.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 120),
            statusIndicator.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return card
    }
    
    private func createKeyMetricsCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.systemBlue.withAlphaComponent(0.05))
        
        let titleLabel = NSTextField(labelWithString: "📈 Key Metrics")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = NSColor.systemBlue
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // Metrics container
        let metricsContainer = NSView()
        metricsContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(metricsContainer)
        
        // Store direct reference for reliable updates
        self.metricsCardContainer = metricsContainer
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            metricsContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            metricsContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            metricsContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            metricsContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        
        return card
    }
    
    private func createSessionStatusCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.systemGreen.withAlphaComponent(0.05))
        
        let titleLabel = NSTextField(labelWithString: "⚡ Session Status")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = NSColor.systemGreen
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // Status container
        let statusContainer = NSView()
        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statusContainer)
        
        // Store direct reference
        self.statusCardContainer = statusContainer
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            statusContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            statusContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            statusContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            statusContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        
        return card
    }
    
    private func createEventAnalyticsCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.systemPurple.withAlphaComponent(0.05))
        
        let titleLabel = NSTextField(labelWithString: "📊 Event Analytics")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = NSColor.systemPurple
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // Analytics container
        let analyticsContainer = NSView()
        analyticsContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(analyticsContainer)
        
        // Store direct reference
        self.eventAnalyticsCardContainer = analyticsContainer
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            analyticsContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            analyticsContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            analyticsContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            analyticsContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        
        return card
    }
    
    private func createTimelineOverviewCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.systemOrange.withAlphaComponent(0.05))
        
        let titleLabel = NSTextField(labelWithString: "⏱️ Timeline")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = NSColor.systemOrange
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // Timeline preview container
        let timelineContainer = NSView()
        timelineContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(timelineContainer)
        
        // Store direct reference
        self.timelineCardContainer = timelineContainer
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            timelineContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            timelineContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            timelineContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            timelineContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        
        return card
    }
    
    private func createSessionInsightsCard() -> NSView {
        let card = createModernCard(bgColor: NSColor.systemTeal.withAlphaComponent(0.05))
        
        let titleLabel = NSTextField(labelWithString: "🧠 AI Insights")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = NSColor.systemTeal
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        // Insights container
        let insightsContainer = NSView()
        insightsContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(insightsContainer)
        
        // Store direct reference
        self.insightsCardContainer = insightsContainer
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            insightsContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            insightsContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            insightsContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            insightsContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
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
    
    private func createEnhancedEventsView() -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let eventsLabel = NSTextField(labelWithString: "Events Analysis\n\nLoading event data...")
        eventsLabel.font = NSFont.systemFont(ofSize: 16)
        eventsLabel.textColor = .labelColor
        eventsLabel.lineBreakMode = .byWordWrapping
        eventsLabel.maximumNumberOfLines = 0
        eventsLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(eventsLabel)
        
        NSLayoutConstraint.activate([
            eventsLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            eventsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            eventsLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20)
        ])
        
        return containerView
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
    
    private func createEnhancedTimelineView() -> NSView {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let timelineLabel = NSTextField(labelWithString: "Timeline Visualization\n\nEvent timeline will appear here once data is loaded.")
        timelineLabel.font = NSFont.systemFont(ofSize: 16)
        timelineLabel.textColor = .labelColor
        timelineLabel.lineBreakMode = .byWordWrapping
        timelineLabel.maximumNumberOfLines = 0
        timelineLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(timelineLabel)
        
        NSLayoutConstraint.activate([
            timelineLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            timelineLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            timelineLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20)
        ])
        
        return containerView
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
                
                DispatchQueue.main.async {
                    self.events = eventsArray
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
    }
    
    private func finishLoading() {
        print("🔄 Finishing loading with \(events.count) events")
        loadingIndicator.stopAnimation(nil)
        loadingIndicator.isHidden = true
        
        // Ensure stats are calculated before updating views
        calculateSessionStats()
        updateAllViews()
        
        print("✅ Loading complete - UI updated")
    }
    
    private func updateAllViews() {
        updateOverviewTab()
        updateStatsView()
        updateEventTable()
        updateTimeline()
        updateNotesFromMetadata()
        updateTagsFromMetadata()
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
        timelineView?.setEvents(events)
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
    }
    
    @objc private func zoomTimelineOut() {
        timelineView?.zoomOut()
    }
    
    @objc private func resetTimelineZoom() {
        timelineView?.resetZoom()
    }
    
    @objc private func toggleEventDetails(_ sender: NSButton) {
        timelineView?.showEventDetails = sender.state == .on
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
        return events.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < events.count else { return nil }
        
        let event = events[row]
        let cellView = NSTableCellView()
        
        let textField = NSTextField()
        textField.isBordered = false
        textField.isEditable = false
        textField.backgroundColor = .clear
        textField.font = NSFont.systemFont(ofSize: 16)
        
        switch tableColumn?.identifier.rawValue {
        case "timestamp":
            if let timestamp = event["timestamp"] as? Double {
                textField.stringValue = formatTimestamp(timestamp)
                textField.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
            }
            
        case "source":
            textField.stringValue = (event["source"] as? String ?? "unknown").capitalized
            
        case "type":
            textField.stringValue = (event["type"] as? String ?? "unknown").replacingOccurrences(of: "_", with: " ").capitalized
            
        case "details":
            textField.stringValue = formatEventData(event["data"] as? [String: Any] ?? [:])
            textField.lineBreakMode = .byTruncatingTail
            
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
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 28
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = eventTableView.selectedRow
        if selectedRow >= 0 && selectedRow < events.count {
            let event = events[selectedRow]
            updateTimelineInfo(with: event)
        }
    }
    
    private func updateTimelineInfo(with event: [String: Any]) {
        guard let timelineTab = tabView.tabViewItems.first(where: { $0.label.contains("Timeline") }),
              let containerView = timelineTab.view,
              let infoPanel = containerView.subviews.last,
              let infoLabel = objc_getAssociatedObject(infoPanel, "timelineInfoLabel") as? NSTextField else { return }
        
        var infoText = "Selected Event:\n\n"
        
        if let timestamp = event["timestamp"] as? Double {
            infoText += "Time: \(formatTimestamp(timestamp))\n"
        }
        
        if let source = event["source"] as? String {
            infoText += "Source: \(source.capitalized)\n"
        }
        
        if let type = event["type"] as? String {
            infoText += "Type: \(type.replacingOccurrences(of: "_", with: " ").capitalized)\n"
        }
        
        if let data = event["data"] as? [String: Any] {
            infoText += "\nDetails:\n\(formatEventDataDetailed(data))"
        }
        
        infoLabel.stringValue = infoText
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
    private var zoomLevel: CGFloat = 1.0
    private var panOffset: CGFloat = 0
    var showEventDetails = true
    
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
    
    func zoomIn() {
        zoomLevel = min(zoomLevel * 1.5, 10.0)
        needsDisplay = true
    }
    
    func zoomOut() {
        zoomLevel = max(zoomLevel / 1.5, 0.1)
        needsDisplay = true
    }
    
    func resetZoom() {
        zoomLevel = 1.0
        panOffset = 0
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard !events.isEmpty else {
            drawEmptyState()
            return
        }
        
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        
        drawTimelineBackground()
        drawEventTracks()
        drawTimeAxis()
        
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
        
        // Draw grid lines
        NSColor.separatorColor.setStroke()
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 0.5
        
        // Vertical grid lines
        let stepCount = 10
        for i in 0...stepCount {
            let x = bounds.minX + CGFloat(i) * bounds.width / CGFloat(stepCount)
            gridPath.move(to: NSPoint(x: x, y: bounds.minY))
            gridPath.line(to: NSPoint(x: x, y: bounds.maxY))
        }
        
        gridPath.stroke()
    }
    
    private func drawEventTracks() {
        let margin: CGFloat = 40
        let timelineRect = NSRect(
            x: margin,
            y: margin,
            width: (bounds.width - 2 * margin) * zoomLevel + panOffset,
            height: bounds.height - 2 * margin
        )
        
        // Group events by source
        var eventsBySource: [String: [(Double, [String: Any])]] = [:]
        let duration = endTime - startTime
        
        for event in events {
            guard let timestamp = event["timestamp"] as? Double,
                  let source = event["source"] as? String else { continue }
            
            if eventsBySource[source] == nil {
                eventsBySource[source] = []
            }
            eventsBySource[source]?.append((timestamp, event))
        }
        
        let trackHeight = timelineRect.height / CGFloat(eventsBySource.count)
        var trackIndex: CGFloat = 0
        
        let colors: [String: NSColor] = [
            "focus": .systemBlue,
            "interaction": .systemGreen,
            "system": .systemOrange,
            "custom": .systemPurple
        ]
        
        for (source, sourceEvents) in eventsBySource {
            let color = colors[source] ?? .systemGray
            let trackY = timelineRect.minY + trackIndex * trackHeight
            
            // Draw track background
            color.withAlphaComponent(0.1).setFill()
            NSRect(x: timelineRect.minX, y: trackY, width: timelineRect.width, height: trackHeight).fill()
            
            // Draw events
            for (timestamp, event) in sourceEvents {
                let relativeTime = (timestamp - startTime) / duration
                let x = timelineRect.minX + relativeTime * timelineRect.width
                
                // Event marker
                color.setFill()
                let markerRect = NSRect(x: x - 3, y: trackY + 5, width: 6, height: trackHeight - 10)
                markerRect.fill()
                
                // Event details (if enabled and zoomed in enough)
                if showEventDetails && zoomLevel > 2.0 {
                    if let eventType = event["type"] as? String {
                        let labelAttributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: 16),
                            .foregroundColor: NSColor.labelColor
                        ]
                        let labelSize = eventType.size(withAttributes: labelAttributes)
                        let labelPoint = NSPoint(x: x - labelSize.width/2, y: trackY + trackHeight - 15)
                        eventType.draw(at: labelPoint, withAttributes: labelAttributes)
                    }
                }
            }
            
            // Draw source label
            let label = source.uppercased()
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
            label.draw(at: NSPoint(x: 5, y: trackY + trackHeight/2 - 8), withAttributes: labelAttributes)
            
            trackIndex += 1
        }
    }
    
    private func drawTimeAxis() {
        let margin: CGFloat = 40
        let timelineRect = NSRect(
            x: margin,
            y: margin,
            width: (bounds.width - 2 * margin) * zoomLevel,
            height: bounds.height - 2 * margin
        )
        
        // Draw time axis line
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
        
        let timeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        let startLabel = timeFormatter.string(from: startDate)
        let endLabel = timeFormatter.string(from: endDate)
        
        startLabel.draw(at: NSPoint(x: timelineRect.minX, y: timelineRect.maxY + 25), withAttributes: timeAttributes)
        endLabel.draw(at: NSPoint(x: timelineRect.maxX - 60, y: timelineRect.maxY + 25), withAttributes: timeAttributes)
        
        // Draw intermediate time markers if zoomed in
        if zoomLevel > 1.5 {
            let markerCount = min(Int(zoomLevel * 3), 10)
            let duration = endTime - startTime
            
            for i in 1..<markerCount {
                let progress = CGFloat(i) / CGFloat(markerCount)
                let markerTime = startTime + Double(progress) * duration
                let markerDate = Date(timeIntervalSince1970: markerTime / 1_000_000)
                let markerX = timelineRect.minX + progress * timelineRect.width
                
                // Draw tick mark
                let tickPath = NSBezierPath()
                tickPath.move(to: NSPoint(x: markerX, y: timelineRect.maxY + 15))
                tickPath.line(to: NSPoint(x: markerX, y: timelineRect.maxY + 25))
                tickPath.lineWidth = 0.5
                tickPath.stroke()
                
                // Draw time label
                let markerLabel = timeFormatter.string(from: markerDate)
                markerLabel.draw(at: NSPoint(x: markerX - 25, y: timelineRect.maxY + 27), withAttributes: timeAttributes)
            }
        }
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
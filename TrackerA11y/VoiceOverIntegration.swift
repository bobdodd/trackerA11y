import Cocoa
import ApplicationServices
import AVFoundation
import ScreenCaptureKit

protocol VoiceOverIntegrationDelegate: AnyObject {
    func voiceOverDidAnnounce(text: String, element: [String: Any]?, timestamp: TimeInterval)
    func voiceOverFocusDidChange(element: [String: Any], timestamp: TimeInterval)
    func voiceOverStateDidChange(enabled: Bool)
}

class VoiceOverIntegration {
    weak var delegate: VoiceOverIntegrationDelegate?
    
    private var axObserver: AXObserver?
    private var isMonitoring = false
    private var currentApp: AXUIElement?
    private var systemWideElement: AXUIElement
    
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var isCapturingAudio = false
    private var audioOutputURL: URL?
    
    private var lastAnnouncementText: String = ""
    private var lastAnnouncementTimestamp: Double = 0
    private let deduplicationWindow: Double = 500_000
    
    init() {
        systemWideElement = AXUIElementCreateSystemWide()
    }
    
    // MARK: - VoiceOver Toggle
    
    var isVoiceOverEnabled: Bool {
        let script = "tell application \"System Events\" to get (name of processes) contains \"VoiceOver\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return output == "true"
        } catch {
            return false
        }
    }
    
    func toggleVoiceOver() {
        let script = """
        tell application "System Events"
            key code 96 using {command down}
        end tell
        """
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let enabled = self.isVoiceOverEnabled
                self.delegate?.voiceOverStateDidChange(enabled: enabled)
            }
        } catch {
        }
    }
    
    func enableVoiceOver() {
        if !isVoiceOverEnabled {
            toggleVoiceOver()
        }
    }
    
    func disableVoiceOver() {
        if isVoiceOverEnabled {
            toggleVoiceOver()
        }
    }
    
    // MARK: - Accessibility Monitoring
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        let trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        
        if !trusted {
            return
        }
        
        isMonitoring = true
        
        startNotificationObserver()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            observeApp(pid: frontApp.processIdentifier)
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        
        if let observer = axObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            axObserver = nil
        }
    }
    
    private func startNotificationObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(voiceOverAnnouncementReceived(_:)),
            name: NSNotification.Name("com.apple.VoiceOver.N"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(voiceOverOutputReceived(_:)),
            name: NSNotification.Name("com.apple.accessibility.AXAnnouncementNotification"),
            object: nil
        )
    }
    
    @objc private func voiceOverAnnouncementReceived(_ notification: Notification) {
        let timestamp = Date().timeIntervalSince1970 * 1_000_000
        let text = notification.userInfo?["AXAnnouncementKey"] as? String ?? "Unknown announcement"
        
        delegate?.voiceOverDidAnnounce(text: text, element: nil, timestamp: timestamp)
    }
    
    @objc private func voiceOverOutputReceived(_ notification: Notification) {
        let timestamp = Date().timeIntervalSince1970 * 1_000_000
        let userInfo = notification.userInfo as? [String: Any]
        let text = userInfo?["AXAnnouncement"] as? String ?? notification.object as? String ?? "Unknown"
        
        delegate?.voiceOverDidAnnounce(text: text, element: nil, timestamp: timestamp)
    }
    
    @objc private func activeAppChanged(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        observeApp(pid: app.processIdentifier)
    }
    
    private func observeApp(pid: pid_t) {
        if let observer = axObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        
        let appElement = AXUIElementCreateApplication(pid)
        currentApp = appElement
        
        var observer: AXObserver?
        let result = AXObserverCreate(pid, axCallback, &observer)
        
        if result == .success, let observer = observer {
            axObserver = observer
            
            let notifications: [String] = [
                kAXFocusedUIElementChangedNotification,
                kAXAnnouncementRequestedNotification
            ]
            
            for notification in notifications {
                AXObserverAddNotification(observer, appElement, notification as CFString, Unmanaged.passUnretained(self).toOpaque())
            }
            
            CFRunLoopAddSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
    }
    
    func handleAccessibilityNotification(_ notification: String, element: AXUIElement) {
        let timestamp = Date().timeIntervalSince1970 * 1_000_000
        let elementInfo = extractElementInfo(element)
        
        switch notification {
        case kAXFocusedUIElementChangedNotification:
            let description = buildVoiceOverDescription(from: elementInfo)
            if !description.isEmpty {
                if description == lastAnnouncementText && (timestamp - lastAnnouncementTimestamp) < deduplicationWindow {
                    return
                }
                lastAnnouncementText = description
                lastAnnouncementTimestamp = timestamp
                delegate?.voiceOverDidAnnounce(text: description, element: elementInfo, timestamp: timestamp)
            }
            
        case kAXAnnouncementRequestedNotification:
            var announcement: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXAnnouncementKey as CFString, &announcement)
            if let text = announcement as? String, !text.isEmpty {
                if text == lastAnnouncementText && (timestamp - lastAnnouncementTimestamp) < deduplicationWindow {
                    return
                }
                lastAnnouncementText = text
                lastAnnouncementTimestamp = timestamp
                delegate?.voiceOverDidAnnounce(text: text, element: elementInfo, timestamp: timestamp)
            }
            
        default:
            break
        }
    }
    
    private func extractElementInfo(_ element: AXUIElement) -> [String: Any] {
        var info: [String: Any] = [:]
        
        let attributes: [(String, String)] = [
            (kAXRoleAttribute, "role"),
            (kAXRoleDescriptionAttribute, "roleDescription"),
            (kAXTitleAttribute, "title"),
            (kAXDescriptionAttribute, "description"),
            (kAXValueAttribute, "value"),
            (kAXLabelValueAttribute, "label"),
            (kAXHelpAttribute, "help"),
            (kAXPlaceholderValueAttribute, "placeholder"),
            (kAXSelectedTextAttribute, "selectedText"),
            (kAXEnabledAttribute, "enabled"),
            (kAXFocusedAttribute, "focused")
        ]
        
        for (axAttr, key) in attributes {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, axAttr as CFString, &value) == .success {
                if let stringValue = value as? String {
                    info[key] = stringValue
                } else if let boolValue = value as? Bool {
                    info[key] = boolValue
                } else if let numberValue = value as? NSNumber {
                    info[key] = numberValue
                }
            }
        }
        
        var position: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
           let positionValue = position {
            var point = CGPoint.zero
            if AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) {
                info["x"] = point.x
                info["y"] = point.y
            }
        }
        
        var size: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
           let sizeValue = size {
            var sizeRect = CGSize.zero
            if AXValueGetValue(sizeValue as! AXValue, .cgSize, &sizeRect) {
                info["width"] = sizeRect.width
                info["height"] = sizeRect.height
            }
        }
        
        return info
    }
    
    private func buildVoiceOverDescription(from info: [String: Any]) -> String {
        var parts: [String] = []
        
        if let roleDesc = info["roleDescription"] as? String {
            parts.append(roleDesc)
        } else if let role = info["role"] as? String {
            parts.append(role.replacingOccurrences(of: "AX", with: ""))
        }
        
        if let title = info["title"] as? String, !title.isEmpty {
            parts.append(title)
        }
        
        if let label = info["label"] as? String, !label.isEmpty {
            parts.append(label)
        }
        
        if let description = info["description"] as? String, !description.isEmpty {
            parts.append(description)
        }
        
        if let value = info["value"] as? String, !value.isEmpty {
            parts.append(value)
        }
        
        if let help = info["help"] as? String, !help.isEmpty {
            parts.append("(\(help))")
        }
        
        return parts.joined(separator: ", ")
    }
    
    // MARK: - Audio Capture
    
    func startAudioCapture(outputURL: URL) {
        guard !isCapturingAudio else { return }
        
        audioOutputURL = outputURL
        
        if #available(macOS 13.0, *) {
            startScreenCaptureKitAudio(outputURL: outputURL)
        } else {
            startAVAudioEngineCapture(outputURL: outputURL)
        }
    }
    
    func stopAudioCapture() {
        guard isCapturingAudio else { return }
        
        isCapturingAudio = false
        
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
    }
    
    @available(macOS 13.0, *)
    private func startScreenCaptureKitAudio(outputURL: URL) {
        Task {
            do {
                let content = try await SCShareableContent.current
                
                guard let display = content.displays.first else {
                    return
                }
                
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                let config = SCStreamConfiguration()
                config.capturesAudio = true
                config.excludesCurrentProcessAudio = false
                config.width = 2
                config.height = 2
                config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                
                isCapturingAudio = true
                
            } catch {
                startAVAudioEngineCapture(outputURL: outputURL)
            }
        }
    }
    
    private func startAVAudioEngineCapture(outputURL: URL) {
        audioEngine = AVAudioEngine()
        
        guard let engine = audioEngine else { return }
        
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        do {
            audioFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
        } catch {
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            try? self?.audioFile?.write(from: buffer)
        }
        
        do {
            try engine.start()
            isCapturingAudio = true
        } catch {
        }
    }
    
    deinit {
        stopMonitoring()
        stopAudioCapture()
    }
}

private func axCallback(observer: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) {
    guard let refcon = refcon else { return }
    let integration = Unmanaged<VoiceOverIntegration>.fromOpaque(refcon).takeUnretainedValue()
    
    DispatchQueue.main.async {
        integration.handleAccessibilityNotification(notification as String, element: element)
    }
}

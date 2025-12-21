import Foundation
import Cocoa

protocol TrackerBridgeDelegate: AnyObject {
    func trackerDidCaptureEvent()
    func trackerDidEncounterError(_ error: String)
    func trackerDidInitialize()
}

class TrackerBridge: NSObject {
    weak var delegate: TrackerBridgeDelegate?
    private var isInitialized = false
    private var isTracking = false
    private var isPaused = false
    private var currentSessionId: String?
    private var eventTimer: Timer?
    
    // Node.js process for running TrackerA11y Core
    private var nodeProcess: Process?
    private var trackerTask: Process?
    
    func initialize() {
        // Initialize the bridge to TrackerA11y Core
        setupNodeBridge()
        isInitialized = true
        delegate?.trackerDidInitialize()
    }
    
    private func setupNodeBridge() {
        // Set up communication with Node.js TrackerA11y Core
        // This will run the existing TypeScript tracker in a subprocess
        
        print("🔧 Setting up Node.js bridge for TrackerA11y Core")
        
        // For now, simulate the tracker initialization
        // In a real implementation, this would:
        // 1. Start a Node.js process running TrackerA11y Core
        // 2. Set up IPC communication
        // 3. Handle events from the Node.js process
        
        DispatchQueue.global(qos: .background).async {
            // Simulate async initialization
            sleep(1)
            DispatchQueue.main.async {
                print("✅ Node.js bridge ready")
            }
        }
    }
    
    func startTracking(sessionId: String) {
        print("🔧 DEBUG: startTracking() called with sessionId: \(sessionId)")
        print("🔍 DEBUG: isInitialized: \(isInitialized)")
        print("🔍 DEBUG: isTracking: \(isTracking)")
        
        guard isInitialized else {
            print("❌ DEBUG: Tracker not initialized")
            delegate?.trackerDidEncounterError("Tracker not initialized")
            return
        }
        
        guard !isTracking else {
            print("❌ DEBUG: Tracking already in progress")
            delegate?.trackerDidEncounterError("Tracking already in progress")
            return
        }
        
        currentSessionId = sessionId
        isTracking = true
        
        print("✅ DEBUG: Starting tracker core...")
        
        // Start the actual TrackerA11y Core
        startTrackerCore()
        
        // Simulate event capture for demo
        startEventSimulation()
        
        print("🚀 TrackerA11y Core started for session: \(sessionId)")
    }
    
    func stopTracking() {
        print("🔧 DEBUG: stopTracking() called")
        print("🔍 DEBUG: isTracking: \(isTracking)")
        
        guard isTracking else { 
            print("❌ DEBUG: Not tracking, returning early")
            return 
        }
        
        print("✅ DEBUG: Stopping tracking...")
        
        isTracking = false
        isPaused = false
        let stoppedSessionId = currentSessionId
        currentSessionId = nil
        
        print("🔍 DEBUG: Stopped session: \(stoppedSessionId ?? "nil")")
        
        // Stop event simulation
        stopEventSimulation()
        
        // Stop the TrackerA11y Core
        stopTrackerCore()
        
        print("⏹️ TrackerA11y Core stopped")
    }
    
    func pauseTracking() {
        guard isTracking && !isPaused else { return }
        
        isPaused = true
        
        // Pause event simulation
        pauseEventSimulation()
        
        // Send SIGUSR1 to the node process running event-recorder-demo
        if let pid = findNodeProcessByPattern("event-recorder-demo") {
            kill(pid, SIGUSR1)
            print("⏸ Sent SIGUSR1 (pause) to node process (PID: \(pid))")
        } else {
            print("⚠️ Could not find node process to pause")
        }
        
        print("⏸ TrackerA11y Core paused")
    }
    
    func resumeTracking() {
        guard isTracking && isPaused else { return }
        
        isPaused = false
        
        // Resume event simulation
        resumeEventSimulation()
        
        // Send SIGUSR2 to the node process running event-recorder-demo
        if let pid = findNodeProcessByPattern("event-recorder-demo") {
            kill(pid, SIGUSR2)
            print("▶️ Sent SIGUSR2 (resume) to node process (PID: \(pid))")
        } else {
            print("⚠️ Could not find node process to resume")
        }
        
        print("▶️ TrackerA11y Core resumed")
    }
    
    private func findNodeProcessByPattern(_ pattern: String) -> Int32? {
        // Use pgrep to quickly find the node process - this is fast and non-blocking
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", pattern]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // pgrep returns PIDs one per line, take the first one
                let pids = output.split(separator: "\n").compactMap { Int32($0) }
                if let pid = pids.first {
                    return pid
                }
            }
        } catch {
            print("⚠️ pgrep failed: \(error)")
        }
        return nil
    }
    
    
    private func startTrackerCore() {
        print("🔧 DEBUG: startTrackerCore() called")
        
        // Use the existing TrackerA11y recording system
        guard let projectPath = findProjectPath() else {
            print("❌ DEBUG: Could not find project path")
            delegate?.trackerDidEncounterError("Could not find TrackerA11y project path")
            return
        }
        
        print("✅ DEBUG: Found project path: \(projectPath)")
        
        // Stop any existing process first
        stopTrackerCore()
        
        print("🚀 Starting TrackerA11y recording process...")
        print("📁 Project path: \(projectPath)")
        print("🔍 DEBUG: Current working directory: \(FileManager.default.currentDirectoryPath)")
        print("💻 DEBUG: About to start npm process...")
        
        // Capture session ID for use in async block
        let capturedSessionId = currentSessionId ?? "unknown"
        
        DispatchQueue.global(qos: .background).async {
            print("📋 DEBUG: In background queue, setting up process...")
            
            // Use the existing npm recording script
            self.nodeProcess = Process()
            self.nodeProcess?.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/npm")
            self.nodeProcess?.arguments = ["run", "demo:recorder"]
            self.nodeProcess?.currentDirectoryURL = URL(fileURLWithPath: projectPath)
            
            // Start the process in its own process group so we can kill all children
            self.nodeProcess?.qualityOfService = .userInitiated
            
            // Pass session ID to Node.js recorder via environment
            var env = ProcessInfo.processInfo.environment
            env["TRACKER_SESSION_ID"] = capturedSessionId
            self.nodeProcess?.environment = env
            
            print("🔍 DEBUG: Process setup complete")
            print("🔍 DEBUG: Executable: /opt/homebrew/bin/npm")
            print("🔍 DEBUG: Arguments: ['run', 'demo:recorder']")
            print("🔍 DEBUG: Working directory: \(projectPath)")
            
            // Set up termination handler
            self.nodeProcess?.terminationHandler = { process in
                DispatchQueue.main.async {
                    print("📊 DEBUG: Recording process terminated with status: \(process.terminationStatus)")
                    if process.terminationStatus == 0 {
                        print("✅ DEBUG: Recording completed successfully")
                    } else {
                        print("⚠️ DEBUG: Recording process ended with error code: \(process.terminationStatus)")
                    }
                }
            }
            
            do {
                print("🚀 DEBUG: About to call process.run()...")
                try self.nodeProcess?.run()
                print("✅ DEBUG: process.run() succeeded - recording should be starting")
                print("🔍 DEBUG: Process PID: \(self.nodeProcess?.processIdentifier ?? 0)")
                print("🔍 DEBUG: Process is running: \(self.nodeProcess?.isRunning ?? false)")
                
                // Keep the process alive in background
                DispatchQueue.main.async {
                    print("🔴 DEBUG: Recording is now active. Use Stop Recording to end session.")
                }
                
            } catch {
                print("❌ DEBUG: process.run() failed with error: \(error)")
                DispatchQueue.main.async {
                    self.delegate?.trackerDidEncounterError("Failed to start TrackerA11y recording: \(error.localizedDescription)")
                    print("❌ Failed to start recording: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func stopTrackerCore() {
        print("🔧 DEBUG: stopTrackerCore() called")
        killNodeProcess(synchronous: false)
    }
    
    private func killNodeProcess(synchronous: Bool) {
        guard let process = nodeProcess else {
            print("⚠️ DEBUG: No recording process to stop")
            return
        }
        
        let pid = process.processIdentifier
        print("🛑 DEBUG: Stopping TrackerA11y recording process (PID: \(pid))...")
        print("🔍 DEBUG: Process is running: \(process.isRunning)")
        
        // Kill child processes first (node spawned by npm)
        killChildProcesses(parentPid: pid, signal: SIGINT)
        
        // Send SIGINT to the main process
        print("📤 DEBUG: Sending SIGINT to npm process...")
        kill(pid, SIGINT)
        
        if synchronous {
            // For app termination, wait synchronously
            var waitCount = 0
            while process.isRunning && waitCount < 30 {
                Thread.sleep(forTimeInterval: 0.1)
                waitCount += 1
            }
            
            if process.isRunning {
                print("⚠️ Process still running after 3s, sending SIGKILL...")
                killChildProcesses(parentPid: pid, signal: SIGKILL)
                kill(pid, SIGKILL)
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            // Final cleanup: kill any remaining node processes from our session
            killTrackerNodeProcesses()
            
            print("✅ Recording process terminated (synchronous)")
            nodeProcess = nil
        } else {
            // Non-blocking termination with fallback
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if process.isRunning {
                    print("⚠️ Process still running, sending SIGTERM...")
                    self.killChildProcesses(parentPid: pid, signal: SIGTERM)
                    kill(pid, SIGTERM)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if process.isRunning {
                            print("⚠️ Process still running, sending SIGKILL...")
                            self.killChildProcesses(parentPid: pid, signal: SIGKILL)
                            kill(pid, SIGKILL)
                        }
                        // Final cleanup of any orphaned processes
                        self.killTrackerNodeProcesses()
                        self.nodeProcess = nil
                        print("✅ Recording process terminated")
                    }
                } else {
                    // Still clean up any orphaned helpers
                    self.killTrackerNodeProcesses()
                    print("✅ Recording process stopped gracefully")
                    self.nodeProcess = nil
                }
            }
            
            // Notify about session creation
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("✅ Recording stopped - new session should be created in recordings/ directory")
                print("💡 Tip: Click 'View Sessions' to see the new recording session")
            }
        }
    }
    
    private func killChildProcesses(parentPid: Int32, signal: Int32) {
        // Use pgrep to find child processes
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-P", String(parentPid)]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let childPids = output.split(separator: "\n").compactMap { Int32($0) }
                for childPid in childPids {
                    print("📤 Sending signal \(signal) to child process \(childPid)")
                    // Recursively kill grandchildren first
                    killChildProcesses(parentPid: childPid, signal: signal)
                    kill(childPid, signal)
                }
            }
        } catch {
            print("⚠️ Failed to find child processes: \(error)")
        }
    }
    
    private func killTrackerNodeProcesses() {
        // Kill any orphaned processes from our recording session
        let processPatterns = [
            "event-recorder-demo",  // ts-node recorder
            "mouse_capture"         // native mouse capture helper
        ]
        
        for pattern in processPatterns {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            task.arguments = ["-f", pattern]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                // Ignore errors - process may not exist
            }
        }
        print("🧹 Cleaned up any orphaned tracker processes")
    }
    
    private func findProjectPath() -> String? {
        // Find the TrackerA11y project directory by looking for package.json
        let possiblePaths = [
            "/Users/bob3/Desktop/trackerA11y",  // Most likely location
            FileManager.default.currentDirectoryPath,
            "\(FileManager.default.currentDirectoryPath)/..",
            Bundle.main.bundleURL.deletingLastPathComponent().path,
            Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().path
        ]
        
        for path in possiblePaths {
            // Look for package.json to identify TrackerA11y project
            if FileManager.default.fileExists(atPath: "\(path)/package.json") {
                // Verify it's the TrackerA11y project by checking for recordings directory
                if FileManager.default.fileExists(atPath: "\(path)/recordings") {
                    print("🔍 Found TrackerA11y project at: \(path)")
                    return path
                }
            }
        }
        
        print("❌ TrackerA11y project not found in any of these paths:")
        for path in possiblePaths {
            print("   - \(path)")
        }
        return nil
    }
    
    // MARK: - Event Simulation (for demo purposes)
    private func startEventSimulation() {
        eventTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if self.isTracking && !self.isPaused {
                self.delegate?.trackerDidCaptureEvent()
            }
        }
    }
    
    private func pauseEventSimulation() {
        // Timer keeps running but events are not triggered due to isPaused check
        print("⏸ Event simulation paused")
    }
    
    private func resumeEventSimulation() {
        // Events will resume automatically as isPaused is now false
        print("▶️ Event simulation resumed")
    }
    
    private func stopEventSimulation() {
        eventTimer?.invalidate()
        eventTimer = nil
    }
    
    func cleanup() {
        print("🔧 DEBUG: TrackerBridge.cleanup() called (async version)")
        stopTracking()
        stopTrackerCore()
    }
    
    func cleanupSynchronously() {
        print("🔧 DEBUG: cleanupSynchronously() called")
        stopEventSimulation()
        isTracking = false
        isPaused = false
        currentSessionId = nil
        killNodeProcess(synchronous: true)
        // Always clean up orphaned processes even if nodeProcess was already nil
        killTrackerNodeProcesses()
        print("🔧 DEBUG: cleanupSynchronously() completed")
    }
}

// MARK: - Real TrackerA11y Integration Functions
extension TrackerBridge {
    
    private func runTrackerDemo() {
        // Run one of the existing TrackerA11y demos
        guard let projectPath = findProjectPath() else { return }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/npm")
        task.arguments = ["run", "demo:enhanced"]
        task.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        
        do {
            try task.run()
            print("✅ Started TrackerA11y demo")
        } catch {
            delegate?.trackerDidEncounterError("Failed to start demo: \(error.localizedDescription)")
        }
    }
    
    private func connectToMongoDB() {
        // Connect to MongoDB for data storage
        // This would integrate with the existing MongoDBStore
        print("🗄️ Connecting to MongoDB...")
    }
    
    private func exportSessionData() -> [String: Any] {
        // Export session data using existing TrackerA11y functionality
        return [
            "sessionId": currentSessionId ?? "",
            "events": [],
            "metadata": [
                "platform": "macOS",
                "appVersion": "1.0.0",
                "timestamp": Date().timeIntervalSince1970
            ]
        ]
    }
}
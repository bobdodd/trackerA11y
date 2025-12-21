import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia

enum ScreenRecorderState {
    case idle
    case recording
    case paused
}

protocol ScreenRecorderDelegate: AnyObject {
    func screenRecorderDidStartRecording()
    func screenRecorderDidStopRecording(outputURL: URL?)
    func screenRecorderDidPauseRecording(interimURL: URL?)
    func screenRecorderDidResumeRecording()
    func screenRecorderDidFail(error: Error)
}

@available(macOS 12.3, *)
class ScreenRecorder: NSObject {
    
    weak var delegate: ScreenRecorderDelegate?
    
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?
    private var microphoneInput: AVAssetWriterInput?
    
    private var videoQueue = DispatchQueue(label: "com.trackera11y.screenrecorder.video", qos: .userInitiated)
    private var audioQueue = DispatchQueue(label: "com.trackera11y.screenrecorder.audio", qos: .userInitiated)
    private var frameCount: Int = 0
    
    private(set) var state: ScreenRecorderState = .idle
    private var outputURL: URL?
    private var startTime: CMTime?
    private var lastFrameTime: CMTime?
    private var totalPausedDuration: CMTime = .zero
    private var sessionStartTimestamp: Double = 0
    
    private var streamConfiguration: SCStreamConfiguration?
    private var contentFilter: SCContentFilter?
    
    private var segmentURLs: [URL] = []
    private var currentSegmentIndex: Int = 0
    private var baseOutputURL: URL?
    private var displayWidth: Int = 0
    private var displayHeight: Int = 0
    
    var recordingStartTimestamp: Double {
        return sessionStartTimestamp
    }
    
    func requestPermissions() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return true
        } catch {
            print("❌ Screen recording permission denied: \(error)")
            return false
        }
    }
    
    func startRecording(to outputURL: URL) async throws {
        guard state == .idle else {
            throw ScreenRecorderError.alreadyRecording
        }
        
        self.baseOutputURL = outputURL
        let segment0URL = createSegmentURL(index: 0)
        self.outputURL = segment0URL
        self.segmentURLs = []
        self.currentSegmentIndex = 0
        sessionStartTimestamp = Date().timeIntervalSince1970 * 1_000_000
        
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        
        guard let display = content.displays.first else {
            throw ScreenRecorderError.noDisplayFound
        }
        
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 5
        config.showsCursor = true
        config.capturesAudio = false
        
        displayWidth = config.width
        displayHeight = config.height
        streamConfiguration = config
        
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        contentFilter = filter
        
        try setupAssetWriter(outputURL: segment0URL, width: config.width, height: config.height)
        try setupMicrophoneCapture()
        
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
        
        try await stream?.startCapture()
        
        state = .recording
        startTime = nil
        lastFrameTime = nil
        totalPausedDuration = .zero
        frameCount = 0
        
        DispatchQueue.main.async {
            self.delegate?.screenRecorderDidStartRecording()
        }
        
        print("🎬 Screen recording started: \(segment0URL.lastPathComponent)")
    }
    
    func pauseRecording() async {
        guard state == .recording else { return }
        
        state = .paused
        
        await finishCurrentSegment()
        
        if let url = outputURL {
            segmentURLs.append(url)
        }
        
        var interimURL: URL? = nil
        
        if segmentURLs.count == 1 {
            if let segment = segmentURLs.first, let base = baseOutputURL {
                do {
                    if FileManager.default.fileExists(atPath: base.path) {
                        try FileManager.default.removeItem(at: base)
                    }
                    try FileManager.default.copyItem(at: segment, to: base)
                    interimURL = base
                } catch {
                    print("⚠️ Could not copy segment to base: \(error)")
                    interimURL = segment
                }
            }
        } else if segmentURLs.count > 1 {
            interimURL = await mergeSegmentsForInterim()
        }
        
        DispatchQueue.main.async {
            self.delegate?.screenRecorderDidPauseRecording(interimURL: interimURL)
        }
        
        print("⏸ Screen recording paused - \(segmentURLs.count) segment(s), merged video available")
    }
    
    private func mergeSegmentsForInterim() async -> URL? {
        guard let baseURL = baseOutputURL else { return segmentURLs.last }
        
        print("🎬 Merging \(segmentURLs.count) segments for interim review...")
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("❌ Failed to create video track")
            return segmentURLs.last
        }
        
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var currentTime = CMTime.zero
        
        for segmentURL in segmentURLs {
            let asset = AVAsset(url: segmentURL)
            
            do {
                let duration = try await asset.load(.duration)
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                
                if let sourceVideoTrack = videoTracks.first {
                    try videoTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: sourceVideoTrack,
                        at: currentTime
                    )
                }
                
                if let sourceAudioTrack = audioTracks.first, let audioTrack = audioTrack {
                    try audioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: sourceAudioTrack,
                        at: currentTime
                    )
                }
                
                currentTime = CMTimeAdd(currentTime, duration)
            } catch {
                print("⚠️ Error processing segment \(segmentURL.lastPathComponent): \(error)")
            }
        }
        
        if FileManager.default.fileExists(atPath: baseURL.path) {
            try? FileManager.default.removeItem(at: baseURL)
        }
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("❌ Failed to create export session")
            return segmentURLs.last
        }
        
        exportSession.outputURL = baseURL
        exportSession.outputFileType = .mp4
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            print("✅ Interim merge complete: \(baseURL.lastPathComponent)")
            return baseURL
        } else {
            print("❌ Interim merge failed: \(exportSession.error?.localizedDescription ?? "unknown")")
            return segmentURLs.last
        }
    }
    
    func resumeRecording() async throws {
        guard state == .paused else { return }
        
        currentSegmentIndex += 1
        let segmentURL = createSegmentURL(index: currentSegmentIndex)
        outputURL = segmentURL
        
        try setupAssetWriter(outputURL: segmentURL, width: displayWidth, height: displayHeight)
        
        startTime = nil
        lastFrameTime = nil
        
        state = .recording
        
        DispatchQueue.main.async {
            self.delegate?.screenRecorderDidResumeRecording()
        }
        
        print("▶️ Screen recording resumed - new segment: \(segmentURL.lastPathComponent)")
    }
    
    private func createSegmentURL(index: Int) -> URL {
        guard let baseURL = baseOutputURL else {
            return URL(fileURLWithPath: "/tmp/recording_segment_\(index).mp4")
        }
        let baseName = baseURL.deletingPathExtension().lastPathComponent
        let directory = baseURL.deletingLastPathComponent()
        return directory.appendingPathComponent("\(baseName)_segment\(index).mp4")
    }
    
    private func finishCurrentSegment() async {
        guard let writer = assetWriter else { return }
        
        guard writer.status == .writing else {
            print("⚠️ Asset writer was not writing")
            assetWriter = nil
            videoInput = nil
            audioInput = nil
            pixelBufferAdaptor = nil
            return
        }
        
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                if writer.status == .completed {
                    print("✅ Segment written successfully")
                } else if let error = writer.error {
                    print("❌ Failed to write segment: \(error)")
                }
                continuation.resume()
            }
        }
        
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
    }
    
    func stopRecording() async {
        guard state != .idle else { return }
        
        let wasRecording = state == .recording
        state = .idle
        
        do {
            try await stream?.stopCapture()
        } catch {
            print("⚠️ Error stopping stream: \(error)")
        }
        
        stream = nil
        
        stopMicrophoneCapture()
        
        if wasRecording {
            await finishCurrentSegment()
            if let url = outputURL {
                segmentURLs.append(url)
            }
        }
        
        var finalURL: URL? = nil
        
        if segmentURLs.count == 1 {
            finalURL = segmentURLs.first
            if let base = baseOutputURL, let segment = finalURL, segment != base {
                do {
                    if FileManager.default.fileExists(atPath: base.path) {
                        try FileManager.default.removeItem(at: base)
                    }
                    try FileManager.default.moveItem(at: segment, to: base)
                    finalURL = base
                } catch {
                    print("⚠️ Could not rename segment to final: \(error)")
                }
            }
        } else if segmentURLs.count > 1 {
            finalURL = await mergeSegments()
        }
        
        DispatchQueue.main.async {
            self.delegate?.screenRecorderDidStopRecording(outputURL: finalURL)
        }
        
        print("⏹ Screen recording stopped (captured \(frameCount) frames, \(segmentURLs.count) segments)")
    }
    
    private func mergeSegments() async -> URL? {
        guard let baseURL = baseOutputURL else { return segmentURLs.first }
        
        print("🎬 Merging \(segmentURLs.count) video segments...")
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("❌ Failed to create video track")
            return segmentURLs.first
        }
        
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var currentTime = CMTime.zero
        
        for segmentURL in segmentURLs {
            let asset = AVAsset(url: segmentURL)
            
            do {
                let duration = try await asset.load(.duration)
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                
                if let sourceVideoTrack = videoTracks.first {
                    try videoTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: sourceVideoTrack,
                        at: currentTime
                    )
                }
                
                if let sourceAudioTrack = audioTracks.first, let audioTrack = audioTrack {
                    try audioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: duration),
                        of: sourceAudioTrack,
                        at: currentTime
                    )
                }
                
                currentTime = CMTimeAdd(currentTime, duration)
            } catch {
                print("⚠️ Error processing segment \(segmentURL.lastPathComponent): \(error)")
            }
        }
        
        let exportURL = baseURL
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try? FileManager.default.removeItem(at: exportURL)
        }
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            print("❌ Failed to create export session")
            return segmentURLs.first
        }
        
        exportSession.outputURL = exportURL
        exportSession.outputFileType = .mp4
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            print("✅ Segments merged successfully")
            for segmentURL in segmentURLs where segmentURL != baseURL {
                try? FileManager.default.removeItem(at: segmentURL)
            }
            return exportURL
        } else {
            print("❌ Failed to merge segments: \(exportSession.error?.localizedDescription ?? "unknown")")
            return segmentURLs.first
        }
    }
    
    private func setupAssetWriter(outputURL: URL, width: Int, height: Int) throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 30
            ]
        ]
        
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        
        if let videoInput = videoInput, assetWriter?.canAdd(videoInput) == true {
            assetWriter?.add(videoInput)
            
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )
        }
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000
        ]
        
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true
        
        if let audioInput = audioInput, assetWriter?.canAdd(audioInput) == true {
            assetWriter?.add(audioInput)
        }
    }
    
    private var audioCaptureSession: AVCaptureSession?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    
    private func setupMicrophoneCapture() throws {
        audioCaptureSession = AVCaptureSession()
        
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            print("⚠️ No microphone found")
            return
        }
        
        do {
            let micInput = try AVCaptureDeviceInput(device: microphone)
            if audioCaptureSession?.canAddInput(micInput) == true {
                audioCaptureSession?.addInput(micInput)
            }
            
            audioDataOutput = AVCaptureAudioDataOutput()
            audioDataOutput?.setSampleBufferDelegate(self, queue: audioQueue)
            
            if let output = audioDataOutput, audioCaptureSession?.canAddOutput(output) == true {
                audioCaptureSession?.addOutput(output)
            }
            
            audioCaptureSession?.startRunning()
            print("🎤 Microphone capture started")
        } catch {
            print("⚠️ Failed to setup microphone: \(error)")
        }
    }
    
    private func stopMicrophoneCapture() {
        audioCaptureSession?.stopRunning()
        audioCaptureSession = nil
        audioDataOutput = nil
    }
    
    private func finishWriting() async {
        guard let writer = assetWriter else { return }
        
        // Only finish if we actually started writing
        guard writer.status == .writing else {
            print("⚠️ Asset writer was never started (no frames captured)")
            if let url = outputURL {
                try? FileManager.default.removeItem(at: url)
            }
            assetWriter = nil
            videoInput = nil
            audioInput = nil
            pixelBufferAdaptor = nil
            return
        }
        
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                if writer.status == .completed {
                    print("✅ Video file written successfully")
                } else if let error = writer.error {
                    print("❌ Failed to write video: \(error)")
                }
                continuation.resume()
            }
        }
        
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
    }
    
    private func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if state == .paused {
            lastFrameTime = currentTime
            return 
        }
        
        guard state == .recording else { return }
        guard let writer = assetWriter, let input = videoInput else { return }
        guard writer.status != .failed else { return }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        if writer.status == .unknown {
            startTime = currentTime
            lastFrameTime = currentTime
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            print("🎬 Asset writer started")
        }
        
        guard writer.status == .writing else {
            if writer.status == .failed {
                print("❌ Writer failed: \(writer.error?.localizedDescription ?? "unknown")")
            }
            return
        }
        guard input.isReadyForMoreMediaData else { return }
        guard let start = startTime else { return }
        
        if let lastTime = lastFrameTime {
            let gap = CMTimeSubtract(currentTime, lastTime)
            if gap.seconds > 0.5 {
                totalPausedDuration = CMTimeAdd(totalPausedDuration, CMTimeSubtract(gap, CMTimeMake(value: 1, timescale: 30)))
                print("🎬 Detected pause gap of \(gap.seconds)s, adjusted totalPausedDuration")
            }
        }
        lastFrameTime = currentTime
        
        var adjustedTime = CMTimeSubtract(currentTime, start)
        adjustedTime = CMTimeSubtract(adjustedTime, totalPausedDuration)
        
        if adjustedTime.seconds < 0 { return }
        
        if let adaptor = pixelBufferAdaptor {
            adaptor.append(imageBuffer, withPresentationTime: adjustedTime)
        } else {
            if let adjustedBuffer = createAdjustedSampleBuffer(sampleBuffer, newTime: adjustedTime) {
                input.append(adjustedBuffer)
            }
        }
        
        frameCount += 1
        if frameCount == 1 {
            print("🎬 First video frame captured")
        }
    }
    
    private func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard state == .recording else { return }
        guard let writer = assetWriter, let input = audioInput else { return }
        guard writer.status == .writing else { return }
        guard input.isReadyForMoreMediaData else { return }
        guard let start = startTime else { return }
        
        let originalTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        var adjustedTime = CMTimeSubtract(originalTime, start)
        adjustedTime = CMTimeSubtract(adjustedTime, totalPausedDuration)
        
        if adjustedTime.seconds < 0 { return }
        
        guard let adjustedBuffer = createAdjustedAudioSampleBuffer(sampleBuffer, newTime: adjustedTime) else { return }
        
        input.append(adjustedBuffer)
    }
    
    private func createAdjustedSampleBuffer(_ sampleBuffer: CMSampleBuffer, newTime: CMTime) -> CMSampleBuffer? {
        var timingInfo = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sampleBuffer),
            presentationTimeStamp: newTime,
            decodeTimeStamp: .invalid
        )
        
        var adjustedBuffer: CMSampleBuffer?
        
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: nil,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &adjustedBuffer
        )
        
        return status == noErr ? adjustedBuffer : nil
    }
    
    private func createAdjustedAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer, newTime: CMTime) -> CMSampleBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        var timingInfo = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sampleBuffer),
            presentationTimeStamp: newTime,
            decodeTimeStamp: .invalid
        )
        
        var adjustedBuffer: CMSampleBuffer?
        
        let status = CMSampleBufferCreate(
            allocator: nil,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: numSamples,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &adjustedBuffer
        )
        
        return status == noErr ? adjustedBuffer : nil
    }
}

@available(macOS 12.3, *)
extension ScreenRecorder: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("❌ Stream stopped with error: \(error)")
        DispatchQueue.main.async {
            self.delegate?.screenRecorderDidFail(error: error)
        }
    }
}

@available(macOS 12.3, *)
extension ScreenRecorder: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        switch type {
        case .screen:
            appendVideoSampleBuffer(sampleBuffer)
        case .audio:
            break
        case .microphone:
            break
        @unknown default:
            break
        }
    }
}

@available(macOS 12.3, *)
extension ScreenRecorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        appendAudioSampleBuffer(sampleBuffer)
    }
}

enum ScreenRecorderError: Error, LocalizedError {
    case alreadyRecording
    case noDisplayFound
    case permissionDenied
    case setupFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Screen recording is already in progress"
        case .noDisplayFound:
            return "No display found for recording"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .setupFailed(let message):
            return "Setup failed: \(message)"
        }
    }
}

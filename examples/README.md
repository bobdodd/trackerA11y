# TrackerA11y Examples

This directory contains demonstration applications showcasing TrackerA11y's capabilities.

## Available Demos

### 1. Focus Tracking Demo (`focus-tracking-demo.ts`)
Demonstrates real-time application focus tracking on macOS.

**Features:**
- Cross-platform focus detection
- Window title and process ID tracking
- Accessibility context information
- Real-time event monitoring

**Usage:**
```bash
npm run ts-node examples/focus-tracking-demo.ts
```

### 2. Audio Processing Demo (`audio-processing-demo.ts`)
Showcases the Python ML pipeline integration for audio analysis.

**Features:**
- Real-time audio recording
- Speaker diarization
- Speech transcription
- Multi-language support

**Prerequisites:**
```bash
pip install -r audio_pipeline/requirements.txt
```

**Usage:**
```bash
npm run ts-node examples/audio-processing-demo.ts
```

### 3. Event Correlation Demo (`correlation-demo.ts`)
Demonstrates the advanced event correlation engine that ties everything together.

**Features:**
- Real-time event correlation
- Cross-source event matching (focus + audio + interaction)
- Automatic accessibility insight generation
- WCAG-compliant issue detection
- Performance monitoring and statistics

**Usage:**
```bash
npm run ts-node examples/correlation-demo.ts
```

### 4. Interaction Monitoring Demo (`interaction-demo.ts`)
Shows privacy-safe system-wide interaction monitoring.

**Features:**
- Keyboard and mouse interaction capture
- Privacy controls and sensitive data filtering
- Real-time correlation with focus events
- Custom accessibility pattern detection
- Cross-platform interaction abstraction

**Usage:**
```bash
npm run ts-node examples/interaction-demo.ts
```

### 5. Timing Synchronization Demo (`timing-demo.ts`)
Demonstrates microsecond-precision timing and synchronization.

**Features:**
- Microsecond-precision event timestamping
- Clock drift detection and correction
- NTP synchronization capabilities
- Timing validation and analysis
- Comprehensive timing statistics

**Usage:**
```bash
npm run ts-node examples/timing-demo.ts
```

## What to Expect

### Focus Tracking Demo
```
🚀 Starting TrackerA11y Focus Tracking Demo
📱 Platform: darwin
⏱️  Switch between applications to see focus tracking in action

✅ Focus tracking initialized successfully
🎯 Current focus: Visual Studio Code

📋 Focus Changed:
   Time: 2025-12-16T04:15:23.456Z
   App: System Preferences (PID: 1234)
   Window: Security & Privacy
   Role: window
   Bundle: com.apple.systempreferences
   States: focused, enabled
```

### Audio Processing Demo
```
🎤 Starting TrackerA11y Audio Processing Demo
✅ Audio processing pipeline initialized successfully
🎯 Ready to process audio data

🎙️  Audio Events Detected:
   Time: 2025-12-16T04:15:30.789Z
   Language: EN
   Confidence: 95.2%
   Speakers: 1
   Speaker Timeline:
     SPEAKER_00: 0.0s - 2.5s
   Text: "Click the submit button"
```

### Event Correlation Demo
```
🧠 Starting TrackerA11y Event Correlation Demo
✅ TrackerA11y Core initialized
🎬 Tracking started - begin using your system to generate events

📋 Event: FOCUS at 2025-12-16T04:15:35.123Z
   Focus: Visual Studio Code

📋 Event: AUDIO at 2025-12-16T04:15:37.456Z
   Audio: "click the button" (en)

🔗 CORRELATION DETECTED!
   Rule: focus-audio-correlation
   Type: temporal
   Confidence: 85.0%
   Primary Event: focus
   Related Events: audio
   Time Difference: 2333ms

💡 ACCESSIBILITY INSIGHT GENERATED!
   Type: BARRIER
   Severity: MEDIUM
   Description: Voice command detected but focus may not be properly set on target element
   WCAG Reference: WCAG 2.4.3 (Focus Order)
   Evidence: Focus, Audio
   💡 Remedy: Ensure focus is programmatically set when responding to voice commands
   Code Example: element.focus(); // Set focus after voice command processing
```

## Demo Instructions

1. **Start with Focus Tracking**: Get familiar with how TrackerA11y detects application focus changes
2. **Try Audio Processing**: Test voice commands and speech recognition (requires Python setup)
3. **Experience Correlation**: See how the system connects different events to generate insights

### Interactive Testing Ideas

**Focus Tracking:**
- Switch between applications (⌘+Tab on macOS)
- Open/close windows
- Navigate between UI elements

**Audio Processing:**
- Speak voice commands like "click", "select", "navigate"
- Try different languages
- Test with background noise

**Event Correlation:**
- Combine actions: speak while switching apps
- Use voice commands while navigating
- Rapid application switching to test pattern detection

## Troubleshooting

### Accessibility Permissions (macOS)
If you see permission errors:
1. Open System Preferences → Security & Privacy
2. Click Privacy tab → Accessibility  
3. Add Terminal or your IDE to allowed apps
4. Restart the demo

### Python Audio Pipeline Issues
If audio processing fails:
```bash
# Install required dependencies
pip install -r audio_pipeline/requirements.txt

# Verify Python version (3.9+ required)
python --version

# Test audio pipeline directly
python audio_pipeline/src/audio_pipeline/main.py --mode standalone
```

### Performance Tips
- Close unnecessary applications for cleaner focus tracking
- Use a quiet environment for better audio recognition
- Monitor system resources during correlation demo

## Next Steps

After exploring these demos, you can:

1. **Integrate with your application**: Use `TrackerA11yCore` in your own projects
2. **Create custom correlation rules**: Add domain-specific accessibility patterns
3. **Extend event sources**: Add custom event types for your specific use cases
4. **Build accessibility testing suites**: Use insights for automated accessibility testing

## API Documentation

See the TypeScript interfaces in `src/types/index.ts` for complete API documentation.

Key classes:
- `TrackerA11yCore`: Main orchestration service
- `EventCorrelator`: Correlation engine
- `FocusManager`: Cross-platform focus tracking
- `AudioProcessorBridge`: Python ML pipeline integration
# TrackerA11y Event Recorder

**Comprehensive event recording system for audio analysis correlation**

## What It Does

Records **everything** that happens on your computer with microsecond precision:

- 🖱️ **Every mouse click** with exact coordinates  
- ⌨️ **Every keystroke** (navigation keys, not passwords)
- 🎯 **Every application focus change**
- 🌐 **DOM state** whenever you interact with web pages
- 📸 **Screenshots** at key interaction moments
- ⏱️ **Microsecond-precise timestamps** for audio synchronization

**No analysis, no insights - just pure data capture for your audio analysis system.**

## Quick Start

### 1. Basic Recording
```bash
npm run demo:recorder
```

### 2. CLI Tool
```bash
# Start recording with custom settings
npm run record -- --output ./my-session --quality high

# Analyze a completed recording
npm run analyze ./recordings/session_1234567890
```

### 3. Programmatic Use
```typescript
import { EventRecorder } from './src/recorder';

const recorder = new EventRecorder({
  outputDirectory: './recordings',
  screenshot: { enabled: true, quality: 'medium', triggers: ['click', 'focus_change'] },
  dom: { enabled: true, browsers: ['Safari', 'Chrome'] },
  interactions: { captureClicks: true, captureKeystrokes: true }
});

await recorder.startRecording();
// ... do stuff ...
const outputDir = await recorder.stopRecording();
```

## Output Format

Each recording session creates:

```
recordings/session_1701234567890/
├── events.json          # Complete event log
├── summary.txt          # Session overview  
├── screenshots/         # PNG screenshots
│   ├── screenshot_0_1701234567890123_click.png
│   └── screenshot_1_1701234567890456_focus_change.png
└── dom_states/          # Web page snapshots
    ├── dom_0_1701234567890789.html
    └── dom_0_1701234567890789.json
```

### Event Log Format
```json
{
  "sessionId": "session_1701234567890",
  "startTime": 1701234567890123,
  "endTime": 1701234567899456,
  "events": [
    {
      "id": "interaction_1701234567890123_abc123",
      "timestamp": 1701234567890123,
      "source": "interaction", 
      "type": "click",
      "data": {
        "interactionType": "click",
        "coordinates": { "x": 450, "y": 200 },
        "target": { "applicationName": "Safari" }
      },
      "screenshot": {
        "filename": "screenshot_0_1701234567890123_click.png",
        "path": "/path/to/screenshot.png",
        "timestamp": 1701234567890123
      },
      "domState": {
        "url": "https://example.com",
        "title": "Example Page",
        "elementCount": 245,
        "activeElement": { "tagName": "BUTTON", "id": "submit-btn" }
      }
    }
  ]
}
```

## Event Types Captured

| Source | Type | Data Captured |
|--------|------|---------------|
| `interaction` | `click` | Coordinates, button, click count |
| `interaction` | `key` | Key pressed, modifiers |
| `interaction` | `scroll` | Scroll delta, direction |
| `focus` | `application_focus_changed` | App name, window title, process ID |
| `system` | `initial_state` | Starting application focus |
| `system` | `recording_ended` | Session statistics |

## Perfect for Audio Analysis

### Microsecond Timestamps
Every event has precise timing for synchronization:
```json
{
  "timestamp": 1701234567890123,
  "metadata": {
    "timingInfo": {
      "synchronizedTimestamp": 1701234567890123,
      "uncertainty": 15.2,
      "accuracy": 12.5
    }
  }
}
```

### Screenshots Show Context
Visual state at exact moment of interaction:
```json
{
  "screenshot": {
    "timestamp": 1701234567890123,
    "trigger": "click",
    "dimensions": { "width": 1920, "height": 1080 }
  }
}
```

### DOM State for Web Interactions
Complete web page structure when user acts:
```json
{
  "domState": {
    "url": "https://example.com/form",
    "title": "Contact Form",
    "activeElement": { 
      "tagName": "INPUT", 
      "id": "email-field",
      "textContent": "Enter email..."
    },
    "elementCount": 156,
    "viewport": { "width": 1200, "height": 800 }
  }
}
```

## Configuration Options

### Screenshots
```typescript
screenshot: {
  enabled: true,
  quality: 'medium',           // low | medium | high | lossless  
  format: 'png',               // png | jpg | webp
  minInterval: 2000,           // Min milliseconds between captures
  triggers: ['click', 'key'],  // Event types that trigger capture
  captureFullScreen: true,     // Full screen vs active window
}
```

### DOM Capture  
```typescript
dom: {
  enabled: true,
  captureFullDOM: true,        // Complete HTML structure
  captureStyles: false,        // Include CSS (increases size)
  minInterval: 5000,           // Min milliseconds between captures
  browsers: ['Safari', 'Chrome'] // Which browsers to monitor
}
```

### Interactions
```typescript
interactions: {
  captureClicks: true,         // Mouse clicks
  captureKeystrokes: true,     // Keyboard input
  captureScrolls: true,        // Scroll events
  captureMouseMovements: false, // Mouse movement (very noisy)
  captureCoordinates: true,    // Exact click positions
  captureTimings: true         // Precise timing data
}
```

## System Requirements

### macOS Permissions Required
1. **Accessibility**: System Preferences → Security & Privacy → Privacy → Accessibility
2. **Screen Recording**: System Preferences → Security & Privacy → Privacy → Screen Recording

Add Terminal (or your IDE) to both lists.

### Browser Support
- ✅ **Safari**: Full DOM capture via AppleScript  
- ✅ **Chrome**: DOM capture via DevTools Protocol
- ⚠️ **Firefox**: Limited support (extensible)
- ⚠️ **Edge**: Limited support (extensible)

## CLI Reference

### Record Command
```bash
npm run cli record [options]

Options:
  -o, --output <dir>       Output directory (default: "./recordings")
  -s, --screenshots        Enable screenshots (default: true)
  -d, --dom               Enable DOM capture (default: true)
  --no-screenshots        Disable screenshot capture
  --no-dom               Disable DOM capture  
  -q, --quality <level>   Screenshot quality: low|medium|high|lossless
  -i, --interval <ms>     Min interval between captures (default: 2000)
```

### Analyze Command
```bash
npm run cli analyze <recording-directory>

# Shows:
# - Session duration and event count
# - Breakdown by event type  
# - Number of screenshots and DOM states captured
```

## Native Session Viewer

TrackerA11y includes a complete native macOS application for viewing and analyzing recorded sessions:

### 📱 **Visual Session Analysis**

Launch the session viewer:
```bash
open TrackerA11yApp-FullyWorking.app
```

### 🔍 **Session Browser Features**
- **Complete Session List**: Browse all recorded sessions from MongoDB
- **Session Statistics**: View event counts, duration, and status for each session
- **Real Data Display**: Shows actual recorded event counts (3 events vs 93+ events)
- **Quick Navigation**: Click any session to open detailed view

### 📊 **Three-Tab Session Detail View**

#### 1. **Session Info Tab**
- Session ID and creation timestamp
- Recording status and duration
- Total event count and statistics
- Data source information

#### 2. **Event Log Tab**  
- Formatted event list with timestamps
- Event source identification (system, focus, interaction)
- Detailed event data and metadata
- Chronological ordering for analysis

#### 3. **Timeline Tab**
- **Interactive timeline visualization** 
- **Color-coded event tracks** by type:
  - 🔵 Focus events (blue)
  - 🟢 Interaction events (green)  
  - 🟠 System events (orange)
  - 🟣 Custom events (purple)
- **Time axis** with start/end timestamps
- **Event markers** positioned by actual timing

### ✨ **Key Benefits**

- **No Command Line Required**: Point-and-click interface for session analysis
- **Real-time Data**: Loads actual session data from recordings directory
- **Professional Interface**: Native macOS design following system patterns
- **MongoDB Integration**: Direct database connectivity with status monitoring
- **Export Capabilities**: Save session data in multiple formats

## Integration with Audio Analysis

The event recorder is designed to provide **perfect context** for audio analysis:

1. **Precise Timing**: Microsecond timestamps align with audio timeline
2. **Visual Context**: Screenshots show what user was looking at
3. **Interaction Context**: Exact coordinates and elements user interacted with  
4. **DOM Context**: Web page structure and active elements
5. **Application Context**: Which apps were focused during audio

Use this data to correlate user speech with their actual interactions and visual context.

## Real-World Example

```json
{
  "timestamp": 1701234567890123,
  "source": "interaction",
  "type": "click", 
  "data": {
    "coordinates": { "x": 890, "y": 340 },
    "target": { "applicationName": "Safari" }
  },
  "screenshot": "screenshot_5_click.png",
  "domState": {
    "url": "https://checkout.example.com",
    "activeElement": { "tagName": "BUTTON", "id": "place-order" }
  }
}
```

**Audio at same timestamp**: *"Place my order"*

**Perfect correlation**: User said "place my order" at exact moment they clicked the "Place Order" button on checkout page.

---

*No analysis, no complexity - just comprehensive, precise event capture for your audio analysis needs.*
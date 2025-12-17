# TrackerA11y Setup Guide

## Quick Fix for Common Issues

### 1. Screenshot Permission Issue

**Problem**: `Screenshot capability test failed - screenshots may not work`

**Solution**:
1. Open **System Preferences** → **Security & Privacy** → **Privacy**
2. Click **Screen Recording** on the left
3. Click the lock icon and enter your password
4. Check the box next to **Terminal** (or your IDE like VS Code)
5. Restart your terminal/IDE

### 2. Accessibility Permission Issue  

**Problem**: Focus tracking or interaction monitoring fails

**Solution**:
1. Open **System Preferences** → **Security & Privacy** → **Privacy** 
2. Click **Accessibility** on the left
3. Click the lock icon and enter your password
4. Check the box next to **Terminal** (or your IDE like VS Code)
5. Restart your terminal/IDE

### 3. Multiple Shutdown Messages

**Problem**: Seeing duplicate "Stopping recording" messages

**Solution**: This is a known issue with the current version. The recording still works correctly, just ignore the duplicates.

## Minimal Working Setup

If you're having issues, here's a minimal setup that should work:

### Step 1: Quick Start
```bash
git clone https://github.com/bobdodd/trackerA11y.git
cd trackerA11y
npm install
```

### Step 2: Grant Permissions
- **Accessibility**: System Preferences → Security & Privacy → Privacy → Accessibility → Add Terminal
- **Screen Recording**: System Preferences → Security & Privacy → Privacy → Screen Recording → Add Terminal

### Step 3: Test Basic Recording
```bash
npm run record -- --no-screenshots --no-dom
```

This runs with minimal features - just interaction and focus tracking.

### Step 4: Test Full Recording  
```bash
npm run record
```

This includes screenshots and DOM capture.

## Troubleshooting

### If Screenshots Don't Work
Recording will continue without screenshots. You'll still get:
- All interaction events with coordinates
- Focus changes
- DOM states (if enabled)
- Complete event log

### If DOM Capture Fails
Recording will continue without DOM states. You'll still get:
- All interaction events  
- Focus changes
- Screenshots (if enabled)
- Complete event log

### If Everything Fails
Try the most basic recording:
```bash
npm run cli record -- --no-screenshots --no-dom --output ./test-recording
```

## Expected Output

### Working Session
```
🎥 TrackerA11y Event Recorder
🔴 Starting comprehensive event recording...

✅ Screenshot capture initialized
✅ DOM capture initialized  
✅ Event recording started

📝 15:58:09 | FOCUS | application_focus_changed | App: Safari
📝 15:58:10 | INTERACTION | click | Click: (450,200)
📸 Screenshot captured: screenshot_0_click.png
📋 DOM captured: Google Search (245 elements)

^C
🛑 Stopping recording...
✅ Recording stopped and saved
📁 Session data: ./recordings/session_1234567890
📊 Total events: 25
⏱️  Duration: 45.67s
```

### Files Created
```
recordings/session_1234567890/
├── events.json          # Complete event log
├── summary.txt          # Session statistics
├── screenshots/         # Screenshots (if enabled)
│   └── screenshot_0_1234567890_click.png
└── dom_states/          # DOM snapshots (if enabled)
    ├── dom_0_1234567890.html
    └── dom_0_1234567890.json
```

## Known Issues

1. **Duplicate shutdown messages** - Harmless, fix coming
2. **AppleScript timeouts during shutdown** - Doesn't affect recording quality
3. **Screen recording permission warnings** - One-time setup issue

The core recording functionality works even with these issues.

## What Gets Recorded

Even with permission issues, you'll still capture:
- ✅ Every mouse click with exact coordinates
- ✅ Every keystroke (navigation keys only)
- ✅ Every application focus change
- ✅ Microsecond-precise timestamps
- ⚠️ Screenshots (requires Screen Recording permission)
- ⚠️ DOM states (requires browser access)

The event log is the most important output for audio correlation.
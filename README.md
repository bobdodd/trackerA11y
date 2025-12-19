# TrackerA11y - Comprehensive Accessibility Testing Platform

## Project Overview

TrackerA11y is a unified accessibility testing platform that combines real-time interaction tracking, screen structure analysis, and integrated diarized audio processing to provide the most comprehensive view of user experience during accessibility testing. By implementing a hybrid TypeScript-Python architecture, TrackerA11y becomes the definitive tool for understanding both what users do and what they think during accessibility testing sessions.

## Project Vision

TrackerA11y represents a paradigm shift from fragmented accessibility testing tools to a unified platform that provides unprecedented insight into user experience. Unlike existing solutions that require complex tool integration and post-hoc correlation, TrackerA11y captures and correlates all aspects of user interaction in real-time with microsecond precision.

## Hybrid Architecture Benefits

### TypeScript Core + Python Audio Pipeline

**Why This Approach?**
- **TypeScript Core**: Optimal for real-time system integration, cross-platform APIs, and web technology integration
- **Python Audio Pipeline**: Leverages ML/AI ecosystem for state-of-the-art audio processing
- **Best of Both Worlds**: Each language used for its optimal strengths

**Key Benefits:**
- **Elimination of synchronization complexity**: Native integration prevents data loss and timing errors
- **Real-time correlation**: Immediate insights as testing progresses  
- **Higher accuracy**: Purpose-built components optimized for their specific tasks
- **Simplified workflow**: Single installation, unified reporting, seamless operation
- **Enhanced analysis**: Capabilities impossible with fragmented tools
- **Scalable performance**: Independent scaling of audio processing and system monitoring

### Comprehensive Capabilities

#### Enhanced Interaction Tracking (TypeScript Core)
1. **Application Focus Tracking**: Monitor which application has focus across all platforms
2. **Advanced Mouse Event Capture**: Complete mouse button support (left, right, middle, additional) with modifier keys
   - **Modifier Key Support**: Capture Command+click, Shift+click, Control+click, Option+click combinations
   - **Comprehensive Button Support**: All mouse buttons including middle-click and additional buttons
   - **Enhanced Event Types**: Mouse down/up, drag, hover, dwell time tracking
3. **Dock Integration**: Native macOS dock detection and interaction tracking
   - **Universal Dock Detection**: Works with dock in any position (bottom, left, right)
   - **Application Icon Tracking**: Identify specific applications being launched from dock
   - **Coordinate-Based Detection**: Robust detection without hanging or timeouts
4. **Browser Element Detection**: Deep DOM inspection for web accessibility testing
   - **Cross-Browser Support**: Safari, Chrome, Firefox integration
   - **Real-Time Element Identification**: Instant detection of clicked web elements
   - **Coordinate Mapping**: Accurate screen-to-browser coordinate transformation
5. **Hover & Dwell Time Analysis**: Advanced interaction timing analysis
   - **Hover Detection**: 500ms threshold with 10px movement tolerance
   - **Dwell Time Measurement**: Precise timing of user hesitation and exploration
   - **Movement Tracking**: Sub-pixel precision mouse movement analysis
6. **Page/Screen Structure Analysis**: Deep inspection of accessibility trees and DOM structures
7. **Screen Recording Integration**: Synchronized visual capture with interaction overlays

#### Integrated Audio Analysis (Python Pipeline)
8. **High-Quality Audio Recording**: Professional-grade 48kHz/96kHz lossless audio capture
9. **Speaker Diarization**: Advanced AI-powered separation using pyannote/speaker-diarization-3.1
10. **Role-Aware Transcription**: Specialized transcription with Whisper Large v3 optimized for each speaker
11. **Think-Aloud Analysis**: Deep analysis of user cognitive processes and mental models
12. **Sentiment & Emotion Tracking**: Real-time detection of user frustration, confusion, and satisfaction

#### Intelligence & Correlation (Hybrid System)
13. **Real-Time Correlation**: Immediate linking of user speech with their actions via IPC bridge
14. **Accessibility Issue Detection**: Automated identification of barriers through audio-visual correlation
15. **Intent Analysis**: Understanding user goals and expectations from speech-action patterns
16. **Comprehensive Reporting**: Multi-format reports with unified audio-visual-interaction insights

### Technical Excellence

#### Performance & Scale
- **Cross-platform support**: Desktop (Windows, macOS, Linux) and mobile (iOS, Android)
- **Microsecond precision**: High-performance timestamping and event correlation
- **Non-intrusive operation**: Minimal impact on testing experience with optimized resource usage
- **Professional audio quality**: Configurable 48kHz/96kHz recording with advanced noise reduction

#### AI & Machine Learning
- **State-of-the-art diarization**: pyannote/speaker-diarization-3.1 for accurate speaker separation
- **Advanced transcription**: Whisper Large v3 with role-specific optimization and confidence scoring
- **Intelligent correlation**: ML-powered linking of speech patterns to interaction events
- **Accessibility expertise**: Domain-specific models trained on accessibility testing scenarios

## Project Structure

```
trackerA11y/
├── TrackerA11y/                  # Native macOS Application (Swift)
│   ├── AppDelegate.swift         # Application lifecycle
│   ├── MainViewController.swift  # Main interface controller
│   ├── SessionListViewController.swift     # Session browser
│   ├── SessionDetailViewController.swift   # Session viewer with tabs
│   ├── TrackerBridge.swift       # TypeScript integration bridge
│   └── Assets.xcassets/          # App icons and resources
├── TrackerA11yApp.xcodeproj/     # Xcode project configuration
├── TrackerA11yApp-FullyWorking.app/  # Pre-built native application
├── src/                          # TypeScript Core
│   ├── core/                     # Core system orchestration
│   ├── platforms/                # Platform-specific implementations
│   ├── bridge/                   # Python IPC communication
│   ├── recorder/                 # Event recording and session management
│   ├── types/                    # TypeScript type definitions
│   └── utils/                    # Utility functions
├── audio_pipeline/               # Python Audio Processing
│   ├── src/audio_pipeline/       # Python source code
│   │   ├── processors/           # Audio analysis engines
│   │   ├── models/               # Data models
│   │   └── communication/        # IPC handling
│   └── tests/                    # Python tests
├── app/                          # Electron Application (Development)
│   ├── electron/                 # Electron main and renderer processes
│   ├── src/                      # React frontend components
│   └── public/                   # Static web assets
├── recordings/                   # Session data storage
├── docs/                         # Comprehensive documentation
└── tests/                        # TypeScript tests
```

## Getting Started

### Prerequisites

**Native macOS Application:**
- macOS 14.0+ (Sonoma or later)
- Xcode 15.0+ (for building from source)
- MongoDB installed and running
- Accessibility permissions enabled

**TypeScript Core:**
- Node.js 18+
- npm or yarn
- Platform-specific development tools (Xcode, Visual Studio, etc.)

**Python Audio Pipeline:**
- Python 3.9+
- pip or poetry
- PyTorch (for ML models)
- Audio system access

### Quick Start - Native macOS App

The easiest way to get started is with our native macOS application:

1. **Run the pre-built app:**
```bash
# Launch the native TrackerA11y application
open TrackerA11yApp-FullyWorking.app
```

2. **Or build from source:**
```bash
# Build the native macOS application
xcodebuild -project TrackerA11yApp.xcodeproj -scheme TrackerA11yApp -configuration Release build
```

### Development Installation

1. **Install TypeScript dependencies:**
```bash
npm install
```

2. **Install Python audio pipeline:**
```bash
cd audio_pipeline
pip install -r requirements.txt
# or with poetry
poetry install
```

3. **Build TypeScript core:**
```bash
npm run build
```

4. **Run tests:**
```bash
# TypeScript tests
npm test

# Python tests  
cd audio_pipeline
pytest
```

### Development

**Start development mode:**
```bash
# Terminal 1: TypeScript development server
npm run dev

# Terminal 2: Python pipeline in development mode
cd audio_pipeline
python -m audio_pipeline.main --mode standalone --log-level DEBUG
```

## Native macOS Application Features

TrackerA11y includes a complete native macOS application for session management and analysis:

### 🖥️ **Session Management**
- **Real-time Recording Controls**: Start/stop tracking sessions with one click
- **MongoDB Integration**: Direct connection to session database with status monitoring
- **Session History**: Browse and analyze all recorded sessions
- **Export Functionality**: Export session data in multiple formats

### 📊 **Session Viewer**
- **Three-tab Interface**: Session Info, Event Log, and Timeline views
- **Real Data Display**: Shows actual event counts and session statistics
- **Interactive Timeline**: Visual timeline with colored event tracks by type
- **Detailed Event Logs**: Formatted event display with timestamps and metadata

### 🎯 **Key Features**
- **Native Performance**: Built with Swift for optimal macOS integration
- **Professional UI**: Follows macOS design guidelines with native controls
- **Database Connectivity**: Real-time MongoDB connection status and validation
- **Accessibility Focus**: Purpose-built for accessibility testing workflows

### 📱 **Using the Native App**

1. **Launch the application:**
```bash
open TrackerA11yApp-FullyWorking.app
```

2. **Start a recording session:**
   - Click "Start Recording" to begin tracking
   - The app monitors focus changes, interactions, and events
   - View real-time event counts and session statistics

3. **View session history:**
   - Click "View Sessions" to browse recorded sessions
   - Select any session to view detailed information
   - Explore session info, event logs, and timeline visualizations

4. **Export session data:**
   - Use the export function to save session data
   - Multiple format options for analysis and reporting

## Enhanced Usage Examples

### Quick Start: Enhanced Demo
Experience all the new enhanced features with the comprehensive demo:

```bash
# Run the enhanced accessibility demo with all features
npm run demo:enhanced
```

This demo showcases:
- 🖱️ **Advanced Mouse Tracking**: All button support with modifier keys
- 🚢 **Dock Detection**: Native macOS dock interaction tracking  
- 🌐 **Browser Integration**: Real-time DOM element detection
- 🫧 **Hover Analysis**: Dwell time and movement precision
- ⌨️ **Enhanced Output**: Clean, emoji-coded interaction logging

### Recording with Enhanced Features
Start a comprehensive recording session:

```bash
# Record everything with enhanced tracking
npm run record
```

### Accessibility-Only Demo
For focused accessibility testing:

```bash
# Original accessibility demo (clean output)
npm run demo:accessibility
```

### Enhanced Feature Examples

**Dock Interactions:**
```
🖱️ CLICK [Command] #1 | 🚢 Dock: Terminal
⬇️ DOCK PRESS | 🚢 Dock: Safari
🖱️ RIGHT CLICK #2 | 🚢 Dock: Chrome
```

**Browser Element Detection:**
```
🖱️ CLICK #3 | <button> "Submit Form"
🖱️ CLICK [Shift] #4 | <a> "Learn More" (https://example.com...)
⬇️ PRESS LEFT [Control] | <input>#search "Search for..."
```

**Enhanced Interactions:**
```
🫧 HOVER START | <div> "Navigation Menu"
🫧 HOVER END (1250ms)
🫳 DRAG LEFT [Option] | <div> "Draggable Item"
⬆️ SCROLL [Command] | <main> "Main Content"
```

## Architecture Deep Dive

For detailed information about our architecture decisions and implementation:

- **[Architecture Decisions](./docs/architecture-decisions.md)** - Comprehensive ADR for hybrid TypeScript-Python approach
- **[Application Focus Tracking](./docs/app-focus-tracking.md)** - Platform-specific APIs and implementation patterns
- **[User Interaction Tracking](./docs/user-interaction-tracking.md)** - Cross-platform interaction monitoring
- **[Screen Structure Analysis](./docs/screen-structure-analysis.md)** - Accessibility tree analysis and DOM inspection
- **[Audio Synchronization](./docs/audio-synchronization.md)** - High-precision timestamping and correlation
- **[Implementation Guide](./docs/implementation-guide.md)** - Production-ready architecture and code examples

## Development Roadmap

### Phase 1: Foundation (Months 1-3) 🚧 *In Progress*
- [x] **Project Structure**: Hybrid TypeScript-Python architecture setup
- [x] **Documentation**: Architecture decisions and technical foundations  
- [ ] **Cross-Platform Tracking Core**: Application focus and interaction monitoring
- [ ] **Audio Infrastructure**: Recording and diarization pipeline with IPC bridge
- [ ] **Correlation Engine**: Real-time event linking and timestamping system
- [ ] **Data Models**: Unified data structures for multi-modal analysis

### Phase 2: Intelligence (Months 4-6)
- [ ] **Advanced Transcription**: Role-aware speech processing with Whisper Large v3
- [ ] **Accessibility Analysis**: AI-powered barrier detection from audio-visual correlation
- [ ] **Screen Structure Analysis**: Complete accessibility tree monitoring and change detection
- [ ] **Performance Optimization**: Efficient data processing and storage systems

### Phase 3: Platform (Months 7-12)
- [ ] **API Development**: Comprehensive developer APIs and SDKs
- [ ] **Integration Ecosystem**: Connectors for CI/CD, testing frameworks, and research tools
- [ ] **Advanced Analytics**: ML-powered insights and automated reporting
- [ ] **Enterprise Features**: Real-time monitoring, compliance reporting, and team collaboration

## Contributing

We welcome contributions to TrackerA11y! Please see our contributing guidelines and:

1. Check existing issues and pull requests
2. Follow our code style (ESLint for TypeScript, Black for Python)
3. Add tests for new functionality
4. Update documentation as needed

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- **pyannote.audio team** for state-of-the-art speaker diarization
- **OpenAI Whisper team** for advanced speech recognition
- **Accessibility community** for inspiration and domain expertise

---

**TrackerA11y**: Where accessibility testing meets artificial intelligence. 🤖♿
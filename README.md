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

#### Visual & Interaction Tracking (TypeScript Core)
1. **Application Focus Tracking**: Monitor which application has focus across all platforms
2. **User Interaction Monitoring**: Capture and timestamp all user interactions with microsecond precision
3. **Page/Screen Structure Analysis**: Deep inspection of accessibility trees and DOM structures
4. **Lifecycle Tracking**: Monitor all changes and user interactions throughout testing sessions
5. **Screen Recording Integration**: Synchronized visual capture with interaction overlays

#### Integrated Audio Analysis (Python Pipeline)
6. **High-Quality Audio Recording**: Professional-grade 48kHz/96kHz lossless audio capture
7. **Speaker Diarization**: Advanced AI-powered separation using pyannote/speaker-diarization-3.1
8. **Role-Aware Transcription**: Specialized transcription with Whisper Large v3 optimized for each speaker
9. **Think-Aloud Analysis**: Deep analysis of user cognitive processes and mental models
10. **Sentiment & Emotion Tracking**: Real-time detection of user frustration, confusion, and satisfaction

#### Intelligence & Correlation (Hybrid System)
11. **Real-Time Correlation**: Immediate linking of user speech with their actions via IPC bridge
12. **Accessibility Issue Detection**: Automated identification of barriers through audio-visual correlation
13. **Intent Analysis**: Understanding user goals and expectations from speech-action patterns
14. **Comprehensive Reporting**: Multi-format reports with unified audio-visual-interaction insights

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
├── src/                          # TypeScript Core
│   ├── core/                     # Core system orchestration
│   ├── platforms/                # Platform-specific implementations
│   ├── bridge/                   # Python IPC communication
│   ├── types/                    # TypeScript type definitions
│   └── utils/                    # Utility functions
├── audio_pipeline/               # Python Audio Processing
│   ├── src/audio_pipeline/       # Python source code
│   │   ├── processors/           # Audio analysis engines
│   │   ├── models/               # Data models
│   │   └── communication/        # IPC handling
│   └── tests/                    # Python tests
├── docs/                         # Comprehensive documentation
└── tests/                        # TypeScript tests
```

## Getting Started

### Prerequisites

**TypeScript Core:**
- Node.js 18+
- npm or yarn
- Platform-specific development tools (Xcode, Visual Studio, etc.)

**Python Audio Pipeline:**
- Python 3.9+
- pip or poetry
- PyTorch (for ML models)
- Audio system access

### Installation

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
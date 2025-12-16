# TrackerA11y - Accessibility Testing Microscope

## Project Overview

TrackerA11y is a comprehensive tool designed to support lived experience accessibility testing by providing detailed insights into user interactions and application behavior during accessibility testing sessions. This tool complements the existing audio transcription capabilities found in the [pythonAudioA11y repository](https://github.com/bobdodd/pythonAudioA11y) by adding visual and interaction tracking.

## Project Goals

While the existing audio analysis tool provides valuable insights from transcribed think-aloud sessions, it operates with a constraint: it only works with diarized transcription of audio files without understanding the application or website being tested. TrackerA11y aims to fill this gap by providing:

### Core Functionality
1. **Application Focus Tracking**: Monitor which application has focus (typically browsers on desktop, native apps on mobile)
2. **User Interaction Monitoring**: Capture and timestamp all user interactions with the focused application
3. **Page/Screen Structure Analysis**: Deep inspection of the current page or screen structure
4. **Lifecycle Tracking**: Monitor all changes and user interactions throughout the testing session
5. **Timestamp Synchronization**: Provide precise timing information to correlate with screen recordings and audio transcriptions

### Technical Requirements
- **Cross-platform support**: Desktop (Windows, macOS, Linux) and mobile (iOS, Android)
- **Real-time monitoring**: Low-latency capture of events and state changes
- **Non-intrusive operation**: Minimal impact on the testing experience
- **Data correlation**: Seamless integration with existing audio analysis workflow
- **Accessibility tree inspection**: Deep understanding of accessibility markup and screen reader information

## Architecture Concepts

### Application Focus Detection
- **Desktop**: OS-level APIs to detect active windows and applications
- **Mobile**: Platform-specific methods to identify foreground applications
- **Browser Detection**: Specialized handling for web content within browsers

### Interaction Tracking
- **Mouse/Touch Events**: Position, click types, gestures
- **Keyboard Events**: Key presses, combinations, input sequences
- **Voice Commands**: Integration with system accessibility features
- **Screen Reader Commands**: Detection of assistive technology interactions

### Page/Screen Analysis
- **DOM Structure**: For web content - accessibility tree, semantic markup
- **Native App Elements**: Platform accessibility APIs for mobile/desktop apps
- **Visual Elements**: OCR and computer vision for visual context
- **Dynamic Changes**: Real-time monitoring of structure modifications

### Data Output
- **Timestamped Events**: All interactions and changes with precise timing
- **Structured Logs**: JSON/XML format for easy processing
- **Correlation IDs**: Link events across different data sources
- **Export Formats**: Integration with existing analysis tools

## Companion Project
This tool is designed to work alongside [pythonAudioA11y](https://github.com/bobdodd/pythonAudioA11y), which provides:
- Audio transcription from screen recordings
- Diarized speech analysis
- Think-aloud protocol analysis
- Accessibility insight extraction from verbal feedback

## Next Steps
1. Research existing accessibility testing frameworks and tools
2. Investigate platform-specific APIs for focus and interaction tracking
3. Design data models for event correlation and timestamping
4. Prototype core tracking functionality
5. Develop integration interfaces with audio analysis pipeline
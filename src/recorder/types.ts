/**
 * Types for comprehensive event recording system
 */

export interface RecorderConfig {
  outputDirectory?: string;
  screenshot: ScreenshotConfig;
  dom: DOMConfig;
  interactions: InteractionRecorderConfig;
  flushInterval?: number; // milliseconds
}

export interface ScreenshotConfig {
  enabled: boolean;
  quality: 'low' | 'medium' | 'high' | 'lossless';
  format: 'png' | 'jpg' | 'webp';
  minInterval: number; // milliseconds between screenshots
  triggers: string[]; // event types that trigger screenshots
  captureFullScreen: boolean;
  captureActiveWindow: boolean;
}

export interface DOMConfig {
  enabled: boolean;
  captureFullDOM: boolean;
  captureStyles: boolean;
  captureResources: boolean;
  minInterval: number; // milliseconds between DOM captures
  browsers: string[]; // which browsers to monitor
}

export interface InteractionRecorderConfig {
  captureClicks: boolean;
  captureKeystrokes: boolean;
  captureScrolls: boolean;
  captureMouseMovements: boolean;
  captureTouchEvents: boolean;
  captureCoordinates: boolean;
  captureTimings: boolean;
}

export interface RecordedEvent {
  id: string;
  timestamp: number; // microseconds since epoch
  source: 'focus' | 'interaction' | 'system' | 'custom' | 'dom' | 'screenshot';
  type: string;
  data: any;
  metadata: {
    sessionId: string;
    capturedAt: number;
    timingInfo: any;
  };
  screenshot?: ScreenshotInfo;
  domState?: DOMState;
}

export interface ScreenshotInfo {
  filename: string;
  path: string;
  timestamp: number;
  dimensions: { width: number; height: number };
  format: string;
  size: number; // bytes
  trigger: string; // what caused this screenshot
}

export interface DOMState {
  url: string;
  title: string;
  timestamp: number;
  filename: string;
  path: string;
  elementCount: number;
  viewport: { width: number; height: number };
  scrollPosition: { x: number; y: number };
  activeElement?: {
    tagName: string;
    id?: string;
    className?: string;
    textContent?: string;
  };
}

export interface EventLog {
  sessionId: string;
  startTime: number;
  endTime: number;
  events: RecordedEvent[];
  metadata: {
    platform: string;
    config: RecorderConfig;
    version: string;
  };
}

export interface RecordingSession {
  sessionId: string;
  startTime: number;
  endTime?: number;
  outputDirectory: string;
  eventCount: number;
  screenshotCount: number;
  domStateCount: number;
  status: 'recording' | 'stopped' | 'error';
}
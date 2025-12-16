/**
 * Core type definitions for TrackerA11y platform
 */

// Base event interface for all tracked events
export interface TimestampedEvent {
  id: string;
  timestamp: number; // microseconds since epoch
  type: string;
  source: 'focus' | 'interaction' | 'audio' | 'accessibility' | 'screen';
  data: Record<string, any>;
  correlationId?: string;
  metadata?: EventMetadata;
}

export interface EventMetadata {
  platform: string;
  sessionId?: string;
  userId?: string;
  confidence?: number;
  tags?: string[];
  capturedAt?: number;
  [key: string]: any; // Allow additional metadata fields
}

// Focus tracking events
export interface FocusEvent extends TimestampedEvent {
  source: 'focus';
  data: {
    applicationName: string;
    windowTitle: string;
    processId: number;
    accessibilityContext?: AccessibilityContext;
  };
}

export interface AccessibilityContext {
  role?: string;
  name?: string;
  description?: string;
  value?: string;
  states?: string[];
  properties?: Record<string, any>;
}

// User interaction events
export interface InteractionEvent extends TimestampedEvent {
  source: 'interaction';
  data: {
    interactionType: 'click' | 'key' | 'scroll' | 'touch' | 'voice' | 'mouse_move' | 'drag' | 'hover';
    target?: {
      element?: string;
      selector?: string;
      coordinates?: { x: number; y: number };
      applicationName?: string;
      windowTitle?: string;
    };
    inputData?: {
      key?: string;
      modifiers?: string[];
      text?: string;
      button?: 'left' | 'right' | 'middle';
      clickCount?: number;
      scrollDelta?: { x: number; y: number };
      pressure?: number;
    };
  };
}

// Audio processing events from Python pipeline
export interface AudioEvent extends TimestampedEvent {
  source: 'audio';
  data: {
    text: string;
    language: string;
    confidence: number;
    speakers: SpeakerInfo[];
    totalSpeakers: number;
    startTime: number;
    endTime: number;
    processingTime: number;
    sentiment?: 'positive' | 'negative' | 'neutral' | 'frustrated' | 'confused';
    intent?: string;
  };
}

export interface SpeakerInfo {
  speaker_id: string;
  start_time: number;
  end_time: number;
  confidence: number;
}

// Configuration interfaces
export interface TrackerA11yConfig {
  platforms: Platform[];
  syncPrecision: 'millisecond' | 'microsecond' | 'nanosecond';
  realTimeMonitoring: boolean;
  audioIntegration?: AudioConfig;
  interactionTracking?: boolean;
  interactionConfig?: InteractionConfig;
  outputFormats: OutputFormat[];
  storage?: StorageConfig;
}

export interface AudioConfig {
  sampleRate?: number;
  recordingQuality: '48khz' | '96khz';
  diarizationModel?: string;
  transcriptionModel?: string;
  synchronizationMethod?: 'bwf' | 'smpte' | 'ptp';
  realTimeProcessing?: boolean;
  pythonPipelinePath?: string;
}

export interface CorrelationConfig {
  eventBuffer: {
    maxEventsPerSource: number;
    maxEventAge: number; // microseconds
    cleanupInterval: number; // milliseconds
  };
  correlationRules: {
    maxTimeWindow: number; // microseconds
    minConfidence: number;
  };
  insights: {
    enableAutoGeneration: boolean;
    severityThreshold: 'low' | 'medium' | 'high' | 'critical';
  };
}

export interface InteractionConfig {
  enableMouse?: boolean;
  enableKeyboard?: boolean;
  enableTouch?: boolean;
  enableAccessibility?: boolean;
  privacyMode?: 'strict' | 'safe' | 'detailed';
  captureLevel?: 'events' | 'detailed' | 'full';
  filterSensitive?: boolean;
}

export type Platform = 'web' | 'ios' | 'android' | 'windows' | 'macos' | 'linux';
export type OutputFormat = 'json' | 'xml' | 'axe-core' | 'lighthouse' | 'wcag-em';

export interface StorageConfig {
  type: 'local' | 's3' | 'gcs' | 'azure';
  endpoint?: string;
  bucket?: string;
  accessKey?: string;
  secretKey?: string;
  region?: string;
}

// Correlation and analysis results
export interface CorrelatedEvent {
  primaryEvent: TimestampedEvent;
  relatedEvents: TimestampedEvent[];
  correlationType: 'temporal' | 'semantic' | 'causal' | 'spatial';
  confidence: number;
  insights?: AccessibilityInsight[];
}

export interface AccessibilityInsight {
  type: 'barrier' | 'success' | 'suggestion' | 'pattern';
  severity: 'low' | 'medium' | 'high' | 'critical';
  description: string;
  wcagReference?: string;
  evidence: {
    audioEvidence?: AudioEvent[];
    interactionEvidence?: InteractionEvent[];
    focusEvidence?: FocusEvent[];
  };
  remediation?: {
    description: string;
    codeExample?: string;
    resources?: string[];
  };
}

// Inter-Process Communication types for Python bridge
export interface IPCMessage {
  type: 'init' | 'shutdown' | 'ping' | 'pong' | 'process_audio' | 'audio_event' | 'processing_status' | 'update_config' | 'get_status' | 'error';
  id: string;
  timestamp: number;
  session_id?: string;
  payload: any;
}

export interface AudioProcessingRequest extends IPCMessage {
  type: 'process_audio';
  payload: {
    audioBuffer: Buffer;
    sessionId: string;
    timestamp: number;
    metadata?: Record<string, any>;
  };
}

export interface AudioProcessingResult extends IPCMessage {
  type: 'audio_event';
  payload: {
    sessionId: string;
    events: AudioEvent[];
    processingTime: number;
    confidence: number;
  };
}
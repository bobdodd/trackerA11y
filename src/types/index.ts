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
    interactionType: 'click' | 'key' | 'scroll' | 'touch' | 'voice';
    target?: {
      element?: string;
      selector?: string;
      coordinates?: { x: number; y: number };
    };
    inputData?: {
      key?: string;
      modifiers?: string[];
      text?: string;
    };
  };
}

// Audio processing events from Python pipeline
export interface AudioEvent extends TimestampedEvent {
  source: 'audio';
  data: {
    speaker: string;
    text: string;
    confidence: number;
    sentiment?: 'positive' | 'negative' | 'neutral' | 'frustrated' | 'confused';
    intent?: string;
    duration: number;
    audioSegment: {
      startTime: number;
      endTime: number;
      frequency?: number;
      amplitude?: number;
    };
  };
}

// Configuration interfaces
export interface TrackerA11yConfig {
  platforms: Platform[];
  syncPrecision: 'millisecond' | 'microsecond' | 'nanosecond';
  realTimeMonitoring: boolean;
  audioIntegration: AudioConfig;
  outputFormats: OutputFormat[];
  storage?: StorageConfig;
}

export interface AudioConfig {
  recordingQuality: '48khz' | '96khz';
  diarizationModel: string;
  transcriptionModel: string;
  synchronizationMethod: 'bwf' | 'smpte' | 'ptp';
  realTimeProcessing: boolean;
  pythonPipelinePath?: string;
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
  type: 'audio_data' | 'audio_result' | 'control' | 'error' | 'heartbeat';
  payload: any;
  requestId?: string;
  timestamp: number;
}

export interface AudioProcessingRequest extends IPCMessage {
  type: 'audio_data';
  payload: {
    audioBuffer: Buffer;
    sessionId: string;
    timestamp: number;
    metadata?: Record<string, any>;
  };
}

export interface AudioProcessingResult extends IPCMessage {
  type: 'audio_result';
  payload: {
    sessionId: string;
    events: AudioEvent[];
    processingTime: number;
    confidence: number;
  };
}
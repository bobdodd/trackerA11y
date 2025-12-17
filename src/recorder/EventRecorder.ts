/**
 * Comprehensive Event Recorder
 * Records ALL events with precise timing - no analysis, just capture
 */

import { EventEmitter } from 'events';
import { TimeSync } from '@/sync/TimeSync';
import { EventTimestamper } from '@/sync/EventTimestamper';
import { FocusManager } from '@/core/FocusManager';
import { InteractionManager } from '@/interaction/InteractionManager';
import { ScreenshotCapture } from './ScreenshotCapture';
import { DOMCapture } from './DOMCapture';
import { RecorderConfig, RecordedEvent, EventLog } from './types';
import * as fs from 'fs/promises';
import * as path from 'path';

export class EventRecorder extends EventEmitter {
  private config: RecorderConfig;
  private timeSync: TimeSync;
  private timestamper: EventTimestamper;
  private focusManager: FocusManager;
  private interactionManager: InteractionManager;
  private screenshotCapture: ScreenshotCapture;
  private domCapture: DOMCapture;
  
  private isRecording = false;
  private sessionId: string;
  private outputDir: string;
  private eventLog: EventLog;
  private eventBuffer: RecordedEvent[] = [];
  private lastScreenshotTime = 0;

  constructor(config: RecorderConfig) {
    super();
    this.config = config;
    this.sessionId = `session_${Date.now()}`;
    this.outputDir = path.resolve(config.outputDirectory || './recordings', this.sessionId);
    
    // Initialize timing
    this.timeSync = new TimeSync({
      precision: 'microsecond',
      systemClockSync: true,
      ntpSync: { enabled: false, servers: [], syncInterval: 300000 },
      audioSync: { enabled: false, method: 'bwf' },
      calibration: { autoCalibrate: true, calibrationInterval: 60000, driftThreshold: 10 }
    });
    this.timestamper = new EventTimestamper(this.timeSync, this.sessionId);

    // Initialize event sources
    this.focusManager = new FocusManager();
    this.interactionManager = new InteractionManager({
      enableMouse: true,
      enableKeyboard: true,
      enableTouch: false,
      enableAccessibility: true,
      privacyMode: 'detailed', // Capture everything
      captureLevel: 'full',
      filterSensitive: false // Record everything
    });

    // Initialize capture systems
    this.screenshotCapture = new ScreenshotCapture(this.outputDir, config.screenshot);
    this.domCapture = new DOMCapture(this.outputDir, config.dom);

    // Initialize event log
    this.eventLog = {
      sessionId: this.sessionId,
      startTime: 0,
      endTime: 0,
      events: [],
      metadata: {
        platform: process.platform,
        config: this.config,
        version: '1.0.0'
      }
    };
  }

  /**
   * Start recording all events
   */
  async startRecording(): Promise<void> {
    if (this.isRecording) {
      throw new Error('Recording already in progress');
    }

    console.log(`🔴 Starting comprehensive event recording...`);
    console.log(`📁 Output directory: ${this.outputDir}`);

    try {
      // Ensure output directory exists
      await fs.mkdir(this.outputDir, { recursive: true });

      // Initialize all systems
      await this.timeSync.initialize();
      await this.focusManager.initialize();
      await this.interactionManager.initialize();
      await this.screenshotCapture.initialize();
      await this.domCapture.initialize();

      // Set up event handlers
      this.setupEventHandlers();

      // Start monitoring
      await this.interactionManager.startMonitoring();

      this.isRecording = true;
      this.eventLog.startTime = this.timeSync.now();

      // Take initial screenshot
      await this.captureInitialState();

      console.log('✅ Event recording started');
      console.log('📊 Recording all user interactions, focus changes, DOM states, and screenshots');
      console.log('⏹️  Press Ctrl+C to stop recording\n');

      this.emit('recordingStarted', { sessionId: this.sessionId, outputDir: this.outputDir });

    } catch (error) {
      console.error('❌ Failed to start recording:', error);
      throw error;
    }
  }

  /**
   * Stop recording and save all data
   */
  async stopRecording(): Promise<string> {
    if (!this.isRecording) {
      return this.outputDir;
    }

    console.log('\n🛑 Stopping event recording...');

    try {
      // Stop monitoring first
      await this.interactionManager.stopMonitoring();

      // Take final screenshot (but don't fail if it doesn't work)
      try {
        await this.captureFinalState();
      } catch (error) {
        console.warn('⚠️  Could not capture final state:', error.message);
      }

      // Finalize event log
      this.eventLog.endTime = this.timeSync.now();
      this.eventLog.events = this.eventBuffer;

      // Save event log
      const logPath = path.join(this.outputDir, 'events.json');
      await fs.writeFile(logPath, JSON.stringify(this.eventLog, null, 2));

      // Generate summary
      const summaryPath = path.join(this.outputDir, 'summary.txt');
      await this.generateSummary(summaryPath);

      this.isRecording = false;

      console.log('✅ Recording stopped and saved');
      console.log(`📁 Session data: ${this.outputDir}`);
      console.log(`📊 Total events: ${this.eventBuffer.length}`);
      console.log(`⏱️  Duration: ${((this.eventLog.endTime - this.eventLog.startTime) / 1000000).toFixed(2)}s`);

      this.emit('recordingStopped', { 
        sessionId: this.sessionId, 
        outputDir: this.outputDir,
        eventCount: this.eventBuffer.length,
        duration: this.eventLog.endTime - this.eventLog.startTime
      });

      return this.outputDir;

    } catch (error) {
      console.error('❌ Error stopping recording:', error);
      throw error;
    }
  }

  /**
   * Record a custom event
   */
  recordCustomEvent(type: string, data: any): void {
    if (!this.isRecording) return;

    const event = this.createRecordedEvent('custom', type, data);
    this.addEvent(event);
  }

  /**
   * Get current recording statistics
   */
  getRecordingStats() {
    return {
      isRecording: this.isRecording,
      sessionId: this.sessionId,
      startTime: this.eventLog.startTime,
      currentTime: this.timeSync.now(),
      eventCount: this.eventBuffer.length,
      outputDir: this.outputDir
    };
  }

  private setupEventHandlers(): void {
    // Focus change events
    this.focusManager.on('focusChanged', async (event) => {
      const recordedEvent = this.createRecordedEvent('focus', 'application_focus_changed', {
        applicationName: event.data.applicationName,
        windowTitle: event.data.windowTitle,
        processId: event.data.processId,
        accessibilityContext: event.data.accessibilityContext
      });

      // Capture DOM state if it's a browser
      if (this.isBrowserApplication(event.data.applicationName)) {
        recordedEvent.domState = await this.domCapture.captureDOMState();
      }

      // Take screenshot if significant focus change
      if (this.shouldCaptureScreenshot('focus_change')) {
        recordedEvent.screenshot = await this.screenshotCapture.captureScreenshot('focus_change');
      }

      this.addEvent(recordedEvent);
    });

    // Interaction events
    this.interactionManager.on('interaction', async (event) => {
      const recordedEvent = this.createRecordedEvent('interaction', event.data.interactionType, {
        interactionType: event.data.interactionType,
        target: event.data.target,
        inputData: event.data.inputData,
        coordinates: event.data.target?.coordinates
      });

      // Capture DOM state for web interactions
      const currentFocus = await this.focusManager.getCurrentFocus();
      if (currentFocus && this.isBrowserApplication(currentFocus.data.applicationName)) {
        recordedEvent.domState = await this.domCapture.captureDOMState();
      }

      // Take screenshot for significant interactions
      if (this.shouldCaptureScreenshot('interaction', event.data.interactionType)) {
        recordedEvent.screenshot = await this.screenshotCapture.captureScreenshot(event.data.interactionType);
      }

      this.addEvent(recordedEvent);
    });

    // Error handling
    this.focusManager.on('error', (error) => {
      this.recordCustomEvent('system_error', { component: 'focusManager', error: error.message });
    });

    this.interactionManager.on('error', (error) => {
      this.recordCustomEvent('system_error', { component: 'interactionManager', error: error.message });
    });
  }

  private createRecordedEvent(source: RecordedEvent['source'], type: string, data: any): RecordedEvent {
    const timestamp = this.timeSync.now();
    
    return {
      id: `${source}_${timestamp}_${Math.random().toString(36).substr(2, 9)}`,
      timestamp,
      source,
      type,
      data,
      metadata: {
        sessionId: this.sessionId,
        capturedAt: Date.now() * 1000,
        timingInfo: this.timestamper.createTimingReference()
      }
    };
  }

  private addEvent(event: RecordedEvent): void {
    this.eventBuffer.push(event);
    
    // Real-time logging
    const time = new Date(event.timestamp / 1000).toISOString().split('T')[1].split('.')[0];
    console.log(`📝 ${time} | ${event.source.toUpperCase()} | ${event.type} | ${this.formatEventData(event.data)}`);

    this.emit('eventRecorded', event);

    // Periodic flush to disk
    if (this.eventBuffer.length % 100 === 0) {
      this.flushEventBuffer();
    }
  }

  private formatEventData(data: any): string {
    if (data.applicationName) return `App: ${data.applicationName}`;
    if (data.interactionType) {
      if (data.inputData?.key) return `Key: ${data.inputData.key}`;
      if (data.coordinates) return `Click: (${data.coordinates.x},${data.coordinates.y})`;
      return `${data.interactionType}`;
    }
    return JSON.stringify(data).substring(0, 50);
  }

  private async flushEventBuffer(): Promise<void> {
    if (this.eventBuffer.length === 0) return;

    try {
      const tempPath = path.join(this.outputDir, 'events_temp.json');
      const tempLog = { ...this.eventLog, events: this.eventBuffer };
      await fs.writeFile(tempPath, JSON.stringify(tempLog, null, 2));
    } catch (error) {
      console.error('Failed to flush event buffer:', error);
    }
  }

  private shouldCaptureScreenshot(eventType: string, interactionType?: string): boolean {
    const config = this.config.screenshot;
    if (!config.enabled) return false;

    const now = this.timeSync.now();
    if (now - this.lastScreenshotTime < config.minInterval * 1000) return false;

    // Screenshot triggers
    const triggers = config.triggers || ['click', 'focus_change', 'key'];
    const shouldCapture = triggers.includes(eventType) || 
                         (interactionType && triggers.includes(interactionType));

    if (shouldCapture) {
      this.lastScreenshotTime = now;
      return true;
    }

    return false;
  }

  private isBrowserApplication(appName: string): boolean {
    const browsers = ['Chrome', 'Firefox', 'Safari', 'Edge', 'Brave', 'Arc'];
    return browsers.some(browser => appName.toLowerCase().includes(browser.toLowerCase()));
  }

  private async captureInitialState(): Promise<void> {
    console.log('📸 Capturing initial system state...');
    
    // Initial screenshot
    if (this.config.screenshot.enabled) {
      await this.screenshotCapture.captureScreenshot('initial_state');
    }

    // Initial focus state
    const currentFocus = await this.focusManager.getCurrentFocus();
    if (currentFocus) {
      const event = this.createRecordedEvent('system', 'initial_focus', currentFocus.data);
      
      if (this.isBrowserApplication(currentFocus.data.applicationName)) {
        event.domState = await this.domCapture.captureDOMState();
      }
      
      this.addEvent(event);
    }
  }

  private async captureFinalState(): Promise<void> {
    console.log('📸 Capturing final system state...');
    
    if (this.config.screenshot.enabled) {
      await this.screenshotCapture.captureScreenshot('final_state');
    }

    const event = this.createRecordedEvent('system', 'recording_ended', {
      duration: this.timeSync.now() - this.eventLog.startTime,
      totalEvents: this.eventBuffer.length
    });
    
    this.addEvent(event);
  }

  private async generateSummary(summaryPath: string): Promise<void> {
    const duration = (this.eventLog.endTime - this.eventLog.startTime) / 1000000;
    const eventTypes = this.eventBuffer.reduce((acc, event) => {
      acc[event.type] = (acc[event.type] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    const summary = `
Event Recording Summary
======================
Session ID: ${this.sessionId}
Duration: ${duration.toFixed(2)} seconds
Total Events: ${this.eventBuffer.length}
Platform: ${process.platform}

Event Breakdown:
${Object.entries(eventTypes)
  .sort(([,a], [,b]) => b - a)
  .map(([type, count]) => `  ${type}: ${count}`)
  .join('\n')}

Output Files:
- events.json: Complete event log with timestamps
- screenshots/: Screenshots captured during session
- dom_states/: DOM snapshots for web interactions
- summary.txt: This summary file

For audio analysis correlation:
- All events have microsecond-precise timestamps
- Screenshots show visual state at moment of interaction
- DOM states capture web page structure when relevant
- Complete interaction history with coordinates and keys
`;

    await fs.writeFile(summaryPath, summary);
  }

  async shutdown(): Promise<void> {
    if (this.isRecording) {
      await this.stopRecording();
    }

    // Shutdown all components with error handling
    const shutdownPromises = [
      this.timeSync.shutdown(),
      this.screenshotCapture.shutdown(),
      this.domCapture.shutdown(),
      this.focusManager.shutdown().catch(err => console.warn('Focus manager shutdown warning:', err.message)),
      this.interactionManager.shutdown().catch(err => console.warn('Interaction manager shutdown warning:', err.message))
    ];

    await Promise.allSettled(shutdownPromises);
  }
}
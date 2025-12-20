/**
 * Core Focus Manager - Cross-platform application focus tracking
 * Orchestrates platform-specific implementations with unified interface
 */

import { EventEmitter } from 'events';
import { FocusEvent, Platform } from '@/types';

export interface PlatformFocusTracker {
  startMonitoring(): Promise<void>;
  stopMonitoring(): Promise<void>;
  getCurrentFocus(): Promise<FocusEvent | null>;
  getAccessibilityContext(processId: number): Promise<any>;
}

export abstract class BaseFocusTracker extends EventEmitter implements PlatformFocusTracker {
  protected isMonitoring = false;
  protected platform: Platform;
  protected pollInterval: number;
  protected lastFocusEvent: FocusEvent | null = null;

  constructor(platform: Platform, pollInterval = 100) {
    super();
    this.platform = platform;
    this.pollInterval = pollInterval;
  }

  abstract startMonitoring(): Promise<void>;
  abstract stopMonitoring(): Promise<void>;
  abstract getCurrentFocus(): Promise<FocusEvent | null>;
  abstract getAccessibilityContext(processId: number): Promise<any>;

  protected createFocusEvent(
    applicationName: string,
    windowTitle: string,
    processId: number,
    accessibilityContext?: any
  ): FocusEvent {
    return {
      id: `focus_${Date.now()}_${Math.random()}`,
      timestamp: Date.now() * 1000, // Convert to microseconds
      type: 'focus_change',
      source: 'focus',
      data: {
        applicationName,
        windowTitle,
        processId,
        accessibilityContext
      },
      metadata: {
        platform: this.platform,
        sessionId: process.env.TRACKERA11Y_SESSION_ID || 'default',
        confidence: 1.0
      }
    };
  }

  protected shouldEmitFocusChange(newEvent: FocusEvent): boolean {
    if (!this.lastFocusEvent) return true;
    
    const lastData = this.lastFocusEvent.data;
    const newData = newEvent.data;
    
    return (
      lastData.applicationName !== newData.applicationName ||
      lastData.windowTitle !== newData.windowTitle ||
      lastData.processId !== newData.processId
    );
  }

  protected emitFocusChange(event: FocusEvent): void {
    if (this.shouldEmitFocusChange(event)) {
      this.lastFocusEvent = event;
      this.emit('focusChanged', event);
    }
  }
}

export class FocusManager extends EventEmitter {
  private tracker: BaseFocusTracker;
  private isInitialized = false;
  private currentPlatform: Platform;

  constructor(platform?: Platform) {
    super();
    this.currentPlatform = platform || this.detectPlatform();
    this.tracker = this.createPlatformTracker(this.currentPlatform);
  }

  private detectPlatform(): Platform {
    const platform = process.platform;
    switch (platform) {
      case 'darwin': return 'macos';
      case 'win32': return 'windows';
      case 'linux': return 'linux';
      default: 
        throw new Error(`Unsupported platform: ${platform}`);
    }
  }

  private createPlatformTracker(platform: Platform): BaseFocusTracker {
    switch (platform) {
      case 'macos':
        const { MacOSFocusTracker } = require('@/platforms/macos/MacOSFocusTracker');
        return new MacOSFocusTracker();
      case 'windows':
        const { WindowsFocusTracker } = require('@/platforms/windows/WindowsFocusTracker');
        return new WindowsFocusTracker();
      case 'linux':
        const { LinuxFocusTracker } = require('@/platforms/linux/LinuxFocusTracker');
        return new LinuxFocusTracker();
      default:
        throw new Error(`Unsupported platform: ${platform}`);
    }
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    try {
      this.tracker.on('focusChanged', this.handleFocusChange.bind(this));
      this.tracker.on('elementFocusChanged', this.handleElementFocusChange.bind(this));
      this.tracker.on('error', this.handleTrackerError.bind(this));
      
      await this.tracker.startMonitoring();
      this.isInitialized = true;
      this.emit('initialized');
    } catch (error) {
      const errorMsg = `Failed to initialize focus tracking: ${error}`;
      this.emit('error', new Error(errorMsg));
      throw new Error(errorMsg);
    }
  }

  async shutdown(): Promise<void> {
    if (!this.isInitialized) return;

    try {
      await this.tracker.stopMonitoring();
      this.tracker.removeAllListeners();
      this.isInitialized = false;
      this.emit('shutdown');
    } catch (error) {
      this.emit('error', new Error(`Failed to shutdown focus tracking: ${error}`));
    }
  }

  async getCurrentFocus(): Promise<FocusEvent | null> {
    if (!this.isInitialized) {
      throw new Error('Focus manager not initialized');
    }
    return await this.tracker.getCurrentFocus();
  }

  private handleFocusChange(event: FocusEvent): void {
    // Enrich with additional metadata
    event.metadata = {
      ...event.metadata,
      capturedAt: Date.now() * 1000,
      platform: this.currentPlatform
    };

    // Forward to listeners
    this.emit('focusChanged', event);
  }

  private handleElementFocusChange(elementInfo: any): void {
    // Emit element focus change for keyboard navigation tracking
    this.emit('elementFocusChanged', {
      timestamp: Date.now() * 1000,
      element: elementInfo,
      platform: this.currentPlatform
    });
  }

  private handleTrackerError(error: Error): void {
    this.emit('error', error);
  }

  get platform(): Platform {
    return this.currentPlatform;
  }

  get initialized(): boolean {
    return this.isInitialized;
  }
}
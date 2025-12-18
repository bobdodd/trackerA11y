/**
 * Cross-platform Interaction Monitoring Manager
 * Captures and processes mouse, keyboard, and accessibility interactions
 */

import { EventEmitter } from 'events';
import { 
  InteractionEvent, 
  Platform,
  InteractionConfig
} from '@/types';
import { BaseInteractionTracker } from './BaseInteractionTracker';

export class InteractionManager extends EventEmitter {
  private tracker: BaseInteractionTracker | null = null;
  private currentPlatform: Platform;
  private isInitialized = false;
  private isMonitoring = false;
  private config: InteractionConfig;
  
  // Statistics
  private stats = {
    totalInteractions: 0,
    mouseEvents: 0,
    keyboardEvents: 0,
    touchEvents: 0,
    lastInteractionTime: 0
  };

  constructor(config: InteractionConfig = {}) {
    super();
    this.currentPlatform = this.detectPlatform();
    this.config = {
      enableMouse: true,
      enableKeyboard: true,
      enableTouch: false,
      enableAccessibility: true,
      privacyMode: 'safe',
      captureLevel: 'events',
      filterSensitive: true,
      ...config
    };
  }

  /**
   * Initialize the interaction manager
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      // Create platform-specific tracker
      this.tracker = await this.createPlatformTracker();
      
      if (!this.tracker) {
        throw new Error(`Interaction tracking not supported on ${this.currentPlatform}`);
      }

      // Set up event handlers
      this.setupEventHandlers();

      // Initialize the tracker
      await this.tracker.initialize();

      this.isInitialized = true;
      this.emit('initialized');

    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Start monitoring interactions
   */
  async startMonitoring(): Promise<void> {
    if (!this.isInitialized || !this.tracker) {
      throw new Error('Interaction manager not initialized');
    }

    if (this.isMonitoring) {
      return;
    }

    try {
      await this.tracker.startMonitoring();
      this.isMonitoring = true;
      this.emit('monitoringStarted');
    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Stop monitoring interactions
   */
  async stopMonitoring(): Promise<void> {
    if (!this.isMonitoring || !this.tracker) {
      return;
    }

    try {
      await this.tracker.stopMonitoring();
      this.isMonitoring = false;
      this.emit('monitoringStopped');
    } catch (error) {
      this.emit('error', error);
    }
  }

  /**
   * Get current interaction statistics
   */
  getStatistics() {
    return { ...this.stats };
  }

  /**
   * Update interaction configuration
   */
  updateConfig(newConfig: Partial<InteractionConfig>): void {
    this.config = { ...this.config, ...newConfig };
    
    if (this.tracker) {
      this.tracker.updateConfig(this.config);
    }
    
    this.emit('configUpdated', this.config);
  }

  /**
   * Get supported interaction types for current platform
   */
  getSupportedTypes(): string[] {
    if (!this.tracker) {
      return [];
    }
    return this.tracker.getSupportedTypes();
  }

  private detectPlatform(): Platform {
    switch (process.platform) {
      case 'darwin':
        return 'macos';
      case 'win32':
        return 'windows';
      case 'linux':
        return 'linux';
      default:
        throw new Error(`Unsupported platform: ${process.platform}`);
    }
  }

  private async createPlatformTracker(): Promise<BaseInteractionTracker | null> {
    switch (this.currentPlatform) {
      case 'macos':
        // Use native helper for real system-wide event capture
        const { NativeInteractionTracker } = await import('./macos/NativeInteractionTracker');
        return new NativeInteractionTracker(this.config);
      
      case 'windows':
        // Future implementation
        throw new Error('Windows interaction tracking not yet implemented');
      
      case 'linux':
        // Future implementation  
        throw new Error('Linux interaction tracking not yet implemented');
      
      default:
        return null;
    }
  }

  private setupEventHandlers(): void {
    if (!this.tracker) return;

    this.tracker.on('interaction', (event: InteractionEvent) => {
      this.handleInteraction(event);
    });

    this.tracker.on('error', (error: Error) => {
      this.emit('error', error);
    });

    this.tracker.on('permissionRequired', (info: any) => {
      this.emit('permissionRequired', info);
    });
  }

  private handleInteraction(event: InteractionEvent): void {
    // Update statistics
    this.updateStatistics(event);

    // Apply privacy filtering if enabled
    const filteredEvent = this.applyPrivacyFilters(event);

    // Emit the interaction event
    this.emit('interaction', filteredEvent);
  }

  private updateStatistics(event: InteractionEvent): void {
    this.stats.totalInteractions++;
    this.stats.lastInteractionTime = event.timestamp;

    switch (event.data.interactionType) {
      case 'click':
      case 'scroll':
        this.stats.mouseEvents++;
        break;
      case 'key':
        this.stats.keyboardEvents++;
        break;
      case 'touch':
        this.stats.touchEvents++;
        break;
    }
  }

  private applyPrivacyFilters(event: InteractionEvent): InteractionEvent {
    if (!this.config.filterSensitive) {
      return event;
    }

    const filtered = { ...event };

    // Filter sensitive keyboard input
    if (event.data.interactionType === 'key' && event.data.inputData?.text) {
      // Only capture navigation keys, not text content
      if (!this.isNavigationKey(event.data.inputData.key)) {
        filtered.data = {
          ...filtered.data,
          inputData: {
            ...event.data.inputData,
            text: '[filtered]'
          }
        };
      }
    }

    return filtered;
  }

  private isNavigationKey(key?: string): boolean {
    if (!key) return false;
    
    const navigationKeys = [
      'Tab', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight',
      'Enter', 'Escape', 'Space', 'Home', 'End', 'PageUp', 'PageDown',
      'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'
    ];
    
    return navigationKeys.includes(key);
  }

  /**
   * Shutdown the interaction manager
   */
  async shutdown(): Promise<void> {
    await this.stopMonitoring();
    
    if (this.tracker) {
      await this.tracker.shutdown();
      this.tracker = null;
    }
    
    this.isInitialized = false;
    this.emit('shutdown');
  }
}
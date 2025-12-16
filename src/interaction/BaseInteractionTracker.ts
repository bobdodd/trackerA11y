/**
 * Base class for platform-specific interaction trackers
 * Provides common interface and functionality for interaction monitoring
 */

import { EventEmitter } from 'events';
import { InteractionEvent, InteractionConfig } from '@/types';

export abstract class BaseInteractionTracker extends EventEmitter {
  protected config: InteractionConfig;
  protected isInitialized = false;
  protected isMonitoring = false;

  constructor(config: InteractionConfig) {
    super();
    this.config = config;
  }

  /**
   * Initialize the tracker
   */
  abstract initialize(): Promise<void>;

  /**
   * Start monitoring interactions
   */
  abstract startMonitoring(): Promise<void>;

  /**
   * Stop monitoring interactions
   */
  abstract stopMonitoring(): Promise<void>;

  /**
   * Get supported interaction types
   */
  abstract getSupportedTypes(): string[];

  /**
   * Update tracker configuration
   */
  updateConfig(config: InteractionConfig): void {
    this.config = config;
  }

  /**
   * Check if tracker is initialized
   */
  get initialized(): boolean {
    return this.isInitialized;
  }

  /**
   * Check if tracker is monitoring
   */
  get monitoring(): boolean {
    return this.isMonitoring;
  }

  /**
   * Create a standardized interaction event
   */
  protected createInteractionEvent(
    interactionType: string,
    data: any,
    timestamp?: number
  ): InteractionEvent {
    return {
      id: `interaction_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      timestamp: timestamp || Date.now() * 1000, // Convert to microseconds
      type: 'interaction',
      source: 'interaction',
      data: {
        interactionType: interactionType as any,
        target: data.target,
        inputData: data.inputData
      },
      metadata: {
        platform: process.platform,
        sessionId: data.sessionId,
        confidence: data.confidence || 1.0,
        capturedAt: Date.now() * 1000
      }
    };
  }

  /**
   * Shutdown the tracker
   */
  async shutdown(): Promise<void> {
    await this.stopMonitoring();
    this.isInitialized = false;
  }
}
/**
 * TrackerA11y Core Integration Service
 * Orchestrates all accessibility tracking components and event correlation
 */

import { EventEmitter } from 'events';
import { FocusManager } from './FocusManager';
import { AudioProcessorBridge } from '@/bridge/AudioProcessorBridge';
import { EventCorrelator } from '@/correlation/EventCorrelator';
import { InteractionManager } from '@/interaction/InteractionManager';
import { 
  TrackerA11yConfig, 
  TimestampedEvent, 
  FocusEvent, 
  AudioEvent,
  InteractionEvent,
  CorrelatedEvent,
  AccessibilityInsight,
  CorrelationConfig,
  AudioConfig,
  InteractionConfig
} from '@/types';

export interface TrackerA11yStats {
  uptime: number;
  eventsProcessed: {
    focus: number;
    audio: number;
    interaction: number;
    total: number;
  };
  correlations: {
    found: number;
    avgConfidence: number;
  };
  insights: {
    generated: number;
    byType: Record<string, number>;
    bySeverity: Record<string, number>;
  };
  performance: {
    avgEventProcessingTime: number;
    avgCorrelationTime: number;
  };
}

export class TrackerA11yCore extends EventEmitter {
  private config: TrackerA11yConfig;
  private focusManager: FocusManager;
  private audioProcessor: AudioProcessorBridge | null = null;
  private interactionManager: InteractionManager | null = null;
  private eventCorrelator: EventCorrelator;
  private isInitialized = false;
  private isActive = false;
  private startTime: number = 0;
  
  // Statistics tracking
  private stats: TrackerA11yStats = {
    uptime: 0,
    eventsProcessed: {
      focus: 0,
      audio: 0,
      interaction: 0,
      total: 0
    },
    correlations: {
      found: 0,
      avgConfidence: 0
    },
    insights: {
      generated: 0,
      byType: {},
      bySeverity: {}
    },
    performance: {
      avgEventProcessingTime: 0,
      avgCorrelationTime: 0
    }
  };
  
  // Event storage for analysis
  private recentEvents: TimestampedEvent[] = [];
  private recentInsights: AccessibilityInsight[] = [];

  constructor(config: TrackerA11yConfig) {
    super();
    this.config = config;
    
    // Initialize core components
    this.focusManager = new FocusManager();
    this.eventCorrelator = new EventCorrelator(this.getCorrelationConfig());
    
    // Initialize audio processor if configured
    if (config.audioIntegration) {
      this.audioProcessor = new AudioProcessorBridge(config.audioIntegration);
    }
    
    // Initialize interaction manager if configured
    if (config.interactionTracking !== false) {
      this.interactionManager = new InteractionManager(config.interactionConfig || {});
    }
    
    this.setupEventHandlers();
  }

  /**
   * Initialize all components
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    console.log('🚀 Initializing TrackerA11y Core...');
    this.startTime = Date.now();

    try {
      // Initialize components in sequence
      await this.focusManager.initialize();
      console.log('✅ Focus tracking initialized');

      if (this.audioProcessor) {
        await this.audioProcessor.initialize();
        console.log('✅ Audio processing initialized');
      }

      if (this.interactionManager) {
        await this.interactionManager.initialize();
        console.log('✅ Interaction monitoring initialized');
      }

      await this.eventCorrelator.initialize();
      console.log('✅ Event correlation initialized');

      this.isInitialized = true;
      this.emit('initialized');
      console.log('🎯 TrackerA11y Core initialized successfully');

    } catch (error) {
      console.error('❌ Failed to initialize TrackerA11y Core:', error);
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Start accessibility tracking
   */
  async start(): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('TrackerA11y Core not initialized');
    }

    if (this.isActive) {
      return;
    }

    console.log('▶️ Starting accessibility tracking...');

    try {
      // Start focus tracking (no specific start method, it's event-driven)
      // Audio processor starts automatically when initialized
      
      // Start interaction monitoring if available
      if (this.interactionManager) {
        await this.interactionManager.startMonitoring();
        console.log('👆 Interaction monitoring started');
      }
      
      this.isActive = true;
      this.emit('started');
      console.log('🎬 Accessibility tracking started');

    } catch (error) {
      console.error('❌ Failed to start tracking:', error);
      this.emit('error', error);
      throw error;
    }
  }

  /**
   * Stop accessibility tracking
   */
  async stop(): Promise<void> {
    if (!this.isActive) {
      return;
    }

    console.log('⏹️ Stopping accessibility tracking...');

    // Stop interaction monitoring
    if (this.interactionManager) {
      await this.interactionManager.stopMonitoring();
    }

    this.isActive = false;
    this.emit('stopped');
    console.log('⏸️ Accessibility tracking stopped');
  }

  /**
   * Get current focus information
   */
  async getCurrentFocus(): Promise<FocusEvent | null> {
    if (!this.isInitialized) {
      throw new Error('TrackerA11y Core not initialized');
    }

    return await this.focusManager.getCurrentFocus();
  }

  /**
   * Get tracking statistics
   */
  getStatistics(): TrackerA11yStats {
    const correlationStats = this.eventCorrelator.getStatistics();
    
    return {
      ...this.stats,
      uptime: this.isInitialized ? Date.now() - this.startTime : 0,
      correlations: {
        found: correlationStats.correlationsFound,
        avgConfidence: correlationStats.correlationsFound > 0 ? 0.8 : 0 // Placeholder
      },
      insights: {
        generated: correlationStats.insightsGenerated,
        byType: this.groupInsightsByType(),
        bySeverity: this.groupInsightsBySeverity()
      },
      performance: {
        avgEventProcessingTime: correlationStats.averageProcessingTime,
        avgCorrelationTime: 0 // Placeholder
      }
    };
  }

  /**
   * Get recent events
   */
  getRecentEvents(limit: number = 50): TimestampedEvent[] {
    return this.recentEvents.slice(-limit);
  }

  /**
   * Get recent insights
   */
  getRecentInsights(limit: number = 20): AccessibilityInsight[] {
    return this.recentInsights.slice(-limit);
  }

  /**
   * Get insights by severity
   */
  getInsightsBySeverity(severity: 'low' | 'medium' | 'high' | 'critical'): AccessibilityInsight[] {
    return this.recentInsights.filter(insight => insight.severity === severity);
  }

  /**
   * Add a custom correlation rule
   */
  addCorrelationRule(rule: any): void {
    this.eventCorrelator.registerRule(rule);
  }

  /**
   * Remove a correlation rule
   */
  removeCorrelationRule(ruleId: string): boolean {
    return this.eventCorrelator.removeRule(ruleId);
  }

  private setupEventHandlers(): void {
    // Focus event handling
    this.focusManager.on('focusChanged', (event: FocusEvent) => {
      this.handleEvent(event);
    });

    this.focusManager.on('error', (error) => {
      this.emit('error', error);
    });

    // Audio event handling
    if (this.audioProcessor) {
      this.audioProcessor.on('audioEvents', (events: AudioEvent[]) => {
        events.forEach(event => this.handleEvent(event));
      });

      this.audioProcessor.on('error', (error) => {
        this.emit('error', error);
      });
    }

    // Interaction event handling
    if (this.interactionManager) {
      this.interactionManager.on('interaction', (event: InteractionEvent) => {
        this.handleEvent(event);
      });

      this.interactionManager.on('error', (error) => {
        this.emit('error', error);
      });

      this.interactionManager.on('permissionRequired', (info) => {
        this.emit('permissionRequired', info);
      });
    }

    // Correlation event handling
    this.eventCorrelator.on('correlationFound', ({ correlation, ruleId }) => {
      this.handleCorrelation(correlation, ruleId);
    });

    this.eventCorrelator.on('insightGenerated', (insight: AccessibilityInsight) => {
      this.handleInsight(insight);
    });

    this.eventCorrelator.on('error', (error) => {
      this.emit('error', error);
    });
  }

  private handleEvent(event: TimestampedEvent): void {
    const startTime = performance.now();

    try {
      // Update statistics
      this.stats.eventsProcessed.total++;
      this.stats.eventsProcessed[event.source as keyof typeof this.stats.eventsProcessed]++;

      // Store recent events
      this.recentEvents.push(event);
      if (this.recentEvents.length > 1000) {
        this.recentEvents.splice(0, this.recentEvents.length - 1000);
      }

      // Add to correlation engine
      this.eventCorrelator.addEvent(event);

      // Update performance metrics
      const processingTime = performance.now() - startTime;
      this.updateAvgProcessingTime(processingTime);

      this.emit('eventProcessed', event);

    } catch (error) {
      console.error('Error handling event:', error);
      this.emit('error', error);
    }
  }

  private handleCorrelation(correlation: CorrelatedEvent, ruleId: string): void {
    console.log(`🔗 Correlation found (${ruleId}):`, {
      type: correlation.correlationType,
      confidence: correlation.confidence,
      eventCount: correlation.relatedEvents.length + 1
    });

    this.emit('correlation', { correlation, ruleId });
  }

  private handleInsight(insight: AccessibilityInsight): void {
    // Store insight
    this.recentInsights.push(insight);
    if (this.recentInsights.length > 500) {
      this.recentInsights.splice(0, this.recentInsights.length - 500);
    }

    // Update statistics
    this.stats.insights.generated++;

    console.log(`💡 Accessibility insight generated:`, {
      type: insight.type,
      severity: insight.severity,
      description: insight.description.substring(0, 100) + '...'
    });

    this.emit('insight', insight);

    // Emit high-severity insights as alerts
    if (insight.severity === 'high' || insight.severity === 'critical') {
      this.emit('alert', insight);
    }
  }

  private getCorrelationConfig(): CorrelationConfig {
    return {
      eventBuffer: {
        maxEventsPerSource: 1000,
        maxEventAge: 300000000, // 5 minutes in microseconds
        cleanupInterval: 60000 // 1 minute in milliseconds
      },
      correlationRules: {
        maxTimeWindow: 10000000, // 10 seconds in microseconds
        minConfidence: 0.6
      },
      insights: {
        enableAutoGeneration: true,
        severityThreshold: 'low'
      }
    };
  }

  private groupInsightsByType(): Record<string, number> {
    const byType: Record<string, number> = {};
    for (const insight of this.recentInsights) {
      byType[insight.type] = (byType[insight.type] || 0) + 1;
    }
    return byType;
  }

  private groupInsightsBySeverity(): Record<string, number> {
    const bySeverity: Record<string, number> = {};
    for (const insight of this.recentInsights) {
      bySeverity[insight.severity] = (bySeverity[insight.severity] || 0) + 1;
    }
    return bySeverity;
  }

  private updateAvgProcessingTime(newTime: number): void {
    const total = this.stats.eventsProcessed.total;
    const currentAvg = this.stats.performance.avgEventProcessingTime;
    
    this.stats.performance.avgEventProcessingTime = 
      (currentAvg * (total - 1) + newTime) / total;
  }

  /**
   * Shutdown all components
   */
  async shutdown(): Promise<void> {
    console.log('🛑 Shutting down TrackerA11y Core...');

    await this.stop();

    try {
      await this.focusManager.shutdown();
      
      if (this.audioProcessor) {
        await this.audioProcessor.shutdown();
      }
      
      if (this.interactionManager) {
        await this.interactionManager.shutdown();
      }
      
      await this.eventCorrelator.shutdown();

      this.isInitialized = false;
      this.emit('shutdown');
      console.log('✅ TrackerA11y Core shutdown complete');

    } catch (error) {
      console.error('❌ Error during shutdown:', error);
      this.emit('error', error);
    }
  }

  /**
   * Export current session data
   */
  exportSessionData(): {
    metadata: {
      startTime: number;
      duration: number;
      platform: string;
      config: TrackerA11yConfig;
    };
    statistics: TrackerA11yStats;
    events: TimestampedEvent[];
    insights: AccessibilityInsight[];
  } {
    return {
      metadata: {
        startTime: this.startTime,
        duration: Date.now() - this.startTime,
        platform: process.platform,
        config: this.config
      },
      statistics: this.getStatistics(),
      events: this.recentEvents,
      insights: this.recentInsights
    };
  }
}
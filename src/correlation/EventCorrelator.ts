/**
 * Real-time Event Correlation Engine
 * Correlates events from multiple sources (focus, audio, interaction) to generate accessibility insights
 */

import { EventEmitter } from 'events';
import { 
  TimestampedEvent, 
  FocusEvent, 
  AudioEvent, 
  InteractionEvent,
  CorrelatedEvent,
  AccessibilityInsight,
  CorrelationConfig
} from '@/types';

export interface CorrelationWindow {
  windowSize: number; // milliseconds
  maxEvents: number;
  cleanupInterval: number; // milliseconds
}

export interface CorrelationRule {
  id: string;
  name: string;
  sources: string[]; // event sources to correlate
  timeWindow: number; // max time difference in microseconds
  minConfidence: number;
  handler: (events: TimestampedEvent[]) => CorrelatedEvent | null;
}

export class EventCorrelator extends EventEmitter {
  private config: CorrelationConfig;
  private eventBuffer: Map<string, TimestampedEvent[]> = new Map();
  private correlationRules: Map<string, CorrelationRule> = new Map();
  private cleanupTimer: NodeJS.Timeout | null = null;
  private isActive = false;
  
  // Performance metrics
  private stats = {
    eventsProcessed: 0,
    correlationsFound: 0,
    insightsGenerated: 0,
    averageProcessingTime: 0
  };

  constructor(config: CorrelationConfig) {
    super();
    this.config = config;
    this.setupDefaultRules();
    this.startCleanupTimer();
  }

  /**
   * Initialize the correlation engine
   */
  async initialize(): Promise<void> {
    if (this.isActive) {
      return;
    }

    this.isActive = true;
    this.emit('initialized');
    console.log('Event correlation engine initialized');
  }

  /**
   * Add an event to the correlation buffer
   */
  addEvent(event: TimestampedEvent): void {
    if (!this.isActive) {
      throw new Error('Correlation engine not initialized');
    }

    const startTime = performance.now();

    // Add to event buffer
    const sourceBuffer = this.getOrCreateBuffer(event.source);
    sourceBuffer.push(event);

    // Maintain buffer size
    this.maintainBufferSize(event.source);

    // Find correlations for this event
    this.findCorrelations(event);

    // Update performance metrics
    this.stats.eventsProcessed++;
    const processingTime = performance.now() - startTime;
    this.updateAverageProcessingTime(processingTime);

    this.emit('eventAdded', event);
  }

  /**
   * Register a custom correlation rule
   */
  registerRule(rule: CorrelationRule): void {
    this.correlationRules.set(rule.id, rule);
    this.emit('ruleRegistered', rule);
  }

  /**
   * Remove a correlation rule
   */
  removeRule(ruleId: string): boolean {
    const removed = this.correlationRules.delete(ruleId);
    if (removed) {
      this.emit('ruleRemoved', ruleId);
    }
    return removed;
  }

  /**
   * Get correlation statistics
   */
  getStatistics(): typeof this.stats {
    return { ...this.stats };
  }

  /**
   * Clear all event buffers
   */
  clearBuffers(): void {
    this.eventBuffer.clear();
    this.emit('buffersCleaned');
  }

  /**
   * Get events from a specific source within a time window
   */
  getEventsInWindow(
    source: string, 
    centerTime: number, 
    windowSize: number
  ): TimestampedEvent[] {
    const buffer = this.eventBuffer.get(source);
    if (!buffer) {
      return [];
    }

    const startTime = centerTime - windowSize / 2;
    const endTime = centerTime + windowSize / 2;

    return buffer.filter(event => 
      event.timestamp >= startTime && event.timestamp <= endTime
    );
  }

  private getOrCreateBuffer(source: string): TimestampedEvent[] {
    let buffer = this.eventBuffer.get(source);
    if (!buffer) {
      buffer = [];
      this.eventBuffer.set(source, buffer);
    }
    return buffer;
  }

  private maintainBufferSize(source: string): void {
    const buffer = this.eventBuffer.get(source);
    if (!buffer) return;

    const maxSize = this.config.eventBuffer.maxEventsPerSource;
    if (buffer.length > maxSize) {
      // Remove oldest events
      buffer.splice(0, buffer.length - maxSize);
    }
  }

  private findCorrelations(newEvent: TimestampedEvent): void {
    for (const [ruleId, rule] of this.correlationRules) {
      // Check if this rule applies to the new event
      if (!rule.sources.includes(newEvent.source)) {
        continue;
      }

      // Find related events within the time window
      const relatedEvents = this.findRelatedEvents(newEvent, rule);
      
      if (relatedEvents.length >= 2) { // Need at least 2 events to correlate
        try {
          const correlation = rule.handler([newEvent, ...relatedEvents]);
          if (correlation) {
            this.handleCorrelation(correlation, ruleId);
          }
        } catch (error) {
          console.error(`Error in correlation rule ${ruleId}:`, error);
          this.emit('correlationError', { ruleId, error, event: newEvent });
        }
      }
    }
  }

  private findRelatedEvents(
    targetEvent: TimestampedEvent, 
    rule: CorrelationRule
  ): TimestampedEvent[] {
    const relatedEvents: TimestampedEvent[] = [];
    const targetTime = targetEvent.timestamp;

    for (const source of rule.sources) {
      if (source === targetEvent.source) continue; // Skip same source

      const buffer = this.eventBuffer.get(source);
      if (!buffer) continue;

      // Find events within time window
      const candidateEvents = buffer.filter(event => {
        const timeDiff = Math.abs(event.timestamp - targetTime);
        return timeDiff <= rule.timeWindow;
      });

      // Get the closest event from this source
      if (candidateEvents.length > 0) {
        const closest = candidateEvents.reduce((prev, curr) => {
          const prevDiff = Math.abs(prev.timestamp - targetTime);
          const currDiff = Math.abs(curr.timestamp - targetTime);
          return currDiff < prevDiff ? curr : prev;
        });
        relatedEvents.push(closest);
      }
    }

    return relatedEvents;
  }

  private handleCorrelation(correlation: CorrelatedEvent, ruleId: string): void {
    this.stats.correlationsFound++;
    
    // Generate insights from correlation
    const insights = this.generateInsights(correlation);
    if (insights.length > 0) {
      this.stats.insightsGenerated += insights.length;
      correlation.insights = insights;
    }

    this.emit('correlationFound', { correlation, ruleId });

    // Emit insights separately for consumers
    insights.forEach(insight => {
      this.emit('insightGenerated', insight);
    });
  }

  private generateInsights(correlation: CorrelatedEvent): AccessibilityInsight[] {
    const insights: AccessibilityInsight[] = [];

    // Focus + Audio correlation analysis
    if (this.hasSources(correlation, ['focus', 'audio'])) {
      const focusInsights = this.analyzeFocusAudioCorrelation(correlation);
      insights.push(...focusInsights);
    }

    // Focus + Interaction correlation analysis
    if (this.hasSources(correlation, ['focus', 'interaction'])) {
      const interactionInsights = this.analyzeFocusInteractionCorrelation(correlation);
      insights.push(...interactionInsights);
    }

    // Audio + Interaction correlation analysis
    if (this.hasSources(correlation, ['audio', 'interaction'])) {
      const audioInteractionInsights = this.analyzeAudioInteractionCorrelation(correlation);
      insights.push(...audioInteractionInsights);
    }

    return insights;
  }

  private hasSources(correlation: CorrelatedEvent, sources: string[]): boolean {
    const eventSources = new Set([
      correlation.primaryEvent.source,
      ...correlation.relatedEvents.map(e => e.source)
    ]);
    return sources.every(source => eventSources.has(source as any));
  }

  private analyzeFocusAudioCorrelation(correlation: CorrelatedEvent): AccessibilityInsight[] {
    const insights: AccessibilityInsight[] = [];
    
    const focusEvent = this.findEventBySource(correlation, 'focus') as FocusEvent;
    const audioEvent = this.findEventBySource(correlation, 'audio') as AudioEvent;
    
    if (!focusEvent || !audioEvent) return insights;

    // Check for voice commands without proper focus
    if (audioEvent.data.text.toLowerCase().includes('click') || 
        audioEvent.data.text.toLowerCase().includes('select')) {
      
      const timeDiff = Math.abs(audioEvent.timestamp - focusEvent.timestamp) / 1000; // milliseconds
      
      if (timeDiff > 2000) { // More than 2 seconds gap
        insights.push({
          type: 'barrier',
          severity: 'medium',
          description: 'Voice command detected but focus may not be properly set on target element',
          wcagReference: 'WCAG 2.4.3 (Focus Order)',
          evidence: {
            audioEvidence: [audioEvent],
            focusEvidence: [focusEvent]
          },
          remediation: {
            description: 'Ensure focus is programmatically set when responding to voice commands',
            codeExample: 'element.focus(); // Set focus after voice command processing',
            resources: ['https://www.w3.org/WAI/WCAG21/Understanding/focus-order.html']
          }
        });
      }
    }

    // Check for frustrated speech patterns
    if (audioEvent.data.sentiment === 'frustrated' && 
        focusEvent.data.applicationName) {
      
      insights.push({
        type: 'pattern',
        severity: 'medium',
        description: `User frustration detected while using ${focusEvent.data.applicationName}`,
        evidence: {
          audioEvidence: [audioEvent],
          focusEvidence: [focusEvent]
        },
        remediation: {
          description: 'Review UI design and interaction patterns for accessibility barriers'
        }
      });
    }

    return insights;
  }

  private analyzeFocusInteractionCorrelation(correlation: CorrelatedEvent): AccessibilityInsight[] {
    const insights: AccessibilityInsight[] = [];
    
    const focusEvent = this.findEventBySource(correlation, 'focus') as FocusEvent;
    const interactionEvent = this.findEventBySource(correlation, 'interaction') as InteractionEvent;
    
    if (!focusEvent || !interactionEvent) return insights;

    // Check for rapid focus changes (potential keyboard traps)
    if (interactionEvent.data.interactionType === 'key' && 
        interactionEvent.data.inputData?.key === 'Tab') {
      
      insights.push({
        type: 'suggestion',
        severity: 'low',
        description: 'Tab navigation detected - verify focus indicators are visible',
        wcagReference: 'WCAG 2.4.7 (Focus Visible)',
        evidence: {
          focusEvidence: [focusEvent],
          interactionEvidence: [interactionEvent]
        },
        remediation: {
          description: 'Ensure focus indicators meet contrast requirements and are clearly visible',
          codeExample: ':focus { outline: 2px solid #0066cc; outline-offset: 2px; }'
        }
      });
    }

    return insights;
  }

  private analyzeAudioInteractionCorrelation(correlation: CorrelatedEvent): AccessibilityInsight[] {
    // Placeholder for future audio-interaction correlation analysis
    return [];
  }

  private findEventBySource(
    correlation: CorrelatedEvent, 
    source: string
  ): TimestampedEvent | null {
    if (correlation.primaryEvent.source === source) {
      return correlation.primaryEvent;
    }
    
    return correlation.relatedEvents.find(e => e.source === source) || null;
  }

  private setupDefaultRules(): void {
    // Focus + Audio correlation rule
    this.registerRule({
      id: 'focus-audio-correlation',
      name: 'Focus and Audio Event Correlation',
      sources: ['focus', 'audio'],
      timeWindow: 5000000, // 5 seconds in microseconds
      minConfidence: 0.7,
      handler: (events) => {
        const focusEvent = events.find(e => e.source === 'focus') as FocusEvent;
        const audioEvent = events.find(e => e.source === 'audio') as AudioEvent;
        
        if (!focusEvent || !audioEvent) return null;

        return {
          primaryEvent: focusEvent,
          relatedEvents: [audioEvent],
          correlationType: 'temporal',
          confidence: 0.85,
          insights: [] // Will be populated by generateInsights
        };
      }
    });

    // Focus + Interaction correlation rule
    this.registerRule({
      id: 'focus-interaction-correlation',
      name: 'Focus and Interaction Event Correlation',
      sources: ['focus', 'interaction'],
      timeWindow: 1000000, // 1 second in microseconds
      minConfidence: 0.8,
      handler: (events) => {
        const focusEvent = events.find(e => e.source === 'focus') as FocusEvent;
        const interactionEvent = events.find(e => e.source === 'interaction') as InteractionEvent;
        
        if (!focusEvent || !interactionEvent) return null;

        return {
          primaryEvent: interactionEvent,
          relatedEvents: [focusEvent],
          correlationType: 'causal',
          confidence: 0.9,
          insights: []
        };
      }
    });

    // Multi-source correlation rule
    this.registerRule({
      id: 'multi-modal-correlation',
      name: 'Multi-Modal Accessibility Pattern',
      sources: ['focus', 'audio', 'interaction'],
      timeWindow: 10000000, // 10 seconds in microseconds
      minConfidence: 0.6,
      handler: (events) => {
        if (events.length < 3) return null;

        // Find the most recent event as primary
        const primaryEvent = events.reduce((latest, current) => 
          current.timestamp > latest.timestamp ? current : latest
        );

        const relatedEvents = events.filter(e => e !== primaryEvent);

        return {
          primaryEvent,
          relatedEvents,
          correlationType: 'semantic',
          confidence: 0.75,
          insights: []
        };
      }
    });
  }

  private startCleanupTimer(): void {
    const interval = this.config.eventBuffer.cleanupInterval || 60000; // 1 minute default
    
    this.cleanupTimer = setInterval(() => {
      this.cleanupOldEvents();
    }, interval);
  }

  private cleanupOldEvents(): void {
    const maxAge = this.config.eventBuffer.maxEventAge || 300000000; // 5 minutes in microseconds
    const cutoffTime = Date.now() * 1000 - maxAge; // Convert to microseconds
    
    let totalRemoved = 0;

    for (const [source, buffer] of this.eventBuffer) {
      const originalLength = buffer.length;
      
      // Remove events older than cutoff
      const filtered = buffer.filter(event => event.timestamp > cutoffTime);
      
      if (filtered.length < originalLength) {
        this.eventBuffer.set(source, filtered);
        totalRemoved += originalLength - filtered.length;
      }
    }

    if (totalRemoved > 0) {
      this.emit('eventsCleanedUp', { removed: totalRemoved });
    }
  }

  private updateAverageProcessingTime(newTime: number): void {
    const count = this.stats.eventsProcessed;
    const currentAvg = this.stats.averageProcessingTime;
    
    // Rolling average
    this.stats.averageProcessingTime = 
      (currentAvg * (count - 1) + newTime) / count;
  }

  /**
   * Shutdown the correlation engine
   */
  async shutdown(): Promise<void> {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = null;
    }

    this.clearBuffers();
    this.isActive = false;
    this.emit('shutdown');
  }
}
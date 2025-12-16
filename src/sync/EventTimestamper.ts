/**
 * Event Timestamper for TrackerA11y
 * Provides consistent timestamping across all event sources
 */

import { TimeSync, TimeReference } from './TimeSync';
import { TimestampedEvent } from '@/types';

export interface TimestampMetadata {
  sourceTime: number; // Original timestamp from source
  syncedTime: number; // Time-synchronized timestamp
  uncertainty: number; // Timing uncertainty in microseconds
  source: 'system' | 'audio' | 'performance' | 'external';
  correlationWindow: string; // Time window ID for event correlation
  clockDrift?: number; // Clock drift at time of capture
  ntpOffset?: number; // NTP offset at time of capture
}

export interface EventTimingInfo {
  originalTimestamp: number;
  synchronizedTimestamp: number;
  latency: number; // Processing latency
  accuracy: number; // Timestamp accuracy
  source: string;
  metadata: TimestampMetadata;
}

export class EventTimestamper {
  private timeSync: TimeSync;
  private sessionId: string;
  private sequenceCounter = 0;

  constructor(timeSync: TimeSync, sessionId?: string) {
    this.timeSync = timeSync;
    this.sessionId = sessionId || `session_${Date.now()}`;
  }

  /**
   * Timestamp an event with synchronized time
   */
  timestampEvent<T extends TimestampedEvent>(
    event: Omit<T, 'timestamp' | 'id'>,
    options: {
      sourceTime?: number;
      timeSource?: 'system' | 'audio' | 'performance' | 'external';
      correlationWindowSize?: number;
    } = {}
  ): T {
    const captureTime = this.timeSync.performanceNow();
    const sourceTime = options.sourceTime || captureTime;
    const timeSource = options.timeSource || 'performance';
    
    // Synchronize the timestamp
    const synchronizedTime = this.timeSync.synchronizeEventTime(sourceTime, timeSource);
    
    // Calculate timing metadata
    const uncertainty = this.timeSync.getTimeUncertainty(synchronizedTime);
    const metrics = this.timeSync.getMetrics();
    const correlationWindow = this.timeSync.createCorrelationWindow(
      options.correlationWindowSize || 1000000 // Default 1-second window
    );
    
    // Generate unique event ID
    const eventId = this.generateEventId(event.source);
    
    // Create timestamp metadata
    const timestampMetadata: TimestampMetadata = {
      sourceTime,
      syncedTime: synchronizedTime,
      uncertainty,
      source: timeSource,
      correlationWindow,
      clockDrift: metrics.drift,
      ntpOffset: this.timeSync.getMetrics().avgLatency > 0 ? metrics.avgLatency : undefined
    };

    // Build the complete event
    const timestampedEvent: T = {
      ...event,
      id: eventId,
      timestamp: synchronizedTime,
      metadata: {
        ...event.metadata,
        sessionId: this.sessionId,
        capturedAt: captureTime,
        timing: timestampMetadata
      }
    } as T;

    return timestampedEvent;
  }

  /**
   * Create a timing reference for event synchronization
   */
  createTimingReference(): EventTimingInfo {
    const originalTime = Date.now() * 1000;
    const performanceTime = this.timeSync.performanceNow();
    const synchronizedTime = this.timeSync.synchronizeEventTime(performanceTime, 'performance');
    const metrics = this.timeSync.getMetrics();
    
    return {
      originalTimestamp: originalTime,
      synchronizedTimestamp: synchronizedTime,
      latency: performanceTime - originalTime,
      accuracy: metrics.accuracy,
      source: 'timestamper',
      metadata: {
        sourceTime: originalTime,
        syncedTime: synchronizedTime,
        uncertainty: metrics.precision,
        source: 'performance',
        correlationWindow: this.timeSync.createCorrelationWindow(1000000)
      }
    };
  }

  /**
   * Synchronize a batch of events
   */
  synchronizeEvents<T extends TimestampedEvent>(
    events: T[],
    options: {
      preserveRelativeTiming?: boolean;
      timeSource?: 'system' | 'audio' | 'performance' | 'external';
    } = {}
  ): T[] {
    if (events.length === 0) return events;

    const timeSource = options.timeSource || 'performance';
    const preserveRelative = options.preserveRelativeTiming ?? true;

    if (!preserveRelative) {
      // Simple synchronization without preserving relative timing
      return events.map(event => 
        this.timestampEvent(event, { timeSource })
      );
    }

    // Preserve relative timing between events
    const sortedEvents = [...events].sort((a, b) => a.timestamp - b.timestamp);
    const baseEvent = sortedEvents[0];
    const baseSyncTime = this.timeSync.synchronizeEventTime(baseEvent.timestamp, timeSource);
    
    return sortedEvents.map(event => {
      const relativeDelta = event.timestamp - baseEvent.timestamp;
      const syncedTime = baseSyncTime + relativeDelta;
      
      return {
        ...event,
        timestamp: syncedTime,
        metadata: {
          ...event.metadata,
          sessionId: this.sessionId,
          timing: {
            sourceTime: event.timestamp,
            syncedTime,
            uncertainty: this.timeSync.getTimeUncertainty(syncedTime),
            source: timeSource,
            correlationWindow: this.timeSync.createCorrelationWindow(1000000)
          }
        }
      };
    });
  }

  /**
   * Calculate time correlation between events
   */
  calculateTimeCorrelation(
    event1: TimestampedEvent,
    event2: TimestampedEvent
  ): {
    timeDelta: number; // Microseconds between events
    uncertainty: number; // Combined uncertainty
    correlation: 'simultaneous' | 'sequential' | 'distant';
    confidence: number; // 0-1 correlation confidence
  } {
    const timeDelta = Math.abs(event2.timestamp - event1.timestamp);
    
    // Get uncertainties from metadata or calculate
    const uncertainty1 = (event1.metadata as any)?.timing?.uncertainty || 
                        this.timeSync.getTimeUncertainty(event1.timestamp);
    const uncertainty2 = (event2.metadata as any)?.timing?.uncertainty || 
                        this.timeSync.getTimeUncertainty(event2.timestamp);
    
    const combinedUncertainty = Math.sqrt(uncertainty1 ** 2 + uncertainty2 ** 2);
    
    // Determine correlation type
    let correlation: 'simultaneous' | 'sequential' | 'distant';
    let confidence: number;
    
    if (timeDelta <= combinedUncertainty * 2) {
      correlation = 'simultaneous';
      confidence = 1 - (timeDelta / (combinedUncertainty * 2));
    } else if (timeDelta <= 100000) { // 100ms
      correlation = 'sequential';
      confidence = 1 - (timeDelta / 100000);
    } else {
      correlation = 'distant';
      confidence = Math.max(0, 1 - (timeDelta / 1000000)); // 1 second max
    }
    
    return {
      timeDelta,
      uncertainty: combinedUncertainty,
      correlation,
      confidence: Math.max(0, Math.min(1, confidence))
    };
  }

  /**
   * Group events by time correlation windows
   */
  groupEventsByTimeWindow<T extends TimestampedEvent>(
    events: T[],
    windowSize: number = 1000000 // 1 second default
  ): Map<string, T[]> {
    const groups = new Map<string, T[]>();
    
    for (const event of events) {
      const windowId = this.timeSync.createCorrelationWindow(windowSize);
      const eventWindowId = Math.floor(event.timestamp / windowSize);
      const key = `timewindow_${eventWindowId}_${windowSize}us`;
      
      if (!groups.has(key)) {
        groups.set(key, []);
      }
      groups.get(key)!.push(event);
    }
    
    return groups;
  }

  /**
   * Get timing statistics for a set of events
   */
  getTimingStatistics<T extends TimestampedEvent>(events: T[]): {
    totalEvents: number;
    timeSpan: number; // Total time span in microseconds
    averageInterval: number; // Average time between events
    minInterval: number;
    maxInterval: number;
    frequency: number; // Events per second
    synchronizationAccuracy: number; // Average accuracy
  } {
    if (events.length === 0) {
      return {
        totalEvents: 0,
        timeSpan: 0,
        averageInterval: 0,
        minInterval: 0,
        maxInterval: 0,
        frequency: 0,
        synchronizationAccuracy: 0
      };
    }

    const sortedEvents = [...events].sort((a, b) => a.timestamp - b.timestamp);
    const intervals: number[] = [];
    const uncertainties: number[] = [];
    
    for (let i = 1; i < sortedEvents.length; i++) {
      const interval = sortedEvents[i].timestamp - sortedEvents[i - 1].timestamp;
      intervals.push(interval);
      
      const uncertainty = (sortedEvents[i].metadata as any)?.timing?.uncertainty;
      if (uncertainty) {
        uncertainties.push(uncertainty);
      }
    }

    const timeSpan = sortedEvents[sortedEvents.length - 1].timestamp - sortedEvents[0].timestamp;
    const averageInterval = intervals.length > 0 ? intervals.reduce((a, b) => a + b, 0) / intervals.length : 0;
    const frequency = timeSpan > 0 ? (events.length - 1) / (timeSpan / 1000000) : 0;
    const synchronizationAccuracy = uncertainties.length > 0 
      ? uncertainties.reduce((a, b) => a + b, 0) / uncertainties.length 
      : this.timeSync.getMetrics().accuracy;

    return {
      totalEvents: events.length,
      timeSpan,
      averageInterval,
      minInterval: intervals.length > 0 ? Math.min(...intervals) : 0,
      maxInterval: intervals.length > 0 ? Math.max(...intervals) : 0,
      frequency,
      synchronizationAccuracy
    };
  }

  /**
   * Validate event timing consistency
   */
  validateEventTiming<T extends TimestampedEvent>(events: T[]): {
    isValid: boolean;
    issues: string[];
    statistics: ReturnType<typeof this.getTimingStatistics>;
  } {
    const issues: string[] = [];
    const stats = this.getTimingStatistics(events);
    
    // Check for negative time intervals
    const sortedEvents = [...events].sort((a, b) => a.timestamp - b.timestamp);
    for (let i = 1; i < sortedEvents.length; i++) {
      if (sortedEvents[i].timestamp < sortedEvents[i - 1].timestamp) {
        issues.push(`Event ${i} has timestamp earlier than previous event`);
      }
    }
    
    // Check for unrealistic frequencies
    if (stats.frequency > 10000) { // More than 10kHz
      issues.push(`Unrealistic event frequency: ${stats.frequency.toFixed(2)} Hz`);
    }
    
    // Check for timing gaps
    const maxReasonableGap = 10000000; // 10 seconds
    if (stats.maxInterval > maxReasonableGap) {
      issues.push(`Large timing gap detected: ${(stats.maxInterval / 1000000).toFixed(2)} seconds`);
    }
    
    return {
      isValid: issues.length === 0,
      issues,
      statistics: stats
    };
  }

  private generateEventId(source: string): string {
    const timestamp = this.timeSync.now();
    const sequence = ++this.sequenceCounter;
    const sessionPrefix = this.sessionId.split('_')[1] || 'unknown';
    
    return `${source}_${sessionPrefix}_${timestamp}_${sequence}`;
  }

  /**
   * Get current session ID
   */
  getSessionId(): string {
    return this.sessionId;
  }

  /**
   * Update session ID (for session transitions)
   */
  setSessionId(sessionId: string): void {
    this.sessionId = sessionId;
    this.sequenceCounter = 0; // Reset sequence for new session
  }
}
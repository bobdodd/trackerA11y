/**
 * Unit tests for EventCorrelator
 * Tests event correlation, rule processing, and insight generation
 */

import { EventCorrelator, CorrelationRule } from '../../src/correlation/EventCorrelator';
import { 
  CorrelationConfig, 
  FocusEvent, 
  AudioEvent, 
  InteractionEvent,
  TimestampedEvent 
} from '../../src/types';

describe('EventCorrelator', () => {
  let correlator: EventCorrelator;
  let mockConfig: CorrelationConfig;

  beforeEach(() => {
    mockConfig = {
      eventBuffer: {
        maxEventsPerSource: 100,
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

    correlator = new EventCorrelator(mockConfig);
  });

  afterEach(async () => {
    await correlator.shutdown();
  });

  describe('initialization', () => {
    it('should initialize successfully', async () => {
      await expect(correlator.initialize()).resolves.toBeUndefined();
    });

    it('should emit initialized event', async () => {
      const initPromise = new Promise<void>((resolve) => {
        correlator.once('initialized', resolve);
      });

      await correlator.initialize();
      await initPromise;
    });

    it('should not initialize twice', async () => {
      await correlator.initialize();
      await expect(correlator.initialize()).resolves.toBeUndefined();
    });
  });

  describe('event processing', () => {
    beforeEach(async () => {
      await correlator.initialize();
    });

    it('should add events to buffer', () => {
      const focusEvent = createMockFocusEvent(Date.now() * 1000);
      
      expect(() => correlator.addEvent(focusEvent)).not.toThrow();
      
      const events = correlator.getEventsInWindow('focus', focusEvent.timestamp, 1000000);
      expect(events).toHaveLength(1);
      expect(events[0]).toEqual(focusEvent);
    });

    it('should emit eventAdded when event is processed', async () => {
      const focusEvent = createMockFocusEvent(Date.now() * 1000);
      
      const eventPromise = new Promise<TimestampedEvent>((resolve) => {
        correlator.once('eventAdded', resolve);
      });

      correlator.addEvent(focusEvent);
      
      const emittedEvent = await eventPromise;
      expect(emittedEvent).toEqual(focusEvent);
    });

    it('should maintain buffer size limits', async () => {
      const smallConfig = {
        ...mockConfig,
        eventBuffer: { ...mockConfig.eventBuffer, maxEventsPerSource: 2 }
      };
      
      const smallCorrelator = new EventCorrelator(smallConfig);
      await smallCorrelator.initialize(); // Initialize before using
      
      // Add 3 events, should keep only 2
      for (let i = 0; i < 3; i++) {
        const event = createMockFocusEvent((Date.now() + i * 1000) * 1000);
        smallCorrelator.addEvent(event);
      }
      
      const events = smallCorrelator.getEventsInWindow('focus', Date.now() * 1000, 10000000);
      expect(events.length).toBeLessThanOrEqual(2);
      
      await smallCorrelator.shutdown();
    });

    it('should throw error when not initialized', () => {
      const uninitializedCorrelator = new EventCorrelator(mockConfig);
      const focusEvent = createMockFocusEvent(Date.now() * 1000);
      
      expect(() => uninitializedCorrelator.addEvent(focusEvent))
        .toThrow('Correlation engine not initialized');
    });
  });

  describe('correlation rules', () => {
    beforeEach(async () => {
      await correlator.initialize();
    });

    it('should register custom rules', () => {
      const customRule: CorrelationRule = {
        id: 'test-rule',
        name: 'Test Rule',
        sources: ['focus', 'audio'],
        timeWindow: 1000000,
        minConfidence: 0.8,
        handler: () => null
      };

      expect(() => correlator.registerRule(customRule)).not.toThrow();
    });

    it('should emit ruleRegistered event', async () => {
      const customRule: CorrelationRule = {
        id: 'test-rule',
        name: 'Test Rule',
        sources: ['focus', 'audio'],
        timeWindow: 1000000,
        minConfidence: 0.8,
        handler: () => null
      };

      const rulePromise = new Promise<CorrelationRule>((resolve) => {
        correlator.once('ruleRegistered', resolve);
      });

      correlator.registerRule(customRule);
      
      const emittedRule = await rulePromise;
      expect(emittedRule).toEqual(customRule);
    });

    it('should remove rules', () => {
      const customRule: CorrelationRule = {
        id: 'test-rule',
        name: 'Test Rule',
        sources: ['focus', 'audio'],
        timeWindow: 1000000,
        minConfidence: 0.8,
        handler: () => null
      };

      correlator.registerRule(customRule);
      expect(correlator.removeRule('test-rule')).toBe(true);
      expect(correlator.removeRule('non-existent')).toBe(false);
    });
  });

  describe('event correlation', () => {
    beforeEach(async () => {
      await correlator.initialize();
    });

    it('should find correlations between focus and audio events', async () => {
      const baseTime = Date.now() * 1000;
      
      const correlationPromise = new Promise<any>((resolve) => {
        correlator.once('correlationFound', resolve);
      });

      // Add focus event first
      const focusEvent = createMockFocusEvent(baseTime);
      correlator.addEvent(focusEvent);

      // Give a short delay for processing
      await new Promise(resolve => setTimeout(resolve, 10));

      // Add audio event within correlation window
      const audioEvent = createMockAudioEvent(baseTime + 1000000); // 1 second later
      correlator.addEvent(audioEvent);

      const { correlation, ruleId } = await correlationPromise;
      
      expect(correlation).toBeDefined();
      expect(correlation.primaryEvent.source).toBe('focus');
      expect(correlation.relatedEvents).toHaveLength(1);
      expect(correlation.relatedEvents[0].source).toBe('audio');
      expect(ruleId).toBe('focus-audio-correlation');
    }, 10000); // 10 second timeout

    it('should not correlate events outside time window', async () => {
      let correlationFound = false;
      correlator.on('correlationFound', () => {
        correlationFound = true;
      });

      const baseTime = Date.now() * 1000;
      
      // Add focus event
      const focusEvent = createMockFocusEvent(baseTime);
      correlator.addEvent(focusEvent);

      // Add audio event outside correlation window (10+ seconds)
      const audioEvent = createMockAudioEvent(baseTime + 15000000); // 15 seconds later
      correlator.addEvent(audioEvent);

      // Wait a bit to see if correlation is found
      await new Promise(resolve => setTimeout(resolve, 100));
      
      expect(correlationFound).toBe(false);
    });

    it('should generate insights from correlations', async () => {
      const insightPromise = new Promise<any>((resolve) => {
        correlator.once('insightGenerated', resolve);
      });

      const baseTime = Date.now() * 1000;
      
      // Create a voice command scenario
      const focusEvent = createMockFocusEvent(baseTime, 'VS Code');
      const audioEvent = createMockAudioEvent(baseTime + 3000000, 'click the button'); // 3 seconds later
      
      correlator.addEvent(focusEvent);
      correlator.addEvent(audioEvent);

      const insight = await insightPromise;
      
      expect(insight).toBeDefined();
      expect(insight.type).toBeDefined();
      expect(insight.severity).toBeDefined();
      expect(insight.description).toBeDefined();
    });
  });

  describe('event window queries', () => {
    beforeEach(async () => {
      await correlator.initialize();
    });

    it('should return events within time window', () => {
      const baseTime = Date.now() * 1000;
      const windowSize = 2000000; // 2 seconds
      
      // Add events at different times
      const event1 = createMockFocusEvent(baseTime - 1000000); // 1 second before
      const event2 = createMockFocusEvent(baseTime); // exact time
      const event3 = createMockFocusEvent(baseTime + 1000000); // 1 second after
      const event4 = createMockFocusEvent(baseTime + 3000000); // 3 seconds after (outside window)
      
      correlator.addEvent(event1);
      correlator.addEvent(event2);
      correlator.addEvent(event3);
      correlator.addEvent(event4);
      
      const eventsInWindow = correlator.getEventsInWindow('focus', baseTime, windowSize);
      
      expect(eventsInWindow).toHaveLength(3);
      expect(eventsInWindow.map(e => e.timestamp)).toEqual([
        baseTime - 1000000,
        baseTime,
        baseTime + 1000000
      ]);
    });

    it('should return empty array for non-existent source', () => {
      const events = correlator.getEventsInWindow('nonexistent', Date.now() * 1000, 1000000);
      expect(events).toEqual([]);
    });
  });

  describe('statistics', () => {
    beforeEach(async () => {
      await correlator.initialize();
    });

    it('should track processing statistics', () => {
      const focusEvent = createMockFocusEvent(Date.now() * 1000);
      correlator.addEvent(focusEvent);
      
      const stats = correlator.getStatistics();
      
      expect(stats.eventsProcessed).toBe(1);
      expect(stats.averageProcessingTime).toBeGreaterThan(0);
    });

    it('should track correlation statistics', async () => {
      const correlationPromise = new Promise<void>((resolve) => {
        correlator.once('correlationFound', resolve);
      });

      const baseTime = Date.now() * 1000;
      
      correlator.addEvent(createMockFocusEvent(baseTime));
      correlator.addEvent(createMockAudioEvent(baseTime + 1000000));
      
      await correlationPromise;
      
      const stats = correlator.getStatistics();
      expect(stats.correlationsFound).toBe(1);
    });
  });

  describe('cleanup', () => {
    beforeEach(async () => {
      await correlator.initialize();
    });

    it('should clear all buffers', () => {
      correlator.addEvent(createMockFocusEvent(Date.now() * 1000));
      correlator.addEvent(createMockAudioEvent(Date.now() * 1000));
      
      correlator.clearBuffers();
      
      const focusEvents = correlator.getEventsInWindow('focus', Date.now() * 1000, 1000000);
      const audioEvents = correlator.getEventsInWindow('audio', Date.now() * 1000, 1000000);
      
      expect(focusEvents).toEqual([]);
      expect(audioEvents).toEqual([]);
    });

    it('should shutdown gracefully', async () => {
      await expect(correlator.shutdown()).resolves.toBeUndefined();
    });
  });

  // Helper functions
  function createMockFocusEvent(timestamp: number, appName: string = 'Test App'): FocusEvent {
    return {
      id: `focus-${Date.now()}-${Math.random()}`,
      timestamp,
      type: 'focus',
      source: 'focus',
      data: {
        applicationName: appName,
        windowTitle: 'Test Window',
        processId: 12345,
        accessibilityContext: {
          role: 'window',
          name: 'Test Window',
          states: ['focused']
        }
      }
    };
  }

  function createMockAudioEvent(timestamp: number, text: string = 'Hello world'): AudioEvent {
    return {
      id: `audio-${Date.now()}-${Math.random()}`,
      timestamp,
      type: 'audio',
      source: 'audio',
      data: {
        text,
        language: 'en',
        confidence: 0.95,
        speakers: [
          {
            speaker_id: 'SPEAKER_00',
            start_time: 0,
            end_time: 2,
            confidence: 0.9
          }
        ],
        totalSpeakers: 1,
        startTime: 0,
        endTime: 2,
        processingTime: 1.5
      }
    };
  }

  function createMockInteractionEvent(timestamp: number): InteractionEvent {
    return {
      id: `interaction-${Date.now()}-${Math.random()}`,
      timestamp,
      type: 'interaction',
      source: 'interaction',
      data: {
        interactionType: 'key',
        target: {
          element: 'button',
          selector: '#submit-btn',
          coordinates: { x: 100, y: 200 }
        },
        inputData: {
          key: 'Enter',
          modifiers: [],
          text: ''
        }
      }
    };
  }
});
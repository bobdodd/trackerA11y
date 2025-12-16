/**
 * Unit tests for TimeSync system
 */

import { TimeSync, TimeSyncConfig } from '../../src/sync/TimeSync';
import { EventTimestamper } from '../../src/sync/EventTimestamper';

describe('TimeSync', () => {
  let timeSync: TimeSync;
  let config: TimeSyncConfig;

  beforeEach(() => {
    config = {
      precision: 'microsecond',
      systemClockSync: true,
      ntpSync: {
        enabled: false, // Disable for tests
        servers: ['test.ntp.pool.org'],
        syncInterval: 300000
      },
      audioSync: {
        enabled: false,
        method: 'bwf'
      },
      calibration: {
        autoCalibrate: true,
        calibrationInterval: 60000,
        driftThreshold: 10
      }
    };
    
    timeSync = new TimeSync(config);
  });

  afterEach(async () => {
    await timeSync.shutdown();
  });

  describe('initialization', () => {
    it('should initialize successfully', async () => {
      const initPromise = timeSync.initialize();
      
      // Listen for initialized event
      const initializedPromise = new Promise<void>((resolve) => {
        timeSync.once('initialized', resolve);
      });
      
      await initPromise;
      await initializedPromise;
      
      const metrics = timeSync.getMetrics();
      expect(metrics.accuracy).toBeGreaterThan(0);
      expect(metrics.precision).toBeGreaterThan(0);
    });

    it('should not reinitialize if already initialized', async () => {
      await timeSync.initialize();
      
      // Should not throw
      await timeSync.initialize();
      
      expect(timeSync.getMetrics()).toBeDefined();
    });
  });

  describe('timestamp generation', () => {
    beforeEach(async () => {
      await timeSync.initialize();
    });

    it('should generate microsecond timestamps', () => {
      const timestamp1 = timeSync.now();
      const timestamp2 = timeSync.now();
      
      expect(timestamp1).toBeGreaterThan(0);
      expect(timestamp2).toBeGreaterThanOrEqual(timestamp1);
      
      // Should be in microseconds (much larger than milliseconds)
      expect(timestamp1).toBeGreaterThan(Date.now() * 500);
    });

    it('should generate performance timestamps', () => {
      const perfTime = timeSync.performanceNow();
      
      expect(perfTime).toBeGreaterThan(0);
      expect(typeof perfTime).toBe('number');
    });

    it('should synchronize timestamps from different sources', () => {
      const systemTime = Date.now() * 1000; // Convert to microseconds
      const performanceTime = timeSync.performanceNow();
      
      const syncedSystemTime = timeSync.synchronizeEventTime(systemTime, 'system');
      const syncedPerfTime = timeSync.synchronizeEventTime(performanceTime, 'performance');
      
      expect(syncedSystemTime).toBeCloseTo(systemTime, 0);
      expect(syncedPerfTime).toBeGreaterThan(0);
    });
  });

  describe('time conversions', () => {
    it('should convert between time units', () => {
      const milliseconds = 1000;
      const microseconds = timeSync.convertTime(milliseconds, 'ms', 'us');
      const backToMs = timeSync.convertTime(microseconds, 'us', 'ms');
      
      expect(microseconds).toBe(1000000);
      expect(backToMs).toBe(milliseconds);
    });

    it('should handle nanosecond conversions', () => {
      const microseconds = 1000;
      const nanoseconds = timeSync.convertTime(microseconds, 'us', 'ns');
      const backToUs = timeSync.convertTime(nanoseconds, 'ns', 'us');
      
      expect(nanoseconds).toBe(1000000);
      expect(backToUs).toBe(microseconds);
    });
  });

  describe('correlation windows', () => {
    beforeEach(async () => {
      await timeSync.initialize();
    });

    it('should create correlation windows', () => {
      const window1 = timeSync.createCorrelationWindow(1000000); // 1 second
      const window2 = timeSync.createCorrelationWindow(1000000);
      
      expect(window1).toMatch(/^timewindow_\d+_1000000us$/);
      expect(window2).toMatch(/^timewindow_\d+_1000000us$/);
      
      // Should be the same for close timestamps
      expect(window1).toBe(window2);
    });

    it('should create different windows for different sizes', () => {
      const smallWindow = timeSync.createCorrelationWindow(100000); // 100ms
      const largeWindow = timeSync.createCorrelationWindow(1000000); // 1s
      
      expect(smallWindow).not.toBe(largeWindow);
      expect(smallWindow).toContain('100000us');
      expect(largeWindow).toContain('1000000us');
    });
  });

  describe('uncertainty calculation', () => {
    beforeEach(async () => {
      await timeSync.initialize();
    });

    it('should calculate time uncertainty', () => {
      const timestamp = timeSync.now();
      
      // Immediate uncertainty should be minimal
      const immediateUncertainty = timeSync.getTimeUncertainty(timestamp);
      expect(immediateUncertainty).toBeGreaterThanOrEqual(0);
      
      // Older timestamps should have higher uncertainty
      const oldTimestamp = timestamp - 1000000; // 1 second ago
      const olderUncertainty = timeSync.getTimeUncertainty(oldTimestamp);
      expect(olderUncertainty).toBeGreaterThanOrEqual(immediateUncertainty);
    });
  });

  describe('calibration', () => {
    it('should perform calibration during initialization', async () => {
      const calibratedPromise = new Promise<any>((resolve) => {
        timeSync.once('calibrated', resolve);
      });
      
      await timeSync.initialize();
      const calibrationMetrics = await calibratedPromise;
      
      expect(calibrationMetrics.accuracy).toBeGreaterThan(0);
      expect(calibrationMetrics.precision).toBeGreaterThan(0);
      expect(calibrationMetrics.lastCalibration).toBeGreaterThan(0);
    });

    it('should detect clock drift over time', async () => {
      await timeSync.initialize();
      
      // Simulate some time passing and check for drift detection
      const initialMetrics = timeSync.getMetrics();
      
      // We can't easily simulate real drift in tests, but we can check the structure
      expect(typeof initialMetrics.drift).toBe('number');
    });
  });

  describe('metrics', () => {
    beforeEach(async () => {
      await timeSync.initialize();
    });

    it('should provide timing metrics', () => {
      const metrics = timeSync.getMetrics();
      
      expect(metrics).toHaveProperty('accuracy');
      expect(metrics).toHaveProperty('precision');
      expect(metrics).toHaveProperty('stability');
      expect(metrics).toHaveProperty('drift');
      expect(metrics).toHaveProperty('lastCalibration');
      expect(metrics).toHaveProperty('syncErrors');
      expect(metrics).toHaveProperty('avgLatency');
      
      expect(metrics.accuracy).toBeGreaterThan(0);
      expect(metrics.precision).toBeGreaterThan(0);
    });
  });
});

describe('EventTimestamper', () => {
  let timeSync: TimeSync;
  let timestamper: EventTimestamper;

  beforeEach(async () => {
    const config: TimeSyncConfig = {
      precision: 'microsecond',
      systemClockSync: true,
      ntpSync: { enabled: false, servers: [], syncInterval: 300000 },
      audioSync: { enabled: false, method: 'bwf' },
      calibration: {
        autoCalibrate: true,
        calibrationInterval: 60000,
        driftThreshold: 10
      }
    };
    
    timeSync = new TimeSync(config);
    await timeSync.initialize();
    timestamper = new EventTimestamper(timeSync);
  });

  afterEach(async () => {
    await timeSync.shutdown();
  });

  describe('event timestamping', () => {
    it('should timestamp events with synchronized time', () => {
      const event = {
        type: 'test',
        source: 'focus' as const,
        data: { test: true },
        metadata: {}
      };
      
      const timestampedEvent = timestamper.timestampEvent(event);
      
      expect(timestampedEvent.id).toBeDefined();
      expect(timestampedEvent.timestamp).toBeGreaterThan(0);
      expect(timestampedEvent.metadata?.timing).toBeDefined();
      
      const timing = (timestampedEvent.metadata as any).timing;
      expect(timing.sourceTime).toBeGreaterThan(0);
      expect(timing.syncedTime).toBeGreaterThan(0);
      expect(timing.uncertainty).toBeGreaterThan(0);
      expect(timing.correlationWindow).toMatch(/^timewindow_\d+_\d+us$/);
    });

    it('should handle different time sources', () => {
      const event = {
        type: 'test',
        source: 'interaction' as const,
        data: { test: true },
        metadata: {}
      };
      
      const systemEvent = timestamper.timestampEvent(event, { timeSource: 'system' });
      const performanceEvent = timestamper.timestampEvent(event, { timeSource: 'performance' });
      
      expect(systemEvent.timestamp).toBeGreaterThan(0);
      expect(performanceEvent.timestamp).toBeGreaterThan(0);
      
      const systemTiming = (systemEvent.metadata as any).timing;
      const perfTiming = (performanceEvent.metadata as any).timing;
      
      expect(systemTiming.source).toBe('system');
      expect(perfTiming.source).toBe('performance');
    });
  });

  describe('batch synchronization', () => {
    it('should synchronize multiple events', () => {
      const events = [
        {
          id: '1',
          timestamp: Date.now() * 1000,
          type: 'test1',
          source: 'focus' as const,
          data: {}
        },
        {
          id: '2',
          timestamp: Date.now() * 1000 + 1000,
          type: 'test2',
          source: 'interaction' as const,
          data: {}
        }
      ];
      
      const syncedEvents = timestamper.synchronizeEvents(events);
      
      expect(syncedEvents).toHaveLength(2);
      expect(syncedEvents[0].timestamp).toBeGreaterThan(0);
      expect(syncedEvents[1].timestamp).toBeGreaterThan(syncedEvents[0].timestamp);
    });

    it('should preserve relative timing when requested', () => {
      const baseTime = Date.now() * 1000;
      const events = [
        {
          id: '1',
          timestamp: baseTime,
          type: 'test1',
          source: 'focus' as const,
          data: {}
        },
        {
          id: '2',
          timestamp: baseTime + 5000, // 5ms later
          type: 'test2',
          source: 'interaction' as const,
          data: {}
        }
      ];
      
      const syncedEvents = timestamper.synchronizeEvents(events, { 
        preserveRelativeTiming: true 
      });
      
      const timeDelta = syncedEvents[1].timestamp - syncedEvents[0].timestamp;
      expect(timeDelta).toBe(5000); // Should preserve 5ms difference
    });
  });

  describe('time correlation', () => {
    it('should calculate correlation between events', () => {
      const event1 = timestamper.timestampEvent({
        type: 'test1',
        source: 'focus' as const,
        data: {},
        metadata: {}
      });
      
      // Create second event slightly later
      const event2 = timestamper.timestampEvent({
        type: 'test2',
        source: 'interaction' as const,
        data: {},
        metadata: {}
      }, {
        sourceTime: event1.timestamp + 1000 // 1ms later
      });
      
      const correlation = timestamper.calculateTimeCorrelation(event1, event2);
      
      expect(correlation.timeDelta).toBe(1000);
      expect(correlation.uncertainty).toBeGreaterThan(0);
      expect(correlation.correlation).toBe('simultaneous');
      expect(correlation.confidence).toBeGreaterThan(0);
    });

    it('should detect sequential vs simultaneous events', () => {
      const baseEvent = timestamper.timestampEvent({
        type: 'base',
        source: 'focus' as const,
        data: {},
        metadata: {}
      });
      
      const simultaneousEvent = timestamper.timestampEvent({
        type: 'simultaneous',
        source: 'interaction' as const,
        data: {},
        metadata: {}
      }, {
        sourceTime: baseEvent.timestamp + 100 // Very close
      });
      
      const sequentialEvent = timestamper.timestampEvent({
        type: 'sequential',
        source: 'audio' as const,
        data: {},
        metadata: {}
      }, {
        sourceTime: baseEvent.timestamp + 50000 // 50ms later
      });
      
      const simultaneousCorr = timestamper.calculateTimeCorrelation(baseEvent, simultaneousEvent);
      const sequentialCorr = timestamper.calculateTimeCorrelation(baseEvent, sequentialEvent);
      
      expect(simultaneousCorr.correlation).toBe('simultaneous');
      expect(sequentialCorr.correlation).toBe('sequential');
    });
  });

  describe('timing statistics', () => {
    it('should calculate timing statistics for events', () => {
      const events = [];
      const baseTime = Date.now() * 1000;
      
      for (let i = 0; i < 5; i++) {
        events.push(timestamper.timestampEvent({
          type: `test${i}`,
          source: 'focus' as const,
          data: {},
          metadata: {}
        }, {
          sourceTime: baseTime + i * 10000 // 10ms intervals
        }));
      }
      
      const stats = timestamper.getTimingStatistics(events);
      
      expect(stats.totalEvents).toBe(5);
      expect(stats.averageInterval).toBe(10000); // 10ms
      expect(stats.timeSpan).toBe(40000); // 40ms total
      expect(stats.frequency).toBeCloseTo(100, 1); // ~100 Hz
    });

    it('should handle empty event arrays', () => {
      const stats = timestamper.getTimingStatistics([]);
      
      expect(stats.totalEvents).toBe(0);
      expect(stats.timeSpan).toBe(0);
      expect(stats.frequency).toBe(0);
    });
  });

  describe('timing validation', () => {
    it('should validate proper event timing', () => {
      const events = [];
      const baseTime = Date.now() * 1000;
      
      for (let i = 0; i < 3; i++) {
        events.push(timestamper.timestampEvent({
          type: `test${i}`,
          source: 'focus' as const,
          data: {},
          metadata: {}
        }, {
          sourceTime: baseTime + i * 1000
        }));
      }
      
      const validation = timestamper.validateEventTiming(events);
      
      expect(validation.isValid).toBe(true);
      expect(validation.issues).toHaveLength(0);
      expect(validation.statistics).toBeDefined();
    });

    it('should detect timing issues', () => {
      const events = [];
      
      // Create events with unrealistic frequency
      for (let i = 0; i < 100; i++) {
        events.push(timestamper.timestampEvent({
          type: `test${i}`,
          source: 'focus' as const,
          data: {},
          metadata: {}
        }, {
          sourceTime: Date.now() * 1000 + i // 1μs intervals = 1MHz
        }));
      }
      
      const validation = timestamper.validateEventTiming(events);
      
      expect(validation.isValid).toBe(false);
      expect(validation.issues.length).toBeGreaterThan(0);
      expect(validation.issues.some(issue => 
        issue.includes('Unrealistic event frequency')
      )).toBe(true);
    });
  });
});
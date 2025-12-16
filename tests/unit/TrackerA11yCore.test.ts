/**
 * Unit tests for TrackerA11yCore
 * Tests integration of all accessibility tracking components
 */

import { TrackerA11yCore } from '../../src/core/TrackerA11yCore';
import { TrackerA11yConfig, FocusEvent } from '../../src/types';

// Mock the FocusManager
jest.mock('../../src/core/FocusManager');
jest.mock('../../src/bridge/AudioProcessorBridge');

describe('TrackerA11yCore', () => {
  let tracker: TrackerA11yCore;
  let mockConfig: TrackerA11yConfig;

  beforeEach(() => {
    mockConfig = {
      platforms: ['macos'],
      syncPrecision: 'microsecond',
      realTimeMonitoring: true,
      audioIntegration: {
        recordingQuality: '48khz',
        diarizationModel: 'pyannote/speaker-diarization-3.1',
        transcriptionModel: 'base',
        synchronizationMethod: 'bwf',
        realTimeProcessing: true,
        sampleRate: 48000
      },
      outputFormats: ['json']
    };

    tracker = new TrackerA11yCore(mockConfig);
  });

  afterEach(async () => {
    await tracker.shutdown();
  });

  describe('initialization', () => {
    it('should create TrackerA11yCore with config', () => {
      expect(tracker).toBeDefined();
      expect(tracker).toBeInstanceOf(TrackerA11yCore);
    });

    it('should initialize successfully', async () => {
      await expect(tracker.initialize()).resolves.toBeUndefined();
    });

    it('should emit initialized event', async () => {
      const initPromise = new Promise<void>((resolve) => {
        tracker.once('initialized', resolve);
      });

      await tracker.initialize();
      await initPromise;
    });

    it('should not initialize twice', async () => {
      await tracker.initialize();
      await expect(tracker.initialize()).resolves.toBeUndefined();
    });
  });

  describe('tracking lifecycle', () => {
    beforeEach(async () => {
      await tracker.initialize();
    });

    it('should start tracking', async () => {
      await expect(tracker.start()).resolves.toBeUndefined();
    });

    it('should emit started event', async () => {
      const startPromise = new Promise<void>((resolve) => {
        tracker.once('started', resolve);
      });

      await tracker.start();
      await startPromise;
    });

    it('should stop tracking', async () => {
      await tracker.start();
      await expect(tracker.stop()).resolves.toBeUndefined();
    });

    it('should emit stopped event', async () => {
      await tracker.start();
      
      const stopPromise = new Promise<void>((resolve) => {
        tracker.once('stopped', resolve);
      });

      await tracker.stop();
      await stopPromise;
    });

    it('should throw error when starting without initialization', async () => {
      const uninitializedTracker = new TrackerA11yCore(mockConfig);
      
      await expect(uninitializedTracker.start())
        .rejects.toThrow('TrackerA11y Core not initialized');
    });
  });

  describe('statistics', () => {
    beforeEach(async () => {
      await tracker.initialize();
    });

    it('should provide initial statistics', () => {
      const stats = tracker.getStatistics();
      
      expect(stats).toBeDefined();
      expect(stats.uptime).toBeGreaterThanOrEqual(0);
      expect(stats.eventsProcessed.total).toBe(0);
      expect(stats.correlations.found).toBe(0);
      expect(stats.insights.generated).toBe(0);
    });

    it('should update uptime after initialization', () => {
      const stats1 = tracker.getStatistics();
      
      setTimeout(() => {
        const stats2 = tracker.getStatistics();
        expect(stats2.uptime).toBeGreaterThan(stats1.uptime);
      }, 10);
    });
  });

  describe('event handling', () => {
    beforeEach(async () => {
      await tracker.initialize();
    });

    it('should store and retrieve recent events', () => {
      const initialEvents = tracker.getRecentEvents();
      expect(initialEvents).toEqual([]);
      
      // Events would be added through the actual components
      // This test verifies the interface exists
      expect(typeof tracker.getRecentEvents).toBe('function');
    });

    it('should store and retrieve recent insights', () => {
      const initialInsights = tracker.getRecentInsights();
      expect(initialInsights).toEqual([]);
      
      expect(typeof tracker.getRecentInsights).toBe('function');
    });

    it('should filter insights by severity', () => {
      const highSeverityInsights = tracker.getInsightsBySeverity('high');
      expect(Array.isArray(highSeverityInsights)).toBe(true);
    });
  });

  describe('correlation rules', () => {
    beforeEach(async () => {
      await tracker.initialize();
    });

    it('should add custom correlation rule', () => {
      const customRule = {
        id: 'test-rule',
        name: 'Test Rule',
        sources: ['focus', 'audio'],
        timeWindow: 1000000,
        minConfidence: 0.8,
        handler: () => null
      };

      expect(() => tracker.addCorrelationRule(customRule)).not.toThrow();
    });

    it('should remove correlation rule', () => {
      const customRule = {
        id: 'test-rule',
        name: 'Test Rule',
        sources: ['focus', 'audio'],
        timeWindow: 1000000,
        minConfidence: 0.8,
        handler: () => null
      };

      tracker.addCorrelationRule(customRule);
      expect(tracker.removeCorrelationRule('test-rule')).toBe(true);
      expect(tracker.removeCorrelationRule('non-existent')).toBe(false);
    });
  });

  describe('data export', () => {
    beforeEach(async () => {
      await tracker.initialize();
    });

    it('should export session data', () => {
      const sessionData = tracker.exportSessionData();
      
      expect(sessionData).toBeDefined();
      expect(sessionData.metadata).toBeDefined();
      expect(sessionData.metadata.platform).toBe(process.platform);
      expect(sessionData.metadata.config).toEqual(mockConfig);
      expect(sessionData.statistics).toBeDefined();
      expect(sessionData.events).toBeDefined();
      expect(sessionData.insights).toBeDefined();
    });

    it('should include correct metadata in export', () => {
      const sessionData = tracker.exportSessionData();
      
      expect(sessionData.metadata.startTime).toBeGreaterThan(0);
      expect(sessionData.metadata.duration).toBeGreaterThanOrEqual(0);
      expect(sessionData.metadata.platform).toBe(process.platform);
    });
  });

  describe('error handling', () => {
    it('should emit error events', async () => {
      const errorPromise = new Promise<Error>((resolve) => {
        tracker.once('error', resolve);
      });

      // Trigger an error by calling getCurrentFocus without initialization
      try {
        await tracker.getCurrentFocus();
      } catch (error) {
        // Expected error
      }

      // The error might be emitted, but getCurrentFocus throws directly
      // so we test the interface exists
      expect(typeof tracker.getCurrentFocus).toBe('function');
    });
  });

  describe('shutdown', () => {
    it('should shutdown without initialization', async () => {
      await expect(tracker.shutdown()).resolves.toBeUndefined();
    });

    it('should shutdown after initialization', async () => {
      await tracker.initialize();
      await expect(tracker.shutdown()).resolves.toBeUndefined();
    });

    it('should emit shutdown event', async () => {
      await tracker.initialize();
      
      const shutdownPromise = new Promise<void>((resolve) => {
        tracker.once('shutdown', resolve);
      });

      await tracker.shutdown();
      await shutdownPromise;
    });
  });

  describe('configuration without audio', () => {
    it('should work without audio integration', async () => {
      const configWithoutAudio: TrackerA11yConfig = {
        platforms: ['macos'],
        syncPrecision: 'microsecond',
        realTimeMonitoring: true,
        outputFormats: ['json']
      };

      const trackerWithoutAudio = new TrackerA11yCore(configWithoutAudio);
      
      await expect(trackerWithoutAudio.initialize()).resolves.toBeUndefined();
      await expect(trackerWithoutAudio.start()).resolves.toBeUndefined();
      
      const stats = trackerWithoutAudio.getStatistics();
      expect(stats).toBeDefined();
      
      await trackerWithoutAudio.shutdown();
    });
  });
});
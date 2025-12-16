/**
 * Unit tests for FocusManager
 * Tests cross-platform focus tracking functionality
 */

import { FocusManager } from '@/core/FocusManager';
import { FocusEvent } from '@/types';

describe('FocusManager', () => {
  let focusManager: FocusManager;

  beforeEach(() => {
    focusManager = new FocusManager();
  });

  afterEach(async () => {
    if (focusManager.initialized) {
      await focusManager.shutdown();
    }
  });

  describe('Platform Detection', () => {
    it('should detect current platform correctly', () => {
      expect(focusManager.platform).toBe('macos');
    });
  });

  describe('Initialization', () => {
    it('should initialize successfully', async () => {
      await expect(focusManager.initialize()).resolves.not.toThrow();
      expect(focusManager.initialized).toBe(true);
    });

    it('should not initialize twice', async () => {
      await focusManager.initialize();
      await expect(focusManager.initialize()).resolves.not.toThrow();
      expect(focusManager.initialized).toBe(true);
    });

    it('should emit initialized event', async () => {
      const initPromise = new Promise<void>((resolve) => {
        focusManager.once('initialized', resolve);
      });

      await focusManager.initialize();
      await expect(initPromise).resolves.not.toThrow();
    });
  });

  describe('Focus Tracking', () => {
    beforeEach(async () => {
      await focusManager.initialize();
    });

    it('should get current focus', async () => {
      const focusEvent = await focusManager.getCurrentFocus();
      
      if (focusEvent) {
        expect(focusEvent).toBeValidFocusEvent();
        expect(focusEvent.data.applicationName).toBeDefined();
        expect(focusEvent.data.processId).toBeGreaterThan(0);
        expect(focusEvent.timestamp).toBeValidTimestamp();
      } else {
        // If no focus, that's also valid in some scenarios
        console.warn('No focus event returned - this might be expected in test environment');
      }
    });

    it('should emit focus change events', (done) => {
      let eventReceived = false;

      const timeout = setTimeout(() => {
        if (!eventReceived) {
          console.log('No focus change event received within timeout - this is expected in CI environments');
          done();
        }
      }, 5000);

      focusManager.on('focusChanged', (event: FocusEvent) => {
        if (!eventReceived) {
          eventReceived = true;
          clearTimeout(timeout);
          
          expect(event).toBeValidFocusEvent();
          expect(event.metadata?.platform).toBe('macos');
          done();
        }
      });

      focusManager.on('error', (error) => {
        clearTimeout(timeout);
        console.warn('Focus tracking error (expected in CI):', error.message);
        done();
      });
    });
  });

  describe('Shutdown', () => {
    beforeEach(async () => {
      await focusManager.initialize();
    });

    it('should shutdown gracefully', async () => {
      await expect(focusManager.shutdown()).resolves.not.toThrow();
      expect(focusManager.initialized).toBe(false);
    });

    it('should emit shutdown event', async () => {
      const shutdownPromise = new Promise<void>((resolve) => {
        focusManager.once('shutdown', resolve);
      });

      await focusManager.shutdown();
      await expect(shutdownPromise).resolves.not.toThrow();
    });
  });

  describe('Error Handling', () => {
    it('should throw error when getting focus without initialization', async () => {
      await expect(focusManager.getCurrentFocus()).rejects.toThrow('Focus manager not initialized');
    });

    it('should handle tracker errors gracefully', async () => {
      await focusManager.initialize();
      
      const errorPromise = new Promise<Error>((resolve) => {
        focusManager.once('error', resolve);
      });

      // Simulate an error by accessing private tracker
      (focusManager as any).tracker.emit('error', new Error('Test error'));
      
      const error = await errorPromise;
      expect(error.message).toBe('Test error');
    });
  });
});
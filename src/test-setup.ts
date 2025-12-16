/**
 * Jest test setup file
 * Configures test environment and global utilities
 */

export {}; // Make this file a module

declare global {
  namespace jest {
    interface Matchers<R> {
      toBeValidTimestamp(): R;
      toBeValidFocusEvent(): R;
    }
  }
}

// Custom Jest matchers for TrackerA11y
expect.extend({
  toBeValidTimestamp(received: number) {
    const isValid = typeof received === 'number' && 
                   received > 0 && 
                   received <= Date.now() * 1000; // Allow microseconds
    
    return {
      message: () => `expected ${received} to be a valid timestamp`,
      pass: isValid
    };
  },

  toBeValidFocusEvent(received: any) {
    const hasRequiredFields = received &&
                             typeof received.id === 'string' &&
                             typeof received.timestamp === 'number' &&
                             received.source === 'focus' &&
                             received.data &&
                             typeof received.data.applicationName === 'string' &&
                             typeof received.data.processId === 'number';

    return {
      message: () => `expected ${JSON.stringify(received)} to be a valid focus event`,
      pass: hasRequiredFields
    };
  }
});

// Mock environment variables for tests
process.env.TRACKERA11Y_SESSION_ID = 'test-session';
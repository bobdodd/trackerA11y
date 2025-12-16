/**
 * Unit tests for AudioProcessorBridge
 * Tests IPC communication with Python audio pipeline
 */

import { AudioProcessorBridge } from '../../src/bridge/AudioProcessorBridge';
import { AudioConfig } from '../../src/types';
import { EventEmitter } from 'events';

// Mock child_process
jest.mock('child_process');

describe('AudioProcessorBridge', () => {
  let bridge: AudioProcessorBridge;
  let mockConfig: AudioConfig;

  beforeEach(() => {
    mockConfig = {
      sampleRate: 48000,
      diarizationModel: 'pyannote/speaker-diarization-3.1',
      transcriptionModel: 'large-v3',
      recordingQuality: '48khz',
      realTimeProcessing: true,
      pythonPipelinePath: 'python'
    };

    bridge = new AudioProcessorBridge(mockConfig);
  });

  afterEach(async () => {
    await bridge.shutdown();
  });

  describe('initialization', () => {
    it('should initialize with correct configuration', () => {
      expect(bridge).toBeDefined();
      expect(bridge).toBeInstanceOf(EventEmitter);
    });

    it('should emit initialized event on successful startup', async () => {
      const mockProcess = {
        stdout: new EventEmitter(),
        stderr: new EventEmitter(), 
        stdin: { write: jest.fn() },
        on: jest.fn(),
        kill: jest.fn()
      };

      const { spawn } = require('child_process');
      spawn.mockReturnValue(mockProcess);

      const initPromise = bridge.initialize();

      // Simulate Python pipeline sending status message
      setTimeout(() => {
        const statusMessage = {
          type: 'processing_status',
          id: 'status_1',
          timestamp: Date.now() * 1000,
          session_id: 'main',
          payload: {
            is_recording: false,
            is_processing: true,
            queue_size: 0,
            total_processed: 0,
            average_processing_time: 0.0
          }
        };

        const encoded = Buffer.from(JSON.stringify(statusMessage)).toString('base64');
        mockProcess.stdout.emit('data', Buffer.from(`${encoded}\n`));
      }, 100);

      await expect(initPromise).resolves.toBeUndefined();
    });
  });

  describe('audio processing', () => {
    it('should process audio data and return events', async () => {
      const mockProcess = {
        stdout: new EventEmitter(),
        stderr: new EventEmitter(),
        stdin: { write: jest.fn() },
        on: jest.fn(),
        kill: jest.fn()
      };

      const { spawn } = require('child_process');
      spawn.mockReturnValue(mockProcess);

      // Initialize bridge
      const initPromise = bridge.initialize();
      setTimeout(() => {
        const statusMessage = {
          type: 'processing_status',
          id: 'status_1', 
          timestamp: Date.now() * 1000,
          session_id: 'main',
          payload: { is_processing: true }
        };
        const encoded = Buffer.from(JSON.stringify(statusMessage)).toString('base64');
        mockProcess.stdout.emit('data', Buffer.from(`${encoded}\n`));
      }, 50);
      await initPromise;

      // Mock audio buffer
      const audioBuffer = Buffer.alloc(1024);
      const sessionId = 'test-session';

      // Start processing
      const processPromise = bridge.processAudioData(audioBuffer, sessionId);

      // Simulate Python response
      setTimeout(() => {
        const audioEvent = {
          type: 'audio_event',
          id: 'event_1',
          timestamp: Date.now() * 1000,
          session_id: sessionId,
          payload: {
            success: true,
            text: 'Hello world',
            language: 'en',
            confidence: 0.95,
            speakers: [
              {
                speaker_id: 'SPEAKER_00',
                start_time: 0.0,
                end_time: 2.0,
                confidence: 0.9
              }
            ],
            total_speakers: 1,
            start_time: 0.0,
            end_time: 2.0,
            processing_time: 1.5
          }
        };

        const encoded = Buffer.from(JSON.stringify(audioEvent)).toString('base64');
        mockProcess.stdout.emit('data', Buffer.from(`${encoded}\n`));
      }, 100);

      const events = await processPromise;
      
      expect(events).toHaveLength(1);
      expect(events[0]).toMatchObject({
        source: 'audio',
        data: {
          text: 'Hello world',
          language: 'en',
          confidence: 0.95,
          totalSpeakers: 1
        }
      });
    });

    it('should handle processing errors gracefully', async () => {
      const mockProcess = {
        stdout: new EventEmitter(),
        stderr: new EventEmitter(),
        stdin: { write: jest.fn() },
        on: jest.fn(),
        kill: jest.fn()
      };

      const { spawn } = require('child_process');
      spawn.mockReturnValue(mockProcess);

      // Initialize
      const initPromise = bridge.initialize();
      setTimeout(() => {
        const statusMessage = {
          type: 'processing_status',
          id: 'status_1',
          timestamp: Date.now() * 1000,
          session_id: 'main',
          payload: { is_processing: true }
        };
        const encoded = Buffer.from(JSON.stringify(statusMessage)).toString('base64');
        mockProcess.stdout.emit('data', Buffer.from(`${encoded}\n`));
      }, 50);
      await initPromise;

      const audioBuffer = Buffer.alloc(1024);
      const sessionId = 'test-session';

      const processPromise = bridge.processAudioData(audioBuffer, sessionId);

      // Simulate error response
      setTimeout(() => {
        const errorMessage = {
          type: 'error',
          id: 'error_1',
          timestamp: Date.now() * 1000,
          session_id: sessionId,
          payload: {
            error_type: 'AUDIO_PROCESSING_ERROR',
            message: 'Failed to process audio',
            details: null
          }
        };

        const encoded = Buffer.from(JSON.stringify(errorMessage)).toString('base64');
        mockProcess.stdout.emit('data', Buffer.from(`${encoded}\n`));
      }, 100);

      await expect(processPromise).rejects.toThrow('Python pipeline error');
    });
  });

  describe('heartbeat', () => {
    it('should send ping messages periodically', async () => {
      const mockProcess = {
        stdout: new EventEmitter(),
        stderr: new EventEmitter(),
        stdin: { write: jest.fn() },
        on: jest.fn(),
        kill: jest.fn()
      };

      const { spawn } = require('child_process');
      spawn.mockReturnValue(mockProcess);

      // Initialize
      const initPromise = bridge.initialize();
      setTimeout(() => {
        const statusMessage = {
          type: 'processing_status',
          id: 'status_1',
          timestamp: Date.now() * 1000,
          session_id: 'main',
          payload: { is_processing: true }
        };
        const encoded = Buffer.from(JSON.stringify(statusMessage)).toString('base64');
        mockProcess.stdout.emit('data', Buffer.from(`${encoded}\n`));
      }, 50);
      await initPromise;

      // Wait for heartbeat
      await new Promise(resolve => setTimeout(resolve, 100));

      expect(mockProcess.stdin.write).toHaveBeenCalled();
      
      // Check if ping messages are being sent
      const calls = mockProcess.stdin.write.mock.calls;
      const pingMessages = calls.filter(call => {
        try {
          const decoded = JSON.parse(Buffer.from(call[0].slice(0, -1), 'base64').toString());
          return decoded.type === 'ping';
        } catch {
          return false;
        }
      });

      expect(pingMessages.length).toBeGreaterThan(0);
    });
  });

  describe('shutdown', () => {
    it('should cleanup resources on shutdown', async () => {
      const mockProcess = {
        stdout: new EventEmitter(),
        stderr: new EventEmitter(),
        stdin: { write: jest.fn() },
        on: jest.fn(),
        kill: jest.fn(),
        once: jest.fn((event, callback) => {
          if (event === 'exit') {
            setTimeout(callback, 50);
          }
        })
      };

      const { spawn } = require('child_process');
      spawn.mockReturnValue(mockProcess);

      await bridge.shutdown();

      expect(mockProcess.kill).toHaveBeenCalled();
    });
  });
});
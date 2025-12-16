/**
 * Bridge between TypeScript core and Python audio processing pipeline
 * Handles inter-process communication and data serialization
 */

import { spawn, ChildProcess } from 'child_process';
import { EventEmitter } from 'events';
import * as msgpack from 'msgpack-lite';
import { 
  AudioEvent, 
  IPCMessage, 
  AudioProcessingRequest, 
  AudioProcessingResult,
  AudioConfig 
} from '@/types';

export class AudioProcessorBridge extends EventEmitter {
  private pythonProcess: ChildProcess | null = null;
  private isInitialized = false;
  private pendingRequests = new Map<string, {
    resolve: (result: AudioEvent[]) => void;
    reject: (error: Error) => void;
    timestamp: number;
  }>();
  private config: AudioConfig;
  private heartbeatInterval: NodeJS.Timeout | null = null;

  constructor(config: AudioConfig) {
    super();
    this.config = config;
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      await this.startPythonPipeline();
      await this.waitForPipelineReady();
      this.setupHeartbeat();
      this.isInitialized = true;
      this.emit('initialized');
    } catch (error) {
      this.emit('error', new Error(`Failed to initialize audio pipeline: ${error}`));
      throw error;
    }
  }

  private async startPythonPipeline(): Promise<void> {
    const pythonPath = this.config.pythonPipelinePath || 'python';
    const pipelinePath = 'audio_pipeline/src/audio_pipeline/main.py';
    
    const args = [
      pipelinePath,
      '--mode', 'ipc',
      '--diarization-model', this.config.diarizationModel || 'pyannote/speaker-diarization-3.1',
      '--transcription-model', this.config.transcriptionModel || 'large-v3',
      '--quality', this.config.recordingQuality || '48khz',
      '--real-time', (this.config.realTimeProcessing !== false).toString(),
      '--log-level', 'INFO'
    ];

    this.pythonProcess = spawn(pythonPath, args, {
      stdio: ['pipe', 'pipe', 'pipe'],
      cwd: process.cwd()
    });

    this.pythonProcess.stdout?.on('data', this.handlePythonOutput.bind(this));
    this.pythonProcess.stderr?.on('data', this.handlePythonError.bind(this));
    this.pythonProcess.on('error', this.handleProcessError.bind(this));
    this.pythonProcess.on('exit', this.handleProcessExit.bind(this));
  }

  private handlePythonOutput(data: Buffer): void {
    try {
      // Messages are msgpack-encoded and newline-delimited
      const lines = data.toString().trim().split('\n');
      
      for (const line of lines) {
        if (line.trim()) {
          const message: IPCMessage = msgpack.decode(Buffer.from(line, 'base64'));
          this.processIPCMessage(message);
        }
      }
    } catch (error) {
      this.emit('error', new Error(`Failed to parse Python output: ${error}`));
    }
  }

  private processIPCMessage(message: IPCMessage): void {
    switch (message.type) {
      case 'audio_event':
        this.handleAudioEvent(message);
        break;
      case 'processing_status':
        this.handleProcessingStatus(message);
        break;
      case 'pong':
        this.emit('heartbeat', message.timestamp);
        break;
      case 'error':
        this.handlePythonIPCError(message);
        break;
      default:
        console.warn(`Unknown IPC message type: ${message.type}`);
    }
  }

  private handleAudioEvent(message: IPCMessage): void {
    const payload = message.payload;
    
    // Convert Python response to TypeScript AudioEvent format
    const audioEvent: AudioEvent = {
      id: message.id,
      timestamp: message.timestamp,
      type: 'audio',
      source: 'audio',
      data: {
        text: payload.text || '',
        language: payload.language || 'en',
        confidence: payload.confidence || 0.0,
        speakers: payload.speakers || [],
        totalSpeakers: payload.total_speakers || 0,
        startTime: payload.start_time || 0.0,
        endTime: payload.end_time || 0.0,
        processingTime: payload.processing_time || 0.0
      }
    };

    // Check for pending request
    const pendingRequest = this.pendingRequests.get(message.session_id || '');
    if (pendingRequest) {
      pendingRequest.resolve([audioEvent]);
      this.pendingRequests.delete(message.session_id || '');
    }

    // Emit for real-time listeners
    this.emit('audioEvents', [audioEvent]);
  }

  private handleProcessingStatus(message: IPCMessage): void {
    this.emit('status', message.payload);
  }

  private handlePythonIPCError(message: IPCMessage): void {
    const error = new Error(`Python pipeline error: ${message.payload.message}`);
    this.emit('error', error);

    // Reject any pending requests if this is a session-specific error
    if (message.payload.sessionId) {
      const pendingRequest = this.pendingRequests.get(message.payload.sessionId);
      if (pendingRequest) {
        pendingRequest.reject(error);
        this.pendingRequests.delete(message.payload.sessionId);
      }
    }
  }

  private handlePythonError(data: Buffer): void {
    const errorMessage = data.toString().trim();
    console.error('Python pipeline error:', errorMessage);
    this.emit('error', new Error(`Python stderr: ${errorMessage}`));
  }

  private handleProcessError(error: Error): void {
    this.emit('error', new Error(`Python process error: ${error.message}`));
    this.cleanup();
  }

  private handleProcessExit(code: number | null, signal: string | null): void {
    const message = `Python process exited with code ${code}, signal ${signal}`;
    this.emit('error', new Error(message));
    this.cleanup();
  }

  async processAudioData(
    audioBuffer: Buffer, 
    sessionId: string, 
    metadata?: Record<string, any>
  ): Promise<AudioEvent[]> {
    if (!this.isInitialized || !this.pythonProcess) {
      throw new Error('Audio processor bridge not initialized');
    }

    return new Promise((resolve, reject) => {
      const requestId = `req_${Date.now()}_${Math.random()}`;
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(sessionId);
        reject(new Error('Audio processing timeout'));
      }, 30000); // 30 second timeout

      this.pendingRequests.set(sessionId, {
        resolve: (events) => {
          clearTimeout(timeout);
          resolve(events);
        },
        reject: (error) => {
          clearTimeout(timeout);
          reject(error);
        },
        timestamp: Date.now()
      });

      const request: IPCMessage = {
        type: 'process_audio',
        id: requestId,
        timestamp: Date.now() * 1000, // Convert to microseconds
        session_id: sessionId,
        payload: {
          audio_data: audioBuffer.toString('base64'),
          sample_rate: this.config.sampleRate || 48000,
          channels: 1,
          format: 'int16',
          duration: audioBuffer.length / (2 * (this.config.sampleRate || 48000)), // bytes to seconds
          real_time: this.config.realTimeProcessing !== false
        }
      };

      this.sendToPython(request);
    });
  }

  private sendToPython(message: IPCMessage): void {
    if (!this.pythonProcess?.stdin) {
      throw new Error('Python process stdin not available');
    }

    try {
      // Encode as msgpack and send as base64-encoded line
      const encoded = msgpack.encode(message);
      const base64 = encoded.toString('base64');
      this.pythonProcess.stdin.write(`${base64}\n`);
    } catch (error) {
      this.emit('error', new Error(`Failed to send message to Python: ${error}`));
    }
  }

  private async waitForPipelineReady(): Promise<void> {
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('Timeout waiting for Python pipeline to initialize'));
      }, 15000); // Increased timeout for model loading

      // Send initialization message
      const initMessage: IPCMessage = {
        type: 'init',
        id: `init_${Date.now()}`,
        timestamp: Date.now() * 1000,
        session_id: 'main',
        payload: {
          config: {
            sample_rate: this.config.sampleRate || 48000,
            diarization_model: this.config.diarizationModel || 'pyannote/speaker-diarization-3.1',
            transcription_model: this.config.transcriptionModel || 'large-v3',
            real_time: this.config.realTimeProcessing !== false
          }
        }
      };

      const onReady = () => {
        clearTimeout(timeout);
        this.off('error', onError);
        resolve();
      };

      const onError = (error: Error) => {
        clearTimeout(timeout);
        this.off('status', onReady);
        reject(error);
      };

      this.once('status', onReady);
      this.once('error', onError);
      
      this.sendToPython(initMessage);
    });
  }

  private setupHeartbeat(): void {
    this.heartbeatInterval = setInterval(() => {
      if (!this.pythonProcess) {
        return;
      }

      const heartbeat: IPCMessage = {
        type: 'ping',
        id: `ping_${Date.now()}`,
        timestamp: Date.now() * 1000,
        session_id: 'main',
        payload: {}
      };

      try {
        this.sendToPython(heartbeat);
      } catch (error) {
        this.emit('error', new Error(`Heartbeat failed: ${error}`));
      }
    }, 5000); // 5 second heartbeat
  }

  async shutdown(): Promise<void> {
    this.cleanup();
    
    if (this.pythonProcess) {
      // Send graceful shutdown signal
      const shutdownMessage: IPCMessage = {
        type: 'shutdown',
        id: `shutdown_${Date.now()}`,
        timestamp: Date.now() * 1000,
        session_id: 'main',
        payload: {}
      };

      try {
        this.sendToPython(shutdownMessage);
      } catch {
        // Ignore errors during shutdown
      }

      // Wait for graceful exit, then force kill
      await new Promise<void>((resolve) => {
        const timeout = setTimeout(() => {
          this.pythonProcess?.kill('SIGKILL');
          resolve();
        }, 3000);

        this.pythonProcess?.once('exit', () => {
          clearTimeout(timeout);
          resolve();
        });
      });
    }
  }

  private cleanup(): void {
    this.isInitialized = false;
    
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }

    // Reject all pending requests
    this.pendingRequests.forEach(({ reject }) => {
      reject(new Error('Audio processor bridge shutting down'));
    });
    this.pendingRequests.clear();

    this.pythonProcess = null;
  }

}
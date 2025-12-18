/**
 * Native macOS Interaction Tracker
 * Uses native helper app for real system-wide event capture
 */

import { spawn, ChildProcess } from 'child_process';
import { BaseInteractionTracker } from '../BaseInteractionTracker';
import { InteractionEvent, InteractionConfig } from '@/types';
import { AccessibilityInspector, AccessibilityHitTest } from '@/accessibility/AccessibilityInspector';
import * as path from 'path';

export class NativeInteractionTracker extends BaseInteractionTracker {
  private nativeProcess: ChildProcess | null = null;
  private sessionId: string = '';
  private nativeHelperPath: string;
  private accessibilityInspector: AccessibilityInspector;
  private lastClickTime: number = 0;

  constructor(config: InteractionConfig) {
    super(config);
    this.sessionId = `native_session_${Date.now()}`;
    this.nativeHelperPath = path.resolve(__dirname, '../../../native_helpers/native_helpers/mouse_capture');
    this.accessibilityInspector = new AccessibilityInspector();
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      // Check if native helper exists
      await this.checkNativeHelper();
      
      this.isInitialized = true;
      this.emit('initialized');
      console.log('✅ Native interaction tracker initialized');
    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  async startMonitoring(): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('Native tracker not initialized');
    }

    if (this.isMonitoring) {
      return;
    }

    try {
      await this.startNativeCapture();
      
      this.isMonitoring = true;
      this.emit('monitoringStarted');
      console.log('🎯 Native event capture started');
    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  async stopMonitoring(): Promise<void> {
    if (!this.isMonitoring) {
      return;
    }

    if (this.nativeProcess) {
      // Send SIGTERM for graceful shutdown
      this.nativeProcess.kill('SIGTERM');
      
      // Wait a moment for graceful shutdown
      await new Promise(resolve => setTimeout(resolve, 500));
      
      if (this.nativeProcess && !this.nativeProcess.killed) {
        this.nativeProcess.kill('SIGKILL');
      }
      
      this.nativeProcess = null;
    }

    this.isMonitoring = false;
    this.emit('monitoringStopped');
    console.log('⏹️  Native event capture stopped');
  }

  getSupportedTypes(): string[] {
    return ['click', 'key', 'scroll', 'mouse_move', 'drag'];
  }

  private async checkNativeHelper(): Promise<void> {
    const fs = await import('fs/promises');
    
    try {
      await fs.access(this.nativeHelperPath, fs.constants.X_OK);
    } catch (error) {
      throw new Error(`Native helper not found at ${this.nativeHelperPath}. Run 'make' in the native_helpers directory.`);
    }
  }

  private async startNativeCapture(): Promise<void> {
    console.log(`🚀 Starting native helper: ${this.nativeHelperPath}`);
    
    this.nativeProcess = spawn(this.nativeHelperPath, [], {
      stdio: ['ignore', 'pipe', 'pipe']
    });

    if (!this.nativeProcess.stdout || !this.nativeProcess.stderr) {
      throw new Error('Failed to create native event capture process');
    }

    // Handle stdout (JSON events)
    this.nativeProcess.stdout.on('data', (data) => {
      this.handleNativeOutput(data.toString());
    });

    // Handle stderr (error messages)
    this.nativeProcess.stderr.on('data', (data) => {
      console.error('Native helper error:', data.toString());
    });

    // Handle process exit
    this.nativeProcess.on('exit', (code, signal) => {
      console.log(`Native helper exited with code ${code}, signal ${signal}`);
      if (this.isMonitoring && code !== 0) {
        this.emit('error', new Error(`Native helper exited unexpectedly with code ${code}`));
      }
    });

    // Handle process errors
    this.nativeProcess.on('error', (error) => {
      console.error('Native helper process error:', error);
      this.emit('error', error);
    });

    // Give the process a moment to start
    await new Promise(resolve => setTimeout(resolve, 100));
    
    if (this.nativeProcess && this.nativeProcess.exitCode !== null) {
      throw new Error(`Native helper failed to start (exit code: ${this.nativeProcess.exitCode})`);
    }
  }

  private handleNativeOutput(data: string): void {
    const lines = data.trim().split('\n');
    
    for (const line of lines) {
      if (!line.trim()) continue;
      
      try {
        const event = JSON.parse(line);
        this.processNativeEvent(event);
        
      } catch (error) {
        // Skip malformed JSON (probably debug output)
        console.debug('Skipping non-JSON output:', line);
      }
    }
  }

  private async processNativeEvent(nativeEvent: any): Promise<void> {
    const interactionEvent = await this.convertNativeEvent(nativeEvent);
    
    if (interactionEvent) {
      this.emit('interaction', interactionEvent);
    }
  }

  private async convertNativeEvent(nativeEvent: any): Promise<InteractionEvent | null> {
    try {
      // Skip system messages
      if (nativeEvent.type === 'system') {
        console.log(`📟 Native helper: ${nativeEvent.data.message}`);
        return null;
      }

      let interactionType: string;
      let target: any = {};
      let inputData: any = {};

      switch (nativeEvent.type) {
        case 'mouse_click':
          interactionType = 'click';
          
          // Debug: Log what the native helper is sending with more context (only for non-dock clicks)
          // console.debug(`🖱️  Native click detected: (${nativeEvent.data.x}, ${nativeEvent.data.y}) button=${nativeEvent.data.button} clickCount=${nativeEvent.data.clickCount} timestamp=${nativeEvent.data.systemTimestamp}`);
          
          // Get accessibility information for the clicked element
          let accessibilityInfo: AccessibilityHitTest | null = null;
          try {
            accessibilityInfo = await this.accessibilityInspector.hitTest(
              nativeEvent.data.x, 
              nativeEvent.data.y
            );
          } catch (error) {
            console.debug('Could not get accessibility info for click:', error instanceof Error ? error.message : 'Unknown error');
          }
          
          target = {
            coordinates: { 
              x: nativeEvent.data.x, 
              y: nativeEvent.data.y 
            },
            // Include accessibility information if available
            ...(accessibilityInfo && {
              element: accessibilityInfo.element,
              applicationContext: accessibilityInfo.context
            })
          };
          inputData = {
            button: nativeEvent.data.button,
            clickCount: nativeEvent.data.clickCount || 1,
            // Add semantic context from accessibility tree
            ...(accessibilityInfo?.element && {
              elementRole: accessibilityInfo.element.role,
              elementTitle: accessibilityInfo.element.title,
              elementLabel: accessibilityInfo.element.label,
              elementValue: accessibilityInfo.element.value
            })
          };
          break;

        case 'key_press':
          interactionType = 'key';
          inputData = {
            key: nativeEvent.data.key,
            keyCode: nativeEvent.data.keyCode,
            modifiers: nativeEvent.data.modifiers || []
          };
          break;

        case 'scroll':
          interactionType = 'scroll';
          target = {
            coordinates: { 
              x: nativeEvent.data.x, 
              y: nativeEvent.data.y 
            }
          };
          inputData = {
            scrollDelta: {
              x: nativeEvent.data.deltaX,
              y: nativeEvent.data.deltaY
            }
          };
          break;

        case 'mouse_move':
          interactionType = 'mouse_move';
          target = {
            coordinates: { 
              x: nativeEvent.data.x, 
              y: nativeEvent.data.y 
            }
          };
          break;

        case 'mouse_drag':
          interactionType = 'drag';
          target = {
            coordinates: { 
              x: nativeEvent.data.x, 
              y: nativeEvent.data.y 
            }
          };
          inputData = {
            button: nativeEvent.data.button
          };
          break;

        default:
          console.debug('Unknown native event type:', nativeEvent.type);
          return null;
      }

      // Apply privacy filters
      if (!this.shouldCaptureInteraction(interactionType)) {
        return null;
      }

      return this.createInteractionEvent(
        interactionType,
        {
          target,
          inputData,
          sessionId: this.sessionId,
          confidence: 0.95, // Native events are highly reliable
          nativeTimestamp: nativeEvent.data.systemTimestamp
        },
        nativeEvent.timestamp || Date.now() * 1000
      );

    } catch (error) {
      console.error('Failed to convert native event:', error, nativeEvent);
      return null;
    }
  }

  private shouldCaptureInteraction(interactionType: string): boolean {
    switch (interactionType) {
      case 'click':
        return this.config.enableMouse !== false;
      case 'key':
        return this.config.enableKeyboard !== false;
      case 'scroll':
        return this.config.enableMouse !== false;
      case 'mouse_move':
        return this.config.enableMouse === true && this.config.captureLevel === 'full';
      case 'drag':
        return this.config.enableMouse !== false;
      default:
        return true;
    }
  }

  async shutdown(): Promise<void> {
    await this.stopMonitoring();
    await super.shutdown();
  }
}
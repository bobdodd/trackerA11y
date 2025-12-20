/**
 * Native macOS Interaction Tracker
 * Uses native helper app for real system-wide event capture
 */

import { spawn, ChildProcess } from 'child_process';
import { BaseInteractionTracker } from '../BaseInteractionTracker';
import { InteractionEvent, InteractionConfig } from '@/types';
import * as path from 'path';

export class NativeInteractionTracker extends BaseInteractionTracker {
  private nativeProcess: ChildProcess | null = null;
  private sessionId: string = '';
  private nativeHelperPath: string;
  private hoverTracker: {
    currentPosition: { x: number; y: number } | null;
    startTime: number | null;
    element: any | null;
    timer: NodeJS.Timeout | null;
    minHoverTime: number;
  } = {
    currentPosition: null,
    startTime: null,
    element: null,
    timer: null,
    minHoverTime: 500 // Minimum 500ms to consider a hover
  };

  constructor(config: InteractionConfig) {
    super(config);
    this.sessionId = `native_session_${Date.now()}`;
    this.nativeHelperPath = path.resolve(__dirname, '../../../native_helpers/native_helpers/mouse_capture');
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
    return ['click', 'mouse_down', 'mouse_up', 'key', 'scroll', 'mouse_move', 'drag', 'hover', 'focus_change', 'focus_lost'];
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
      // Only log actual errors, skip debug output
      const errorMsg = data.toString().trim();
      if (errorMsg && !errorMsg.includes('warning:')) {
        console.error('Native helper error:', errorMsg);
      }
    });

    // Handle process exit
    this.nativeProcess.on('exit', (code, signal) => {
      // Only log unexpected exits
      if (this.isMonitoring && code !== 0) {
        console.log(`Native helper exited unexpectedly with code ${code}, signal ${signal}`);
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
        case 'mouse_click': // Backward compatibility
        case 'mouse_down':
          interactionType = nativeEvent.type === 'mouse_click' ? 'click' : 'mouse_down';
          
          // Use native element info if provided by mouse_capture
          const nativeElement = nativeEvent.data.element;
          
          const isDockClick = nativeElement?.applicationName === 'Dock';
          
          target = {
            coordinates: { 
              x: nativeEvent.data.x, 
              y: nativeEvent.data.y 
            },
            // Include native accessibility information if available
            ...(nativeElement && {
              element: {
                role: nativeElement.role || 'unknown',
                title: nativeElement.title,
                label: nativeElement.label,
                value: nativeElement.value,
                description: isDockClick ? 'Dock item' : nativeElement.roleDescription,
                enabled: nativeElement.enabled !== false,
                focused: nativeElement.focused === true,
                bounds: nativeElement.boundsX !== undefined ? {
                  x: nativeElement.boundsX,
                  y: nativeElement.boundsY,
                  width: nativeElement.boundsWidth,
                  height: nativeElement.boundsHeight
                } : undefined
              },
              applicationContext: {
                processId: nativeElement.pid || -1,
                applicationName: nativeElement.applicationName || 'Unknown'
              },
              isDockItem: isDockClick
            })
          };
          inputData = {
            button: nativeEvent.data.button,
            clickCount: nativeEvent.data.clickCount || 1,
            modifiers: nativeEvent.data.modifiers || [],
            isDockClick,
            // Add semantic context from native accessibility
            ...(nativeElement && {
              elementRole: nativeElement.role,
              elementTitle: nativeElement.title,
              elementLabel: nativeElement.label,
              elementValue: nativeElement.value
            })
          };
          break;

        case 'mouse_up':
          // Generate both mouse_up and click events for mouse up
          // Use native element info if provided by mouse_capture
          const mouseUpNativeElement = nativeEvent.data.element;
          
          const isUpDockClick = mouseUpNativeElement?.applicationName === 'Dock';
          
          const upTarget = {
            coordinates: { 
              x: nativeEvent.data.x, 
              y: nativeEvent.data.y 
            },
            // Include native accessibility information if available
            ...(mouseUpNativeElement && {
              element: {
                role: mouseUpNativeElement.role || 'unknown',
                title: mouseUpNativeElement.title,
                label: mouseUpNativeElement.label,
                value: mouseUpNativeElement.value,
                description: isUpDockClick ? 'Dock item' : mouseUpNativeElement.roleDescription,
                enabled: mouseUpNativeElement.enabled !== false,
                focused: mouseUpNativeElement.focused === true,
                bounds: mouseUpNativeElement.boundsX !== undefined ? {
                  x: mouseUpNativeElement.boundsX,
                  y: mouseUpNativeElement.boundsY,
                  width: mouseUpNativeElement.boundsWidth,
                  height: mouseUpNativeElement.boundsHeight
                } : undefined
              },
              applicationContext: {
                processId: mouseUpNativeElement.pid || -1,
                applicationName: mouseUpNativeElement.applicationName || 'Unknown'
              },
              isDockItem: isUpDockClick
            })
          };
          const upInputData = {
            button: nativeEvent.data.button,
            clickCount: nativeEvent.data.clickCount || 1,
            modifiers: nativeEvent.data.modifiers || [],
            isDockClick: isUpDockClick,
            // Add semantic context from native accessibility
            ...(mouseUpNativeElement && {
              elementRole: mouseUpNativeElement.role,
              elementTitle: mouseUpNativeElement.title,
              elementLabel: mouseUpNativeElement.label,
              elementValue: mouseUpNativeElement.value
            })
          };

          // Emit mouse_up event
          const mouseUpEvent = this.createInteractionEvent(
            'mouse_up',
            {
              target: upTarget,
              inputData: upInputData,
              sessionId: this.sessionId,
              confidence: 0.95,
              nativeTimestamp: nativeEvent.data.systemTimestamp
            },
            nativeEvent.timestamp || Date.now() * 1000
          );
          
          if (this.shouldCaptureInteraction('mouse_up')) {
            this.emit('interaction', mouseUpEvent);
          }

          // Also emit a click event (traditional complete click behavior)
          interactionType = 'click';
          target = upTarget;
          inputData = upInputData;
          break;

        case 'key_press':
          interactionType = 'key';
          const key = nativeEvent.data.key;
          const modifiers = nativeEvent.data.modifiers || [];
          
          inputData = {
            key,
            keyCode: nativeEvent.data.keyCode,
            modifiers
          };
          break;

        case 'focus_change':
          interactionType = 'focus_change';
          const focusedElement = nativeEvent.data.focusedElement;
          const focusTrigger = nativeEvent.data.trigger || 'keyboard';
          
          if (focusTrigger === 'click') {
            target = {
              coordinates: {
                x: nativeEvent.data.x,
                y: nativeEvent.data.y
              }
            };
            inputData = {
              trigger: 'click',
              ...(focusedElement && {
                focusedElement: {
                  role: focusedElement.role,
                  subrole: focusedElement.subrole,
                  title: focusedElement.title,
                  label: focusedElement.label,
                  value: focusedElement.value,
                  roleDescription: focusedElement.roleDescription,
                  domId: focusedElement.domId,
                  domClassList: focusedElement.domClassList,
                  applicationName: focusedElement.applicationName,
                  bounds: focusedElement.boundsX !== undefined ? {
                    x: focusedElement.boundsX,
                    y: focusedElement.boundsY,
                    width: focusedElement.boundsWidth,
                    height: focusedElement.boundsHeight
                  } : undefined
                }
              })
            };
          } else {
            const focusKey = nativeEvent.data.key;
            const focusModifiers = nativeEvent.data.modifiers || [];
            inputData = {
              trigger: 'keyboard',
              key: focusKey,
              keyCode: nativeEvent.data.keyCode,
              modifiers: focusModifiers,
              ...(focusedElement && {
                focusedElement: {
                  role: focusedElement.role,
                  subrole: focusedElement.subrole,
                  title: focusedElement.title,
                  label: focusedElement.label,
                  value: focusedElement.value,
                  roleDescription: focusedElement.roleDescription,
                  domId: focusedElement.domId,
                  domClassList: focusedElement.domClassList,
                  applicationName: focusedElement.applicationName,
                  bounds: focusedElement.boundsX !== undefined ? {
                    x: focusedElement.boundsX,
                    y: focusedElement.boundsY,
                    width: focusedElement.boundsWidth,
                    height: focusedElement.boundsHeight
                  } : undefined
                }
              })
            };
          }
          break;

        case 'focus_lost':
          interactionType = 'focus_lost';
          const lostTrigger = nativeEvent.data.trigger || 'click';
          target = {
            coordinates: {
              x: nativeEvent.data.x,
              y: nativeEvent.data.y
            }
          };
          inputData = {
            trigger: lostTrigger
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
            },
            modifiers: nativeEvent.data.modifiers || []
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
          inputData = {};
          
          // Track hover behavior
          await this.trackHover(nativeEvent.data.x, nativeEvent.data.y, nativeEvent.data.systemTimestamp);
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
            button: nativeEvent.data.button,
            modifiers: nativeEvent.data.modifiers || []
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
      case 'mouse_down':
      case 'mouse_up':
        return this.config.enableMouse !== false;
      case 'key':
        return this.config.enableKeyboard !== false;
      case 'scroll':
        return this.config.enableMouse !== false;
      case 'mouse_move':
        return this.config.enableMouse === true && this.config.captureLevel === 'full';
      case 'drag':
        return this.config.enableMouse !== false;
      case 'hover':
        return this.config.enableMouse !== false;
      default:
        return true;
    }
  }

  /**
   * Track hover behavior - detects when mouse stays in same area for extended time
   */
  private async trackHover(x: number, y: number, timestamp: number): Promise<void> {
    const currentTime = timestamp || Date.now() * 1000;
    const position = { x, y };
    
    // Check if mouse has moved significantly (more than 10 pixels)
    const hasMovedSignificantly = this.hoverTracker.currentPosition && (
      Math.abs(x - this.hoverTracker.currentPosition.x) > 10 || 
      Math.abs(y - this.hoverTracker.currentPosition.y) > 10
    );
    
    // If mouse moved significantly, end current hover and start new tracking
    if (hasMovedSignificantly) {
      await this.endHover(currentTime);
      this.startHoverTracking(position, currentTime);
    } 
    // If no current hover tracking, start it
    else if (!this.hoverTracker.currentPosition) {
      this.startHoverTracking(position, currentTime);
    }
    // Otherwise, continue current hover tracking (mouse is stationary)
  }

  private startHoverTracking(position: { x: number; y: number }, timestamp: number): void {
    this.hoverTracker.currentPosition = position;
    this.hoverTracker.startTime = timestamp;
    
    // Clear any existing timer
    if (this.hoverTracker.timer) {
      clearTimeout(this.hoverTracker.timer);
    }
    
    // Set timer to emit hover event after minimum hover time
    this.hoverTracker.timer = setTimeout(async () => {
      await this.emitHoverEvent();
    }, this.hoverTracker.minHoverTime);
  }

  private async endHover(timestamp: number): Promise<void> {
    if (this.hoverTracker.timer) {
      clearTimeout(this.hoverTracker.timer);
      this.hoverTracker.timer = null;
    }
    
    // If we had a valid hover (long enough), emit hover end event
    if (this.hoverTracker.startTime && this.hoverTracker.currentPosition) {
      const hoverDuration = timestamp - this.hoverTracker.startTime;
      if (hoverDuration >= this.hoverTracker.minHoverTime * 1000) { // Convert to microseconds
        await this.emitHoverEndEvent(hoverDuration / 1000); // Convert back to milliseconds
      }
    }
    
    this.resetHoverTracking();
  }

  private async emitHoverEvent(): Promise<void> {
    if (!this.hoverTracker.currentPosition || !this.hoverTracker.startTime) {
      return;
    }

    const interactionEvent = this.createInteractionEvent(
      'hover',
      {
        target: {
          coordinates: this.hoverTracker.currentPosition
        },
        inputData: {
          hoverStartTime: this.hoverTracker.startTime,
          minHoverDuration: this.hoverTracker.minHoverTime
        },
        sessionId: this.sessionId,
        confidence: 0.85
      },
      this.hoverTracker.startTime
    );

    this.hoverTracker.element = {};
    this.emit('interaction', interactionEvent);
  }

  private async emitHoverEndEvent(durationMs: number): Promise<void> {
    if (!this.hoverTracker.currentPosition || !this.hoverTracker.element) {
      return;
    }

    const interactionEvent = this.createInteractionEvent(
      'hover_end',
      {
        target: {
          coordinates: this.hoverTracker.currentPosition
        },
        inputData: {
          dwellTime: durationMs,
          hoverStartTime: this.hoverTracker.startTime
        },
        sessionId: this.sessionId,
        confidence: 0.90
      },
      Date.now() * 1000
    );

    this.emit('interaction', interactionEvent);
  }

  private resetHoverTracking(): void {
    this.hoverTracker.currentPosition = null;
    this.hoverTracker.startTime = null;
    this.hoverTracker.element = null;
    if (this.hoverTracker.timer) {
      clearTimeout(this.hoverTracker.timer);
      this.hoverTracker.timer = null;
    }
  }

  async shutdown(): Promise<void> {
    // Clean up hover tracking
    this.resetHoverTracking();
    
    await this.stopMonitoring();
    await super.shutdown();
  }
}
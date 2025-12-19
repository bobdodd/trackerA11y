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
    return ['click', 'mouse_down', 'mouse_up', 'key', 'scroll', 'mouse_move', 'drag', 'hover'];
  }

  /**
   * Get accessibility and browser element information for coordinates
   */
  private async getElementInfoAtCoordinates(x: number, y: number): Promise<AccessibilityHitTest | null> {
    try {
      // Add timeout to prevent hanging
      const timeoutPromise = new Promise<null>((resolve) => {
        setTimeout(() => resolve(null), 2000); // 2 second timeout
      });
      
      const hitTestPromise = this.accessibilityInspector.hitTest(x, y);
      
      return await Promise.race([hitTestPromise, timeoutPromise]);
    } catch (error) {
      console.debug('Could not get element info:', error instanceof Error ? error.message : 'Unknown error');
      return null;
    }
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
          
          // Get accessibility information for the element
          let accessibilityInfo: any = null;
          try {
            accessibilityInfo = await this.getElementInfoAtCoordinates(
              nativeEvent.data.x, 
              nativeEvent.data.y
            );
          } catch (error) {
            // Ignore accessibility errors
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

        case 'mouse_up':
          // Generate both mouse_up and click events for mouse up
          
          // Get accessibility information for the element
          let mouseUpAccessibilityInfo = await this.getElementInfoAtCoordinates(
            nativeEvent.data.x, 
            nativeEvent.data.y
          );
          
          const upTarget = {
            coordinates: { 
              x: nativeEvent.data.x, 
              y: nativeEvent.data.y 
            },
            // Include accessibility information if available
            ...(mouseUpAccessibilityInfo && {
              element: mouseUpAccessibilityInfo.element,
              applicationContext: mouseUpAccessibilityInfo.context
            })
          };
          const upInputData = {
            button: nativeEvent.data.button,
            clickCount: nativeEvent.data.clickCount || 1,
            // Add semantic context from accessibility tree
            ...(mouseUpAccessibilityInfo?.element && {
              elementRole: mouseUpAccessibilityInfo.element.role,
              elementTitle: mouseUpAccessibilityInfo.element.title,
              elementLabel: mouseUpAccessibilityInfo.element.label,
              elementValue: mouseUpAccessibilityInfo.element.value
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
          inputData = {
            key: nativeEvent.data.key,
            keyCode: nativeEvent.data.keyCode,
            modifiers: nativeEvent.data.modifiers || []
          };
          break;

        case 'scroll':
          interactionType = 'scroll';
          
          // Get accessibility information for scroll location
          let scrollAccessibilityInfo = await this.getElementInfoAtCoordinates(
            nativeEvent.data.x, 
            nativeEvent.data.y
          );
          
          target = {
            coordinates: { 
              x: nativeEvent.data.x, 
              y: nativeEvent.data.y 
            },
            // Include accessibility information if available
            ...(scrollAccessibilityInfo && {
              element: scrollAccessibilityInfo.element,
              applicationContext: scrollAccessibilityInfo.context
            })
          };
          inputData = {
            scrollDelta: {
              x: nativeEvent.data.deltaX,
              y: nativeEvent.data.deltaY
            },
            // Add semantic context from accessibility tree
            ...(scrollAccessibilityInfo?.element && {
              elementRole: scrollAccessibilityInfo.element.role,
              elementTitle: scrollAccessibilityInfo.element.title,
              elementLabel: scrollAccessibilityInfo.element.label,
              elementValue: scrollAccessibilityInfo.element.value
            })
          };
          break;

        case 'mouse_move':
          interactionType = 'mouse_move';
          
          // Get accessibility information for mouse position (lightweight for frequent events)
          let mouseMoveAccessibilityInfo: AccessibilityHitTest | null = null;
          if (this.config.captureLevel === 'full') {
            mouseMoveAccessibilityInfo = await this.getElementInfoAtCoordinates(
              nativeEvent.data.x, 
              nativeEvent.data.y
            );
          }
          
          target = {
            coordinates: { 
              x: nativeEvent.data.x, 
              y: nativeEvent.data.y 
            },
            // Include accessibility information if available
            ...(mouseMoveAccessibilityInfo && {
              element: mouseMoveAccessibilityInfo.element,
              applicationContext: mouseMoveAccessibilityInfo.context
            })
          };
          inputData = {
            // Add semantic context if available
            ...(mouseMoveAccessibilityInfo?.element && {
              elementRole: mouseMoveAccessibilityInfo.element.role,
              elementTitle: mouseMoveAccessibilityInfo.element.title,
              elementLabel: mouseMoveAccessibilityInfo.element.label,
              elementValue: mouseMoveAccessibilityInfo.element.value
            })
          };
          
          // Track hover behavior
          await this.trackHover(nativeEvent.data.x, nativeEvent.data.y, nativeEvent.data.systemTimestamp);
          break;

        case 'mouse_drag':
          interactionType = 'drag';
          
          // Get accessibility information for drag location
          let dragAccessibilityInfo = await this.getElementInfoAtCoordinates(
            nativeEvent.data.x, 
            nativeEvent.data.y
          );
          
          target = {
            coordinates: { 
              x: nativeEvent.data.x, 
              y: nativeEvent.data.y 
            },
            // Include accessibility information if available
            ...(dragAccessibilityInfo && {
              element: dragAccessibilityInfo.element,
              applicationContext: dragAccessibilityInfo.context
            })
          };
          inputData = {
            button: nativeEvent.data.button,
            // Add semantic context from accessibility tree
            ...(dragAccessibilityInfo?.element && {
              elementRole: dragAccessibilityInfo.element.role,
              elementTitle: dragAccessibilityInfo.element.title,
              elementLabel: dragAccessibilityInfo.element.label,
              elementValue: dragAccessibilityInfo.element.value
            })
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

    try {
      // Get accessibility information for the hovered element
      const accessibilityInfo = await this.accessibilityInspector.hitTest(
        this.hoverTracker.currentPosition.x, 
        this.hoverTracker.currentPosition.y
      );

      this.hoverTracker.element = accessibilityInfo;

      const interactionEvent = this.createInteractionEvent(
        'hover',
        {
          target: {
            coordinates: this.hoverTracker.currentPosition,
            ...(accessibilityInfo && {
              element: accessibilityInfo.element,
              applicationContext: accessibilityInfo.context
            })
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

      this.emit('interaction', interactionEvent);
      
    } catch (error) {
      console.debug('Could not get accessibility info for hover:', error instanceof Error ? error.message : 'Unknown error');
    }
  }

  private async emitHoverEndEvent(durationMs: number): Promise<void> {
    if (!this.hoverTracker.currentPosition || !this.hoverTracker.element) {
      return;
    }

    const interactionEvent = this.createInteractionEvent(
      'hover_end',
      {
        target: {
          coordinates: this.hoverTracker.currentPosition,
          ...(this.hoverTracker.element && {
            element: this.hoverTracker.element.element,
            applicationContext: this.hoverTracker.element.context
          })
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
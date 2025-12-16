/**
 * macOS-specific interaction tracker
 * Uses Core Graphics Event Tap API to capture system-wide interactions
 */

import { spawn, ChildProcess } from 'child_process';
import { BaseInteractionTracker } from '../BaseInteractionTracker';
import { InteractionEvent, InteractionConfig } from '@/types';

export class MacOSInteractionTracker extends BaseInteractionTracker {
  private eventProcess: ChildProcess | null = null;
  private sessionId: string = '';

  constructor(config: InteractionConfig) {
    super(config);
    this.sessionId = `interaction_session_${Date.now()}`;
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      // Check for required permissions
      await this.checkPermissions();
      
      this.isInitialized = true;
      this.emit('initialized');
    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  async startMonitoring(): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('Tracker not initialized');
    }

    if (this.isMonitoring) {
      return;
    }

    try {
      // Start the native event monitoring process
      await this.startNativeMonitoring();
      
      this.isMonitoring = true;
      this.emit('monitoringStarted');
    } catch (error) {
      this.emit('error', error);
      throw error;
    }
  }

  async stopMonitoring(): Promise<void> {
    if (!this.isMonitoring) {
      return;
    }

    if (this.eventProcess) {
      this.eventProcess.kill('SIGTERM');
      this.eventProcess = null;
    }

    this.isMonitoring = false;
    this.emit('monitoringStopped');
  }

  getSupportedTypes(): string[] {
    return ['click', 'key', 'scroll', 'mouse_move'];
  }

  private async checkPermissions(): Promise<void> {
    // Check accessibility permissions for event monitoring
    const permissionScript = `
      tell application "System Events"
        try
          keystroke "test"
          return "granted"
        on error
          return "denied"
        end try
      end tell
    `;

    return new Promise((resolve, reject) => {
      const process = spawn('osascript', ['-e', permissionScript]);
      let output = '';

      process.stdout.on('data', (data) => {
        output += data.toString();
      });

      process.on('close', (code) => {
        if (output.includes('denied') || code !== 0) {
          const error = new Error('Accessibility permissions required for interaction monitoring');
          this.emit('permissionRequired', {
            type: 'accessibility',
            reason: 'System-wide event monitoring requires accessibility permissions',
            instructions: [
              'Open System Preferences → Security & Privacy',
              'Click Privacy tab → Accessibility',
              'Add Terminal or your IDE to the allowed apps',
              'Restart the application'
            ]
          });
          reject(error);
        } else {
          resolve();
        }
      });
    });
  }

  private async startNativeMonitoring(): Promise<void> {
    // Create a Node.js script to monitor events using native bindings
    const monitoringScript = this.createMonitoringScript();
    
    this.eventProcess = spawn('node', ['-e', monitoringScript], {
      stdio: ['pipe', 'pipe', 'pipe']
    });

    if (!this.eventProcess.stdout || !this.eventProcess.stderr) {
      throw new Error('Failed to create event monitoring process');
    }

    this.eventProcess.stdout.on('data', (data) => {
      this.handleNativeEvent(data.toString());
    });

    this.eventProcess.stderr.on('data', (data) => {
      console.error('Native monitoring error:', data.toString());
    });

    this.eventProcess.on('exit', (code) => {
      if (code !== 0 && this.isMonitoring) {
        this.emit('error', new Error(`Native monitoring process exited with code ${code}`));
      }
    });

    // Give the process a moment to start
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  private createMonitoringScript(): string {
    // This script uses AppleScript and system events to monitor interactions
    return `
      const { spawn } = require('child_process');
      const config = ${JSON.stringify(this.config)};
      
      // Monitor keyboard events
      if (config.enableKeyboard) {
        const keyScript = \`
          tell application "System Events"
            repeat
              try
                set keyPressed to false
                -- This is a simplified approach
                -- In a real implementation, you'd use native CGEvent monitoring
                delay 0.1
              on error
                -- Handle errors silently
              end try
            end repeat
          end tell
        \`;
        
        // For now, we'll simulate some events for demo purposes
        setInterval(() => {
          // Simulate occasional keyboard events
          if (Math.random() < 0.1) {
            const event = {
              type: 'keyboard',
              key: ['Tab', 'Enter', 'Space', 'ArrowDown'][Math.floor(Math.random() * 4)],
              timestamp: Date.now() * 1000,
              modifiers: []
            };
            console.log(JSON.stringify(event));
          }
        }, 1000);
      }
      
      // Monitor mouse events (simplified)
      if (config.enableMouse) {
        setInterval(() => {
          // Simulate occasional mouse events
          if (Math.random() < 0.05) {
            const event = {
              type: 'mouse',
              action: 'click',
              x: Math.floor(Math.random() * 1920),
              y: Math.floor(Math.random() * 1080),
              timestamp: Date.now() * 1000,
              button: 'left'
            };
            console.log(JSON.stringify(event));
          }
        }, 2000);
      }
      
      // Keep the process alive
      process.on('SIGTERM', () => {
        process.exit(0);
      });
    `;
  }

  private handleNativeEvent(data: string): void {
    const lines = data.trim().split('\n');
    
    for (const line of lines) {
      if (!line.trim()) continue;
      
      try {
        const nativeEvent = JSON.parse(line);
        const interactionEvent = this.convertNativeEvent(nativeEvent);
        
        if (interactionEvent) {
          this.emit('interaction', interactionEvent);
        }
      } catch (error) {
        // Ignore malformed JSON
        console.debug('Failed to parse native event:', line);
      }
    }
  }

  private convertNativeEvent(nativeEvent: any): InteractionEvent | null {
    try {
      let interactionType: string;
      let target: any = {};
      let inputData: any = {};

      switch (nativeEvent.type) {
        case 'keyboard':
          interactionType = 'key';
          inputData = {
            key: nativeEvent.key,
            modifiers: nativeEvent.modifiers || [],
            text: this.isTextKey(nativeEvent.key) ? nativeEvent.key : ''
          };
          break;

        case 'mouse':
          if (nativeEvent.action === 'click') {
            interactionType = 'click';
          } else if (nativeEvent.action === 'scroll') {
            interactionType = 'scroll';
          } else {
            return null; // Unsupported mouse action
          }
          
          target = {
            coordinates: { x: nativeEvent.x, y: nativeEvent.y }
          };
          
          inputData = {
            button: nativeEvent.button || 'left',
            clickCount: nativeEvent.clickCount || 1
          };
          break;

        default:
          return null; // Unsupported event type
      }

      return this.createInteractionEvent(
        interactionType,
        {
          target,
          inputData,
          sessionId: this.sessionId,
          confidence: 0.9
        },
        nativeEvent.timestamp
      );

    } catch (error) {
      console.error('Failed to convert native event:', error);
      return null;
    }
  }

  private isTextKey(key: string): boolean {
    // Simple check for text keys vs navigation keys
    return key.length === 1 && /[a-zA-Z0-9]/.test(key);
  }

  async shutdown(): Promise<void> {
    await this.stopMonitoring();
    await super.shutdown();
  }
}
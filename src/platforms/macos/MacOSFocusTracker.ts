/**
 * macOS Focus Tracker - Uses NSWorkspace and Accessibility APIs
 * Implements focus tracking for macOS using native APIs
 */

import { BaseFocusTracker } from '@/core/FocusManager';
import { FocusEvent, AccessibilityContext } from '@/types';
import { execFile, spawn } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

interface MacOSAppInfo {
  name: string;
  pid: number;
  bundleId?: string;
  windowTitle?: string;
}

interface MacOSAccessibilityInfo {
  role?: string;
  roleDescription?: string;
  title?: string;
  value?: string;
  description?: string;
  enabled?: boolean;
  focused?: boolean;
  bounds?: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
}

export class MacOSFocusTracker extends BaseFocusTracker {
  private monitoringTimer: NodeJS.Timeout | null = null;
  private elementFocusTimer: NodeJS.Timeout | null = null;
  private osascriptPath = '/usr/bin/osascript';
  private lastKnownPid: number | null = null;
  private lastFocusedElement: string | null = null;

  constructor(pollInterval = 500) { // macOS requires less frequent polling
    super('macos', pollInterval);
  }

  async startMonitoring(): Promise<void> {
    if (this.isMonitoring) return;

    // Check for Accessibility permissions
    await this.checkAccessibilityPermissions();

    this.isMonitoring = true;
    this.startPolling();
    this.startElementFocusPolling();
    
    // Also set up NSWorkspace notifications if available
    this.setupWorkspaceNotifications();
  }

  async stopMonitoring(): Promise<void> {
    if (!this.isMonitoring) return;

    this.isMonitoring = false;
    
    if (this.monitoringTimer) {
      clearInterval(this.monitoringTimer);
      this.monitoringTimer = null;
    }
    
    if (this.elementFocusTimer) {
      clearInterval(this.elementFocusTimer);
      this.elementFocusTimer = null;
    }
  }

  async getCurrentFocus(): Promise<FocusEvent | null> {
    try {
      const appInfo = await this.getFrontmostApplication();
      if (!appInfo) return null;

      const accessibilityContext = await this.getAccessibilityContext(appInfo.pid);
      
      return this.createFocusEvent(
        appInfo.name,
        appInfo.windowTitle || 'Unknown Window',
        appInfo.pid,
        accessibilityContext
      );
    } catch (error) {
      // Only log unexpected errors, not interruption/timeout errors
      if (error instanceof Error && !error.message.includes('Command failed') && !error.message.includes('SIGINT')) {
        console.error('Error getting current focus:', error.message);
      }
      return null;
    }
  }

  async getAccessibilityContext(processId: number): Promise<AccessibilityContext> {
    try {
      const accessibilityInfo = await this.getAccessibilityInfo(processId);
      
      return {
        role: accessibilityInfo.role,
        name: accessibilityInfo.title,
        description: accessibilityInfo.description || accessibilityInfo.roleDescription,
        value: accessibilityInfo.value,
        states: this.extractStates(accessibilityInfo),
        properties: {
          bundleId: await this.getBundleId(processId),
          enabled: accessibilityInfo.enabled,
          focused: accessibilityInfo.focused,
          bounds: accessibilityInfo.bounds
        }
      };
    } catch (error) {
      // Only log significant errors, not common process-not-found issues
      if (error instanceof Error && !error.message.includes('Command failed')) {
        console.warn(`Failed to get accessibility context for PID ${processId}:`, error.message);
      }
      return {};
    }
  }

  private async checkAccessibilityPermissions(): Promise<void> {
    const script = `
      tell application "System Events"
        try
          get name of first process whose frontmost is true
          return "granted"
        on error
          return "denied"
        end try
      end tell
    `;

    try {
      const { stdout } = await execFileAsync(this.osascriptPath, ['-e', script]);
      if (stdout.trim() === 'denied') {
        throw new Error('Accessibility permissions not granted. Please enable accessibility access for this application in System Preferences > Security & Privacy > Privacy > Accessibility');
      }
    } catch (error) {
      if (error instanceof Error && error.message.includes('denied')) {
        throw error;
      }
      // If we get here, permissions might actually be OK
      console.warn('Could not verify accessibility permissions, proceeding...', error);
    }
  }

  private startPolling(): void {
    this.monitoringTimer = setInterval(async () => {
      if (!this.isMonitoring) return;

      try {
        const currentFocus = await this.getCurrentFocus();
        if (currentFocus) {
          this.emitFocusChange(currentFocus);
        }
      } catch (error) {
        this.emit('error', new Error(`Focus polling error: ${error}`));
      }
    }, this.pollInterval);
  }

  private setupWorkspaceNotifications(): void {
    // For future implementation - NSWorkspace notifications via native addon
    // This would provide real-time notifications instead of polling
    console.log('Workspace notifications not yet implemented, using polling');
  }

  private startElementFocusPolling(): void {
    this.elementFocusTimer = setInterval(async () => {
      if (!this.isMonitoring) return;

      try {
        const focusedElement = await this.getFocusedUIElement();
        if (focusedElement && focusedElement !== this.lastFocusedElement) {
          this.lastFocusedElement = focusedElement;
          this.emit('elementFocusChanged', this.parseElementFocusInfo(focusedElement));
        }
      } catch (error) {
        // Silent fail for element focus - it's supplementary
      }
    }, 200); // Poll element focus more frequently (200ms)
  }

  private async getFocusedUIElement(): Promise<string | null> {
    const script = `
      tell application "System Events"
        try
          set frontApp to first process whose frontmost is true
          set focusedElem to focused UI element of frontApp
          
          set elemRole to ""
          set elemTitle to ""
          set elemValue to ""
          set elemDesc to ""
          set elemHelp to ""
          
          try
            set elemRole to role of focusedElem
          end try
          try
            set elemTitle to title of focusedElem
          end try
          try
            set elemValue to value of focusedElem
          end try
          try
            set elemDesc to description of focusedElem
          end try
          try
            set elemHelp to help of focusedElem
          end try
          
          -- Get position and size for unique identification
          set elemPos to "0,0"
          set elemSize to "0,0"
          try
            set pos to position of focusedElem
            set elemPos to (item 1 of pos as string) & "," & (item 2 of pos as string)
          end try
          try
            set sz to size of focusedElem
            set elemSize to (item 1 of sz as string) & "," & (item 2 of sz as string)
          end try
          
          return elemRole & "|" & elemTitle & "|" & elemValue & "|" & elemDesc & "|" & elemHelp & "|" & elemPos & "|" & elemSize
        on error
          return ""
        end try
      end tell
    `;

    try {
      const { stdout } = await execFileAsync(this.osascriptPath, ['-e', script], {
        timeout: 500
      });
      const result = stdout.trim();
      return result || null;
    } catch {
      return null;
    }
  }

  private parseElementFocusInfo(elementString: string): {
    role: string;
    title: string;
    value: string;
    description: string;
    help: string;
    position: { x: number; y: number };
    size: { width: number; height: number };
  } {
    const [role, title, value, description, help, posStr, sizeStr] = elementString.split('|');
    
    let position = { x: 0, y: 0 };
    let size = { width: 0, height: 0 };
    
    if (posStr && posStr.includes(',')) {
      const [x, y] = posStr.split(',').map(Number);
      if (!isNaN(x) && !isNaN(y)) {
        position = { x, y };
      }
    }
    
    if (sizeStr && sizeStr.includes(',')) {
      const [w, h] = sizeStr.split(',').map(Number);
      if (!isNaN(w) && !isNaN(h)) {
        size = { width: w, height: h };
      }
    }
    
    return {
      role: role || 'unknown',
      title: title || '',
      value: value || '',
      description: description || '',
      help: help || '',
      position,
      size
    };
  }

  private async getFrontmostApplication(): Promise<MacOSAppInfo | null> {
    const script = `
      tell application "System Events"
        try
          set frontApp to first process whose frontmost is true
          set appName to name of frontApp
          set appPid to unix id of frontApp
          
          -- Try to get window title
          try
            set frontWindow to front window of frontApp
            set windowTitle to name of frontWindow
          on error
            set windowTitle to ""
          end try
          
          return appName & "|" & appPid & "|" & windowTitle
        on error
          return ""
        end try
      end tell
    `;

    try {
      const { stdout } = await execFileAsync(this.osascriptPath, ['-e', script], {
        timeout: 1500 // Shorter timeout for frontmost app check
      });
      const result = stdout.trim();
      
      if (!result) return null;
      
      const [name, pidStr, windowTitle] = result.split('|');
      const pid = parseInt(pidStr, 10);
      
      if (isNaN(pid)) return null;
      
      return {
        name: name || 'Unknown App',
        pid,
        windowTitle: windowTitle || undefined
      };
    } catch (error) {
      // Handle common interruption cases silently
      if (error instanceof Error && (
        error.message.includes('SIGINT') || 
        error.message.includes('timeout') ||
        error.message.includes('Command failed')
      )) {
        return null;
      }
      console.error('Error getting frontmost application:', error instanceof Error ? error.message : 'Unknown error');
      return null;
    }
  }

  private async getAccessibilityInfo(processId: number): Promise<MacOSAccessibilityInfo> {
    // First check if the process still exists
    try {
      const { stdout: checkProcess } = await execFileAsync('/bin/ps', ['-p', processId.toString(), '-o', 'pid=']);
      if (!checkProcess.trim()) {
        // Process doesn't exist anymore
        return {};
      }
    } catch (error) {
      // Process doesn't exist
      return {};
    }

    const script = `
      tell application "System Events"
        try
          set targetProcess to first process whose unix id is ${processId}
          
          -- Get basic window information
          try
            set frontWindow to front window of targetProcess
            set windowTitle to name of frontWindow
            set windowRole to role of frontWindow
            set windowEnabled to enabled of frontWindow
            
            -- Get window bounds
            try
              set windowPosition to position of frontWindow
              set windowSize to size of frontWindow
              set bounds to (item 1 of windowPosition) & "," & (item 2 of windowPosition) & "," & (item 1 of windowSize) & "," & (item 2 of windowSize)
            on error
              set bounds to ""
            end try
            
            return windowRole & "|" & windowTitle & "|" & windowEnabled & "|" & bounds
          on error
            return "unknown|||"
          end try
        on error
          return "unknown|||"
        end try
      end tell
    `;

    try {
      const { stdout } = await execFileAsync(this.osascriptPath, ['-e', script], {
        timeout: 2000 // 2 second timeout to prevent hanging
      });
      const result = stdout.trim();
      
      if (!result || result === 'unknown|||') {
        return {};
      }
      
      const [role, title, enabledStr, boundsStr] = result.split('|');
      
      let bounds: MacOSAccessibilityInfo['bounds'] | undefined;
      if (boundsStr && boundsStr.includes(',')) {
        const [x, y, width, height] = boundsStr.split(',').map(Number);
        if (!isNaN(x) && !isNaN(y) && !isNaN(width) && !isNaN(height)) {
          bounds = { x, y, width, height };
        }
      }

      return {
        role: role !== 'unknown' ? role : undefined,
        title: title || undefined,
        enabled: enabledStr === 'true',
        focused: true, // This is the frontmost window
        bounds
      };
    } catch (error) {
      // Don't log full error details for common cases like process not found
      if (error instanceof Error && (
        error.message.includes('SIGINT') || 
        error.message.includes('timeout') ||
        error.message.includes('Command failed')
      )) {
        // Process likely disappeared or doesn't have accessible windows
        return {};
      }
      console.warn(`Error getting accessibility info for PID ${processId}:`, error instanceof Error ? error.message : 'Unknown error');
      return {};
    }
  }

  private async getBundleId(processId: number): Promise<string | undefined> {
    try {
      const { stdout } = await execFileAsync('/bin/ps', ['-p', processId.toString(), '-o', 'comm=']);
      return stdout.trim();
    } catch (error) {
      console.warn(`Could not get bundle ID for PID ${processId}:`, error);
      return undefined;
    }
  }

  private extractStates(info: MacOSAccessibilityInfo): string[] {
    const states: string[] = [];
    
    if (info.enabled === true) states.push('enabled');
    if (info.enabled === false) states.push('disabled');
    if (info.focused) states.push('focused');
    
    return states;
  }
}

// Export for dynamic loading
module.exports = { MacOSFocusTracker };
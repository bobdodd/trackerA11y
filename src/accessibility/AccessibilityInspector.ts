/**
 * Accessibility Inspector for macOS
 * Captures detailed UI element information at interaction points
 */

import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

export interface UIElement {
  role: string;
  title?: string;
  label?: string;
  value?: string;
  description?: string;
  identifier?: string;
  enabled: boolean;
  focused: boolean;
  selected?: boolean;
  bounds: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  children?: UIElement[];
  parent?: Partial<UIElement>;
}

export interface AccessibilityHitTest {
  element: UIElement;
  hierarchy: UIElement[]; // From root to target element
  context: {
    processId: number;
    applicationName: string;
    windowTitle?: string;
  };
  coordinates: {
    x: number;
    y: number;
  };
}

export class AccessibilityInspector {
  private osascriptPath = '/usr/bin/osascript';

  /**
   * Find the UI element at specific screen coordinates
   */
  async hitTest(x: number, y: number, processId?: number): Promise<AccessibilityHitTest | null> {
    try {
      // Use native accessibility APIs first - they know exactly what's at any coordinate
      console.log(`🎯 AccessibilityInspector: Testing coordinates (${x}, ${y}) for dock detection`);
      const element = await this.getElementAtPoint(x, y, processId);
      if (element) {
        console.log(`✅ AccessibilityInspector: Native accessibility found element with role: ${element.role}, title: ${element.title}`);
        
        // Get the hierarchy from root to this element
        const hierarchy = await this.getElementHierarchy(element, processId);

        // Get application context
        const context = await this.getApplicationContext(processId);

        return {
          element,
          hierarchy,
          context,
          coordinates: { x, y }
        };
      }

      // Browser inspection removed - only dock detection enabled

      return null;
    } catch (error) {
      console.warn(`Accessibility hit test failed at (${x}, ${y}):`, error instanceof Error ? error.message : 'Unknown error');
      return null;
    }
  }

  /**
   * Get detailed information about a UI element at coordinates
   */
  private async getElementAtPoint(x: number, y: number, processId?: number): Promise<UIElement | null> {
    const script = `
      tell application "System Events"
        try
          -- Try to find dock element specifically for dock coordinates
          set dockProcess to process "Dock"
          set targetElement to missing value
          
          -- Check dock process first for dock area clicks (bottom area of screen)
          if ${Math.round(y)} > 900 then
            try
              -- Get the dock list (main dock container)
              set dockList to first UI element of dockProcess
              
              -- Test specific dock icons that might match the coordinates
              -- Safari dock icon
              try
                set safariIcon to (first UI element of dockList whose title is "Safari")
                set elemPos to position of safariIcon
                set elemSize to size of safariIcon
                set elemX to item 1 of elemPos
                set elemY to item 2 of elemPos
                set elemW to item 1 of elemSize
                set elemH to item 2 of elemSize
                set clickableY to elemY - 45
                
                if ${Math.round(x)} >= elemX and ${Math.round(x)} <= (elemX + elemW) and ${Math.round(y)} >= clickableY and ${Math.round(y)} <= (elemY + elemH) then
                  set targetElement to safariIcon
                end if
              end try
              
              -- Terminal dock icon  
              if targetElement is missing value then
                try
                  set terminalIcon to (first UI element of dockList whose title is "Terminal")
                  set elemPos to position of terminalIcon
                  set elemSize to size of terminalIcon
                  set elemX to item 1 of elemPos
                  set elemY to item 2 of elemPos
                  set elemW to item 1 of elemSize
                  set elemH to item 2 of elemSize
                  set clickableY to elemY - 45
                  
                  if ${Math.round(x)} >= elemX and ${Math.round(x)} <= (elemX + elemW) and ${Math.round(y)} >= clickableY and ${Math.round(y)} <= (elemY + elemH) then
                    set targetElement to terminalIcon
                  end if
                end try
              end if
              
            end try
          end if
          
          -- If not found in dock area, return empty (not error) to allow browser fallback
          if targetElement is missing value then
            return ""
          end if
          
          -- Extract basic dock icon information and return immediately
          set elementTitle to title of targetElement
          set elementPosition to position of targetElement
          set elementSize to size of targetElement
          set posX to item 1 of elementPosition
          set posY to item 2 of elementPosition  
          set sizeW to item 1 of elementSize
          set sizeH to item 2 of elementSize
          
          return "button|" & elementTitle & "|||Dock icon|true|false|false|" & (posX as string) & "," & (posY as string) & "," & (sizeW as string) & "," & (sizeH as string)
          
        on error errMsg
          return "error|" & errMsg & "||||||||"
        end try
      end tell
    `;

    try {
      const { stdout } = await execFileAsync(this.osascriptPath, ['-e', script], {
        timeout: 3000
      });
      
      const result = stdout.trim();
      if (!result || result.startsWith('error|')) {
        return null;
      }

      const [role, title, value, description, label, identifier, enabledStr, focusedStr, selectedStr, boundsStr] = result.split('|');
      
      let bounds = { x, y, width: 0, height: 0 };
      if (boundsStr && boundsStr.includes(',')) {
        const [bx, by, bw, bh] = boundsStr.split(',').map(Number);
        if (!isNaN(bx) && !isNaN(by) && !isNaN(bw) && !isNaN(bh)) {
          bounds = { x: bx, y: by, width: bw, height: bh };
        }
      }

      return {
        role: role || 'unknown',
        title: title || undefined,
        value: value || undefined,
        description: description || undefined,
        label: label || undefined,
        identifier: identifier || undefined,
        enabled: enabledStr === 'true',
        focused: focusedStr === 'true',
        selected: selectedStr === 'true',
        bounds
      };
    } catch (error) {
      if (error instanceof Error && (
        error.message.includes('SIGINT') || 
        error.message.includes('timeout') ||
        error.message.includes('Command failed')
      )) {
        return null;
      }
      throw error;
    }
  }

  /**
   * Get the hierarchy from root element to target
   */
  private async getElementHierarchy(element: UIElement, processId?: number): Promise<UIElement[]> {
    // For now, return just the element itself
    // This could be expanded to walk up the parent chain
    return [element];
  }

  /**
   * Get application context information
   */
  private async getApplicationContext(processId?: number): Promise<AccessibilityHitTest['context']> {
    if (!processId) {
      return {
        processId: -1,
        applicationName: 'Unknown'
      };
    }

    try {
      const script = `
        tell application "System Events"
          try
            set targetProcess to first process whose unix id is ${processId}
            set appName to name of targetProcess
            
            try
              set frontWindow to front window of targetProcess
              set windowTitle to name of frontWindow
            on error
              set windowTitle to ""
            end try
            
            return appName & "|" & windowTitle
          on error
            return "Unknown|"
          end try
        end tell
      `;

      const { stdout } = await execFileAsync(this.osascriptPath, ['-e', script], {
        timeout: 2000
      });
      
      const result = stdout.trim();
      const [applicationName, windowTitle] = result.split('|');

      return {
        processId,
        applicationName: applicationName || 'Unknown',
        windowTitle: windowTitle || undefined
      };
    } catch (error) {
      return {
        processId,
        applicationName: 'Unknown'
      };
    }
  }


  /**
   * Get comprehensive accessibility information for debugging
   */
  async inspectApplication(processId: number): Promise<{
    applicationInfo: any;
    windowTree: UIElement[];
  } | null> {
    try {
      const context = await this.getApplicationContext(processId);
      
      // This would ideally walk the entire accessibility tree
      // For now, return basic information
      return {
        applicationInfo: context,
        windowTree: []
      };
    } catch (error) {
      console.warn(`Failed to inspect application ${processId}:`, error instanceof Error ? error.message : 'Unknown error');
      return null;
    }
  }
}
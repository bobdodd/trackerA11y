/**
 * Accessibility Inspector for macOS
 * Captures detailed UI element information at interaction points
 */

import { execFile } from 'child_process';
import { promisify } from 'util';
import { BrowserAccessibilityInspector, BrowserHitTest } from './BrowserAccessibilityInspector';

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
  private browserInspector = new BrowserAccessibilityInspector();

  /**
   * Find the UI element at specific screen coordinates
   */
  async hitTest(x: number, y: number, processId?: number): Promise<AccessibilityHitTest | null> {
    try {
      console.debug(`🎯 AccessibilityInspector.hitTest starting for (${x}, ${y})`);
      // Use native accessibility APIs first - they know exactly what's at any coordinate
      const element = await this.getElementAtPoint(x, y, processId);
      console.debug(`🎯 AccessibilityInspector.getElementAtPoint returned: ${element ? 'element found' : 'null'}`);
      if (element) {
        console.debug(`🎯 Found native element: ${element.role} "${element.title}" desc:"${element.description}"`);
        // Only log dock icon detection for debugging
        if (element.description === 'Dock icon') {
          console.log(`🚢 DOCK ICON DETECTED: ${element.title} at (${element.bounds.x}, ${element.bounds.y})`);
        }
        
        // Get the hierarchy from root to this element
        const hierarchy = await this.getElementHierarchy(element, processId);

        // Get application context (for dock, use Dock process)
        const contextProcessId = element.description === 'Dock icon' ? undefined : processId;
        const context = await this.getApplicationContext(contextProcessId);

        return {
          element,
          hierarchy,
          context,
          coordinates: { x, y }
        };
      }

      // Only try browser DOM inspection if native accessibility found nothing
      console.debug(`🌐 AccessibilityInspector: Trying browser inspection for (${x}, ${y})`);
      const browserHitTest = await this.browserInspector.hitTest(x, y);
      console.debug(`🌐 AccessibilityInspector: Browser inspection returned: ${browserHitTest ? 'found' : 'null'}`);
      if (browserHitTest) {
        // Convert browser hit test to our format
        return this.convertBrowserHitTest(browserHitTest);
      }

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
    // First try a simple coordinate-based dock detection
    const script = `
      tell application "System Events"
        try
          -- Simplified dock detection - check if coordinates are in likely dock area
          set dockProcess to process "Dock"
          set targetElement to missing value
          
          -- Get dock UI elements directly  
          try
            set dockList to first UI element of dockProcess
            set dockItems to UI elements of dockList
            
            -- Check each dock item to see if coordinates match
            repeat with dockItem in dockItems
              try
                set itemPos to position of dockItem
                set itemSize to size of dockItem
                set itemX to item 1 of itemPos
                set itemY to item 2 of itemPos
                set itemW to item 1 of itemSize
                set itemH to item 2 of itemSize
                
                -- Generous clickable area around each dock item
                -- Allow clicks above the dock (common for dock interaction)
                set clickableX to itemX - 10
                set clickableY to itemY - 100  -- Large area above dock
                set clickableW to itemW + 20
                set clickableH to itemH + 120  -- Extended upward area
                
                -- Check if coordinates are within this item's area
                if ${Math.round(x)} >= clickableX and ${Math.round(x)} <= (clickableX + clickableW) and ${Math.round(y)} >= clickableY and ${Math.round(y)} <= (clickableY + clickableH) then
                  set targetElement to dockItem
                  exit repeat
                end if
                
              on error
                -- Skip problematic dock items
              end try
            end repeat
            
          on error dockError
            -- If we can't access dock items, still try to detect dock area by coordinates
            -- Bottom 200 pixels of screen are likely dock area when dock is visible
            tell application "System Events"
              tell process "Finder"
                set screenBounds to bounds of window 1 of desktop
                set screenHeight to item 4 of screenBounds
                
                -- If click is in bottom area and we have dock process, assume dock click
                if ${Math.round(y)} > (screenHeight - 200) then
                  return "button|Dock Icon|||Dock icon|true|false|false|${Math.round(x)},${Math.round(y)},60,60"
                end if
              end tell
            end tell
          end try
          
          -- If no dock item found, return empty for browser fallback
          if targetElement is missing value then
            return ""
          end if
          
          -- Extract dock icon information with fallbacks
          set elementTitle to "Dock Icon"
          try
            set elementTitle to title of targetElement
            if elementTitle is missing value or elementTitle is "" then
              try
                set elementTitle to name of targetElement
              end try
            end if
          on error
            set elementTitle to "Dock Icon"
          end try
          
          set elementPosition to {${Math.round(x)}, ${Math.round(y)}}
          set elementSize to {60, 60}
          try
            set elementPosition to position of targetElement
            set elementSize to size of targetElement
          on error
            -- Use click coordinates as fallback
          end try
          
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
      console.debug(`🔍 AppleScript result for (${x}, ${y}): "${result}"`);
      
      if (!result || result.startsWith('error|')) {
        if (result.startsWith('error|')) {
          console.debug(`❌ AppleScript error: ${result.substring(6)}`);
        }
        console.debug(`❌ No dock element found at (${x}, ${y})`);
        return null;
      }

      const [role, title, value, description, label, identifier, enabledStr, focusedStr, selectedStr, boundsStr] = result.split('|');
      
      let bounds = { x, y, width: 0, height: 0 };
      if (boundsStr && boundsStr.includes(',')) {
        const [bx, by, bw, bh] = boundsStr.split(',').map(Number);
        if (!isNaN(bx) && !isNaN(by) && !isNaN(bw) && !isNaN(bh)) {
          bounds = { x: bx, y: by, width: bw, height: bh };
          console.debug(`📏 Element bounds: (${bx}, ${by}) ${bw}×${bh}`);
        }
      }

      const element = {
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
      
      console.debug(`🎯 Parsed element: ${element.role} "${element.title}" (${element.description})`);
      return element;
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
   * Convert browser hit test to unified format
   */
  private convertBrowserHitTest(browserHitTest: BrowserHitTest): AccessibilityHitTest {
    const domElement = browserHitTest.element;
    
    // Map DOM element to UIElement format
    const element: UIElement = {
      role: this.mapDOMRoleToUIRole(domElement),
      title: domElement.title || domElement.ariaLabel || domElement.textContent,
      label: domElement.ariaLabel || domElement.alt || domElement.placeholder,
      value: domElement.value,
      description: domElement.ariaDescribedBy || domElement.title,
      identifier: domElement.id,
      enabled: !domElement.disabled,
      focused: false, // Would need to check document.activeElement
      selected: domElement.selected,
      bounds: domElement.bounds
    };

    return {
      element,
      hierarchy: [element], // Browser elements are top-level for now
      context: {
        processId: browserHitTest.browserInfo.processId,
        applicationName: browserHitTest.browserInfo.name,
        windowTitle: `${browserHitTest.title} - ${browserHitTest.url}`
      },
      coordinates: browserHitTest.coordinates
    };
  }

  /**
   * Map DOM element types to accessibility roles
   */
  private mapDOMRoleToUIRole(domElement: any): string {
    if (domElement.ariaRole) return domElement.ariaRole;
    if (domElement.role) return domElement.role;
    
    const tag = domElement.tagName?.toLowerCase();
    const type = domElement.type?.toLowerCase();
    
    switch (tag) {
      case 'button':
        return 'button';
      case 'input':
        switch (type) {
          case 'submit':
          case 'button':
            return 'button';
          case 'text':
          case 'email':
          case 'password':
          case 'search':
            return 'textfield';
          case 'checkbox':
            return 'checkbox';
          case 'radio':
            return 'radiobutton';
          default:
            return 'textfield';
        }
      case 'a':
        return 'link';
      case 'textarea':
        return 'textfield';
      case 'select':
        return 'combobox';
      case 'img':
        return 'image';
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return 'heading';
      case 'p':
      case 'span':
      case 'div':
        return 'text';
      default:
        return tag || 'unknown';
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
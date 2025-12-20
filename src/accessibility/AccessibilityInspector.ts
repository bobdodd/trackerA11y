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
      // Use native accessibility APIs first - they know exactly what's at any coordinate
      const element = await this.getElementAtPoint(x, y, processId);
      if (element) {
        
        // Get the hierarchy from root to this element
        const hierarchy = await this.getElementHierarchy(element, processId);

        // Get application context (for dock, use Dock process)
        const contextProcessId = element.description === 'Dock item' ? undefined : processId;
        const context = await this.getApplicationContext(contextProcessId);

        return {
          element,
          hierarchy,
          context,
          coordinates: { x, y }
        };
      }

      // Only try browser DOM inspection if native accessibility found nothing
      const browserHitTest = await this.browserInspector.hitTest(x, y);
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
    const screenHeight = await this.getScreenHeight();
    const dockThreshold = screenHeight - 120;
    
    if (y > dockThreshold) {
      const dockElement = await this.getDockItemAtPoint(x, y);
      if (dockElement) {
        return dockElement;
      }
    }
    
    const generalElement = await this.getGeneralElementAtPoint(x, y);
    if (generalElement) {
      return generalElement;
    }
    
    return null;
  }

  private async getGeneralElementAtPoint(x: number, y: number): Promise<UIElement | null> {
    const script = `
      tell application "System Events"
        try
          set frontApp to first process whose frontmost is true
          set appName to name of frontApp
          
          set focusedElem to missing value
          try
            set focusedElem to focused UI element of frontApp
          end try
          
          if focusedElem is not missing value then
            set elemRole to ""
            set elemTitle to ""
            set elemValue to ""
            set elemDesc to ""
            set elemLabel to ""
            
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
              set elemLabel to name of focusedElem
            end try
            
            return elemRole & "|" & elemTitle & "|" & elemValue & "|" & elemDesc & "|" & elemLabel & "|true|true|false|${Math.round(x)},${Math.round(y)},0,0"
          end if
          
          try
            set frontWin to front window of frontApp
            set winTitle to title of frontWin
            set winRole to role of frontWin
            return winRole & "|" & winTitle & "|||" & appName & "|true|false|false|${Math.round(x)},${Math.round(y)},0,0"
          end try
          
          return ""
        on error errMsg
          return ""
        end try
      end tell
    `;

    try {
      const { stdout } = await execFileAsync(this.osascriptPath, ['-e', script], {
        timeout: 1500
      });
      
      const result = stdout.trim();
      
      if (!result) {
        return null;
      }

      const [role, title, value, description, label, enabledStr, focusedStr, selectedStr, boundsStr] = result.split('|');
      
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
        enabled: enabledStr === 'true',
        focused: focusedStr === 'true',
        selected: selectedStr === 'true',
        bounds
      };
    } catch (error) {
      return null;
    }
  }

  private async getScreenHeight(): Promise<number> {
    try {
      const script = `
        tell application "Finder"
          set screenBounds to bounds of window of desktop
          return item 4 of screenBounds
        end tell
      `;
      const { stdout } = await execFileAsync(this.osascriptPath, ['-e', script], { timeout: 1000 });
      return parseInt(stdout.trim()) || 1080;
    } catch {
      return 1080;
    }
  }

  private async getDockItemAtPoint(x: number, y: number): Promise<UIElement | null> {
    const script = `
      tell application "System Events"
        tell process "Dock"
          set dockItems to UI elements of list 1
          set clickX to ${Math.round(x)}
          set bestMatch to ""
          set bestDistance to 9999
          
          repeat with dockItem in dockItems
            try
              set itemPos to position of dockItem
              set itemSize to size of dockItem
              set itemX to item 1 of itemPos
              set itemW to item 1 of itemSize
              
              -- Check if X coordinate is within this item's horizontal bounds
              if clickX >= itemX and clickX <= (itemX + itemW) then
                set itemName to ""
                set itemRole to ""
                set itemDesc to ""
                
                try
                  set itemName to name of dockItem
                on error
                  set itemName to ""
                end try
                
                try
                  set itemRole to role of dockItem
                on error
                  set itemRole to "button"
                end try
                
                try
                  set itemDesc to description of dockItem
                on error
                  set itemDesc to ""
                end try
                
                return itemRole & "|" & itemName & "||" & itemDesc & "|" & itemName & "|true|false|false|" & itemX & ",${Math.round(y)}," & itemW & ",72"
              end if
            end try
          end repeat
        end tell
      end tell
      return ""
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

      const element = {
        role: role || 'button',
        title: title || undefined,
        value: value || undefined,
        description: description || 'Dock item',
        label: label || title || undefined,
        identifier: identifier || undefined,
        enabled: enabledStr === 'true',
        focused: focusedStr === 'true',
        selected: selectedStr === 'true',
        bounds
      };
      
      return element;
    } catch (error) {
      if (error instanceof Error && (
        error.message.includes('SIGINT') || 
        error.message.includes('timeout') ||
        error.message.includes('Command failed')
      )) {
        return null;
      }
      return null;
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
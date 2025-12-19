/**
 * Browser Accessibility Inspector
 * Captures DOM element information at click coordinates for web browsers
 */

import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

export interface DOMElement {
  tagName: string;
  role?: string;
  id?: string;
  className?: string;
  title?: string;
  ariaLabel?: string;
  ariaDescribedBy?: string;
  ariaRole?: string;
  type?: string; // for input elements
  value?: string;
  textContent?: string;
  href?: string; // for links
  alt?: string; // for images
  placeholder?: string;
  disabled: boolean;
  readonly: boolean;
  checked?: boolean; // for checkboxes/radio
  selected?: boolean; // for options
  bounds: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
}

export interface BrowserHitTest {
  element: DOMElement;
  url: string;
  title: string;
  coordinates: {
    x: number;
    y: number;
  };
  browserInfo: {
    name: string;
    processId: number;
  };
}

export class BrowserAccessibilityInspector {
  /**
   * Test if coordinates are within a browser and get DOM element info
   */
  async hitTest(x: number, y: number, browserName?: string): Promise<BrowserHitTest | null> {
    // Skip browser inspection for dock area coordinates (bottom 150px of screen)
    if (y > 950) {
      return null;
    }
    
    // First, detect which browser window contains these coordinates
    const activeBrowser = await this.detectActiveBrowser(x, y);
    
    if (activeBrowser) {
      try {
        const result = await this.hitTestBrowser(x, y, activeBrowser);
        if (result) {
          return result;
        }
      } catch (error) {
        // Continue to fallback
      }
    }
    
    // Fallback: try browsers in order of preference
    const browsersToTry = browserName ? [browserName] : ['Safari', 'Chrome', 'Firefox', 'Edge'];
    
    for (const browser of browsersToTry) {
      if (browser === activeBrowser) continue; // Already tried above
      
      try {
        const result = await this.hitTestBrowser(x, y, browser);
        if (result) {
          return result;
        }
      } catch (error) {
        // Continue trying other browsers
      }
    }
    
    return null;
  }

  /**
   * Hit test specific browser
   */
  private async hitTestBrowser(x: number, y: number, browserName: string): Promise<BrowserHitTest | null> {
    // Clean browser name and normalize
    const cleanBrowserName = browserName.toLowerCase().trim();
    
    if (cleanBrowserName.includes('safari')) {
      return this.hitTestSafari(x, y);
    } else if (cleanBrowserName.includes('chrome')) {
      return this.hitTestChrome(x, y);
    } else if (cleanBrowserName.includes('firefox')) {
      return null;
    } else if (cleanBrowserName.includes('edge')) {
      return null;
    } else {
      return null;
    }
  }

  /**
   * Safari-specific DOM element inspection
   */
  private async hitTestSafari(x: number, y: number): Promise<BrowserHitTest | null> {
    console.debug(`BrowserAccessibilityInspector: Starting Safari DOM inspection at (${x}, ${y})`);
    const script = `
      tell application "Safari"
        try
          if (count of documents) = 0 then
            return "ERROR:No documents open"
          end if
          
          set frontDoc to front document
          set pageURL to URL of frontDoc
          set pageTitle to name of frontDoc
          
          -- Execute JavaScript with simple coordinate mapping
          set jsCode to "(function(){ try{ var screenX=${x}; var screenY=${y}; var windowX=window.screenX||window.screenLeft||0; var windowY=window.screenY||window.screenTop||0; var innerW=window.innerWidth; var innerH=window.innerHeight; var scrollX=window.scrollX||window.pageXOffset||0; var scrollY=window.scrollY||window.pageYOffset||0; var normalChromeH=80; var contentStartX=windowX; var contentStartY=windowY+normalChromeH; var pageX=screenX-contentStartX; var pageY=screenY-contentStartY; var debugInfo='Screen:('+screenX+','+screenY+') Window:('+windowX+','+windowY+') Inner:('+innerW+','+innerH+') ContentStart:('+contentStartX+','+contentStartY+') Page:('+pageX+','+pageY+') Scroll:('+scrollX+','+scrollY+')'; if(pageX<0||pageY<0||pageX>=innerW||pageY>=innerH) return JSON.stringify({error:'Outside viewport',debug:debugInfo}); var el=document.elementFromPoint(pageX,pageY); if(!el) return JSON.stringify({error:'No element',debug:debugInfo}); return JSON.stringify({tagName:el.tagName,textContent:el.textContent?el.textContent.trim().substring(0,50):'',href:el.href||'',id:el.id||'',className:el.className||'',ariaLabel:el.getAttribute('aria-label')||'',role:el.getAttribute('role')||'',debug:debugInfo}); }catch(e){ return JSON.stringify({error:e.message,debug:'Exception occurred'}); } })();"
          
          set elementInfo to do JavaScript jsCode in frontDoc
          
          return pageURL & "||DELIMITER||" & pageTitle & "||DELIMITER||" & elementInfo
          
        on error errMsg
          return "ERROR:" & errMsg
        end try
      end tell
    `;

    try {
      const { stdout } = await execFileAsync('/usr/bin/osascript', ['-e', script], {
        timeout: 5000
      });
      
      const result = stdout.trim();
      
      if (result.startsWith('ERROR:')) {
        return null;
      }
      
      if (!result) {
        return null;
      }

      const [url, title, elementInfoStr] = result.split('||DELIMITER||');
      
      if (!elementInfoStr) {
        return null;
      }
      
      if (elementInfoStr.startsWith('ERROR:')) {
        return null;
      }

      try {
        const elementInfo = JSON.parse(elementInfoStr);
        
        // Show debug coordinate info only if needed
        if (elementInfo.debug && process.env.DEBUG_COORDS) {
          console.log(`🔍 COORDINATE DEBUG: ${elementInfo.debug}`);
        }
        
        // Check for errors in the JavaScript execution
        if (elementInfo.error) {
          return null;
        }
        return {
          element: {
            tagName: elementInfo.tagName || 'unknown',
            role: elementInfo.role || undefined,
            id: elementInfo.id || undefined,
            className: elementInfo.className || undefined,
            title: elementInfo.title || undefined,
            ariaLabel: elementInfo.ariaLabel || undefined,
            ariaDescribedBy: elementInfo.ariaDescribedBy || undefined,
            ariaRole: elementInfo.ariaRole || undefined,
            type: elementInfo.type || undefined,
            value: elementInfo.value || undefined,
            textContent: elementInfo.textContent || undefined,
            href: elementInfo.href || undefined,
            alt: elementInfo.alt || undefined,
            placeholder: elementInfo.placeholder || undefined,
            disabled: elementInfo.disabled || false,
            readonly: elementInfo.readonly || false,
            checked: elementInfo.checked,
            selected: elementInfo.selected,
            bounds: elementInfo.bounds || { x, y, width: 0, height: 0 }
          },
          url: url || 'unknown',
          title: title || 'Unknown Page',
          coordinates: { x, y },
          browserInfo: {
            name: 'Safari',
            processId: await this.getSafaraPID() || -1
          }
        };
      } catch (parseError) {
        return null;
      }
      
    } catch (error) {
      console.debug(`BrowserAccessibilityInspector: Safari AppleScript error:`, error instanceof Error ? error.message : String(error));
      
      if (error instanceof Error && (
        error.message.includes('SIGINT') || 
        error.message.includes('timeout') ||
        error.message.includes('Command failed')
      )) {
        console.debug(`BrowserAccessibilityInspector: Safari AppleScript timeout or interrupt`);
        return null;
      }
      
      console.debug(`BrowserAccessibilityInspector: Safari AppleScript unexpected error`);
      return null;
    }
  }

  /**
   * Chrome-specific DOM element inspection
   */
  private async hitTestChrome(x: number, y: number): Promise<BrowserHitTest | null> {
    // Chrome doesn't support AppleScript as well as Safari
    // This would require Chrome DevTools Protocol or browser extension
    return null;
  }

  /**
   * Get Safari process ID
   */
  private async getSafaraPID(): Promise<number | null> {
    try {
      const { stdout } = await execFileAsync('/bin/ps', ['-x', '-o', 'pid,comm'], {
        timeout: 2000
      });
      
      const lines = stdout.split('\n');
      for (const line of lines) {
        if (line.includes('Safari') && !line.includes('SafariBookmarksSyncAgent')) {
          const pidMatch = line.trim().match(/^(\d+)/);
          if (pidMatch) {
            return parseInt(pidMatch[1], 10);
          }
        }
      }
      return null;
    } catch (error) {
      return null;
    }
  }

  /**
   * Detect which browser window contains the given coordinates
   */
  private async detectActiveBrowser(x: number, y: number): Promise<string | null> {
    try {
      const script = `
        tell application "System Events"
          try
            set browserApps to {"Safari", "Google Chrome", "Firefox", "Microsoft Edge"}
            repeat with i from 1 to count of browserApps
              set browserName to item i of browserApps
              try
                if exists process browserName then
                  set browserProcess to process browserName
                  repeat with browserWindow in windows of browserProcess
                    try
                      set windowPosition to position of browserWindow
                      set windowSize to size of browserWindow
                      set winX to item 1 of windowPosition
                      set winY to item 2 of windowPosition
                      set winW to item 1 of windowSize
                      set winH to item 2 of windowSize
                      
                      -- Be much more strict about browser content area
                      -- Only consider clicks well within the browser content area
                      -- Exclude title bar (30px), toolbar area (90px), and any edge areas (10px margins)
                      set contentX to winX + 10
                      set contentY to winY + 120  
                      set contentWidth to winW - 20
                      set contentHeight to winH - 150
                      
                      -- Only consider it a browser click if it's well within the content area
                      if ${x} >= contentX and ${x} <= (contentX + contentWidth) and ${y} >= contentY and ${y} <= (contentY + contentHeight) then
                        return browserName as string
                      end if
                    end try
                  end repeat
                end if
              end try
            end repeat
            return "none"
          on error
            return "none"
          end try
        end tell
      `;

      const { stdout } = await execFileAsync('/usr/bin/osascript', ['-e', script], {
        timeout: 3000
      });
      
      const result = stdout.trim();
      
      // Handle malformed AppleScript results
      if (!result || result === 'none' || result.includes('item') || result.includes('{') || result.includes('}')) {
        return null; // No browser at these coordinates
      }
      
      return result;
      
    } catch (error) {
      return null;
    }
  }

  /**
   * Check if coordinates are in macOS system UI areas (dock, menu bar, etc.)
   */
  private async isSystemUIArea(x: number, y: number): Promise<boolean> {
    try {
      console.debug(`isSystemUIArea: Checking coordinates (${x}, ${y})`);
      
      const script = `
        tell application "System Events"
          try
            -- Menu bar is typically at top (y < 30)
            if ${y} < 30 then
              return "menubar:${y}"
            end if
            
            -- Get current dock state and position
            set dockProcess to process "Dock"
            
            -- Check if dock is currently visible by looking at all its windows
            set dockVisible to false
            set activeDockBounds to {}
            
            repeat with dockWindow in (windows of dockProcess)
              try
                set windowPos to position of dockWindow
                set windowSize to size of dockWindow
                
                -- A window with meaningful size indicates visible dock
                if (item 1 of windowSize) > 50 and (item 2 of windowSize) > 20 then
                  set dockVisible to true
                  set activeDockBounds to {item 1 of windowPos, item 2 of windowPos, (item 1 of windowPos) + (item 1 of windowSize), (item 2 of windowPos) + (item 2 of windowSize)}
                  exit repeat
                end if
              end try
            end repeat
            
            if dockVisible then
              set dockLeft to item 1 of activeDockBounds
              set dockTop to item 2 of activeDockBounds  
              set dockRight to item 3 of activeDockBounds
              set dockBottom to item 4 of activeDockBounds
              
              -- Check if click is within the visible dock bounds
              if ${x} >= dockLeft and ${x} <= dockRight and ${y} >= dockTop and ${y} <= dockBottom then
                return "dock:visible:" & dockLeft & "," & dockTop & "," & dockRight & "," & dockBottom
              end if
            end if
            
            return "none"
            
          on error errMsg
            return "error:" & errMsg
          end try
        end tell
      `;

      const { stdout } = await execFileAsync('/usr/bin/osascript', ['-e', script], {
        timeout: 2000
      });
      
      const result = stdout.trim();
      console.debug(`isSystemUIArea: AppleScript result: "${result}"`);
      
      const isSystemUI = result.startsWith('menubar:') || result.startsWith('dock:');
      console.debug(`isSystemUIArea: Final result: ${isSystemUI}`);
      return isSystemUI;
      
    } catch (error) {
      console.debug('Failed to detect system UI areas:', error);
      // If we can't detect system UI, assume it's not system UI to avoid blocking legitimate clicks
      return false;
    }
  }

  /**
   * Check if coordinates might be within a browser window
   */
  async isBrowserRegion(x: number, y: number): Promise<boolean> {
    const activeBrowser = await this.detectActiveBrowser(x, y);
    return activeBrowser !== null;
  }
}
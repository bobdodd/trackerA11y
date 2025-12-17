/**
 * DOM State Capture for Web Applications
 * Captures complete DOM state including structure, styles, and active elements
 */

import { EventEmitter } from 'events';
import { DOMConfig, DOMState } from './types';
import { spawn } from 'child_process';
import * as fs from 'fs/promises';
import * as path from 'path';

export class DOMCapture extends EventEmitter {
  private config: DOMConfig;
  private outputDir: string;
  private domOutputDir: string;
  private isInitialized = false;
  private captureCount = 0;
  private lastCaptureTime = 0;

  constructor(outputDir: string, config: DOMConfig) {
    super();
    this.config = config;
    this.outputDir = outputDir;
    this.domOutputDir = path.join(outputDir, 'dom_states');
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    if (this.config.enabled) {
      // Create DOM output directory
      await fs.mkdir(this.domOutputDir, { recursive: true });
      console.log('✅ DOM capture initialized');
    }

    this.isInitialized = true;
  }

  /**
   * Capture current DOM state if in a supported browser
   */
  async captureDOMState(): Promise<DOMState | undefined> {
    if (!this.config.enabled) return undefined;

    const now = Date.now();
    if (now - this.lastCaptureTime < this.config.minInterval) {
      return undefined; // Too soon since last capture
    }

    try {
      // Try to detect active browser and capture DOM
      const domState = await this.captureActiveBrowserDOM();
      
      if (domState) {
        this.lastCaptureTime = now;
        this.captureCount++;
        
        console.log(`📋 DOM captured: ${domState.title} (${domState.elementCount} elements)`);
        this.emit('domCaptured', domState);
      }

      return domState;

    } catch (error) {
      console.error('Failed to capture DOM state:', error);
      this.emit('error', error);
      return undefined;
    }
  }

  private async captureActiveBrowserDOM(): Promise<DOMState | undefined> {
    // Try different browser automation approaches
    const browsers = ['Chrome', 'Safari', 'Firefox'];
    
    for (const browser of browsers) {
      try {
        const domState = await this.captureBrowserDOM(browser);
        if (domState) return domState;
      } catch (error) {
        // Try next browser
        continue;
      }
    }

    return undefined;
  }

  private async captureBrowserDOM(browser: string): Promise<DOMState | undefined> {
    switch (browser.toLowerCase()) {
      case 'chrome':
        return await this.captureChromeDOM();
      case 'safari':
        return await this.captureSafariDOM();
      case 'firefox':
        return await this.captureFirefoxDOM();
      default:
        return undefined;
    }
  }

  private async captureChromeDOM(): Promise<DOMState | undefined> {
    try {
      // Use Chrome DevTools Protocol to capture DOM
      const script = this.createChromeScript();
      const result = await this.executeAppleScript(script);
      
      if (result) {
        return await this.processChromeResult(result);
      }
    } catch (error) {
      // Chrome not available or accessible
    }

    return undefined;
  }

  private async captureSafariDOM(): Promise<DOMState | undefined> {
    try {
      // Use Safari's AppleScript automation
      const script = `
        tell application "Safari"
          if (count of windows) > 0 then
            tell front window
              tell current tab
                set pageURL to URL
                set pageTitle to name
                set pageHTML to do JavaScript "document.documentElement.outerHTML"
                set elementCount to do JavaScript "document.querySelectorAll('*').length"
                set viewportWidth to do JavaScript "window.innerWidth"
                set viewportHeight to do JavaScript "window.innerHeight"
                set scrollX to do JavaScript "window.pageXOffset"
                set scrollY to do JavaScript "window.pageYOffset"
                
                set activeElement to ""
                try
                  set activeElement to do JavaScript "JSON.stringify({
                    tagName: document.activeElement.tagName,
                    id: document.activeElement.id,
                    className: document.activeElement.className,
                    textContent: document.activeElement.textContent ? document.activeElement.textContent.substring(0, 100) : ''
                  })"
                end try
                
                return pageURL & "|||" & pageTitle & "|||" & elementCount & "|||" & viewportWidth & "|||" & viewportHeight & "|||" & scrollX & "|||" & scrollY & "|||" & activeElement & "|||" & pageHTML
              end tell
            end tell
          end if
        end tell
      `;

      const result = await this.executeAppleScript(script);
      if (result) {
        return await this.processSafariResult(result);
      }
    } catch (error) {
      // Safari not available or accessible
    }

    return undefined;
  }

  private async captureFirefoxDOM(): Promise<DOMState | undefined> {
    // Firefox automation would require additional setup
    // For now, return undefined - can be extended later
    return undefined;
  }

  private createChromeScript(): string {
    return `
      tell application "Google Chrome"
        if (count of windows) > 0 then
          tell front window
            tell active tab
              set pageURL to URL
              set pageTitle to title
              execute javascript "JSON.stringify({
                html: document.documentElement.outerHTML,
                elementCount: document.querySelectorAll('*').length,
                viewport: { width: window.innerWidth, height: window.innerHeight },
                scroll: { x: window.pageXOffset, y: window.pageYOffset },
                activeElement: document.activeElement ? {
                  tagName: document.activeElement.tagName,
                  id: document.activeElement.id,
                  className: document.activeElement.className,
                  textContent: document.activeElement.textContent ? document.activeElement.textContent.substring(0, 100) : ''
                } : null
              })"
            end tell
          end tell
        end if
      end tell
    `;
  }

  private async executeAppleScript(script: string): Promise<string | undefined> {
    return new Promise((resolve) => {
      const process = spawn('osascript', ['-e', script]);
      let output = '';
      let hasOutput = false;

      process.stdout.on('data', (data) => {
        output += data.toString();
        hasOutput = true;
      });

      process.on('close', (code) => {
        if (code === 0 && hasOutput && output.trim()) {
          resolve(output.trim());
        } else {
          resolve(undefined);
        }
      });

      // Timeout after 5 seconds
      setTimeout(() => {
        process.kill();
        resolve(undefined);
      }, 5000);
    });
  }

  private async processSafariResult(result: string): Promise<DOMState | undefined> {
    try {
      const parts = result.split('|||');
      if (parts.length < 8) return undefined;

      const [url, title, elementCount, viewportWidth, viewportHeight, scrollX, scrollY, activeElementJson, html] = parts;
      
      let activeElement;
      try {
        activeElement = JSON.parse(activeElementJson);
      } catch {
        activeElement = undefined;
      }

      const timestamp = Date.now() * 1000; // microseconds
      const filename = `dom_${this.captureCount}_${timestamp}.html`;
      const domPath = path.join(this.domOutputDir, filename);

      // Save HTML to file
      await fs.writeFile(domPath, html);

      // Save metadata
      const metadataPath = path.join(this.domOutputDir, `dom_${this.captureCount}_${timestamp}.json`);
      const metadata = {
        url,
        title,
        timestamp,
        elementCount: parseInt(elementCount),
        viewport: { width: parseInt(viewportWidth), height: parseInt(viewportHeight) },
        scrollPosition: { x: parseInt(scrollX), y: parseInt(scrollY) },
        activeElement
      };
      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));

      return {
        url,
        title,
        timestamp,
        filename,
        path: domPath,
        elementCount: parseInt(elementCount),
        viewport: { width: parseInt(viewportWidth), height: parseInt(viewportHeight) },
        scrollPosition: { x: parseInt(scrollX), y: parseInt(scrollY) },
        activeElement
      };

    } catch (error) {
      console.error('Failed to process Safari DOM result:', error);
      return undefined;
    }
  }

  private async processChromeResult(result: string): Promise<DOMState | undefined> {
    try {
      const data = JSON.parse(result);
      const timestamp = Date.now() * 1000;
      const filename = `dom_${this.captureCount}_${timestamp}.html`;
      const domPath = path.join(this.domOutputDir, filename);

      // Save HTML to file
      await fs.writeFile(domPath, data.html);

      // Save metadata
      const metadataPath = path.join(this.domOutputDir, `dom_${this.captureCount}_${timestamp}.json`);
      const metadata = {
        timestamp,
        elementCount: data.elementCount,
        viewport: data.viewport,
        scrollPosition: data.scroll,
        activeElement: data.activeElement
      };
      await fs.writeFile(metadataPath, JSON.stringify(metadata, null, 2));

      return {
        url: '', // Chrome script would need to return URL
        title: '', // Chrome script would need to return title  
        timestamp,
        filename,
        path: domPath,
        elementCount: data.elementCount,
        viewport: data.viewport,
        scrollPosition: data.scroll,
        activeElement: data.activeElement
      };

    } catch (error) {
      console.error('Failed to process Chrome DOM result:', error);
      return undefined;
    }
  }

  /**
   * Capture DOM state manually (for testing)
   */
  async captureManual(url: string, title: string): Promise<DOMState | undefined> {
    if (!this.config.enabled) return undefined;

    const timestamp = Date.now() * 1000;
    const filename = `dom_manual_${this.captureCount}_${timestamp}.html`;
    const domPath = path.join(this.domOutputDir, filename);

    // Create minimal DOM state for testing
    const html = `<!DOCTYPE html><html><head><title>${title}</title></head><body><p>Manual DOM capture test</p></body></html>`;
    await fs.writeFile(domPath, html);

    const domState: DOMState = {
      url,
      title,
      timestamp,
      filename,
      path: domPath,
      elementCount: 5,
      viewport: { width: 1920, height: 1080 },
      scrollPosition: { x: 0, y: 0 }
    };

    this.captureCount++;
    console.log(`📋 Manual DOM captured: ${title}`);
    this.emit('domCaptured', domState);

    return domState;
  }

  /**
   * Get DOM capture statistics
   */
  getStatistics() {
    return {
      enabled: this.config.enabled,
      captureCount: this.captureCount,
      outputDirectory: this.domOutputDir,
      lastCaptureTime: this.lastCaptureTime
    };
  }

  async shutdown(): Promise<void> {
    if (this.isInitialized) {
      console.log(`📊 DOM capture complete: ${this.captureCount} states captured`);
    }
    this.isInitialized = false;
  }
}
/**
 * Screenshot Capture System
 * Captures screenshots at precise moments when events occur
 */

import { EventEmitter } from 'events';
import { ScreenshotConfig, ScreenshotInfo } from './types';
import { spawn } from 'child_process';
import * as fs from 'fs/promises';
import * as path from 'path';

export class ScreenshotCapture extends EventEmitter {
  private config: ScreenshotConfig;
  private outputDir: string;
  private screenshotOutputDir: string;
  private isInitialized = false;
  private screenshotCount = 0;

  constructor(outputDir: string, config: ScreenshotConfig) {
    super();
    this.config = config;
    this.outputDir = outputDir;
    this.screenshotOutputDir = path.join(outputDir, 'screenshots');
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    if (this.config.enabled) {
      // Create screenshots directory
      await fs.mkdir(this.screenshotOutputDir, { recursive: true });
      
      // Test screenshot capability
      await this.testScreenshotCapability();
      
      console.log('✅ Screenshot capture initialized');
    }

    this.isInitialized = true;
  }

  /**
   * Capture a screenshot with the given trigger reason
   */
  async captureScreenshot(trigger: string): Promise<ScreenshotInfo | undefined> {
    if (!this.config.enabled) return undefined;

    try {
      const timestamp = Date.now() * 1000; // microseconds
      const filename = `screenshot_${this.screenshotCount}_${timestamp}_${trigger}.${this.config.format}`;
      const screenshotPath = path.join(this.screenshotOutputDir, filename);

      let success = false;
      let dimensions = { width: 0, height: 0 };
      let fileSize = 0;

      if (this.config.captureFullScreen) {
        success = await this.captureFullScreen(screenshotPath);
      } else if (this.config.captureActiveWindow) {
        success = await this.captureActiveWindow(screenshotPath);
      } else {
        success = await this.captureFullScreen(screenshotPath);
      }

      if (success) {
        // Get file stats
        const stats = await fs.stat(screenshotPath);
        fileSize = stats.size;

        // Get image dimensions (approximate for now)
        dimensions = await this.getImageDimensions(screenshotPath);

        this.screenshotCount++;

        const screenshotInfo: ScreenshotInfo = {
          filename,
          path: screenshotPath,
          timestamp,
          dimensions,
          format: this.config.format,
          size: fileSize,
          trigger
        };

        console.log(`📸 Screenshot captured: ${filename} (${trigger})`);
        this.emit('screenshotCaptured', screenshotInfo);

        return screenshotInfo;
      }

    } catch (error) {
      console.error('Failed to capture screenshot:', error);
      this.emit('error', error);
    }

    return undefined;
  }

  private async captureFullScreen(outputPath: string): Promise<boolean> {
    return new Promise((resolve) => {
      // Use macOS screencapture command
      const args = [
        '-x', // No sound
        '-t', this.config.format,
        '-q', this.getQualityFlag(),
        outputPath
      ];

      const process = spawn('screencapture', args);

      process.on('close', (code) => {
        resolve(code === 0);
      });

      process.on('error', (error) => {
        console.error('Screenshot process error:', error);
        resolve(false);
      });

      // Timeout after 10 seconds
      setTimeout(() => {
        process.kill();
        resolve(false);
      }, 10000);
    });
  }

  private async captureActiveWindow(outputPath: string): Promise<boolean> {
    return new Promise((resolve) => {
      // Capture only the active window
      const args = [
        '-x', // No sound
        '-w', // Capture window
        '-t', this.config.format,
        '-q', this.getQualityFlag(),
        outputPath
      ];

      const process = spawn('screencapture', args);

      process.on('close', (code) => {
        resolve(code === 0);
      });

      process.on('error', (error) => {
        console.error('Window screenshot process error:', error);
        resolve(false);
      });

      setTimeout(() => {
        process.kill();
        resolve(false);
      }, 10000);
    });
  }

  private getQualityFlag(): string {
    // screencapture quality options (0-100 for jpg, not used for png)
    switch (this.config.quality) {
      case 'low': return '25';
      case 'medium': return '50'; 
      case 'high': return '85';
      case 'lossless': return '100';
      default: return '75';
    }
  }

  private async getImageDimensions(imagePath: string): Promise<{ width: number; height: number }> {
    try {
      // Use sips command to get image dimensions on macOS
      return new Promise((resolve) => {
        const process = spawn('sips', ['-g', 'pixelWidth', '-g', 'pixelHeight', imagePath]);
        let output = '';

        process.stdout.on('data', (data) => {
          output += data.toString();
        });

        process.on('close', (code) => {
          if (code === 0) {
            const lines = output.split('\n');
            let width = 0;
            let height = 0;

            for (const line of lines) {
              if (line.includes('pixelWidth:')) {
                width = parseInt(line.split(':')[1]?.trim() || '0');
              }
              if (line.includes('pixelHeight:')) {
                height = parseInt(line.split(':')[1]?.trim() || '0');
              }
            }

            resolve({ width, height });
          } else {
            resolve({ width: 1920, height: 1080 }); // Default fallback
          }
        });

        setTimeout(() => {
          process.kill();
          resolve({ width: 1920, height: 1080 });
        }, 5000);
      });

    } catch (error) {
      return { width: 1920, height: 1080 }; // Fallback
    }
  }

  private async testScreenshotCapability(): Promise<void> {
    const testPath = path.join(this.screenshotOutputDir, 'test_screenshot.png');
    
    try {
      console.log('🔍 Testing screenshot permissions...');
      const success = await this.captureFullScreen(testPath);
      
      if (success) {
        // Check if file was actually created and has content
        try {
          const stats = await fs.stat(testPath);
          if (stats.size > 1000) { // At least 1KB for a valid screenshot
            await fs.unlink(testPath);
            console.log('✅ Screenshot capability verified');
            return;
          }
        } catch {
          // File not created or empty
        }
      }
      
      // Screenshot failed
      console.log('❌ Screenshot capability test failed');
      console.log('📋 To fix this:');
      console.log('   1. Open System Preferences → Security & Privacy → Privacy');
      console.log('   2. Click "Screen Recording" on the left');
      console.log('   3. Check the box next to "Terminal" (or your IDE)'); 
      console.log('   4. Restart this application');
      console.log('   ℹ️  Recording will continue without screenshots');
      
    } catch (error) {
      console.warn('⚠️  Could not test screenshot capability - will continue without screenshots');
    }
  }

  /**
   * Capture screenshot with custom parameters
   */
  async captureCustom(options: {
    trigger: string;
    region?: { x: number; y: number; width: number; height: number };
    window?: boolean;
  }): Promise<ScreenshotInfo | undefined> {
    if (!this.config.enabled) return undefined;

    const timestamp = Date.now() * 1000;
    const filename = `screenshot_custom_${this.screenshotCount}_${timestamp}_${options.trigger}.${this.config.format}`;
    const screenshotPath = path.join(this.screenshotOutputDir, filename);

    let success = false;

    if (options.region) {
      success = await this.captureRegion(screenshotPath, options.region);
    } else if (options.window) {
      success = await this.captureActiveWindow(screenshotPath);
    } else {
      success = await this.captureFullScreen(screenshotPath);
    }

    if (success) {
      const stats = await fs.stat(screenshotPath);
      const dimensions = await this.getImageDimensions(screenshotPath);

      this.screenshotCount++;

      const screenshotInfo: ScreenshotInfo = {
        filename,
        path: screenshotPath,
        timestamp,
        dimensions,
        format: this.config.format,
        size: stats.size,
        trigger: options.trigger
      };

      this.emit('screenshotCaptured', screenshotInfo);
      return screenshotInfo;
    }

    return undefined;
  }

  private async captureRegion(outputPath: string, region: { x: number; y: number; width: number; height: number }): Promise<boolean> {
    return new Promise((resolve) => {
      const args = [
        '-x',
        '-R', `${region.x},${region.y},${region.width},${region.height}`,
        '-t', this.config.format,
        '-q', this.getQualityFlag(),
        outputPath
      ];

      const process = spawn('screencapture', args);

      process.on('close', (code) => {
        resolve(code === 0);
      });

      process.on('error', () => {
        resolve(false);
      });

      setTimeout(() => {
        process.kill();
        resolve(false);
      }, 10000);
    });
  }

  /**
   * Get screenshot capture statistics
   */
  getStatistics() {
    return {
      enabled: this.config.enabled,
      screenshotCount: this.screenshotCount,
      outputDirectory: this.screenshotOutputDir,
      config: this.config
    };
  }

  /**
   * Create a time-lapse from captured screenshots
   */
  async createTimeLapse(outputPath: string, frameRate: number = 2): Promise<boolean> {
    if (this.screenshotCount === 0) {
      console.log('No screenshots available for time-lapse');
      return false;
    }

    try {
      // Use ffmpeg to create time-lapse video
      return new Promise((resolve) => {
        const args = [
          '-framerate', frameRate.toString(),
          '-pattern_type', 'glob',
          '-i', path.join(this.screenshotOutputDir, '*.png'),
          '-c:v', 'libx264',
          '-pix_fmt', 'yuv420p',
          '-y', // Overwrite output
          outputPath
        ];

        const process = spawn('ffmpeg', args);

        process.on('close', (code) => {
          if (code === 0) {
            console.log(`✅ Time-lapse created: ${outputPath}`);
            resolve(true);
          } else {
            console.log('❌ Time-lapse creation failed (ffmpeg required)');
            resolve(false);
          }
        });

        process.on('error', (error) => {
          console.log('❌ Time-lapse creation failed:', error.message);
          resolve(false);
        });
      });

    } catch (error) {
      console.error('Error creating time-lapse:', error);
      return false;
    }
  }

  async shutdown(): Promise<void> {
    if (this.isInitialized) {
      console.log(`📊 Screenshot capture complete: ${this.screenshotCount} screenshots`);
      
      // Optionally create time-lapse
      if (this.screenshotCount > 5) {
        const timelapseFile = path.join(this.outputDir, 'timelapse.mp4');
        await this.createTimeLapse(timelapseFile);
      }
    }
    this.isInitialized = false;
  }
}
#!/usr/bin/env ts-node
/**
 * TrackerA11y CLI Tool
 * Simple command-line interface for comprehensive event recording
 */

import { program } from 'commander';
import { EventRecorder, RecorderConfig } from './src/recorder';
import * as path from 'path';

program
  .name('trackera11y')
  .description('Comprehensive event recorder for accessibility analysis')
  .version('1.0.0');

program
  .command('record')
  .description('Start recording all user interactions and events')
  .option('-o, --output <directory>', 'Output directory for recordings', './recordings')
  .option('-s, --screenshots', 'Enable screenshot capture', true)
  .option('-d, --dom', 'Enable DOM state capture', true)
  .option('--no-screenshots', 'Disable screenshot capture')
  .option('--no-dom', 'Disable DOM state capture')
  .option('-q, --quality <level>', 'Screenshot quality (low|medium|high|lossless)', 'medium')
  .option('-i, --interval <ms>', 'Minimum interval between captures (ms)', '2000')
  .action(async (options) => {
    console.log('🎥 TrackerA11y Event Recorder');
    console.log('🔴 Starting comprehensive event recording...\n');

    const config: RecorderConfig = {
      outputDirectory: path.resolve(options.output),
      
      screenshot: {
        enabled: options.screenshots,
        quality: options.quality as any,
        format: 'png',
        minInterval: parseInt(options.interval),
        triggers: ['click', 'focus_change', 'key'],
        captureFullScreen: true,
        captureActiveWindow: false
      },
      
      dom: {
        enabled: options.dom,
        captureFullDOM: true,
        captureStyles: false,
        captureResources: false,
        minInterval: 5000,
        browsers: ['Safari', 'Chrome', 'Firefox', 'Edge']
      },
      
      interactions: {
        captureClicks: true,
        captureKeystrokes: true,
        captureScrolls: true,
        captureMouseMovements: false,
        captureTouchEvents: true,
        captureCoordinates: true,
        captureTimings: true
      },
      
      flushInterval: 10000
    };

    const recorder = new EventRecorder(config);

    // Handle shutdown
    process.on('SIGINT', async () => {
      console.log('\n🛑 Stopping recording...');
      try {
        await recorder.stopRecording();
        await recorder.shutdown();
        process.exit(0);
      } catch (error) {
        console.error('Error stopping recording:', error);
        process.exit(1);
      }
    });

    try {
      await recorder.startRecording();
      
      // Keep running
      await new Promise(() => {}); // Run forever until SIGINT
      
    } catch (error) {
      console.error('Failed to start recording:', error);
      process.exit(1);
    }
  });

program
  .command('analyze <recording-directory>')
  .description('Analyze a completed recording session')
  .action(async (recordingDir) => {
    console.log(`📊 Analyzing recording: ${recordingDir}`);
    
    try {
      const eventsFile = path.join(recordingDir, 'events.json');
      const fs = await import('fs/promises');
      const events = JSON.parse(await fs.readFile(eventsFile, 'utf-8'));
      
      console.log('\n📈 Recording Analysis:');
      console.log(`   Session ID: ${events.sessionId}`);
      console.log(`   Duration: ${((events.endTime - events.startTime) / 1000000).toFixed(2)} seconds`);
      console.log(`   Total Events: ${events.events.length}`);
      
      // Event type breakdown
      const eventTypes = events.events.reduce((acc: any, event: any) => {
        acc[event.type] = (acc[event.type] || 0) + 1;
        return acc;
      }, {});
      
      console.log('\n📊 Event Breakdown:');
      Object.entries(eventTypes)
        .sort(([,a], [,b]) => (b as number) - (a as number))
        .forEach(([type, count]) => {
          console.log(`   ${type}: ${count}`);
        });
      
      // Files breakdown
      const screenshotsDir = path.join(recordingDir, 'screenshots');
      const domStatesDir = path.join(recordingDir, 'dom_states');
      
      try {
        const screenshots = await fs.readdir(screenshotsDir);
        console.log(`\n📸 Screenshots: ${screenshots.length}`);
      } catch {
        console.log('\n📸 Screenshots: 0');
      }
      
      try {
        const domStates = await fs.readdir(domStatesDir);
        const htmlFiles = domStates.filter(f => f.endsWith('.html'));
        console.log(`📋 DOM States: ${htmlFiles.length}`);
      } catch {
        console.log('📋 DOM States: 0');
      }
      
      console.log(`\n✅ Analysis complete for ${recordingDir}`);
      
    } catch (error) {
      console.error('Failed to analyze recording:', error);
      process.exit(1);
    }
  });

// Show help if no command provided
if (process.argv.length <= 2) {
  program.help();
}

program.parse();
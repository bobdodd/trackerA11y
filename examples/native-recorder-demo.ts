#!/usr/bin/env ts-node
/**
 * Native Event Recorder Demo
 * Uses the native macOS helper for real mouse/keyboard capture
 */

import { EventRecorder, RecorderConfig } from '../src/recorder';
import { NativeInteractionTracker } from '../src/interaction/macos/NativeInteractionTracker';
import { InteractionManager } from '../src/interaction/InteractionManager';

async function runNativeRecorderDemo() {
  console.log('🎯 TrackerA11y Native Event Recorder');
  console.log('🔥 Uses native macOS helper for REAL mouse/keyboard capture');
  console.log('⚡ Every click, keystroke, and scroll will be captured precisely');
  console.log('⏹️  Press Ctrl+C to stop recording\n');

  const config: RecorderConfig = {
    outputDirectory: './native_recordings',
    
    screenshot: {
      enabled: false, // Disable for now to focus on event capture
      quality: 'medium',
      format: 'png', 
      minInterval: 2000,
      triggers: ['click', 'focus_change'],
      captureFullScreen: true,
      captureActiveWindow: false
    },
    
    dom: {
      enabled: false, // Disable for now to focus on event capture
      captureFullDOM: true,
      captureStyles: false,
      captureResources: false,
      minInterval: 5000,
      browsers: ['Safari', 'Chrome']
    },
    
    interactions: {
      captureClicks: true,
      captureKeystrokes: true,
      captureScrolls: true,
      captureMouseMovements: false, // Can enable if you want (very verbose)
      captureTouchEvents: true,
      captureCoordinates: true,
      captureTimings: true
    },
    
    flushInterval: 5000 // Flush every 5 seconds
  };

  // Create a custom event recorder that uses the native interaction tracker
  class NativeEventRecorder extends EventRecorder {
    protected initializeInteractionManager() {
      // Override to use native tracker instead of simulated one
      const nativeTracker = new NativeInteractionTracker({
        enableMouse: true,
        enableKeyboard: true,
        enableTouch: false,
        enableAccessibility: true,
        privacyMode: 'detailed',
        captureLevel: 'full',
        filterSensitive: false,
        captureClicks: true,
        captureKeystrokes: true,
        captureScrolls: true,
        captureMouseMovements: false,
        captureTouchEvents: true,
        captureCoordinates: true,
        captureTimings: true
      });
      
      return new InteractionManager(this.config.interactions || {}, nativeTracker);
    }
  }

  const recorder = new (NativeEventRecorder as any)(config);
  let isShuttingDown = false;

  // Set up event listeners
  recorder.on('recordingStarted', (info: any) => {
    console.log(`✅ Native recording started`);
    console.log(`📁 Session: ${info.sessionId}`);
    console.log(`💾 Output: ${info.outputDir}`);
    console.log();
    console.log('🎯 Try these actions to see native capture:');
    console.log('   • Click anywhere on the screen');
    console.log('   • Press keyboard keys (Tab, Space, Arrow keys)');
    console.log('   • Scroll with mouse wheel');
    console.log('   • Switch between applications');
    console.log('   • Use keyboard shortcuts (⌘+Tab, ⌘+C, etc.)');
    console.log();
  });

  recorder.on('eventRecorded', (event: any) => {
    // Enhanced real-time display for native events
    const time = new Date(event.timestamp / 1000).toISOString().split('T')[1].split('.')[0];
    
    if (event.source === 'interaction') {
      const { interactionType, target, inputData } = event.data;
      
      if (interactionType === 'click') {
        console.log(`🖱️  ${time} | CLICK | ${inputData.button} button at (${target.coordinates.x}, ${target.coordinates.y})`);
      } else if (interactionType === 'key') {
        const modifierText = inputData.modifiers?.length > 0 ? ` + ${inputData.modifiers.join('+')}` : '';
        console.log(`⌨️  ${time} | KEY | ${inputData.key}${modifierText}`);
      } else if (interactionType === 'scroll') {
        console.log(`📜 ${time} | SCROLL | (${inputData.scrollDelta.x}, ${inputData.scrollDelta.y}) at (${target.coordinates.x}, ${target.coordinates.y})`);
      } else if (interactionType === 'mouse_move') {
        console.log(`🖱️  ${time} | MOUSE MOVE | (${target.coordinates.x}, ${target.coordinates.y})`);
      } else if (interactionType === 'drag') {
        console.log(`🫳 ${time} | DRAG | ${inputData.button} button at (${target.coordinates.x}, ${target.coordinates.y})`);
      }
    } else if (event.source === 'focus') {
      console.log(`🎯 ${time} | FOCUS | ${event.data.applicationName}`);
    }
  });

  recorder.on('recordingStopped', (info: any) => {
    console.log('\n📊 Native Recording Session Complete:');
    console.log(`   Session ID: ${info.sessionId}`);
    console.log(`   Total Events: ${info.eventCount}`);
    console.log(`   Duration: ${(info.duration / 1000000).toFixed(2)} seconds`);
    console.log(`   Output Directory: ${info.outputDir}`);
    console.log();
    console.log('🎯 What Was Captured with Native Helper:');
    console.log('   ✅ Every mouse click with pixel-perfect coordinates');
    console.log('   ✅ Every keystroke with full modifier information');
    console.log('   ✅ Every scroll event with precise deltas');
    console.log('   ✅ Application focus changes');
    console.log('   ✅ Microsecond-precise timestamps');
    console.log();
    console.log('📈 This data is perfect for audio analysis correlation!');
    console.log(`📁 View raw data: cat ${info.outputDir}/events.json`);
  });

  recorder.on('error', (error: Error) => {
    console.error('❌ Recorder error:', error.message);
    
    if (error.message.includes('Native helper not found')) {
      console.log('\n🔨 To build the native helper:');
      console.log('   cd native_helpers');
      console.log('   make');
      console.log('   cd ..');
      console.log('   npm run demo:native');
    } else if (error.message.includes('Accessibility permissions')) {
      console.log('\n🔒 Accessibility Permission Required:');
      console.log('   1. Open System Preferences → Security & Privacy → Privacy');
      console.log('   2. Click "Accessibility" on the left');
      console.log('   3. Check the box next to "Terminal" (or your IDE)');
      console.log('   4. Restart this demo');
    }
  });

  // Handle graceful shutdown
  const gracefulShutdown = async () => {
    if (isShuttingDown) return;
    isShuttingDown = true;
    
    console.log('\n\n🛑 Stopping native recording...');
    
    try {
      await recorder.stopRecording();
      await recorder.shutdown();
      process.exit(0);
    } catch (error) {
      console.error('❌ Error stopping recording:', error);
      process.exit(1);
    }
  };

  process.on('SIGINT', gracefulShutdown);
  process.on('SIGTERM', gracefulShutdown);

  try {
    console.log('🔨 Checking native helper...');
    console.log('🚀 Initializing native event recorder...');
    
    // Start recording with native capture
    await recorder.startRecording();
    
    console.log('👂 Listening for native system events...\n');
    
    // Keep running until interrupted
    await new Promise<void>((resolve) => {
      process.once('SIGINT', resolve);
      process.once('SIGTERM', resolve);
    });

  } catch (error) {
    console.error('💥 Failed to start native recording:', error);
    
    if (error instanceof Error) {
      if (error.message.includes('Native helper not found')) {
        console.log('\n🔨 Build Instructions:');
        console.log('   1. cd native_helpers');
        console.log('   2. make');
        console.log('   3. cd ..');
        console.log('   4. npm run demo:native');
      }
    }
    
    process.exit(1);
  }
}

// Run the demo
if (require.main === module) {
  runNativeRecorderDemo().catch(console.error);
}

export { runNativeRecorderDemo };
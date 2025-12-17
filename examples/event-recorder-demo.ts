#!/usr/bin/env ts-node
/**
 * Comprehensive Event Recorder Demo
 * Records ALL user interactions, focus changes, DOM states, and screenshots
 * Pure data capture - no analysis, perfect for audio correlation
 */

import { EventRecorder, RecorderConfig } from '../src/recorder';

async function runEventRecorderDemo() {
  console.log('🎥 TrackerA11y Comprehensive Event Recorder');
  console.log('📊 Records everything: interactions, focus, DOM, screenshots');
  console.log('⚡ No analysis - pure data capture for audio correlation');
  console.log('⏹️  Press Ctrl+C to stop recording\n');

  const config: RecorderConfig = {
    outputDirectory: './recordings',
    
    screenshot: {
      enabled: true,
      quality: 'medium',
      format: 'png',
      minInterval: 2000, // 2 seconds between screenshots
      triggers: ['click', 'focus_change', 'key'], // What triggers screenshots
      captureFullScreen: true,
      captureActiveWindow: false
    },
    
    dom: {
      enabled: true,
      captureFullDOM: true,
      captureStyles: false, // Keep output size manageable
      captureResources: false,
      minInterval: 5000, // 5 seconds between DOM captures
      browsers: ['Safari', 'Chrome', 'Firefox', 'Edge']
    },
    
    interactions: {
      captureClicks: true,
      captureKeystrokes: true,
      captureScrolls: true,
      captureMouseMovements: false, // Too noisy for most use cases
      captureTouchEvents: true,
      captureCoordinates: true,
      captureTimings: true
    },
    
    flushInterval: 10000 // Flush to disk every 10 seconds
  };

  const recorder = new EventRecorder(config);

  // Event listeners for monitoring
  recorder.on('recordingStarted', (info) => {
    console.log(`✅ Recording started`);
    console.log(`📁 Session: ${info.sessionId}`);
    console.log(`💾 Output: ${info.outputDir}`);
    console.log();
  });

  recorder.on('eventRecorded', (event) => {
    // Real-time feedback is handled by the recorder itself
  });

  recorder.on('recordingStopped', (info) => {
    console.log('\n📊 Recording Session Complete:');
    console.log(`   Session ID: ${info.sessionId}`);
    console.log(`   Total Events: ${info.eventCount}`);
    console.log(`   Duration: ${(info.duration / 1000000).toFixed(2)} seconds`);
    console.log(`   Output Directory: ${info.outputDir}`);
    console.log('\n📂 Generated Files:');
    console.log('   • events.json - Complete event log with microsecond timestamps');
    console.log('   • screenshots/ - Screenshots captured at interaction moments');
    console.log('   • dom_states/ - DOM snapshots for web interactions');
    console.log('   • summary.txt - Session summary and statistics');
    console.log('\n🎵 Ready for audio analysis correlation!');
  });

  recorder.on('error', (error) => {
    console.error('❌ Recorder error:', error.message);
  });

  // Handle graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\n\n🛑 Stopping recording...');
    
    try {
      const outputDir = await recorder.stopRecording();
      
      // Show what was captured
      console.log('\n🎯 What Was Captured:');
      console.log('• Every mouse click with exact coordinates');
      console.log('• Every keystroke (navigation keys, not passwords)');
      console.log('• Every application focus change');
      console.log('• DOM state whenever you interact with web pages');
      console.log('• Screenshots at key interaction moments');
      console.log('• Microsecond-precise timestamps for audio sync');
      
      await recorder.shutdown();
      process.exit(0);
      
    } catch (error) {
      console.error('❌ Error stopping recording:', error);
      process.exit(1);
    }
  });

  process.on('SIGTERM', async () => {
    await recorder.stopRecording();
    await recorder.shutdown();
    process.exit(0);
  });

  try {
    console.log('🚀 Initializing comprehensive event recorder...');
    
    // Check permissions first
    console.log('🔍 Checking system permissions...');
    console.log('   📱 Accessibility: Required for interaction monitoring');
    console.log('   📸 Screen Recording: Required for screenshots');
    console.log('   🌐 Browser Access: Required for DOM capture');
    console.log();
    
    // Start recording
    await recorder.startRecording();
    
    console.log('👉 Demo Actions to Try:');
    console.log('   • Switch between applications (⌘+Tab)');
    console.log('   • Click around in different apps');
    console.log('   • Type in text fields');
    console.log('   • Browse websites (Safari/Chrome)');
    console.log('   • Scroll through documents');
    console.log('   • Use keyboard shortcuts');
    console.log();
    console.log('📝 Watch the real-time event log below:\n');

    // Keep running until interrupted
    await new Promise<void>((resolve) => {
      process.on('SIGINT', resolve);
      process.on('SIGTERM', resolve);
    });

  } catch (error) {
    console.error('💥 Failed to start recording:', error);
    
    if (error instanceof Error) {
      if (error.message.includes('Accessibility permissions')) {
        console.log('\n🔒 Accessibility Permission Required:');
        console.log('   1. Open System Preferences → Security & Privacy');
        console.log('   2. Click Privacy tab → Accessibility');
        console.log('   3. Add Terminal or your IDE to allowed apps');
        console.log('   4. Restart this demo');
      } else if (error.message.includes('Screen Recording')) {
        console.log('\n📸 Screen Recording Permission Required:');
        console.log('   1. Open System Preferences → Security & Privacy');
        console.log('   2. Click Privacy tab → Screen Recording');
        console.log('   3. Add Terminal or your IDE to allowed apps');
        console.log('   4. Restart this demo');
      }
    }
    
    process.exit(1);
  }
}

// Run the demo
if (require.main === module) {
  runEventRecorderDemo().catch(console.error);
}

export { runEventRecorderDemo };
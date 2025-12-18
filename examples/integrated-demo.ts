#!/usr/bin/env ts-node
/**
 * Integrated Native Events + Focus Tracking Demo
 * Shows complete integration of native mouse/keyboard capture with focus tracking
 */

import { EventRecorder, RecorderConfig } from '../src/recorder';

async function runIntegratedDemo() {
  console.log('🎯 TrackerA11y Integrated Event Capture');
  console.log('🔥 Native mouse/keyboard + focus tracking + DOM capture');
  console.log('⚡ Every interaction correlated with application context');
  console.log('⏹️  Press Ctrl+C to stop recording\n');

  const config: RecorderConfig = {
    outputDirectory: './integrated_recordings',
    
    screenshot: {
      enabled: false, // Disable to focus on event capture
      quality: 'medium',
      format: 'png', 
      minInterval: 3000,
      triggers: ['click', 'focus_change'],
      captureFullScreen: true,
      captureActiveWindow: false
    },
    
    dom: {
      enabled: true, // Enable DOM capture for browser context
      captureFullDOM: false, // Lightweight capture
      captureStyles: false,
      captureResources: false,
      minInterval: 8000, // Only capture DOM changes occasionally 
      browsers: ['Safari', 'Chrome']
    },
    
    interactions: {
      captureClicks: true,
      captureKeystrokes: true,
      captureScrolls: true,
      captureMouseMovements: true,
      captureTouchEvents: false,
      captureCoordinates: true,
      captureTimings: true
    },
    
    flushInterval: 3000 // Flush frequently for real-time monitoring
  };

  const recorder = new EventRecorder(config);
  let isShuttingDown = false;
  let eventCount = 0;

  // Track event correlation
  let lastFocusEvent: any = null;
  let recentInteractions: any[] = [];

  recorder.on('recordingStarted', (info: any) => {
    console.log(`✅ Integrated recording started`);
    console.log(`📁 Session: ${info.sessionId}`);
    console.log(`💾 Output: ${info.outputDir}\n`);
    console.log('🎯 Try these correlated actions:');
    console.log('   1. ⌘+Tab to switch apps, then click');
    console.log('   2. Open Safari/Chrome, browse, and click links');
    console.log('   3. Use keyboard shortcuts while app switching');
    console.log('   4. Type in different applications');
    console.log('   5. Scroll in different contexts\n');
  });

  recorder.on('eventRecorded', (event: any) => {
    eventCount++;
    const time = new Date(event.timestamp / 1000).toISOString().split('T')[1].split('.')[0];
    
    if (event.source === 'focus') {
      lastFocusEvent = event;
      console.log(`🎯 ${time} | FOCUS | ${event.data.applicationName} | PID: ${event.data.processId}`);
      
      // Show correlation with recent interactions
      if (recentInteractions.length > 0) {
        const recentCount = recentInteractions.filter(i => 
          event.timestamp - i.timestamp < 2000000 // 2 seconds
        ).length;
        if (recentCount > 0) {
          console.log(`   ↳ 📊 ${recentCount} interactions led to this focus change`);
        }
      }
      
    } else if (event.source === 'interaction') {
      const { interactionType, target, inputData } = event.data;
      
      // Track interaction for correlation
      recentInteractions.push(event);
      if (recentInteractions.length > 10) {
        recentInteractions.shift(); // Keep only recent ones
      }
      
      // Show interaction with current application context
      const appContext = lastFocusEvent ? ` in ${lastFocusEvent.data.applicationName}` : '';
      
      if (interactionType === 'click') {
        // Handle dock clicks specially
        if (target.element && target.element.role === 'button' && target.element.label === 'Dock icon') {
          console.log(`🖱️  ${time} | 🖱️ DOCK CLICK: ${target.element.title} icon`);
        } else {
          let elementInfo = '';
          if (inputData.elementRole) {
            elementInfo = ` → ${inputData.elementRole}`;
            if (inputData.elementTitle) elementInfo += ` "${inputData.elementTitle}"`;
            if (inputData.elementLabel) elementInfo += ` [${inputData.elementLabel}]`;
            if (inputData.elementValue) elementInfo += ` = "${inputData.elementValue}"`;
          }
          console.log(`🖱️  ${time} | CLICK | ${inputData.button} at (${target.coordinates.x}, ${target.coordinates.y})${appContext}${elementInfo}`);
        }
      } else if (interactionType === 'key') {
        const modifierText = inputData.modifiers?.length > 0 ? ` + ${inputData.modifiers.join('+')}` : '';
        console.log(`⌨️  ${time} | KEY | ${inputData.key}${modifierText}${appContext}`);
      } else if (interactionType === 'scroll') {
        console.log(`📜 ${time} | SCROLL | (${inputData.scrollDelta.x}, ${inputData.scrollDelta.y})${appContext}`);
      } else if (interactionType === 'mouse_move') {
        // Only show occasional mouse moves to avoid spam
        if (eventCount % 20 === 0) {
          console.log(`🖱️  ${time} | MOVE | (${target.coordinates.x}, ${target.coordinates.y})${appContext}`);
        }
      }
      
    } else if (event.source === 'dom') {
      console.log(`🌐 ${time} | DOM | ${event.data.url} | Elements: ${event.data.elementCount}`);
    }
  });

  recorder.on('recordingStopped', (info: any) => {
    console.log('\n📊 Integrated Recording Session Complete:');
    console.log(`   Session ID: ${info.sessionId}`);
    console.log(`   Total Events: ${info.eventCount}`);
    console.log(`   Duration: ${(info.duration / 1000000).toFixed(2)} seconds`);
    console.log(`   Output Directory: ${info.outputDir}`);
    console.log();
    console.log('🎯 What Was Captured with Full Integration:');
    console.log('   ✅ Every mouse click with pixel-perfect coordinates');
    console.log('   ✅ Every keystroke with application context');
    console.log('   ✅ Application focus changes with precise timing');
    console.log('   ✅ DOM state for web browsing correlation');
    console.log('   ✅ Perfect timing correlation for audio analysis');
    console.log();
    console.log('📈 This integrated data provides complete user behavior context!');
    console.log(`📁 View raw data: cat ${info.outputDir}/events.json`);
  });

  recorder.on('error', (error: Error) => {
    console.error('❌ Recorder error:', error.message);
    
    if (error.message.includes('Native helper not found')) {
      console.log('\n🔨 To build the native helper:');
      console.log('   cd native_helpers/native_helpers');
      console.log('   make');
      console.log('   cd ../..');
      console.log('   npm run demo:integrated');
    }
  });

  // Handle graceful shutdown
  const gracefulShutdown = async () => {
    if (isShuttingDown) return;
    isShuttingDown = true;
    
    console.log('\n\n🛑 Stopping integrated recording...');
    
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
    console.log('🔨 Initializing integrated recording system...');
    
    await recorder.startRecording();
    
    console.log('👂 Listening for all events with full context...\n');
    
    // Keep running until interrupted
    await new Promise<void>((resolve) => {
      process.once('SIGINT', resolve);
      process.once('SIGTERM', resolve);
    });

  } catch (error) {
    console.error('💥 Failed to start integrated recording:', error);
    process.exit(1);
  }
}

// Run the demo
if (require.main === module) {
  runIntegratedDemo().catch(console.error);
}

export { runIntegratedDemo };
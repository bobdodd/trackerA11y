#!/usr/bin/env ts-node
/**
 * Simple Native Event Capture Test
 * Tests the native macOS helper directly
 */

import { NativeInteractionTracker } from '../src/interaction/macos/NativeInteractionTracker';

async function runNativeTest() {
  console.log('🎯 Native macOS Event Capture Test');
  console.log('🔥 Testing REAL mouse/keyboard capture');
  console.log('⚡ Every click and keystroke will be shown');
  console.log('⏹️  Press Ctrl+C to stop\n');

  const tracker = new NativeInteractionTracker({
    enableMouse: true,
    enableKeyboard: true,
    enableTouch: false,
    enableAccessibility: true,
    privacyMode: 'detailed',
    captureLevel: 'full',
    filterSensitive: false
  });

  let isShuttingDown = false;
  let eventCount = 0;

  // Listen for events
  tracker.on('interaction', (event) => {
    eventCount++;
    const time = new Date(event.timestamp / 1000).toISOString().split('T')[1].split('.')[0];
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
  });

  tracker.on('error', (error) => {
    console.error('❌ Tracker error:', error.message);
    
    if (error.message.includes('Native helper not found')) {
      console.log('\n🔨 To build the native helper:');
      console.log('   cd native_helpers');
      console.log('   make');
      console.log('   cd ..');
      console.log('   npm run ts-node examples/native-test-demo.ts');
    }
  });

  // Handle graceful shutdown
  const gracefulShutdown = async () => {
    if (isShuttingDown) return;
    isShuttingDown = true;
    
    console.log('\n\n🛑 Stopping native test...');
    console.log(`📊 Captured ${eventCount} events`);
    
    try {
      await tracker.shutdown();
      console.log('✅ Native test completed');
      process.exit(0);
    } catch (error) {
      console.error('❌ Error stopping tracker:', error);
      process.exit(1);
    }
  };

  process.on('SIGINT', gracefulShutdown);
  process.on('SIGTERM', gracefulShutdown);

  try {
    console.log('🔨 Initializing native tracker...');
    await tracker.initialize();
    
    console.log('🚀 Starting native event capture...');
    await tracker.startMonitoring();
    
    console.log('👂 Listening for native system events...');
    console.log('🎯 Try clicking, typing, scrolling...\n');
    
    // Keep running until interrupted
    await new Promise<void>((resolve) => {
      process.once('SIGINT', resolve);
      process.once('SIGTERM', resolve);
    });

  } catch (error) {
    console.error('💥 Failed to start native test:', error);
    process.exit(1);
  }
}

// Run the test
if (require.main === module) {
  runNativeTest().catch(console.error);
}

export { runNativeTest };
#!/usr/bin/env ts-node
/**
 * Focus Tracking Demo
 * Demonstrates real-time application focus tracking on macOS
 */

import { FocusManager } from '../src/core/FocusManager';
import { FocusEvent } from '../src/types';

async function runFocusTrackingDemo() {
  console.log('🚀 Starting TrackerA11y Focus Tracking Demo');
  console.log('📱 Platform:', process.platform);
  console.log('⏱️  Switch between applications to see focus tracking in action');
  console.log('🔄 Press Ctrl+C to stop\n');

  const focusManager = new FocusManager();

  // Set up event listeners
  focusManager.on('initialized', () => {
    console.log('✅ Focus tracking initialized successfully');
  });

  focusManager.on('focusChanged', (event: FocusEvent) => {
    const { applicationName, windowTitle, processId, accessibilityContext } = event.data;
    const timestamp = new Date(event.timestamp / 1000).toISOString();
    
    console.log('\n📋 Focus Changed:');
    console.log(`   Time: ${timestamp}`);
    console.log(`   App: ${applicationName} (PID: ${processId})`);
    console.log(`   Window: ${windowTitle}`);
    
    if (accessibilityContext?.role) {
      console.log(`   Role: ${accessibilityContext.role}`);
    }
    
    if (accessibilityContext?.properties?.bundleId) {
      console.log(`   Bundle: ${accessibilityContext.properties.bundleId}`);
    }

    if (accessibilityContext?.states && accessibilityContext.states.length > 0) {
      console.log(`   States: ${accessibilityContext.states.join(', ')}`);
    }
  });

  focusManager.on('error', (error) => {
    console.error('❌ Focus tracking error:', error.message);
    
    if (error.message.includes('Accessibility permissions')) {
      console.log('\n🔒 To fix accessibility permissions:');
      console.log('   1. Open System Preferences → Security & Privacy');
      console.log('   2. Click Privacy tab');
      console.log('   3. Select Accessibility from the list');
      console.log('   4. Add Terminal or your IDE to the allowed apps');
      console.log('   5. Restart this demo\n');
    }
  });

  focusManager.on('shutdown', () => {
    console.log('🛑 Focus tracking stopped');
    process.exit(0);
  });

  // Handle graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\n\n🛑 Shutting down focus tracking...');
    await focusManager.shutdown();
  });

  process.on('SIGTERM', async () => {
    console.log('\n\n🛑 Shutting down focus tracking...');
    await focusManager.shutdown();
  });

  try {
    // Initialize and start tracking
    await focusManager.initialize();
    
    // Get initial focus
    const initialFocus = await focusManager.getCurrentFocus();
    if (initialFocus) {
      console.log(`🎯 Current focus: ${initialFocus.data.applicationName}`);
    }

    // Keep the demo running
    console.log('👀 Monitoring focus changes... (Press Ctrl+C to stop)');
    
    // Prevent process from exiting
    await new Promise<void>((resolve) => {
      process.on('SIGINT', resolve);
      process.on('SIGTERM', resolve);
    });

  } catch (error) {
    console.error('💥 Failed to start focus tracking:', error);
    process.exit(1);
  }
}

// Run the demo
if (require.main === module) {
  runFocusTrackingDemo().catch(console.error);
}

export { runFocusTrackingDemo };
#!/usr/bin/env ts-node
/**
 * Accessibility UI Element Inspector Demo
 * Shows detailed information about UI elements when clicked
 */

import { NativeInteractionTracker } from '../src/interaction/macos/NativeInteractionTracker';

async function runAccessibilityDemo() {
  console.log('🎯 TrackerA11y Accessibility Inspector Demo');
  console.log('🔍 Click anywhere to see detailed UI element information');
  console.log('📋 Shows: role, title, label, value, bounds, states');
  console.log('⏹️  Press Ctrl+C to stop\n');

  const tracker = new NativeInteractionTracker({
    enableMouse: true,
    enableKeyboard: false, // Focus on clicks only
    enableTouch: false,
    enableAccessibility: true,
    privacyMode: 'detailed',
    captureLevel: 'full',
    filterSensitive: false
  });

  let isShuttingDown = false;
  let clickCount = 0;

  // Listen for interactions with accessibility information
  tracker.on('interaction', (event) => {
    const { interactionType, target, inputData } = event.data;
    const time = new Date(event.timestamp / 1000).toISOString().split('T')[1].split('.')[0];
    
    
    // Helper function to get element description
    const getElementDesc = (element: any) => {
      if (!element) return 'unknown element';
      
      // For dock icons
      if (element.description === 'Dock icon') {
        return `🚢 Dock: ${element.title}`;
      }
      
      // For browser elements 
      if (element.tagName) {
        const tag = element.tagName.toLowerCase();
        const text = element.textContent?.trim().substring(0, 30) || '';
        const id = element.id ? `#${element.id}` : '';
        const href = element.href ? ` (${element.href.substring(0, 30)}...)` : '';
        return `<${tag}>${id} "${text}"${href}`;
      }
      
      // For native elements
      const title = element.title || element.label || element.value || 'untitled';
      return `${element.role}: ${title}`;
    };

    // Skip mouse moves unless it's a significant event
    if (interactionType === 'mouse_move') {
      return; // Too noisy
    }

    // Handle different interaction types
    switch (interactionType) {
      case 'click':
        clickCount++;
        const isDoubleClick = inputData.clickCount > 1;
        const clickIcon = inputData.button === 'right' ? '🖱️ ' : 
                         inputData.button === 'middle' ? '🖲️ ' : 
                         isDoubleClick ? '🖱️ ' : '🖱️ ';
        const clickType = inputData.button === 'right' ? 'RIGHT CLICK' :
                         inputData.button === 'middle' ? 'MIDDLE CLICK' :
                         isDoubleClick ? 'DOUBLE CLICK' : 'CLICK';
        
        console.log(`${clickIcon}${clickType} #${clickCount} | ${getElementDesc(target.element)}`);
        break;

      case 'mouse_down':
        const downIcon = inputData.button === 'right' ? '⬇️ ' : '⬇️ ';
        const description = getElementDesc(target.element);
        
        // Special handling for dock icons in mouse down
        if (target.element?.description === 'Dock icon') {
          console.log(`${downIcon}DOCK PRESS | ${description}`);
        } else {
          console.log(`${downIcon}PRESS ${inputData.button.toUpperCase()} | ${description}`);
        }
        break;

      case 'mouse_up':
        const upIcon = inputData.button === 'right' ? '⬆️ ' : '⬆️ ';
        console.log(`${upIcon}RELEASE ${inputData.button.toUpperCase()} | ${getElementDesc(target.element)}`);
        break;

      case 'hover':
        console.log(`🫧 HOVER START | ${getElementDesc(target.element)}`);
        break;

      case 'hover_end':
        console.log(`🫧 HOVER END (${inputData.dwellTime.toFixed(0)}ms)`);
        break;

      case 'drag':
        console.log(`🫳 DRAG ${inputData.button.toUpperCase()} | ${getElementDesc(target.element)}`);
        break;

      case 'scroll':
        const direction = inputData.scrollDelta.y > 0 ? '⬆️ ' : inputData.scrollDelta.y < 0 ? '⬇️ ' : '↔️ ';
        console.log(`${direction}SCROLL | ${getElementDesc(target.element)}`);
        break;

      case 'key':
        const modifiers = inputData.modifiers?.length ? `${inputData.modifiers.join('+')}+` : '';
        console.log(`⌨️  KEY | ${modifiers}${inputData.key}`);
        break;

      default:
        return; // Skip unknown events
    }
  });


  tracker.on('error', (error) => {
    console.error('❌ Tracker error:', error.message);
  });

  // Handle graceful shutdown
  const gracefulShutdown = async () => {
    if (isShuttingDown) return;
    isShuttingDown = true;
    
    console.log('\n\n🛑 Stopping accessibility inspector...');
    console.log(`📊 Analyzed ${clickCount} UI elements`);
    
    try {
      await tracker.shutdown();
      console.log('✅ Accessibility demo completed');
      process.exit(0);
    } catch (error) {
      console.error('❌ Error stopping tracker:', error);
      process.exit(1);
    }
  };

  process.on('SIGINT', gracefulShutdown);
  process.on('SIGTERM', gracefulShutdown);

  try {
    console.log('🔨 Initializing accessibility inspector...');
    await tracker.initialize();
    
    console.log('🚀 Starting accessibility-aware event capture...');
    await tracker.startMonitoring();
    
    console.log('👂 Click on different UI elements to see their accessibility information...\n');
    
    // Keep running until interrupted
    await new Promise<void>((resolve) => {
      process.once('SIGINT', resolve);
      process.once('SIGTERM', resolve);
    });

  } catch (error) {
    console.error('💥 Failed to start accessibility demo:', error);
    process.exit(1);
  }
}


// Run the demo
if (require.main === module) {
  runAccessibilityDemo().catch(console.error);
}

export { runAccessibilityDemo };
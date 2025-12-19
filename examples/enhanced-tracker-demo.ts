#!/usr/bin/env ts-node
/**
 * Enhanced TrackerA11y Demo
 * Shows the full power of the enhanced accessibility and interaction tracking
 */

import { TrackerA11yCore } from '../src/core/TrackerA11yCore';
import { TrackerA11yConfig } from '../src/types';

async function runEnhancedDemo() {
  console.log('🚀 Enhanced TrackerA11y Demo');
  console.log('✨ Features: Focus tracking, Dock detection, Modifier keys, Hover tracking, Browser elements');
  console.log('🔍 Enhanced output with clean formatting');
  console.log('⏹️  Press Ctrl+C to stop\n');

  // Configure TrackerA11y with our enhanced settings
  const config: TrackerA11yConfig = {
    platforms: ['macos'],
    syncPrecision: 'microsecond',
    realTimeMonitoring: true,
    outputFormats: ['json'],
    
    // Enable interaction tracking with enhanced features
    interactionTracking: true,
    interactionConfig: {
      enableMouse: true,
      enableKeyboard: true,
      enableTouch: false,
      enableAccessibility: true,
      privacyMode: 'detailed',
      captureLevel: 'full',
      filterSensitive: false
    }
    
    // Audio integration is optional, so we'll omit it for this demo
  };

  const tracker = new TrackerA11yCore(config);
  let isShuttingDown = false;
  let interactionCount = 0;

  // Handle all events (interactions and focus changes) with enhanced output
  tracker.on('eventProcessed', (event) => {
    if (event.source === 'focus') {
      // Handle focus change events
      const { applicationName, windowTitle, processId } = event.data;
      console.log(`👁️  FOCUS | ${applicationName}${windowTitle ? ` - ${windowTitle}` : ''} (PID: ${processId})`);
      return;
    }
    
    if (event.source !== 'interaction') return;
    
    const { interactionType, target, inputData } = event.data;
    
    // Helper function for clean element description
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

    // Skip mouse moves for cleaner output
    if (interactionType === 'mouse_move') {
      return;
    }

    // Handle different interaction types
    switch (interactionType) {
      case 'click':
        interactionCount++;
        const isDoubleClick = inputData.clickCount > 1;
        const clickIcon = inputData.button === 'right' ? '🖱️ ' : 
                         inputData.button === 'middle' ? '🖲️ ' : 
                         isDoubleClick ? '🖱️ ' : '🖱️ ';
        const clickType = inputData.button === 'right' ? 'RIGHT CLICK' :
                         inputData.button === 'middle' ? 'MIDDLE CLICK' :
                         isDoubleClick ? 'DOUBLE CLICK' : 'CLICK';
        const modifierStr = inputData.modifiers?.length ? ` [${inputData.modifiers.join('+')}]` : '';
        
        console.log(`${clickIcon}${clickType}${modifierStr} #${interactionCount} | ${getElementDesc(target.element)}`);
        break;

      case 'mouse_down':
        const downIcon = inputData.button === 'right' ? '⬇️ ' : '⬇️ ';
        const downModifierStr = inputData.modifiers?.length ? ` [${inputData.modifiers.join('+')}]` : '';
        
        if (target.element?.description === 'Dock icon') {
          console.log(`${downIcon}DOCK PRESS${downModifierStr} | ${getElementDesc(target.element)}`);
        } else {
          console.log(`${downIcon}PRESS ${inputData.button.toUpperCase()}${downModifierStr} | ${getElementDesc(target.element)}`);
        }
        break;

      case 'mouse_up':
        const upIcon = inputData.button === 'right' ? '⬆️ ' : '⬆️ ';
        const upModifierStr = inputData.modifiers?.length ? ` [${inputData.modifiers.join('+')}]` : '';
        console.log(`${upIcon}RELEASE ${inputData.button.toUpperCase()}${upModifierStr} | ${getElementDesc(target.element)}`);
        break;

      case 'hover':
        console.log(`🫧 HOVER START | ${getElementDesc(target.element)}`);
        break;

      case 'hover_end':
        console.log(`🫧 HOVER END (${inputData.dwellTime.toFixed(0)}ms)`);
        break;

      case 'drag':
        const dragModifierStr = inputData.modifiers?.length ? ` [${inputData.modifiers.join('+')}]` : '';
        console.log(`🫳 DRAG ${inputData.button.toUpperCase()}${dragModifierStr} | ${getElementDesc(target.element)}`);
        break;

      case 'scroll':
        const direction = inputData.scrollDelta.y > 0 ? '⬆️ ' : inputData.scrollDelta.y < 0 ? '⬇️ ' : '↔️ ';
        const scrollModifierStr = inputData.modifiers?.length ? ` [${inputData.modifiers.join('+')}]` : '';
        console.log(`${direction}SCROLL${scrollModifierStr} | ${getElementDesc(target.element)}`);
        break;

      case 'key':
        const keyModifiers = inputData.modifiers?.length ? `${inputData.modifiers.join('+')}+` : '';
        console.log(`⌨️  KEY | ${keyModifiers}${inputData.key}`);
        break;

      default:
        return; // Skip unknown events
    }
  });

  // Handle errors
  tracker.on('error', (error) => {
    console.error('❌ Tracker error:', error.message);
  });

  // Handle shutdown gracefully
  const gracefulShutdown = async () => {
    if (isShuttingDown) return;
    isShuttingDown = true;
    
    console.log('\\n\\n🛑 Stopping enhanced tracker...');
    console.log(`📊 Captured ${interactionCount} interactions`);
    
    try {
      await tracker.shutdown();
      console.log('✅ Enhanced demo completed');
      process.exit(0);
    } catch (error) {
      console.error('❌ Error stopping tracker:', error);
      process.exit(1);
    }
  };

  process.on('SIGINT', gracefulShutdown);
  process.on('SIGTERM', gracefulShutdown);

  try {
    console.log('🔨 Initializing enhanced tracker...');
    await tracker.initialize();
    
    console.log('🚀 Starting enhanced accessibility tracking...');
    await tracker.start();
    
    console.log('👂 Switch between apps and interact with dock icons, web pages, and applications...\\n');
    
    // Keep running until interrupted
    await new Promise<void>((resolve) => {
      process.once('SIGINT', resolve);
      process.once('SIGTERM', resolve);
    });

  } catch (error) {
    console.error('💥 Failed to start enhanced tracker:', error);
    process.exit(1);
  }
}

// Run the demo
if (require.main === module) {
  runEnhancedDemo().catch(console.error);
}

export { runEnhancedDemo };
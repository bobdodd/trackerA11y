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

  // Listen for clicks with accessibility information
  tracker.on('interaction', (event) => {
    const { interactionType, target, inputData } = event.data;
    
    // Debug: Show all interaction types with more detail
    if (interactionType !== 'click') {
      const time = new Date(event.timestamp / 1000).toISOString().split('T')[1].split('.')[0];
      console.log(`🔍 ${time} | ${interactionType.toUpperCase()} | at (${target.coordinates?.x}, ${target.coordinates?.y})`);
      return;
    }
    
    if (interactionType === 'click') {
      clickCount++;
      const time = new Date(event.timestamp / 1000).toISOString().split('T')[1].split('.')[0];
      
      // Check if this is a dock icon click
      if (target.element && target.element.role === 'button' && target.element.label === 'Dock icon') {
        console.log(`🖱️ DOCK CLICK: ${target.element.title} icon`);
        return;
      }
      
      console.log(`\n🖱️ CLICK #${clickCount} at ${time}`);
      console.log(`📍 Coordinates: (${target.coordinates.x}, ${target.coordinates.y})`);
      console.log(`🔘 Button: ${inputData.button} (${inputData.clickCount}x)`);
      
      if (target.applicationContext) {
        console.log(`📱 Application: ${target.applicationContext.applicationName} (PID: ${target.applicationContext.processId})`);
        if (target.applicationContext.windowTitle) {
          console.log(`🪟 Window: "${target.applicationContext.windowTitle}"`);
        }
      }
      
      if (target.element) {
        const elem = target.element;
        console.log(`\n🎯 UI ELEMENT DETAILS:`);
        console.log(`   Role: ${elem.role || 'unknown'}`);
        
        if (elem.title) console.log(`   Title: "${elem.title}"`);
        if (elem.label) console.log(`   Label: "${elem.label}"`);
        if (elem.value) console.log(`   Value: "${elem.value}"`);
        if (elem.description) console.log(`   Description: "${elem.description}"`);
        if (elem.identifier) console.log(`   ID: ${elem.identifier}`);
        
        console.log(`   Enabled: ${elem.enabled}`);
        console.log(`   Focused: ${elem.focused}`);
        if (elem.selected !== undefined) console.log(`   Selected: ${elem.selected}`);
        
        if (elem.bounds) {
          console.log(`   Bounds: (${elem.bounds.x}, ${elem.bounds.y}) ${elem.bounds.width}×${elem.bounds.height}`);
        }
        
        // Semantic interpretation
        console.log(`\n🧠 SEMANTIC ANALYSIS:`);
        const semantic = interpretElement(elem);
        console.log(`   Element Type: ${semantic.type}`);
        console.log(`   Purpose: ${semantic.purpose}`);
        console.log(`   Interaction: ${semantic.interaction}`);
        
        if (semantic.content) {
          console.log(`   Content: ${semantic.content}`);
        }
      } else {
        console.log(`❌ No accessibility information available`);
        console.log(`   This might be a non-accessible element or background area`);
      }
      
      console.log(`${'─'.repeat(60)}`);
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

// Interpret UI element semantically
function interpretElement(element: any): {
  type: string;
  purpose: string;
  interaction: string;
  content?: string;
} {
  const role = element.role?.toLowerCase() || 'unknown';
  
  switch (role) {
    case 'button':
      return {
        type: 'Interactive Button',
        purpose: 'Triggers an action when clicked',
        interaction: 'Click to activate',
        content: element.title || element.label || element.value
      };
      
    case 'link':
      return {
        type: 'Hyperlink',
        purpose: 'Navigates to another page or location',
        interaction: 'Click to navigate',
        content: element.title || element.label
      };
      
    case 'textfield':
    case 'textfield':
      return {
        type: 'Text Input Field',
        purpose: 'Allows text entry',
        interaction: 'Click to focus, then type',
        content: element.value || element.label || 'Empty field'
      };
      
    case 'checkbox':
      return {
        type: 'Checkbox',
        purpose: 'Toggle binary choice',
        interaction: 'Click to toggle',
        content: `${element.selected ? 'Checked' : 'Unchecked'}: ${element.label || element.title}`
      };
      
    case 'menuitem':
      return {
        type: 'Menu Item',
        purpose: 'Selection from menu',
        interaction: 'Click to select',
        content: element.title || element.label
      };
      
    case 'tab':
      return {
        type: 'Tab',
        purpose: 'Switch between content panels',
        interaction: 'Click to switch',
        content: element.title || element.label
      };
      
    case 'image':
      return {
        type: 'Image',
        purpose: 'Visual content display',
        interaction: 'Click for action (if interactive)',
        content: element.description || element.label || 'Image content'
      };
      
    default:
      return {
        type: `${role.charAt(0).toUpperCase() + role.slice(1)} Element`,
        purpose: 'Part of the user interface',
        interaction: element.enabled ? 'May be interactive' : 'Non-interactive',
        content: element.title || element.label || element.value || element.description
      };
  }
}

// Run the demo
if (require.main === module) {
  runAccessibilityDemo().catch(console.error);
}

export { runAccessibilityDemo };
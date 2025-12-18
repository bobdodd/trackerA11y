#!/usr/bin/env ts-node
/**
 * Quick dock detection test
 */

import { AccessibilityInspector } from './src/accessibility/AccessibilityInspector';

async function testDockDetection() {
  console.log('🧪 Testing dock detection...\n');
  
  const inspector = new AccessibilityInspector();
  
  // Test various coordinates where dock might be
  const testCoordinates = [
    // Common dock positions on different screen sizes
    [960, 1080],   // Bottom center on 1920x1080
    [960, 900],    // Slightly higher
    [500, 1000],   // Left side of dock
    [1400, 1000],  // Right side of dock
    [100, 1000],   // Far left
    [1800, 1000],  // Far right
    [960, 1050],   // Very bottom
    [960, 800],    // Much higher (should not be dock)
  ];
  
  for (const [x, y] of testCoordinates) {
    console.log(`\n🎯 Testing coordinates (${x}, ${y})...`);
    
    try {
      const result = await inspector.hitTest(x, y);
      
      if (result && result.element.description === 'Dock icon') {
        console.log(`✅ DOCK DETECTED: ${result.element.title} at (${result.element.bounds.x}, ${result.element.bounds.y})`);
      } else if (result) {
        console.log(`🔍 Found: ${result.element.role} "${result.element.title}" (${result.element.description || 'no description'})`);
      } else {
        console.log(`❌ No element found at (${x}, ${y})`);
      }
      
    } catch (error) {
      console.error(`💥 Error testing (${x}, ${y}):`, error instanceof Error ? error.message : error);
    }
    
    // Small delay between tests
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  
  console.log('\n🏁 Dock detection test complete');
}

if (require.main === module) {
  testDockDetection().catch(console.error);
}
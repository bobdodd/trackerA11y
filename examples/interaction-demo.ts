#!/usr/bin/env ts-node
/**
 * Interaction Monitoring Demo
 * Demonstrates real-time keyboard and mouse interaction capture
 */

import { TrackerA11yCore } from '../src/core/TrackerA11yCore';
import { 
  TrackerA11yConfig, 
  InteractionEvent,
  TimestampedEvent,
  CorrelatedEvent,
  AccessibilityInsight
} from '../src/types';

async function runInteractionDemo() {
  console.log('👆 Starting TrackerA11y Interaction Monitoring Demo');
  console.log('🖱️  This demo captures keyboard and mouse interactions in real-time');
  console.log('🔒 Privacy: Only navigation keys and accessibility-relevant interactions are captured');
  console.log('⏱️  Press Ctrl+C to stop\n');

  const config: TrackerA11yConfig = {
    platforms: ['macos'],
    syncPrecision: 'microsecond',
    realTimeMonitoring: true,
    interactionTracking: true,
    interactionConfig: {
      enableMouse: true,
      enableKeyboard: true,
      enableTouch: false,
      enableAccessibility: true,
      privacyMode: 'safe',
      captureLevel: 'events',
      filterSensitive: true
    },
    outputFormats: ['json']
  };

  const tracker = new TrackerA11yCore(config);

  // Set up event listeners
  tracker.on('initialized', () => {
    console.log('✅ TrackerA11y Core initialized with interaction monitoring');
  });

  tracker.on('started', () => {
    console.log('🎬 Interaction tracking started\n');
    console.log('📋 Demo Instructions:');
    console.log('   • Use keyboard navigation (Tab, arrows, Enter, Space)');
    console.log('   • Click around the screen');
    console.log('   • Switch between applications (⌘+Tab on macOS)');
    console.log('   • Try keyboard shortcuts');
    console.log('   • The system will show captured interactions and correlations\n');
  });

  tracker.on('eventProcessed', (event: TimestampedEvent) => {
    const timestamp = new Date(event.timestamp / 1000).toISOString().split('T')[1].split('.')[0];
    
    if (event.source === 'interaction') {
      const interactionEvent = event as InteractionEvent;
      const { interactionType, target, inputData } = interactionEvent.data;
      
      console.log(`👆 Interaction: ${interactionType.toUpperCase()} at ${timestamp}`);
      
      if (interactionType === 'key' && inputData?.key) {
        console.log(`   Key: ${inputData.key}`);
        if (inputData.modifiers && inputData.modifiers.length > 0) {
          console.log(`   Modifiers: ${inputData.modifiers.join(' + ')}`);
        }
      } else if (interactionType === 'click' && target?.coordinates) {
        console.log(`   Position: (${target.coordinates.x}, ${target.coordinates.y})`);
        if (inputData?.button) {
          console.log(`   Button: ${inputData.button}`);
        }
      } else if (interactionType === 'scroll' && inputData?.scrollDelta) {
        console.log(`   Scroll: (${inputData.scrollDelta.x}, ${inputData.scrollDelta.y})`);
      }
      
    } else if (event.source === 'focus') {
      const focusData = (event as any).data;
      console.log(`🎯 Focus: ${focusData.applicationName} at ${timestamp}`);
    }
  });

  tracker.on('correlation', ({ correlation, ruleId }: { correlation: CorrelatedEvent, ruleId: string }) => {
    console.log('\n🔗 INTERACTION CORRELATION DETECTED!');
    console.log(`   Rule: ${ruleId}`);
    console.log(`   Type: ${correlation.correlationType}`);
    console.log(`   Confidence: ${(correlation.confidence * 100).toFixed(1)}%`);
    console.log(`   Events: ${correlation.primaryEvent.source} + ${correlation.relatedEvents.map(e => e.source).join(', ')}`);
    
    // Show timing analysis
    const timeDiff = correlation.relatedEvents.length > 0 
      ? Math.abs(correlation.primaryEvent.timestamp - correlation.relatedEvents[0].timestamp) / 1000
      : 0;
    console.log(`   Time Gap: ${timeDiff.toFixed(0)}ms`);
  });

  tracker.on('insight', (insight: AccessibilityInsight) => {
    console.log(`\n💡 ACCESSIBILITY INSIGHT!`);
    console.log(`   ${insight.type.toUpperCase()} - ${insight.severity.toUpperCase()}`);
    console.log(`   ${insight.description}`);
    
    if (insight.wcagReference) {
      console.log(`   📖 WCAG: ${insight.wcagReference}`);
    }
    
    if (insight.remediation?.description) {
      console.log(`   💡 Fix: ${insight.remediation.description}`);
    }
  });

  tracker.on('permissionRequired', (info: any) => {
    console.log(`\n🔒 PERMISSION REQUIRED: ${info.type}`);
    console.log(`   Reason: ${info.reason}`);
    if (info.instructions) {
      console.log('   Instructions:');
      info.instructions.forEach((instruction: string, idx: number) => {
        console.log(`   ${idx + 1}. ${instruction}`);
      });
    }
    console.log();
  });

  tracker.on('error', (error) => {
    console.error('❌ TrackerA11y Error:', error.message);
    
    if (error.message.includes('Accessibility permissions')) {
      console.log('\n🔒 Accessibility Permission Required:');
      console.log('   This is needed for system-wide interaction monitoring');
      console.log('   1. Open System Preferences → Security & Privacy');
      console.log('   2. Click Privacy tab → Accessibility');
      console.log('   3. Add Terminal or your IDE to allowed apps');
      console.log('   4. Restart this demo\n');
    }
  });

  // Statistics display timer
  const statsInterval = setInterval(() => {
    const stats = tracker.getStatistics();
    
    if (stats.eventsProcessed.total > 0) {
      console.log(`\n📊 Session Statistics (${Math.floor(stats.uptime / 1000)}s):`);
      console.log(`   Total Events: ${stats.eventsProcessed.total}`);
      console.log(`   Focus Changes: ${stats.eventsProcessed.focus}`);
      console.log(`   Interactions: ${stats.eventsProcessed.interaction}`);
      console.log(`   Audio Events: ${stats.eventsProcessed.audio}`);
      console.log(`   Correlations: ${stats.correlations.found}`);
      console.log(`   Insights Generated: ${stats.insights.generated}`);
      
      if (stats.insights.bySeverity) {
        const severities = Object.keys(stats.insights.bySeverity);
        if (severities.length > 0) {
          console.log(`   Insight Severity: ${severities.map(s => `${s}:${stats.insights.bySeverity[s]}`).join(', ')}`);
        }
      }
      console.log();
    }
  }, 20000); // Every 20 seconds

  // Add some custom correlation rules for interaction patterns
  tracker.addCorrelationRule({
    id: 'rapid-tab-navigation',
    name: 'Rapid Tab Key Navigation Detection',
    sources: ['interaction'],
    timeWindow: 5000000, // 5 seconds
    minConfidence: 0.8,
    handler: (events) => {
      // Look for rapid tab key presses
      const tabEvents = events.filter((e: any) => 
        e.source === 'interaction' && 
        e.data.interactionType === 'key' && 
        e.data.inputData?.key === 'Tab'
      );
      
      if (tabEvents.length >= 3) {
        return {
          primaryEvent: tabEvents[0],
          relatedEvents: tabEvents.slice(1),
          correlationType: 'temporal' as const,
          confidence: 0.9,
          insights: [{
            type: 'pattern' as const,
            severity: 'medium' as const,
            description: 'Rapid Tab navigation detected - user may be having difficulty finding focusable elements',
            wcagReference: 'WCAG 2.4.3 (Focus Order)',
            evidence: { interactionEvidence: tabEvents as any },
            remediation: {
              description: 'Review focus order and ensure all interactive elements are properly focusable',
              codeExample: 'element.tabIndex = 0; // Make element focusable'
            }
          }]
        };
      }
      return null;
    }
  });

  tracker.addCorrelationRule({
    id: 'click-after-tab',
    name: 'Mouse Click After Keyboard Navigation',
    sources: ['interaction'],
    timeWindow: 3000000, // 3 seconds
    minConfidence: 0.7,
    handler: (events) => {
      const keyEvent = events.find((e: any) => e.data.interactionType === 'key');
      const clickEvent = events.find((e: any) => e.data.interactionType === 'click');
      
      if (keyEvent && clickEvent && keyEvent.timestamp < clickEvent.timestamp) {
        return {
          primaryEvent: keyEvent,
          relatedEvents: [clickEvent],
          correlationType: 'causal' as const,
          confidence: 0.8,
          insights: [{
            type: 'pattern' as const,
            severity: 'low' as const,
            description: 'User switched from keyboard to mouse navigation - possible keyboard accessibility gap',
            evidence: { interactionEvidence: [keyEvent, clickEvent] as any },
            remediation: {
              description: 'Ensure all mouse-accessible functionality is also keyboard accessible'
            }
          }]
        };
      }
      return null;
    }
  });

  // Handle graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\n\n🛑 Shutting down interaction monitoring...');
    clearInterval(statsInterval);
    
    // Show final statistics
    const finalStats = tracker.getStatistics();
    
    console.log('\n📈 Final Session Summary:');
    console.log(`   Duration: ${Math.floor(finalStats.uptime / 1000)} seconds`);
    console.log(`   Total Events: ${finalStats.eventsProcessed.total}`);
    console.log(`   Focus Changes: ${finalStats.eventsProcessed.focus}`);
    console.log(`   Interactions: ${finalStats.eventsProcessed.interaction}`);
    console.log(`   Correlations Found: ${finalStats.correlations.found}`);
    console.log(`   Insights Generated: ${finalStats.insights.generated}`);
    
    await tracker.shutdown();
    console.log('✅ Interaction demo stopped');
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    await tracker.shutdown();
    process.exit(0);
  });

  try {
    // Initialize and start tracking
    console.log('🚀 Initializing TrackerA11y with interaction monitoring...');
    await tracker.initialize();
    
    console.log('▶️ Starting comprehensive tracking...');
    await tracker.start();

    console.log('👀 Watching for interactions and patterns...\n');
    
    // Keep the demo running
    await new Promise<void>((resolve) => {
      process.on('SIGINT', resolve);
      process.on('SIGTERM', resolve);
    });

  } catch (error) {
    console.error('💥 Failed to start interaction demo:', error);
    
    if (error instanceof Error) {
      if (error.message.includes('not supported')) {
        console.log('\n⚠️  Platform Limitation:');
        console.log('   Interaction monitoring requires platform-specific implementation');
        console.log('   Currently supports: macOS');
        console.log('   Windows and Linux support coming soon\n');
      }
    }
    
    process.exit(1);
  }
}

// Run the demo
if (require.main === module) {
  runInteractionDemo().catch(console.error);
}

export { runInteractionDemo };
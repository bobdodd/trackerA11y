#!/usr/bin/env ts-node
/**
 * Event Correlation Demo
 * Demonstrates real-time correlation between focus, audio, and interaction events
 */

import { TrackerA11yCore } from '../src/core/TrackerA11yCore';
import { 
  TrackerA11yConfig, 
  CorrelatedEvent, 
  AccessibilityInsight,
  TimestampedEvent 
} from '../src/types';

async function runCorrelationDemo() {
  console.log('🧠 Starting TrackerA11y Event Correlation Demo');
  console.log('🔗 This demo shows real-time correlation between different event sources');
  console.log('💡 Watch for accessibility insights generated from event patterns');
  console.log('⏱️  Press Ctrl+C to stop\n');

  const config: TrackerA11yConfig = {
    platforms: ['macos'],
    syncPrecision: 'microsecond',
    realTimeMonitoring: true,
    audioIntegration: {
      recordingQuality: '48khz',
      diarizationModel: 'pyannote/speaker-diarization-3.1',
      transcriptionModel: 'base', // Use smaller model for demo
      synchronizationMethod: 'bwf',
      realTimeProcessing: true,
      pythonPipelinePath: 'python3',
      sampleRate: 48000
    },
    outputFormats: ['json'],
  };

  const tracker = new TrackerA11yCore(config);

  // Set up event listeners
  tracker.on('initialized', () => {
    console.log('✅ TrackerA11y Core initialized');
  });

  tracker.on('started', () => {
    console.log('🎬 Tracking started - begin using your system to generate events\n');
  });

  tracker.on('eventProcessed', (event: TimestampedEvent) => {
    const timestamp = new Date(event.timestamp / 1000).toISOString();
    console.log(`📋 Event: ${event.source.toUpperCase()} at ${timestamp}`);
    
    if (event.source === 'focus') {
      console.log(`   Focus: ${(event as any).data.applicationName}`);
    } else if (event.source === 'audio') {
      const audioData = (event as any).data;
      console.log(`   Audio: "${audioData.text}" (${audioData.language})`);
    }
  });

  tracker.on('correlation', ({ correlation, ruleId }: { correlation: CorrelatedEvent, ruleId: string }) => {
    console.log('\n🔗 CORRELATION DETECTED!');
    console.log(`   Rule: ${ruleId}`);
    console.log(`   Type: ${correlation.correlationType}`);
    console.log(`   Confidence: ${(correlation.confidence * 100).toFixed(1)}%`);
    console.log(`   Primary Event: ${correlation.primaryEvent.source}`);
    console.log(`   Related Events: ${correlation.relatedEvents.map(e => e.source).join(', ')}`);
    
    const timeDiff = correlation.relatedEvents.length > 0 
      ? Math.abs(correlation.primaryEvent.timestamp - correlation.relatedEvents[0].timestamp) / 1000
      : 0;
    console.log(`   Time Difference: ${timeDiff.toFixed(0)}ms\n`);
  });

  tracker.on('insight', (insight: AccessibilityInsight) => {
    console.log(`\n💡 ACCESSIBILITY INSIGHT GENERATED!`);
    console.log(`   Type: ${insight.type.toUpperCase()}`);
    console.log(`   Severity: ${insight.severity.toUpperCase()}`);
    console.log(`   Description: ${insight.description}`);
    
    if (insight.wcagReference) {
      console.log(`   WCAG Reference: ${insight.wcagReference}`);
    }
    
    if (insight.evidence) {
      const evidenceTypes = [];
      if (insight.evidence.focusEvidence?.length) evidenceTypes.push('Focus');
      if (insight.evidence.audioEvidence?.length) evidenceTypes.push('Audio');
      if (insight.evidence.interactionEvidence?.length) evidenceTypes.push('Interaction');
      console.log(`   Evidence: ${evidenceTypes.join(', ')}`);
    }
    
    if (insight.remediation) {
      console.log(`   💡 Remedy: ${insight.remediation.description}`);
      if (insight.remediation.codeExample) {
        console.log(`   Code Example: ${insight.remediation.codeExample}`);
      }
    }
    console.log();
  });

  tracker.on('alert', (insight: AccessibilityInsight) => {
    console.log(`\n🚨 HIGH PRIORITY ALERT!`);
    console.log(`   ${insight.severity.toUpperCase()} SEVERITY`);
    console.log(`   ${insight.description}`);
    console.log();
  });

  tracker.on('error', (error) => {
    console.error('❌ TrackerA11y Error:', error.message);
    
    if (error.message.includes('Python')) {
      console.log('\n💡 Audio Processing Tips:');
      console.log('   • Ensure Python 3.9+ is installed');
      console.log('   • Install: pip install -r audio_pipeline/requirements.txt');
      console.log('   • For demo without audio: comment out audioIntegration in config\n');
    }
  });

  // Statistics display timer
  const statsInterval = setInterval(() => {
    const stats = tracker.getStatistics();
    console.log(`\n📊 Statistics (${Math.floor(stats.uptime / 1000)}s uptime):`);
    console.log(`   Events: ${stats.eventsProcessed.total} total (Focus: ${stats.eventsProcessed.focus}, Audio: ${stats.eventsProcessed.audio})`);
    console.log(`   Correlations: ${stats.correlations.found} found`);
    console.log(`   Insights: ${stats.insights.generated} generated`);
    console.log(`   Avg Processing: ${stats.performance.avgEventProcessingTime.toFixed(2)}ms\n`);
  }, 30000); // Every 30 seconds

  // Add some demo correlation rules
  tracker.addCorrelationRule({
    id: 'rapid-focus-changes',
    name: 'Rapid Focus Changes Detection',
    sources: ['focus'],
    timeWindow: 2000000, // 2 seconds in microseconds
    minConfidence: 0.8,
    handler: (events) => {
      if (events.length < 3) return null;
      
      // Check if focus changes rapidly between different applications
      const apps = new Set(events.map((e: any) => e.data.applicationName));
      if (apps.size >= 3) {
        return {
          primaryEvent: events[0],
          relatedEvents: events.slice(1),
          correlationType: 'temporal' as const,
          confidence: 0.9,
          insights: [{
            type: 'pattern' as const,
            severity: 'medium' as const,
            description: 'Rapid focus changes detected - possible navigation difficulty or confusion',
            evidence: { focusEvidence: events as any },
            remediation: {
              description: 'Consider improving navigation flow or providing clearer user guidance'
            }
          }]
        };
      }
      return null;
    }
  });

  // Handle graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\n\n🛑 Shutting down correlation demo...');
    clearInterval(statsInterval);
    
    // Show final statistics
    const finalStats = tracker.getStatistics();
    const recentInsights = tracker.getRecentInsights(10);
    
    console.log('\n📈 Final Session Summary:');
    console.log(`   Duration: ${Math.floor(finalStats.uptime / 1000)} seconds`);
    console.log(`   Total Events: ${finalStats.eventsProcessed.total}`);
    console.log(`   Correlations Found: ${finalStats.correlations.found}`);
    console.log(`   Insights Generated: ${finalStats.insights.generated}`);
    
    if (recentInsights.length > 0) {
      console.log('\n🔍 Recent Insights:');
      recentInsights.slice(-5).forEach((insight, idx) => {
        console.log(`   ${idx + 1}. [${insight.severity.toUpperCase()}] ${insight.description.substring(0, 80)}...`);
      });
    }
    
    await tracker.shutdown();
    console.log('✅ Correlation demo stopped');
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    await tracker.shutdown();
    process.exit(0);
  });

  try {
    // Initialize and start tracking
    console.log('🚀 Initializing TrackerA11y Core...');
    await tracker.initialize();
    
    console.log('▶️ Starting event tracking...');
    await tracker.start();

    // Test current focus
    const currentFocus = await tracker.getCurrentFocus();
    if (currentFocus) {
      console.log(`🎯 Current Focus: ${currentFocus.data.applicationName}`);
    }

    console.log('\n📋 Demo Instructions:');
    console.log('   • Switch between different applications (⌘+Tab on macOS)');
    console.log('   • Try voice commands or speak near your microphone');
    console.log('   • Use keyboard navigation (Tab, arrows)');
    console.log('   • The system will correlate events and generate insights\n');

    console.log('👀 Watching for events and correlations...\n');
    
    // Keep the demo running
    await new Promise<void>((resolve) => {
      process.on('SIGINT', resolve);
      process.on('SIGTERM', resolve);
    });

  } catch (error) {
    console.error('💥 Failed to start correlation demo:', error);
    
    if (error instanceof Error) {
      if (error.message.includes('Accessibility')) {
        console.log('\n🔒 Accessibility Permission Required:');
        console.log('   1. Open System Preferences → Security & Privacy');
        console.log('   2. Click Privacy tab → Accessibility');
        console.log('   3. Add Terminal or your IDE to allowed apps');
        console.log('   4. Restart this demo\n');
      }
    }
    
    process.exit(1);
  }
}

// Run the demo
if (require.main === module) {
  runCorrelationDemo().catch(console.error);
}

export { runCorrelationDemo };
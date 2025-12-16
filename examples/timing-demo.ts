#!/usr/bin/env ts-node
/**
 * Timing Synchronization Demo
 * Demonstrates microsecond-precision timing and cross-component synchronization
 */

import { TrackerA11yCore } from '../src/core/TrackerA11yCore';
import { 
  TrackerA11yConfig, 
  TimestampedEvent,
  FocusEvent,
  InteractionEvent
} from '../src/types';

async function runTimingDemo() {
  console.log('⏱️  Starting TrackerA11y Timing Synchronization Demo');
  console.log('🔬 This demo demonstrates microsecond-precision timing across all event sources');
  console.log('📊 Press Ctrl+C to stop and see timing analysis\n');

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

  // Set up event listeners for timing analysis
  tracker.on('initialized', () => {
    console.log('✅ TrackerA11y Core initialized with microsecond timing precision');
    
    const timingMetrics = tracker.getTimeSyncMetrics();
    console.log('⏰ Time Sync Metrics:');
    console.log(`   Accuracy: ${timingMetrics.accuracy}μs`);
    console.log(`   Precision: ${timingMetrics.precision}μs`);
    console.log(`   Drift: ${timingMetrics.drift.toFixed(3)}μs/s`);
    console.log();
  });

  tracker.on('started', () => {
    console.log('🎬 Timing-synchronized tracking started\n');
    console.log('📋 Demo Instructions:');
    console.log('   • Interact with your system (keyboard, mouse, switching apps)');
    console.log('   • Watch the precise timing measurements');
    console.log('   • Notice the microsecond-level synchronization');
    console.log('   • Press Ctrl+C to see timing analysis\n');
  });

  const eventTiming: Array<{
    event: TimestampedEvent;
    processingTime: number;
    syncedTime: number;
  }> = [];

  tracker.on('eventProcessed', (event: TimestampedEvent) => {
    const processingTime = performance.now();
    const syncedTime = tracker.getSynchronizedTime();
    
    // Store timing data for analysis
    eventTiming.push({
      event,
      processingTime,
      syncedTime
    });

    const timestamp = new Date(event.timestamp / 1000).toISOString().split('T')[1].split('.')[0];
    const timingInfo = (event.metadata as any)?.timing;
    
    console.log(`📅 Event: ${event.source.toUpperCase()} at ${timestamp}`);
    
    if (event.source === 'interaction') {
      const interactionEvent = event as InteractionEvent;
      const { interactionType } = interactionEvent.data;
      console.log(`   Type: ${interactionType}`);
    } else if (event.source === 'focus') {
      const focusEvent = event as FocusEvent;
      console.log(`   App: ${focusEvent.data.applicationName}`);
    }
    
    if (timingInfo) {
      console.log(`   ⏱️  Sync Delta: ${((timingInfo.syncedTime - timingInfo.sourceTime) / 1000).toFixed(2)}ms`);
      console.log(`   🎯 Uncertainty: ±${timingInfo.uncertainty.toFixed(1)}μs`);
      console.log(`   🪟 Correlation Window: ${timingInfo.correlationWindow}`);
    }
    
    console.log();
  });

  // Time sync events
  tracker.on('calibrated', (metrics) => {
    console.log(`🔧 Time calibrated - Precision: ${metrics.precision.toFixed(2)}μs`);
  });

  tracker.on('ntpSynced', ({ offset, latency }) => {
    console.log(`🌐 NTP synced - Offset: ${offset.toFixed(1)}μs, Latency: ${latency.toFixed(1)}μs`);
  });

  tracker.on('driftDetected', (drift) => {
    console.log(`⚠️  Clock drift detected: ${drift.toFixed(2)}μs/s`);
  });

  // Periodic timing statistics
  const statsInterval = setInterval(() => {
    if (eventTiming.length > 0) {
      console.log(`\n📊 Timing Statistics (${eventTiming.length} events):`);\n      
      const timingStats = tracker.getEventTimingStatistics();
      const syncMetrics = tracker.getTimeSyncMetrics();
      const validation = tracker.validateEventTiming();
      
      console.log('   📈 Event Timing:');
      console.log(`      Average Interval: ${(timingStats.averageInterval / 1000).toFixed(2)}ms`);
      console.log(`      Frequency: ${timingStats.frequency.toFixed(2)} Hz`);
      console.log(`      Time Span: ${(timingStats.timeSpan / 1000000).toFixed(2)}s`);
      console.log(`      Sync Accuracy: ±${timingStats.synchronizationAccuracy.toFixed(1)}μs`);
      
      console.log('   🎯 Synchronization:');
      console.log(`      Precision: ${syncMetrics.precision.toFixed(2)}μs`);
      console.log(`      Accuracy: ${syncMetrics.accuracy.toFixed(2)}μs`);
      console.log(`      Drift: ${syncMetrics.drift.toFixed(3)}μs/s`);
      console.log(`      Stability: ${syncMetrics.stability.toFixed(3)}`);
      
      if (!validation.isValid) {
        console.log('   ⚠️  Timing Issues:');
        validation.issues.forEach(issue => console.log(`      • ${issue}`));
      } else {
        console.log('   ✅ Timing validation: PASSED');
      }
      console.log();
    }
  }, 15000); // Every 15 seconds

  // Handle graceful shutdown with detailed timing analysis
  process.on('SIGINT', async () => {
    console.log('\n\n🛑 Shutting down timing demo...');
    clearInterval(statsInterval);
    
    // Final comprehensive timing analysis
    console.log('\n📈 Final Timing Analysis:');
    
    if (eventTiming.length > 0) {
      const finalStats = tracker.getEventTimingStatistics();
      const syncMetrics = tracker.getTimeSyncMetrics();
      const validation = tracker.validateEventTiming();
      
      console.log('\n🎯 Synchronization Performance:');
      console.log(`   Total Events Processed: ${eventTiming.length}`);
      console.log(`   Session Duration: ${(finalStats.timeSpan / 1000000).toFixed(2)} seconds`);
      console.log(`   Average Event Rate: ${finalStats.frequency.toFixed(2)} events/sec`);
      console.log(`   Timing Precision: ±${syncMetrics.precision.toFixed(2)}μs`);
      console.log(`   Timing Accuracy: ±${syncMetrics.accuracy.toFixed(2)}μs`);
      console.log(`   Clock Stability: ${syncMetrics.stability.toFixed(4)}`);
      console.log(`   Detected Drift: ${syncMetrics.drift.toFixed(3)}μs/s`);
      
      console.log('\n⏱️  Event Timing Distribution:');
      const intervals = [];
      for (let i = 1; i < eventTiming.length; i++) {
        const interval = eventTiming[i].event.timestamp - eventTiming[i-1].event.timestamp;
        intervals.push(interval / 1000); // Convert to milliseconds
      }
      
      if (intervals.length > 0) {
        intervals.sort((a, b) => a - b);
        const median = intervals[Math.floor(intervals.length / 2)];
        const p95 = intervals[Math.floor(intervals.length * 0.95)];
        
        console.log(`   Min Interval: ${Math.min(...intervals).toFixed(2)}ms`);
        console.log(`   Median Interval: ${median.toFixed(2)}ms`);
        console.log(`   95th Percentile: ${p95.toFixed(2)}ms`);
        console.log(`   Max Interval: ${Math.max(...intervals).toFixed(2)}ms`);
      }
      
      // Event source breakdown
      const sourceBreakdown: Record<string, number> = {};
      for (const timing of eventTiming) {
        const source = timing.event.source;
        sourceBreakdown[source] = (sourceBreakdown[source] || 0) + 1;
      }
      
      console.log('\n📊 Event Source Breakdown:');
      Object.entries(sourceBreakdown).forEach(([source, count]) => {
        const percentage = ((count / eventTiming.length) * 100).toFixed(1);
        console.log(`   ${source}: ${count} events (${percentage}%)`);
      });
      
      // Timing validation results
      console.log('\n🔍 Timing Validation:');
      if (validation.isValid) {
        console.log('   ✅ All timing checks PASSED');
        console.log('   🎯 Events are properly synchronized');
        console.log('   ⏰ No timing anomalies detected');
      } else {
        console.log('   ⚠️  Timing validation issues detected:');
        validation.issues.forEach(issue => console.log(`   • ${issue}`));
      }
    } else {
      console.log('   📊 No timing data collected during session');
    }
    
    await tracker.shutdown();
    console.log('\n✅ Timing demo completed');
    console.log('📊 Microsecond-precision timing demonstrated successfully');
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    await tracker.shutdown();
    process.exit(0);
  });

  try {
    // Initialize and start tracking with timing
    console.log('🚀 Initializing TrackerA11y with microsecond timing...');
    await tracker.initialize();
    
    console.log('▶️ Starting synchronized tracking...');
    await tracker.start();

    console.log('👀 Monitoring timing precision...\n');
    
    // Keep the demo running
    await new Promise<void>((resolve) => {
      process.on('SIGINT', resolve);
      process.on('SIGTERM', resolve);
    });

  } catch (error) {
    console.error('💥 Failed to start timing demo:', error);
    
    if (error instanceof Error) {
      if (error.message.includes('not supported')) {
        console.log('\n⚠️  Platform Limitation:');
        console.log('   Microsecond timing requires platform-specific implementation');
        console.log('   Currently supports: macOS with Core Graphics');
        console.log('   Timing accuracy may be reduced on this platform\n');
      }
    }
    
    process.exit(1);
  }
}

// Run the demo
if (require.main === module) {
  runTimingDemo().catch(console.error);
}

export { runTimingDemo };
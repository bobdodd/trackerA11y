#!/usr/bin/env ts-node
/**
 * Audio Processing Pipeline Demo
 * Demonstrates real-time audio recording, diarization, and transcription
 */

import { AudioProcessorBridge } from '../src/bridge/AudioProcessorBridge';
import { AudioConfig, AudioEvent } from '../src/types';
import * as fs from 'fs';
import * as path from 'path';

async function runAudioProcessingDemo() {
  console.log('🎤 Starting TrackerA11y Audio Processing Demo');
  console.log('🔊 This demo requires Python dependencies to be installed');
  console.log('📋 Make sure you have run: pip install -r audio_pipeline/requirements.txt');
  console.log('⏱️  Press Ctrl+C to stop\n');

  const config: AudioConfig = {
    sampleRate: 48000,
    diarizationModel: 'pyannote/speaker-diarization-3.1',
    transcriptionModel: 'base', // Use smaller model for demo
    recordingQuality: '48khz',
    realTimeProcessing: true,
    pythonPipelinePath: 'python3'
  };

  const audioProcessor = new AudioProcessorBridge(config);

  // Set up event listeners
  audioProcessor.on('initialized', () => {
    console.log('✅ Audio processing pipeline initialized successfully');
    console.log('🎯 Ready to process audio data');
  });

  audioProcessor.on('audioEvents', (events: AudioEvent[]) => {
    console.log('\n🎙️  Audio Events Detected:');
    
    for (const event of events) {
      const { text, language, confidence, speakers, totalSpeakers } = event.data;
      const timestamp = new Date(event.timestamp / 1000).toISOString();
      
      console.log(`   Time: ${timestamp}`);
      console.log(`   Language: ${language.toUpperCase()}`);
      console.log(`   Confidence: ${(confidence * 100).toFixed(1)}%`);
      console.log(`   Speakers: ${totalSpeakers}`);
      
      if (speakers && speakers.length > 0) {
        console.log('   Speaker Timeline:');
        for (const speaker of speakers) {
          console.log(`     ${speaker.speaker_id}: ${speaker.start_time.toFixed(1)}s - ${speaker.end_time.toFixed(1)}s`);
        }
      }
      
      console.log(`   Text: "${text}"`);
      console.log('   ---');
    }
  });

  audioProcessor.on('status', (status: any) => {
    console.log('📊 Pipeline Status:', {
      recording: status.is_recording,
      processing: status.is_processing,
      processed: status.total_processed,
      avgTime: `${status.average_processing_time?.toFixed(2) || 0}s`
    });
  });

  audioProcessor.on('error', (error) => {
    console.error('❌ Audio processing error:', error.message);
    
    if (error.message.includes('Python')) {
      console.log('\n💡 Troubleshooting Tips:');
      console.log('   1. Ensure Python 3.9+ is installed');
      console.log('   2. Install dependencies: pip install -r audio_pipeline/requirements.txt');
      console.log('   3. Check Python path in config');
      console.log('   4. Verify audio_pipeline directory exists\n');
    }
  });

  // Handle graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\n\n🛑 Shutting down audio processing...');
    await audioProcessor.shutdown();
    console.log('✅ Audio processing stopped');
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    console.log('\n\n🛑 Shutting down audio processing...');
    await audioProcessor.shutdown();
    process.exit(0);
  });

  try {
    // Initialize the audio processor
    console.log('🚀 Initializing audio processing pipeline...');
    await audioProcessor.initialize();

    // Test with sample audio file if available
    const sampleAudioPath = path.join(__dirname, '../test-data/sample-audio.wav');
    
    if (fs.existsSync(sampleAudioPath)) {
      console.log('\n📂 Processing sample audio file...');
      
      // Read audio file
      const audioData = fs.readFileSync(sampleAudioPath);
      const sessionId = `demo-session-${Date.now()}`;
      
      console.log(`📊 Audio file: ${audioData.length} bytes`);
      
      // Process the audio
      const events = await audioProcessor.processAudioData(audioData, sessionId);
      
      console.log(`✨ Processing complete! Generated ${events.length} events`);
      
    } else {
      console.log('\n📝 No sample audio file found.');
      console.log('   Create test-data/sample-audio.wav to test file processing');
    }

    // Test with synthetic audio data
    console.log('\n🔬 Testing with synthetic audio data...');
    
    const syntheticAudio = Buffer.alloc(48000 * 2); // 1 second of 16-bit audio
    // Fill with simple sine wave
    for (let i = 0; i < syntheticAudio.length; i += 2) {
      const sample = Math.sin(2 * Math.PI * 440 * i / (48000 * 2)) * 16384;
      syntheticAudio.writeInt16LE(Math.round(sample), i);
    }
    
    const syntheticSessionId = `synthetic-session-${Date.now()}`;
    
    console.log('📊 Synthetic audio: 1 second, 440Hz sine wave');
    
    try {
      const syntheticEvents = await audioProcessor.processAudioData(
        syntheticAudio, 
        syntheticSessionId
      );
      
      console.log(`✨ Synthetic processing complete! Generated ${syntheticEvents.length} events`);
    } catch (error) {
      console.log('⚠️  Synthetic audio processing failed (expected for sine wave)');
    }

    // Keep the demo running for real-time events
    console.log('\n👀 Audio processing pipeline is now ready');
    console.log('🔄 Waiting for audio processing events... (Press Ctrl+C to stop)');
    
    // Prevent process from exiting
    await new Promise<void>((resolve) => {
      process.on('SIGINT', resolve);
      process.on('SIGTERM', resolve);
    });

  } catch (error) {
    console.error('💥 Failed to start audio processing:', error);
    
    if (error instanceof Error) {
      if (error.message.includes('ENOENT') || error.message.includes('spawn')) {
        console.log('\n💡 Python executable not found. Try:');
        console.log('   - Installing Python 3.9+');
        console.log('   - Setting pythonPipelinePath in config');
        console.log('   - Adding Python to your PATH');
      }
    }
    
    process.exit(1);
  }
}

// Run the demo
if (require.main === module) {
  runAudioProcessingDemo().catch(console.error);
}

export { runAudioProcessingDemo };
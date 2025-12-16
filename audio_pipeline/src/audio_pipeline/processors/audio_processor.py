#!/usr/bin/env python3
"""
Main audio processor orchestrating recording, diarization, and transcription
Provides unified interface for audio analysis pipeline
"""

import asyncio
import logging
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, List, Dict, Any, Callable
from dataclasses import dataclass

import numpy as np
from numpy.typing import NDArray

from .recorder import AudioRecorder, AudioConfig, AudioChunk
from .diarization import SpeakerDiarizer, DiarizationResult, SpeakerSegment  
from .transcription import TranscriptionProcessor, TranscriptionResult, TranscriptionSegment


@dataclass
class AudioEvent:
    """Unified audio event combining transcription and speaker data"""
    id: str
    timestamp: float  # microseconds
    source: str = "audio"
    
    # Audio metadata
    session_id: str = ""
    processing_time: float = 0.0
    
    # Transcription data
    text: str = ""
    language: str = ""
    confidence: float = 0.0
    
    # Speaker data
    speaker_id: Optional[str] = None
    speaker_segments: List[SpeakerSegment] = None
    
    # Timing
    start_time: float = 0.0  # seconds in audio
    end_time: float = 0.0    # seconds in audio
    
    def __post_init__(self):
        if self.speaker_segments is None:
            self.speaker_segments = []


@dataclass
class ProcessingConfig:
    """Configuration for audio processing pipeline"""
    # Recording settings
    sample_rate: int = 48000
    channels: int = 1
    chunk_duration: float = 5.0  # seconds per processing chunk
    
    # Processing settings
    real_time: bool = True
    process_interval: float = 2.0  # seconds between processing
    min_audio_duration: float = 1.0  # minimum audio to process
    
    # Model settings
    diarization_model: str = "pyannote/speaker-diarization-3.1"
    transcription_model: str = "large-v3"
    
    # Performance settings
    max_concurrent_processing: int = 2
    buffer_duration: float = 30.0


class AudioProcessor:
    """
    Main audio processing orchestrator
    Coordinates recording, diarization, and transcription
    """
    
    def __init__(self, 
                 config: Optional[ProcessingConfig] = None,
                 diarization_model: str = "pyannote/speaker-diarization-3.1",
                 transcription_model: str = "large-v3", 
                 sample_rate: int = 48000,
                 real_time: bool = True):
        
        # Handle legacy parameter format
        if config is None:
            config = ProcessingConfig(
                diarization_model=diarization_model,
                transcription_model=transcription_model, 
                sample_rate=sample_rate,
                real_time=real_time
            )
            
        self.config = config
        self.logger = logging.getLogger(__name__)
        
        # Core components
        self.recorder = AudioRecorder(AudioConfig(
            sample_rate=config.sample_rate,
            channels=config.channels,
            buffer_duration=config.buffer_duration
        ))
        
        self.diarizer = SpeakerDiarizer(config.diarization_model)
        self.transcriber = TranscriptionProcessor(config.transcription_model)
        
        # State management
        self._is_initialized = False
        self._is_processing = False
        self._session_id = ""
        
        # Processing control
        self._processing_queue: asyncio.Queue[List[AudioChunk]] = asyncio.Queue()
        self._result_callback: Optional[Callable[[AudioEvent], None]] = None
        self._processing_tasks: List[asyncio.Task] = []
        
        # Audio buffer management
        self._audio_buffer: List[AudioChunk] = []
        self._last_processing_time = 0.0
        
    def set_result_callback(self, callback: Callable[[AudioEvent], None]) -> None:
        """Set callback for processed audio events"""
        self._result_callback = callback
        
    async def initialize(self) -> None:
        """Initialize all audio processing components"""
        if self._is_initialized:
            return
            
        self._session_id = str(uuid.uuid4())
        self.logger.info(f"Initializing audio processor for session {self._session_id}")
        
        try:
            # Initialize components in parallel
            await asyncio.gather(
                self.recorder.initialize(self._session_id),
                self.diarizer.initialize(), 
                self.transcriber.initialize()
            )
            
            # Set up recorder callback for real-time processing
            if self.config.real_time:
                self.recorder.set_chunk_callback(self._on_audio_chunk)
                
            self._is_initialized = True
            self.logger.info("Audio processor initialized successfully")
            
        except Exception as e:
            self.logger.error(f"Failed to initialize audio processor: {e}")
            raise
            
    def _on_audio_chunk(self, chunk: AudioChunk) -> None:
        """Handle real-time audio chunks from recorder"""
        self._audio_buffer.append(chunk)
        
        # Check if we should process accumulated audio
        current_time = chunk.timestamp
        time_since_last_processing = current_time - self._last_processing_time
        
        if time_since_last_processing >= self.config.process_interval:
            # Check if we have enough audio to process
            total_duration = sum(
                len(c.data) / c.sample_rate for c in self._audio_buffer
            )
            
            if total_duration >= self.config.min_audio_duration:
                # Queue for processing
                buffer_copy = self._audio_buffer.copy()
                self._audio_buffer.clear()
                self._last_processing_time = current_time
                
                # Add to processing queue (non-blocking)
                try:
                    self._processing_queue.put_nowait(buffer_copy)
                except asyncio.QueueFull:
                    self.logger.warning("Processing queue full, dropping audio chunk")
                    
    async def start_recording(self) -> None:
        """Start real-time audio recording and processing"""
        if not self._is_initialized:
            raise RuntimeError("Audio processor not initialized")
            
        if self._is_processing:
            raise RuntimeError("Audio processing already in progress")
            
        self.logger.info("Starting audio recording and processing...")
        
        # Start recorder
        await self.recorder.start_recording()
        
        # Start processing workers if in real-time mode
        if self.config.real_time:
            for i in range(self.config.max_concurrent_processing):
                task = asyncio.create_task(
                    self._processing_worker(f"worker-{i}")
                )
                self._processing_tasks.append(task)
                
        self._is_processing = True
        self.logger.info("Audio recording and processing started")
        
    async def stop_recording(self) -> None:
        """Stop recording and finish processing"""
        if not self._is_processing:
            return
            
        self.logger.info("Stopping audio recording and processing...")
        
        # Stop recorder
        await self.recorder.stop_recording()
        
        # Process any remaining audio in buffer
        if self._audio_buffer:
            final_chunks = self._audio_buffer.copy()
            self._audio_buffer.clear()
            
            # Process final chunks
            if final_chunks:
                await self._process_audio_chunks(final_chunks, "final")
                
        # Signal processing workers to stop and wait for completion
        for _ in range(len(self._processing_tasks)):
            await self._processing_queue.put(None)  # Sentinel value
            
        if self._processing_tasks:
            await asyncio.gather(*self._processing_tasks, return_exceptions=True)
            
        self._processing_tasks.clear()
        self._is_processing = False
        
        self.logger.info("Audio processing stopped")
        
    async def _processing_worker(self, worker_id: str) -> None:
        """Background worker for processing audio chunks"""
        self.logger.debug(f"Processing worker {worker_id} started")
        
        try:
            while True:
                # Get audio chunks from queue
                chunks = await self._processing_queue.get()
                
                # Check for sentinel value (stop signal)
                if chunks is None:
                    break
                    
                # Process the chunks
                await self._process_audio_chunks(chunks, worker_id)
                
        except Exception as e:
            self.logger.error(f"Processing worker {worker_id} error: {e}")
        finally:
            self.logger.debug(f"Processing worker {worker_id} stopped")
            
    async def _process_audio_chunks(self, chunks: List[AudioChunk], 
                                  worker_id: str) -> None:
        """Process a batch of audio chunks"""
        if not chunks:
            return
            
        start_time = asyncio.get_event_loop().time()
        
        try:
            # Combine chunks into single audio array
            audio_arrays = [chunk.data for chunk in chunks]
            combined_audio = np.concatenate(audio_arrays)
            
            sample_rate = chunks[0].sample_rate
            duration = len(combined_audio) / sample_rate
            
            self.logger.debug(
                f"Worker {worker_id}: Processing {duration:.2f}s of audio "
                f"({len(chunks)} chunks)"
            )
            
            # Run diarization and transcription in parallel
            diarization_task = asyncio.create_task(
                self.diarizer.diarize_audio_data(
                    combined_audio, sample_rate, self._session_id
                )
            )
            
            transcription_task = asyncio.create_task(
                self.transcriber.transcribe_audio_data(
                    combined_audio, sample_rate, self._session_id
                )
            )
            
            # Wait for both to complete
            diarization_result, transcription_result = await asyncio.gather(
                diarization_task, transcription_task
            )
            
            # Align transcription with speaker diarization
            aligned_transcription = self.transcriber.align_with_speaker_diarization(
                transcription_result, diarization_result.segments
            )
            
            # Convert to audio events
            audio_events = self._create_audio_events(
                aligned_transcription, diarization_result, chunks
            )
            
            processing_time = asyncio.get_event_loop().time() - start_time
            
            self.logger.info(
                f"Worker {worker_id}: Processed {duration:.2f}s audio in {processing_time:.2f}s "
                f"({len(audio_events)} events, {diarization_result.total_speakers} speakers)"
            )
            
            # Send events to callback
            if self._result_callback:
                for event in audio_events:
                    self._result_callback(event)
                    
        except Exception as e:
            self.logger.error(f"Worker {worker_id}: Processing failed: {e}")
            
    def _create_audio_events(self, transcription: TranscriptionResult,
                           diarization: DiarizationResult,
                           chunks: List[AudioChunk]) -> List[AudioEvent]:
        """Create audio events from transcription and diarization results"""
        events = []
        
        # Group transcription segments by speaker
        speaker_texts: Dict[str, List[TranscriptionSegment]] = {}
        
        for segment in transcription.segments:
            speaker_id = segment.speaker_id or "unknown"
            if speaker_id not in speaker_texts:
                speaker_texts[speaker_id] = []
            speaker_texts[speaker_id].append(segment)
            
        # Create events for each speaker's speech segments
        for speaker_id, segments in speaker_texts.items():
            if not segments:
                continue
                
            # Combine consecutive segments from same speaker
            combined_text = " ".join(seg.text for seg in segments)
            
            # Find corresponding speaker segments for timing
            speaker_segments = [
                seg for seg in diarization.segments 
                if seg.speaker_id == speaker_id
            ]
            
            # Calculate overall timing
            start_time = min(seg.start_time for seg in segments)
            end_time = max(seg.end_time for seg in segments)
            
            # Calculate confidence
            avg_confidence = np.mean([seg.confidence for seg in segments])
            
            # Find overlapping audio chunks
            chunk_start_time = chunks[0].timestamp if chunks else 0
            relative_start = start_time
            relative_end = end_time
            
            event = AudioEvent(
                id=str(uuid.uuid4()),
                timestamp=int((chunk_start_time + relative_start) * 1000000),  # microseconds
                session_id=self._session_id,
                processing_time=transcription.processing_time,
                text=combined_text.strip(),
                language=transcription.language,
                confidence=avg_confidence,
                speaker_id=speaker_id,
                speaker_segments=speaker_segments,
                start_time=relative_start,
                end_time=relative_end
            )
            
            events.append(event)
            
        # Sort events by start time
        events.sort(key=lambda x: x.start_time)
        
        return events
        
    async def process_audio_file(self, audio_path: Path) -> List[AudioEvent]:
        """Process a complete audio file (batch mode)"""
        if not self._is_initialized:
            raise RuntimeError("Audio processor not initialized")
            
        self.logger.info(f"Processing audio file: {audio_path}")
        
        try:
            # Run diarization and transcription in parallel
            diarization_task = asyncio.create_task(
                self.diarizer.diarize_audio_file(audio_path, self._session_id)
            )
            
            transcription_task = asyncio.create_task(
                self.transcriber.transcribe_audio_file(audio_path, self._session_id)
            )
            
            diarization_result, transcription_result = await asyncio.gather(
                diarization_task, transcription_task
            )
            
            # Align transcription with diarization
            aligned_transcription = self.transcriber.align_with_speaker_diarization(
                transcription_result, diarization_result.segments
            )
            
            # Create audio events
            events = self._create_audio_events(
                aligned_transcription, diarization_result, []
            )
            
            self.logger.info(
                f"File processing complete: {len(events)} events, "
                f"{diarization_result.total_speakers} speakers"
            )
            
            return events
            
        except Exception as e:
            self.logger.error(f"File processing failed: {e}")
            raise
            
    async def run_standalone(self) -> None:
        """Run in standalone mode for testing"""
        self.logger.info("Running audio processor in standalone mode")
        
        # Set up a simple callback to log events
        def log_event(event: AudioEvent):
            self.logger.info(
                f"Audio Event: Speaker {event.speaker_id} "
                f"[{event.start_time:.2f}-{event.end_time:.2f}s]: "
                f'"{event.text}"'
            )
            
        self.set_result_callback(log_event)
        
        # Start recording
        await self.start_recording()
        
        try:
            # Keep running until interrupted
            while True:
                await asyncio.sleep(1.0)
        except KeyboardInterrupt:
            self.logger.info("Standalone mode interrupted")
        finally:
            await self.stop_recording()
            
    @property
    def is_initialized(self) -> bool:
        return self._is_initialized
        
    @property
    def is_processing(self) -> bool:
        return self._is_processing
        
    @property
    def session_id(self) -> str:
        return self._session_id
        
    async def cleanup(self) -> None:
        """Clean up all audio processing resources"""
        if self._is_processing:
            await self.stop_recording()
            
        await asyncio.gather(
            self.recorder.cleanup(),
            self.diarizer.cleanup(),
            self.transcriber.cleanup(),
            return_exceptions=True
        )
        
        self._is_initialized = False
        self.logger.info("Audio processor cleanup complete")
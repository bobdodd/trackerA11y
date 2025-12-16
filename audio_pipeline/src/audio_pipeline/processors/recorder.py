#!/usr/bin/env python3
"""
Audio recording functionality for TrackerA11y
Real-time audio capture with configurable quality and chunked processing
"""

import asyncio
import logging
import threading
import time
from queue import Queue, Empty
from typing import Optional, Callable, AsyncGenerator
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf
from numpy.typing import NDArray

try:
    import pyaudio
    PYAUDIO_AVAILABLE = True
except ImportError:
    PYAUDIO_AVAILABLE = False
    logging.warning("PyAudio not available, falling back to soundfile only")


@dataclass
class AudioConfig:
    """Configuration for audio recording"""
    sample_rate: int = 48000
    channels: int = 1  # Mono for speech processing
    chunk_size: int = 4096
    format: int = 16  # 16-bit samples
    device_index: Optional[int] = None
    buffer_duration: float = 30.0  # seconds
    
    @property
    def frames_per_buffer(self) -> int:
        return self.chunk_size
    
    @property
    def buffer_frames(self) -> int:
        return int(self.sample_rate * self.buffer_duration)


@dataclass 
class AudioChunk:
    """Represents a chunk of audio data with metadata"""
    data: NDArray[np.float32]
    timestamp: float
    sample_rate: int
    channels: int
    chunk_id: int
    session_id: str


class AudioRecorder:
    """
    Real-time audio recorder with chunked processing support
    """
    
    def __init__(self, config: Optional[AudioConfig] = None):
        self.config = config or AudioConfig()
        self.logger = logging.getLogger(__name__)
        
        self._is_recording = False
        self._stream: Optional[pyaudio.Stream] = None
        self._pyaudio: Optional[pyaudio.PyAudio] = None
        self._audio_queue: Queue[AudioChunk] = Queue()
        self._chunk_counter = 0
        self._session_id = ""
        
        # Callback for real-time processing
        self._chunk_callback: Optional[Callable[[AudioChunk], None]] = None
        
        # Circular buffer for continuous recording
        self._buffer: Optional[NDArray[np.float32]] = None
        self._buffer_pos = 0
        self._buffer_lock = threading.Lock()
        
    def set_chunk_callback(self, callback: Callable[[AudioChunk], None]) -> None:
        """Set callback for real-time chunk processing"""
        self._chunk_callback = callback
        
    async def initialize(self, session_id: str) -> None:
        """Initialize audio recording system"""
        self._session_id = session_id
        
        if not PYAUDIO_AVAILABLE:
            raise RuntimeError("PyAudio is required for audio recording")
            
        self._pyaudio = pyaudio.PyAudio()
        
        # Initialize circular buffer
        self._buffer = np.zeros(
            (self.config.buffer_frames, self.config.channels), 
            dtype=np.float32
        )
        
        # List available audio devices for debugging
        self._log_audio_devices()
        
        self.logger.info(f"Audio recorder initialized for session {session_id}")
        
    def _log_audio_devices(self) -> None:
        """Log available audio input devices"""
        if not self._pyaudio:
            return
            
        device_count = self._pyaudio.get_device_count()
        self.logger.info(f"Available audio devices ({device_count}):")
        
        for i in range(device_count):
            device_info = self._pyaudio.get_device_info_by_index(i)
            if device_info['maxInputChannels'] > 0:
                self.logger.info(
                    f"  {i}: {device_info['name']} "
                    f"(channels: {device_info['maxInputChannels']}, "
                    f"rate: {device_info['defaultSampleRate']})"
                )
                
    def _audio_callback(self, in_data: bytes, frame_count: int, 
                       time_info: dict, status_flags: int) -> tuple:
        """PyAudio callback for real-time audio processing"""
        try:
            # Convert bytes to numpy array
            audio_data = np.frombuffer(in_data, dtype=np.int16)
            audio_data = audio_data.astype(np.float32) / 32768.0  # Normalize to [-1, 1]
            
            if self.config.channels == 1:
                audio_data = audio_data.reshape(-1, 1)
            else:
                audio_data = audio_data.reshape(-1, self.config.channels)
                
            # Store in circular buffer
            with self._buffer_lock:
                if self._buffer is not None:
                    end_pos = self._buffer_pos + frame_count
                    if end_pos <= self.config.buffer_frames:
                        self._buffer[self._buffer_pos:end_pos] = audio_data
                    else:
                        # Wrap around
                        first_part = self.config.buffer_frames - self._buffer_pos
                        self._buffer[self._buffer_pos:] = audio_data[:first_part]
                        self._buffer[:end_pos - self.config.buffer_frames] = audio_data[first_part:]
                    
                    self._buffer_pos = end_pos % self.config.buffer_frames
            
            # Create audio chunk for processing
            chunk = AudioChunk(
                data=audio_data.flatten() if self.config.channels == 1 else audio_data,
                timestamp=time.time(),
                sample_rate=self.config.sample_rate,
                channels=self.config.channels,
                chunk_id=self._chunk_counter,
                session_id=self._session_id
            )
            
            self._chunk_counter += 1
            
            # Queue for async processing
            try:
                self._audio_queue.put_nowait(chunk)
            except:
                pass  # Queue full, skip this chunk
                
            # Call real-time callback if set
            if self._chunk_callback:
                self._chunk_callback(chunk)
                
        except Exception as e:
            self.logger.error(f"Audio callback error: {e}")
            
        return (None, pyaudio.paContinue)
        
    async def start_recording(self) -> None:
        """Start real-time audio recording"""
        if self._is_recording:
            raise RuntimeError("Recording already in progress")
            
        if not self._pyaudio:
            raise RuntimeError("Audio recorder not initialized")
            
        self.logger.info("Starting audio recording...")
        
        # Determine audio format
        if self.config.format == 16:
            pa_format = pyaudio.paInt16
        elif self.config.format == 24:
            pa_format = pyaudio.paInt24  
        else:
            pa_format = pyaudio.paFloat32
            
        try:
            self._stream = self._pyaudio.open(
                format=pa_format,
                channels=self.config.channels,
                rate=self.config.sample_rate,
                input=True,
                input_device_index=self.config.device_index,
                frames_per_buffer=self.config.frames_per_buffer,
                stream_callback=self._audio_callback
            )
            
            self._stream.start_stream()
            self._is_recording = True
            self._chunk_counter = 0
            
            self.logger.info(
                f"Recording started: {self.config.sample_rate}Hz, "
                f"{self.config.channels} channel(s), {self.config.format}-bit"
            )
            
        except Exception as e:
            self.logger.error(f"Failed to start recording: {e}")
            raise
            
    async def stop_recording(self) -> None:
        """Stop audio recording"""
        if not self._is_recording:
            return
            
        self.logger.info("Stopping audio recording...")
        
        self._is_recording = False
        
        if self._stream:
            self._stream.stop_stream()
            self._stream.close()
            self._stream = None
            
        self.logger.info("Recording stopped")
        
    async def get_audio_chunks(self) -> AsyncGenerator[AudioChunk, None]:
        """Async generator for audio chunks"""
        while self._is_recording or not self._audio_queue.empty():
            try:
                chunk = self._audio_queue.get(timeout=0.1)
                yield chunk
            except Empty:
                await asyncio.sleep(0.01)  # Small delay to prevent busy waiting
                
    def get_buffer_data(self, duration: float = 5.0) -> Optional[NDArray[np.float32]]:
        """Get recent audio data from circular buffer"""
        if not self._buffer or not self._is_recording:
            return None
            
        frames = min(int(duration * self.config.sample_rate), self.config.buffer_frames)
        
        with self._buffer_lock:
            if frames >= self.config.buffer_frames:
                # Return entire buffer
                return np.copy(self._buffer)
            
            # Get last N frames
            start_pos = (self._buffer_pos - frames) % self.config.buffer_frames
            
            if start_pos + frames <= self.config.buffer_frames:
                return np.copy(self._buffer[start_pos:start_pos + frames])
            else:
                # Data wraps around
                first_part = self._buffer[start_pos:]
                second_part = self._buffer[:frames - len(first_part)]
                return np.vstack([first_part, second_part])
                
    async def save_buffer_to_file(self, filepath: Path, duration: float = 30.0) -> bool:
        """Save recent buffer data to audio file"""
        audio_data = self.get_buffer_data(duration)
        if audio_data is None:
            return False
            
        try:
            sf.write(
                filepath, 
                audio_data, 
                self.config.sample_rate,
                format='WAV',
                subtype='PCM_16'
            )
            self.logger.info(f"Buffer saved to {filepath}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to save buffer: {e}")
            return False
            
    @property
    def is_recording(self) -> bool:
        return self._is_recording
        
    @property
    def current_session_id(self) -> str:
        return self._session_id
        
    async def cleanup(self) -> None:
        """Clean up recording resources"""
        await self.stop_recording()
        
        if self._pyaudio:
            self._pyaudio.terminate()
            self._pyaudio = None
            
        self.logger.info("Audio recorder cleanup complete")
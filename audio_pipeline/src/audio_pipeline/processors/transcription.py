#!/usr/bin/env python3
"""
Transcription functionality using OpenAI Whisper
Real-time speech-to-text with speaker alignment
"""

import asyncio
import logging
import tempfile
import time
from pathlib import Path
from typing import List, Dict, Optional, Any, Union
from dataclasses import dataclass
from datetime import datetime, timezone

import torch
import numpy as np
import soundfile as sf
from numpy.typing import NDArray

try:
    import whisper
    WHISPER_AVAILABLE = True
except ImportError:
    WHISPER_AVAILABLE = False
    logging.warning("OpenAI Whisper not available")

from .diarization import SpeakerSegment


@dataclass
class TranscriptionSegment:
    """Represents a transcribed segment with timing and text"""
    text: str
    start_time: float
    end_time: float
    confidence: float
    language: str
    speaker_id: Optional[str] = None
    session_id: str = ""
    
    @property
    def duration(self) -> float:
        return self.end_time - self.start_time
        
    @property
    def words_per_minute(self) -> float:
        """Estimate speaking rate"""
        word_count = len(self.text.split())
        if self.duration <= 0:
            return 0.0
        return (word_count / self.duration) * 60


@dataclass
class TranscriptionResult:
    """Complete transcription result"""
    segments: List[TranscriptionSegment]
    full_text: str
    language: str
    processing_time: float
    timestamp: datetime
    session_id: str
    model_name: str
    
    def get_speaker_text(self, speaker_id: str) -> str:
        """Get all text for a specific speaker"""
        speaker_segments = [seg for seg in self.segments 
                          if seg.speaker_id == speaker_id]
        return " ".join(seg.text for seg in speaker_segments)
    
    def get_text_at_time(self, time: float, window: float = 1.0) -> str:
        """Get text around a specific time"""
        relevant_segments = [
            seg for seg in self.segments
            if (seg.start_time <= time <= seg.end_time) or
               (abs(seg.start_time - time) <= window) or
               (abs(seg.end_time - time) <= window)
        ]
        return " ".join(seg.text for seg in relevant_segments)


class TranscriptionProcessor:
    """
    Speech-to-text transcription using OpenAI Whisper
    Supports multiple models and real-time processing
    """
    
    def __init__(self, model_name: str = "large-v3"):
        self.model_name = model_name
        self.logger = logging.getLogger(__name__)
        
        self._model: Optional[whisper.Whisper] = None
        self._device: str = "cuda" if torch.cuda.is_available() else "cpu"
        self._is_initialized = False
        
        # Transcription options
        self.temperature = 0.0  # Deterministic output
        self.best_of = 5 if model_name.startswith("large") else 1
        self.beam_size = 5 if model_name.startswith("large") else 1
        self.patience = 1.0
        self.length_penalty = 1.0
        self.suppress_tokens = "-1"  # Suppress common noise tokens
        
    async def initialize(self) -> None:
        """Initialize the transcription model"""
        if not WHISPER_AVAILABLE:
            raise RuntimeError("OpenAI Whisper is required for transcription")
            
        self.logger.info(f"Loading Whisper model: {self.model_name}")
        self.logger.info(f"Using device: {self._device}")
        
        try:
            # Load model (this downloads if not cached)
            self._model = await asyncio.get_event_loop().run_in_executor(
                None, whisper.load_model, self.model_name, self._device
            )
            
            self._is_initialized = True
            self.logger.info(f"Whisper {self.model_name} loaded successfully")
            
            # Log model info
            if hasattr(self._model, 'dims'):
                dims = self._model.dims
                self.logger.info(
                    f"Model dimensions: {dims.n_mels} mel bins, "
                    f"{dims.n_audio_ctx} audio context, "
                    f"{dims.n_vocab} vocabulary"
                )
                
        except Exception as e:
            self.logger.error(f"Failed to load Whisper model: {e}")
            raise
            
    async def transcribe_audio_file(self, audio_path: Path, 
                                  session_id: str,
                                  speaker_segments: Optional[List[SpeakerSegment]] = None) -> TranscriptionResult:
        """
        Transcribe an audio file with optional speaker diarization alignment
        """
        if not self._is_initialized or not self._model:
            raise RuntimeError("Transcription model not initialized")
            
        start_time = time.time()
        self.logger.info(f"Starting transcription of {audio_path}")
        
        try:
            # Transcribe with Whisper
            whisper_result = await asyncio.get_event_loop().run_in_executor(
                None, self._transcribe_with_whisper, str(audio_path)
            )
            
            # Convert Whisper result to our format
            segments = self._convert_whisper_segments(
                whisper_result, session_id, speaker_segments
            )
            
            processing_time = time.time() - start_time
            
            result = TranscriptionResult(
                segments=segments,
                full_text=whisper_result["text"].strip(),
                language=whisper_result["language"],
                processing_time=processing_time,
                timestamp=datetime.now(timezone.utc),
                session_id=session_id,
                model_name=self.model_name
            )
            
            self.logger.info(
                f"Transcription complete: {len(segments)} segments, "
                f"{len(result.full_text)} characters, "
                f"{processing_time:.2f}s processing time"
            )
            
            return result
            
        except Exception as e:
            self.logger.error(f"Transcription failed: {e}")
            raise
            
    def _transcribe_with_whisper(self, audio_path: str) -> Dict[str, Any]:
        """Run Whisper transcription (blocking operation)"""
        return self._model.transcribe(
            audio_path,
            temperature=self.temperature,
            best_of=self.best_of,
            beam_size=self.beam_size,
            patience=self.patience,
            length_penalty=self.length_penalty,
            suppress_tokens=self.suppress_tokens,
            word_timestamps=True,  # Enable word-level timestamps
            verbose=False
        )
        
    async def transcribe_audio_data(self, audio_data: NDArray[np.float32], 
                                  sample_rate: int,
                                  session_id: str,
                                  speaker_segments: Optional[List[SpeakerSegment]] = None) -> TranscriptionResult:
        """
        Transcribe audio data in memory
        """
        # Create temporary file for Whisper
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_file:
            tmp_path = Path(tmp_file.name)
            
        try:
            # Save audio data to temporary file
            sf.write(tmp_path, audio_data, sample_rate)
            
            # Transcribe the file
            result = await self.transcribe_audio_file(tmp_path, session_id, speaker_segments)
            
            return result
            
        finally:
            # Clean up temporary file
            if tmp_path.exists():
                tmp_path.unlink()
                
    def _convert_whisper_segments(self, whisper_result: Dict[str, Any], 
                                session_id: str,
                                speaker_segments: Optional[List[SpeakerSegment]] = None) -> List[TranscriptionSegment]:
        """Convert Whisper segments to our format with speaker alignment"""
        segments = []
        
        for whisper_seg in whisper_result.get("segments", []):
            # Create base transcription segment
            transcript_seg = TranscriptionSegment(
                text=whisper_seg["text"].strip(),
                start_time=whisper_seg["start"],
                end_time=whisper_seg["end"],
                confidence=whisper_seg.get("avg_logprob", 0.0),
                language=whisper_result["language"],
                session_id=session_id
            )
            
            # Align with speaker if diarization provided
            if speaker_segments:
                speaker_id = self._find_speaker_for_segment(
                    transcript_seg, speaker_segments
                )
                transcript_seg.speaker_id = speaker_id
                
            segments.append(transcript_seg)
            
        return segments
        
    def _find_speaker_for_segment(self, transcript_seg: TranscriptionSegment,
                                speaker_segments: List[SpeakerSegment]) -> Optional[str]:
        """Find the most likely speaker for a transcription segment"""
        best_overlap = 0.0
        best_speaker = None
        
        segment_duration = transcript_seg.duration
        if segment_duration <= 0:
            return None
            
        for speaker_seg in speaker_segments:
            # Calculate overlap
            overlap_start = max(transcript_seg.start_time, speaker_seg.start_time)
            overlap_end = min(transcript_seg.end_time, speaker_seg.end_time)
            
            if overlap_end > overlap_start:
                overlap_duration = overlap_end - overlap_start
                overlap_ratio = overlap_duration / segment_duration
                
                if overlap_ratio > best_overlap:
                    best_overlap = overlap_ratio
                    best_speaker = speaker_seg.speaker_id
                    
        # Only assign speaker if significant overlap (>50%)
        return best_speaker if best_overlap > 0.5 else None
        
    async def transcribe_streaming_chunks(self, audio_chunks: List[NDArray[np.float32]], 
                                        sample_rate: int,
                                        session_id: str) -> TranscriptionResult:
        """
        Transcribe streaming audio chunks
        """
        if not audio_chunks:
            return TranscriptionResult(
                segments=[],
                full_text="",
                language="en",
                processing_time=0.0,
                timestamp=datetime.now(timezone.utc),
                session_id=session_id,
                model_name=self.model_name
            )
            
        # Concatenate chunks
        combined_audio = np.concatenate(audio_chunks)
        
        # Process combined audio
        result = await self.transcribe_audio_data(combined_audio, sample_rate, session_id)
        
        return result
        
    def align_with_speaker_diarization(self, transcription: TranscriptionResult, 
                                     speaker_segments: List[SpeakerSegment]) -> TranscriptionResult:
        """
        Post-process transcription to align with speaker diarization
        """
        # Update segments with speaker information
        updated_segments = []
        
        for segment in transcription.segments:
            speaker_id = self._find_speaker_for_segment(segment, speaker_segments)
            
            # Create new segment with speaker info
            updated_segment = TranscriptionSegment(
                text=segment.text,
                start_time=segment.start_time,
                end_time=segment.end_time,
                confidence=segment.confidence,
                language=segment.language,
                speaker_id=speaker_id,
                session_id=segment.session_id
            )
            
            updated_segments.append(updated_segment)
            
        # Create new result with updated segments
        return TranscriptionResult(
            segments=updated_segments,
            full_text=transcription.full_text,
            language=transcription.language,
            processing_time=transcription.processing_time,
            timestamp=transcription.timestamp,
            session_id=transcription.session_id,
            model_name=transcription.model_name
        )
        
    def get_confidence_stats(self, transcription: TranscriptionResult) -> Dict[str, float]:
        """Get confidence statistics for transcription"""
        if not transcription.segments:
            return {"mean": 0.0, "min": 0.0, "max": 0.0, "std": 0.0}
            
        confidences = [seg.confidence for seg in transcription.segments]
        
        return {
            "mean": np.mean(confidences),
            "min": np.min(confidences),
            "max": np.max(confidences),
            "std": np.std(confidences)
        }
        
    @property
    def is_initialized(self) -> bool:
        return self._is_initialized
        
    @property
    def device(self) -> str:
        return self._device
        
    @property
    def available_models(self) -> List[str]:
        """Get list of available Whisper models"""
        return ["tiny", "base", "small", "medium", "large", "large-v2", "large-v3"]
        
    async def cleanup(self) -> None:
        """Clean up transcription resources"""
        if self._model:
            # Clear GPU memory if using CUDA
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
                
        self._model = None
        self._is_initialized = False
        self.logger.info("Transcription processor cleanup complete")
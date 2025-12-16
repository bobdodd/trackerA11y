#!/usr/bin/env python3
"""
Speaker diarization functionality using pyannote.audio
Real-time speaker identification and segmentation
"""

import asyncio
import logging
import tempfile
from pathlib import Path
from typing import List, Dict, Optional, Tuple, Any
from dataclasses import dataclass
from datetime import datetime, timezone

import torch
import numpy as np
import soundfile as sf
from numpy.typing import NDArray

try:
    from pyannote.audio import Pipeline
    from pyannote.core import Segment, Timeline, Annotation
    PYANNOTE_AVAILABLE = True
except ImportError:
    PYANNOTE_AVAILABLE = False
    logging.warning("pyannote.audio not available")


@dataclass
class SpeakerSegment:
    """Represents a speaker segment with timing and identity"""
    speaker_id: str
    start_time: float  # seconds
    end_time: float    # seconds
    confidence: float
    audio_chunk_ids: List[int]
    session_id: str
    
    @property
    def duration(self) -> float:
        return self.end_time - self.start_time
        
    def overlaps_with(self, other: 'SpeakerSegment', tolerance: float = 0.1) -> bool:
        """Check if this segment overlaps with another"""
        return not (self.end_time <= other.start_time + tolerance or 
                   self.start_time >= other.end_time - tolerance)


@dataclass
class DiarizationResult:
    """Complete diarization result for an audio segment"""
    segments: List[SpeakerSegment]
    total_speakers: int
    total_duration: float
    timestamp: datetime
    session_id: str
    processing_time: float
    
    def get_speaker_timeline(self, speaker_id: str) -> List[Tuple[float, float]]:
        """Get timeline for specific speaker"""
        return [(seg.start_time, seg.end_time) 
                for seg in self.segments if seg.speaker_id == speaker_id]
    
    def get_active_speakers_at(self, time: float) -> List[str]:
        """Get speakers active at specific time"""
        return [seg.speaker_id for seg in self.segments 
                if seg.start_time <= time <= seg.end_time]


class SpeakerDiarizer:
    """
    Speaker diarization using pyannote.audio pipeline
    Supports both batch and streaming processing
    """
    
    def __init__(self, model_name: str = "pyannote/speaker-diarization-3.1"):
        self.model_name = model_name
        self.logger = logging.getLogger(__name__)
        
        self._pipeline: Optional[Pipeline] = None
        self._device: str = "cuda" if torch.cuda.is_available() else "cpu"
        self._is_initialized = False
        
        # Configuration
        self.min_segment_duration = 1.0  # seconds
        self.max_speakers = 10  # maximum speakers to detect
        self.embedding_batch_size = 32
        
    async def initialize(self) -> None:
        """Initialize the diarization pipeline"""
        if not PYANNOTE_AVAILABLE:
            raise RuntimeError("pyannote.audio is required for speaker diarization")
            
        self.logger.info(f"Initializing speaker diarization: {self.model_name}")
        self.logger.info(f"Using device: {self._device}")
        
        try:
            # Load the diarization pipeline
            self._pipeline = Pipeline.from_pretrained(
                self.model_name,
                use_auth_token=None  # Hugging Face token if needed
            )
            
            # Move to appropriate device
            if torch.cuda.is_available():
                self._pipeline.to(torch.device("cuda"))
                self.logger.info("Diarization pipeline loaded on GPU")
            else:
                self.logger.info("Diarization pipeline loaded on CPU")
                
            self._is_initialized = True
            self.logger.info("Speaker diarization initialized successfully")
            
        except Exception as e:
            self.logger.error(f"Failed to initialize diarization pipeline: {e}")
            raise
            
    async def diarize_audio_file(self, audio_path: Path, 
                                session_id: str) -> DiarizationResult:
        """
        Perform speaker diarization on an audio file
        """
        if not self._is_initialized or not self._pipeline:
            raise RuntimeError("Diarization pipeline not initialized")
            
        start_time = asyncio.get_event_loop().time()
        self.logger.info(f"Starting diarization of {audio_path}")
        
        try:
            # Run diarization (this is CPU/GPU intensive)
            diarization = await asyncio.get_event_loop().run_in_executor(
                None, self._pipeline, str(audio_path)
            )
            
            # Convert pyannote annotation to our format
            segments = self._convert_annotation_to_segments(
                diarization, session_id
            )
            
            # Get audio duration
            audio_data, sample_rate = sf.read(audio_path)
            total_duration = len(audio_data) / sample_rate
            
            processing_time = asyncio.get_event_loop().time() - start_time
            
            result = DiarizationResult(
                segments=segments,
                total_speakers=len(set(seg.speaker_id for seg in segments)),
                total_duration=total_duration,
                timestamp=datetime.now(timezone.utc),
                session_id=session_id,
                processing_time=processing_time
            )
            
            self.logger.info(
                f"Diarization complete: {result.total_speakers} speakers, "
                f"{len(segments)} segments, {processing_time:.2f}s processing time"
            )
            
            return result
            
        except Exception as e:
            self.logger.error(f"Diarization failed: {e}")
            raise
            
    async def diarize_audio_data(self, audio_data: NDArray[np.float32], 
                                sample_rate: int, 
                                session_id: str) -> DiarizationResult:
        """
        Perform speaker diarization on audio data in memory
        """
        # Create temporary file for pyannote (it requires file input)
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_file:
            tmp_path = Path(tmp_file.name)
            
        try:
            # Save audio data to temporary file
            sf.write(tmp_path, audio_data, sample_rate)
            
            # Process the file
            result = await self.diarize_audio_file(tmp_path, session_id)
            
            return result
            
        finally:
            # Clean up temporary file
            if tmp_path.exists():
                tmp_path.unlink()
                
    def _convert_annotation_to_segments(self, annotation: Annotation, 
                                      session_id: str) -> List[SpeakerSegment]:
        """Convert pyannote Annotation to our SpeakerSegment format"""
        segments = []
        
        for segment, _, speaker in annotation.itertracks(yield_label=True):
            # Skip very short segments
            if segment.duration < self.min_segment_duration:
                continue
                
            speaker_segment = SpeakerSegment(
                speaker_id=str(speaker),
                start_time=segment.start,
                end_time=segment.end,
                confidence=1.0,  # pyannote doesn't provide confidence scores by default
                audio_chunk_ids=[],  # Will be populated by caller if needed
                session_id=session_id
            )
            
            segments.append(speaker_segment)
            
        # Sort by start time
        segments.sort(key=lambda x: x.start_time)
        
        return segments
        
    async def process_streaming_chunks(self, audio_chunks: List[NDArray[np.float32]], 
                                     sample_rate: int, 
                                     session_id: str,
                                     overlap_duration: float = 2.0) -> DiarizationResult:
        """
        Process streaming audio chunks with overlap handling
        """
        if not audio_chunks:
            return DiarizationResult(
                segments=[], 
                total_speakers=0, 
                total_duration=0.0,
                timestamp=datetime.now(timezone.utc),
                session_id=session_id,
                processing_time=0.0
            )
            
        # Concatenate chunks
        combined_audio = np.concatenate(audio_chunks)
        
        # Process combined audio
        result = await self.diarize_audio_data(combined_audio, sample_rate, session_id)
        
        return result
        
    def merge_overlapping_segments(self, segments: List[SpeakerSegment], 
                                 tolerance: float = 0.5) -> List[SpeakerSegment]:
        """
        Merge overlapping segments from the same speaker
        """
        if not segments:
            return []
            
        # Group by speaker
        speaker_segments: Dict[str, List[SpeakerSegment]] = {}
        for segment in segments:
            if segment.speaker_id not in speaker_segments:
                speaker_segments[segment.speaker_id] = []
            speaker_segments[segment.speaker_id].append(segment)
            
        # Merge overlapping segments for each speaker
        merged_segments = []
        
        for speaker_id, speaker_segs in speaker_segments.items():
            # Sort by start time
            speaker_segs.sort(key=lambda x: x.start_time)
            
            current_segment = speaker_segs[0]
            
            for next_segment in speaker_segs[1:]:
                # Check if segments should be merged
                if (next_segment.start_time <= current_segment.end_time + tolerance):
                    # Merge segments
                    current_segment = SpeakerSegment(
                        speaker_id=speaker_id,
                        start_time=current_segment.start_time,
                        end_time=max(current_segment.end_time, next_segment.end_time),
                        confidence=max(current_segment.confidence, next_segment.confidence),
                        audio_chunk_ids=current_segment.audio_chunk_ids + next_segment.audio_chunk_ids,
                        session_id=current_segment.session_id
                    )
                else:
                    # No overlap, save current and start new
                    merged_segments.append(current_segment)
                    current_segment = next_segment
                    
            # Add final segment
            merged_segments.append(current_segment)
            
        # Sort all merged segments by start time
        merged_segments.sort(key=lambda x: x.start_time)
        
        return merged_segments
        
    async def get_speaker_embeddings(self, audio_data: NDArray[np.float32], 
                                   sample_rate: int) -> Dict[str, NDArray[np.float32]]:
        """
        Extract speaker embeddings for each detected speaker
        """
        if not self._is_initialized or not self._pipeline:
            raise RuntimeError("Diarization pipeline not initialized")
            
        # This would require access to the embedding model within the pipeline
        # For now, return empty dict as this is an advanced feature
        self.logger.warning("Speaker embedding extraction not yet implemented")
        return {}
        
    @property
    def is_initialized(self) -> bool:
        return self._is_initialized
        
    @property 
    def device(self) -> str:
        return self._device
        
    async def cleanup(self) -> None:
        """Clean up diarization resources"""
        if self._pipeline:
            # Clear GPU memory if using CUDA
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
                
        self._pipeline = None
        self._is_initialized = False
        self.logger.info("Speaker diarization cleanup complete")
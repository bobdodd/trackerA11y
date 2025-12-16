"""
Audio event data models
"""

from dataclasses import dataclass
from typing import List, Optional
import numpy as np
from numpy.typing import NDArray


@dataclass
class AudioEvent:
    """Unified audio event for IPC with TypeScript core"""
    id: str
    timestamp: float  # microseconds
    source: str = "audio"
    
    # Session metadata
    session_id: str = ""
    processing_time: float = 0.0
    
    # Content data
    text: str = ""
    language: str = ""
    confidence: float = 0.0
    
    # Speaker data
    speaker_id: Optional[str] = None
    
    # Timing
    start_time: float = 0.0  # seconds in audio
    end_time: float = 0.0    # seconds in audio


@dataclass
class ProcessedAudio:
    """Processed audio data with analysis results"""
    audio_data: NDArray[np.float32]
    sample_rate: int
    duration: float
    events: List[AudioEvent]
    session_id: str
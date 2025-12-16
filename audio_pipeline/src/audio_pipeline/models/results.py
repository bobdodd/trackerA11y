"""
Processing result data models
"""

from dataclasses import dataclass
from typing import List
from datetime import datetime

from ..processors.diarization import SpeakerSegment


@dataclass
class DiarizationResult:
    """Speaker diarization processing result"""
    segments: List[SpeakerSegment]
    total_speakers: int
    total_duration: float
    timestamp: datetime
    session_id: str
    processing_time: float
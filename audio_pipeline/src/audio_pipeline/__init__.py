"""
TrackerA11y Audio Processing Pipeline

High-performance audio analysis pipeline with speaker diarization 
and advanced transcription for accessibility testing.
"""

__version__ = "0.1.0"
__author__ = "TrackerA11y Team"

from .processors import AudioProcessor, AudioRecorder, SpeakerDiarizer, TranscriptionProcessor
from .communication import IPCHandler
from .models import AudioEvent, ProcessedAudio, DiarizationResult

__all__ = [
    "AudioProcessor",
    "AudioRecorder",
    "SpeakerDiarizer", 
    "TranscriptionProcessor",
    "IPCHandler", 
    "AudioEvent",
    "ProcessedAudio",
    "DiarizationResult"
]
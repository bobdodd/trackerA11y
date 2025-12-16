#!/usr/bin/env python3
"""
IPC message type definitions for TypeScript-Python communication
"""

from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, asdict
from enum import Enum
import json


class MessageType(str, Enum):
    """IPC message types"""
    # Control messages
    INIT = "init"
    SHUTDOWN = "shutdown"
    PING = "ping"
    PONG = "pong"
    
    # Audio processing
    PROCESS_AUDIO = "process_audio"
    AUDIO_EVENT = "audio_event" 
    PROCESSING_STATUS = "processing_status"
    
    # Configuration
    UPDATE_CONFIG = "update_config"
    GET_STATUS = "get_status"
    
    # Error handling
    ERROR = "error"


@dataclass
class IPCMessage:
    """Base IPC message structure"""
    type: MessageType
    id: str
    timestamp: float
    payload: Dict[str, Any]
    session_id: Optional[str] = None
    
    def to_json(self) -> str:
        """Serialize message to JSON"""
        return json.dumps(asdict(self))
    
    @classmethod
    def from_json(cls, json_str: str) -> 'IPCMessage':
        """Deserialize message from JSON"""
        data = json.loads(json_str)
        return cls(**data)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return asdict(self)


@dataclass 
class AudioProcessingRequest:
    """Request for audio processing"""
    audio_data: bytes  # Audio data as bytes
    sample_rate: int
    channels: int
    format: str  # "wav", "raw", etc.
    duration: float
    session_id: str
    chunk_id: Optional[int] = None
    real_time: bool = True


@dataclass
class SpeakerInfo:
    """Speaker information from diarization"""
    speaker_id: str
    start_time: float
    end_time: float
    confidence: float


@dataclass
class AudioProcessingResponse:
    """Response from audio processing"""
    success: bool
    session_id: str
    processing_time: float
    
    # Transcription results
    text: str = ""
    language: str = ""
    confidence: float = 0.0
    
    # Speaker diarization results  
    speakers: List[SpeakerInfo] = None
    total_speakers: int = 0
    
    # Timing information
    start_time: float = 0.0
    end_time: float = 0.0
    
    # Error information
    error_message: Optional[str] = None
    
    def __post_init__(self):
        if self.speakers is None:
            self.speakers = []


@dataclass
class ProcessingStatus:
    """Current processing status"""
    is_recording: bool
    is_processing: bool
    session_id: str
    queue_size: int
    total_processed: int
    average_processing_time: float
    last_error: Optional[str] = None


@dataclass
class ConfigUpdate:
    """Configuration update request"""
    sample_rate: Optional[int] = None
    diarization_model: Optional[str] = None
    transcription_model: Optional[str] = None
    real_time: Optional[bool] = None
    process_interval: Optional[float] = None


@dataclass
class ErrorResponse:
    """Error response message"""
    error_type: str
    message: str
    details: Optional[Dict[str, Any]] = None
    traceback: Optional[str] = None


# Message factory functions

def create_init_message(session_id: str, config: Dict[str, Any]) -> IPCMessage:
    """Create initialization message"""
    import time
    import uuid
    
    return IPCMessage(
        type=MessageType.INIT,
        id=str(uuid.uuid4()),
        timestamp=time.time(),
        session_id=session_id,
        payload={"config": config}
    )


def create_shutdown_message(session_id: str) -> IPCMessage:
    """Create shutdown message"""
    import time
    import uuid
    
    return IPCMessage(
        type=MessageType.SHUTDOWN,
        id=str(uuid.uuid4()),
        timestamp=time.time(),
        session_id=session_id,
        payload={}
    )


def create_audio_processing_message(request: AudioProcessingRequest) -> IPCMessage:
    """Create audio processing request message"""
    import time
    import uuid
    import base64
    
    # Encode audio data as base64 for JSON transmission
    encoded_audio = base64.b64encode(request.audio_data).decode('utf-8')
    
    payload = {
        "audio_data": encoded_audio,
        "sample_rate": request.sample_rate,
        "channels": request.channels,
        "format": request.format,
        "duration": request.duration,
        "chunk_id": request.chunk_id,
        "real_time": request.real_time
    }
    
    return IPCMessage(
        type=MessageType.PROCESS_AUDIO,
        id=str(uuid.uuid4()),
        timestamp=time.time(),
        session_id=request.session_id,
        payload=payload
    )


def create_audio_event_message(response: AudioProcessingResponse) -> IPCMessage:
    """Create audio event response message"""
    import time
    import uuid
    
    # Convert SpeakerInfo objects to dicts
    speakers_data = []
    for speaker in response.speakers:
        speakers_data.append({
            "speaker_id": speaker.speaker_id,
            "start_time": speaker.start_time,
            "end_time": speaker.end_time,
            "confidence": speaker.confidence
        })
    
    payload = {
        "success": response.success,
        "processing_time": response.processing_time,
        "text": response.text,
        "language": response.language,
        "confidence": response.confidence,
        "speakers": speakers_data,
        "total_speakers": response.total_speakers,
        "start_time": response.start_time,
        "end_time": response.end_time,
        "error_message": response.error_message
    }
    
    return IPCMessage(
        type=MessageType.AUDIO_EVENT,
        id=str(uuid.uuid4()),
        timestamp=time.time(),
        session_id=response.session_id,
        payload=payload
    )


def create_status_message(status: ProcessingStatus) -> IPCMessage:
    """Create processing status message"""
    import time
    import uuid
    
    return IPCMessage(
        type=MessageType.PROCESSING_STATUS,
        id=str(uuid.uuid4()),
        timestamp=time.time(),
        session_id=status.session_id,
        payload={
            "is_recording": status.is_recording,
            "is_processing": status.is_processing,
            "queue_size": status.queue_size,
            "total_processed": status.total_processed,
            "average_processing_time": status.average_processing_time,
            "last_error": status.last_error
        }
    )


def create_error_message(error: ErrorResponse, session_id: str) -> IPCMessage:
    """Create error message"""
    import time
    import uuid
    
    return IPCMessage(
        type=MessageType.ERROR,
        id=str(uuid.uuid4()),
        timestamp=time.time(),
        session_id=session_id,
        payload={
            "error_type": error.error_type,
            "message": error.message,
            "details": error.details,
            "traceback": error.traceback
        }
    )


def create_ping_message(session_id: str) -> IPCMessage:
    """Create ping message"""
    import time
    import uuid
    
    return IPCMessage(
        type=MessageType.PING,
        id=str(uuid.uuid4()),
        timestamp=time.time(),
        session_id=session_id,
        payload={}
    )


def create_pong_message(ping_message: IPCMessage) -> IPCMessage:
    """Create pong response to ping"""
    import time
    
    return IPCMessage(
        type=MessageType.PONG,
        id=ping_message.id,  # Use same ID as ping
        timestamp=time.time(),
        session_id=ping_message.session_id,
        payload={"ping_timestamp": ping_message.timestamp}
    )
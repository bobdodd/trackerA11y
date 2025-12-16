"""
Communication modules for IPC with TypeScript core
"""

from .ipc_handler import IPCHandler
from .message_types import IPCMessage, AudioProcessingRequest, AudioProcessingResponse

__all__ = [
    "IPCHandler",
    "IPCMessage", 
    "AudioProcessingRequest",
    "AudioProcessingResponse"
]
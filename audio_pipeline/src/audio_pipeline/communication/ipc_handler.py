#!/usr/bin/env python3
"""
IPC handler for communication with TypeScript core
Uses stdin/stdout for message passing with msgpack serialization
"""

import asyncio
import logging
import sys
import traceback
import base64
from typing import Optional, Dict, Any
import json
import time

import msgpack
import numpy as np

from .message_types import (
    IPCMessage, MessageType, AudioProcessingRequest, AudioProcessingResponse,
    SpeakerInfo, ProcessingStatus, ErrorResponse, ConfigUpdate,
    create_audio_event_message, create_status_message, create_error_message,
    create_pong_message
)
from ..processors import AudioProcessor, ProcessingConfig, AudioEvent


class IPCHandler:
    """
    Handles IPC communication between Python audio pipeline and TypeScript core
    Uses stdin/stdout for message passing
    """
    
    def __init__(self, audio_processor: AudioProcessor):
        self.audio_processor = audio_processor
        self.logger = logging.getLogger(__name__)
        
        self._is_running = False
        self._message_handlers: Dict[MessageType, Any] = {}
        self._setup_message_handlers()
        
        # Statistics
        self._total_processed = 0
        self._processing_times = []
        self._last_error: Optional[str] = None
        
    def _setup_message_handlers(self) -> None:
        """Setup message type handlers"""
        self._message_handlers = {
            MessageType.INIT: self._handle_init,
            MessageType.SHUTDOWN: self._handle_shutdown,
            MessageType.PING: self._handle_ping,
            MessageType.PROCESS_AUDIO: self._handle_process_audio,
            MessageType.UPDATE_CONFIG: self._handle_update_config,
            MessageType.GET_STATUS: self._handle_get_status
        }
        
    async def start(self) -> None:
        """Start IPC communication"""
        self.logger.info("Starting IPC handler...")
        self._is_running = True
        
        # Set up audio processor callback
        self.audio_processor.set_result_callback(self._on_audio_event)
        
        try:
            # Start message processing loop
            await self._message_loop()
        except Exception as e:
            self.logger.error(f"IPC handler error: {e}")
            await self._send_error_message(
                ErrorResponse(
                    error_type="IPC_ERROR",
                    message=str(e),
                    traceback=traceback.format_exc()
                )
            )
        finally:
            self._is_running = False
            
    async def _message_loop(self) -> None:
        """Main message processing loop"""
        self.logger.info("IPC message loop started")
        
        try:
            # Read from stdin line by line
            while self._is_running:
                # Read line from stdin asynchronously
                line = await asyncio.get_event_loop().run_in_executor(
                    None, sys.stdin.readline
                )
                
                if not line:  # EOF
                    self.logger.info("Received EOF, shutting down")
                    break
                    
                line = line.strip()
                if not line:
                    continue
                    
                try:
                    # Parse message
                    if line.startswith('{'):
                        # JSON format
                        message = IPCMessage.from_json(line)
                    else:
                        # msgpack format (base64 encoded)
                        data = base64.b64decode(line)
                        message_dict = msgpack.unpackb(data, raw=False)
                        message = IPCMessage(**message_dict)
                    
                    # Handle message
                    await self._handle_message(message)
                    
                except Exception as e:
                    self.logger.error(f"Failed to process message: {e}")
                    await self._send_error_message(
                        ErrorResponse(
                            error_type="MESSAGE_PROCESSING_ERROR",
                            message=f"Failed to process message: {str(e)}",
                            traceback=traceback.format_exc()
                        )
                    )
                    
        except Exception as e:
            self.logger.error(f"Message loop error: {e}")
            raise
            
    async def _handle_message(self, message: IPCMessage) -> None:
        """Handle incoming IPC message"""
        self.logger.debug(f"Handling message: {message.type}")
        
        handler = self._message_handlers.get(message.type)
        if handler:
            try:
                await handler(message)
            except Exception as e:
                self.logger.error(f"Handler error for {message.type}: {e}")
                await self._send_error_message(
                    ErrorResponse(
                        error_type="HANDLER_ERROR",
                        message=f"Handler failed for {message.type}: {str(e)}",
                        traceback=traceback.format_exc()
                    ),
                    session_id=message.session_id
                )
        else:
            self.logger.warning(f"No handler for message type: {message.type}")
            
    async def _handle_init(self, message: IPCMessage) -> None:
        """Handle initialization message"""
        self.logger.info("Handling initialization")
        
        config_data = message.payload.get("config", {})
        
        try:
            # Update audio processor configuration if provided
            if config_data:
                await self._update_audio_config(config_data)
                
            # Initialize audio processor
            await self.audio_processor.initialize()
            
            # Send success response
            await self._send_status_message(message.session_id)
            
        except Exception as e:
            self.logger.error(f"Initialization failed: {e}")
            await self._send_error_message(
                ErrorResponse(
                    error_type="INITIALIZATION_ERROR",
                    message=str(e),
                    traceback=traceback.format_exc()
                ),
                session_id=message.session_id
            )
            
    async def _handle_shutdown(self, message: IPCMessage) -> None:
        """Handle shutdown message"""
        self.logger.info("Handling shutdown")
        
        try:
            # Clean shutdown of audio processor
            await self.audio_processor.cleanup()
            
            # Stop IPC handler
            self._is_running = False
            
        except Exception as e:
            self.logger.error(f"Shutdown error: {e}")
            
    async def _handle_ping(self, message: IPCMessage) -> None:
        """Handle ping message"""
        pong_message = create_pong_message(message)
        await self._send_message(pong_message)
        
    async def _handle_process_audio(self, message: IPCMessage) -> None:
        """Handle audio processing request"""
        try:
            # Decode audio data
            audio_data_b64 = message.payload["audio_data"]
            audio_bytes = base64.b64decode(audio_data_b64)
            
            # Convert to numpy array based on format
            if message.payload["format"] == "float32":
                audio_array = np.frombuffer(audio_bytes, dtype=np.float32)
            elif message.payload["format"] == "int16":
                audio_array = np.frombuffer(audio_bytes, dtype=np.int16)
                audio_array = audio_array.astype(np.float32) / 32768.0
            else:
                raise ValueError(f"Unsupported audio format: {message.payload['format']}")
                
            sample_rate = message.payload["sample_rate"]
            
            # Process the audio
            start_time = time.time()
            
            # Use audio processor to process the data
            events = await self.audio_processor._process_audio_chunks(
                [type('AudioChunk', (), {
                    'data': audio_array,
                    'timestamp': message.timestamp,
                    'sample_rate': sample_rate,
                    'channels': message.payload["channels"],
                    'chunk_id': message.payload.get("chunk_id", 0),
                    'session_id': message.session_id or ""
                })()],
                "ipc-request"
            )
            
            processing_time = time.time() - start_time
            self._processing_times.append(processing_time)
            self._total_processed += 1
            
            # Send response for each event
            for event in events or []:
                response = self._convert_audio_event_to_response(event, processing_time)
                event_message = create_audio_event_message(response)
                await self._send_message(event_message)
                
        except Exception as e:
            self.logger.error(f"Audio processing failed: {e}")
            await self._send_error_message(
                ErrorResponse(
                    error_type="AUDIO_PROCESSING_ERROR",
                    message=str(e),
                    traceback=traceback.format_exc()
                ),
                session_id=message.session_id
            )
            self._last_error = str(e)
            
    async def _handle_update_config(self, message: IPCMessage) -> None:
        """Handle configuration update"""
        try:
            config_data = message.payload.get("config", {})
            await self._update_audio_config(config_data)
            await self._send_status_message(message.session_id)
        except Exception as e:
            await self._send_error_message(
                ErrorResponse(
                    error_type="CONFIG_UPDATE_ERROR",
                    message=str(e)
                ),
                session_id=message.session_id
            )
            
    async def _handle_get_status(self, message: IPCMessage) -> None:
        """Handle status request"""
        await self._send_status_message(message.session_id)
        
    async def _update_audio_config(self, config_data: Dict[str, Any]) -> None:
        """Update audio processor configuration"""
        # This is a simplified implementation
        # In practice, you might need to restart components with new config
        self.logger.info(f"Updating configuration: {config_data}")
        
    def _convert_audio_event_to_response(self, event: AudioEvent, 
                                       processing_time: float) -> AudioProcessingResponse:
        """Convert AudioEvent to AudioProcessingResponse"""
        speakers = []
        if event.speaker_segments:
            for segment in event.speaker_segments:
                speakers.append(SpeakerInfo(
                    speaker_id=segment.speaker_id,
                    start_time=segment.start_time,
                    end_time=segment.end_time,
                    confidence=segment.confidence
                ))
                
        return AudioProcessingResponse(
            success=True,
            session_id=event.session_id,
            processing_time=processing_time,
            text=event.text,
            language=event.language,
            confidence=event.confidence,
            speakers=speakers,
            total_speakers=len(set(s.speaker_id for s in speakers)),
            start_time=event.start_time,
            end_time=event.end_time
        )
        
    def _on_audio_event(self, event: AudioEvent) -> None:
        """Handle audio event from processor"""
        try:
            # Convert to response format
            response = self._convert_audio_event_to_response(event, event.processing_time)
            
            # Create and send message
            message = create_audio_event_message(response)
            
            # Send asynchronously (schedule for next event loop iteration)
            asyncio.create_task(self._send_message(message))
            
        except Exception as e:
            self.logger.error(f"Failed to handle audio event: {e}")
            
    async def _send_status_message(self, session_id: Optional[str]) -> None:
        """Send current processing status"""
        avg_processing_time = 0.0
        if self._processing_times:
            avg_processing_time = sum(self._processing_times) / len(self._processing_times)
            
        status = ProcessingStatus(
            is_recording=self.audio_processor.is_processing,
            is_processing=self.audio_processor.is_processing,
            session_id=session_id or "",
            queue_size=0,  # Would need to expose this from audio processor
            total_processed=self._total_processed,
            average_processing_time=avg_processing_time,
            last_error=self._last_error
        )
        
        message = create_status_message(status)
        await self._send_message(message)
        
    async def _send_error_message(self, error: ErrorResponse, 
                                session_id: Optional[str] = None) -> None:
        """Send error message"""
        message = create_error_message(error, session_id or "")
        await self._send_message(message)
        
    async def _send_message(self, message: IPCMessage) -> None:
        """Send message to TypeScript core via stdout"""
        try:
            # Use msgpack for efficient serialization
            data = msgpack.packb(message.to_dict())
            encoded = base64.b64encode(data).decode('utf-8')
            
            # Write to stdout with newline
            sys.stdout.write(encoded + '\n')
            sys.stdout.flush()
            
        except Exception as e:
            self.logger.error(f"Failed to send message: {e}")
            
    @property
    def is_running(self) -> bool:
        return self._is_running
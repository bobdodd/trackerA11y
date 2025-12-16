#!/usr/bin/env python3
"""
Main entry point for TrackerA11y audio processing pipeline
Handles IPC communication with TypeScript core
"""

import asyncio
import sys
import argparse
import logging
from typing import Optional

from audio_pipeline.communication import IPCHandler
from audio_pipeline.processors import AudioProcessor


def setup_logging(level: str = "INFO") -> None:
    """Configure logging for the audio pipeline"""
    logging.basicConfig(
        level=getattr(logging, level.upper()),
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        stream=sys.stderr
    )


async def main() -> None:
    """Main async entry point"""
    parser = argparse.ArgumentParser(
        description="TrackerA11y Audio Processing Pipeline"
    )
    parser.add_argument(
        "--mode", 
        choices=["ipc", "standalone"], 
        default="ipc",
        help="Operation mode"
    )
    parser.add_argument(
        "--diarization-model",
        default="pyannote/speaker-diarization-3.1",
        help="Speaker diarization model"
    )
    parser.add_argument(
        "--transcription-model", 
        default="large-v3",
        help="Whisper transcription model"
    )
    parser.add_argument(
        "--quality",
        choices=["48khz", "96khz"],
        default="48khz", 
        help="Audio recording quality"
    )
    parser.add_argument(
        "--real-time",
        type=bool,
        default=True,
        help="Enable real-time processing"
    )
    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default="INFO",
        help="Logging level"
    )
    
    args = parser.parse_args()
    setup_logging(args.log_level)
    
    logger = logging.getLogger(__name__)
    logger.info("Starting TrackerA11y Audio Processing Pipeline")
    
    try:
        # Initialize audio processor
        processor = AudioProcessor(
            diarization_model=args.diarization_model,
            transcription_model=args.transcription_model,
            sample_rate=48000 if args.quality == "48khz" else 96000,
            real_time=args.real_time
        )
        await processor.initialize()
        
        if args.mode == "ipc":
            # IPC mode - communicate with TypeScript core
            ipc_handler = IPCHandler(processor)
            await ipc_handler.start()
        else:
            # Standalone mode for testing
            logger.info("Running in standalone mode...")
            await processor.run_standalone()
            
    except KeyboardInterrupt:
        logger.info("Received interrupt signal, shutting down...")
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
    finally:
        logger.info("Audio processing pipeline shutdown complete")


if __name__ == "__main__":
    asyncio.run(main())
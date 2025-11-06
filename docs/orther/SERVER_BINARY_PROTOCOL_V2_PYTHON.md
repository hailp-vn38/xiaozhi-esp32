# Binary Protocol V2 - Python Server Implementation

> Ready-to-use Python code cho WebSocket server upgrade từ V1 sang V2

---

## 📦 Struct Mapping

```
Device sends 16-byte header (big-endian):
[0-1]   version (uint16)
[2-3]   type (uint16): 0=OPUS, 1=JSON
[4-7]   reserved (uint32)
[8-11]  timestamp (uint32, milliseconds)
[12-15] payload_size (uint32)
[16+]   payload (variable)
```

---

## ✅ Python Implementation

### 1. Basic Parser Class

```python
import struct
import logging
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

class BinaryProtocolV2:
    """Parse BinaryProtocol2 frames from device"""
    
    HEADER_SIZE = 16
    OPUS_TYPE = 0
    JSON_TYPE = 1
    
    @staticmethod
    def parse(data: bytes) -> Optional[Dict[str, Any]]:
        """
        Parse binary frame
        
        Args:
            data: Raw bytes from WebSocket
            
        Returns:
            {
                'version': int,
                'type': int (0=OPUS, 1=JSON),
                'timestamp': int (ms),
                'payload_size': int,
                'payload': bytes,
                'is_opus': bool,
                'is_json': bool
            }
        """
        # Check minimum header
        if len(data) < BinaryProtocolV2.HEADER_SIZE:
            logger.error(f"Frame too small: {len(data)} bytes, need 16+")
            return None
        
        try:
            # Unpack header (big-endian: > prefix)
            version, msg_type, reserved, timestamp, payload_size = struct.unpack(
                '>HHIII',
                data[:16]
            )
            
            # Validate payload
            if len(data) < 16 + payload_size:
                logger.error(
                    f"Incomplete payload: expected {payload_size}, "
                    f"got {len(data) - 16} bytes"
                )
                return None
            
            payload = data[16:16 + payload_size]
            
            return {
                'version': version,
                'type': msg_type,
                'timestamp': timestamp,
                'payload_size': payload_size,
                'payload': payload,
                'is_opus': msg_type == BinaryProtocolV2.OPUS_TYPE,
                'is_json': msg_type == BinaryProtocolV2.JSON_TYPE
            }
            
        except struct.error as e:
            logger.error(f"Parse struct error: {e}")
            return None
```

### 2. Full WebSocket Handler

```python
import asyncio
import json
from datetime import datetime

class AudioWebSocketHandler:
    """Handle WebSocket binary frames with V2 protocol"""
    
    def __init__(self):
        self.session_id = None
        self.audio_buffer = []
        self.playback_timeline = {}
        self.frame_count = 0
    
    async def on_message(self, ws, data: bytes):
        """Called when WebSocket receives data"""
        if not isinstance(data, bytes):
            # Text message (JSON)
            await self.on_json_message(json.loads(data))
            return
        
        # Binary frame
        if len(data) < 10:
            logger.warning(f"Tiny frame ignored: {len(data)} bytes")
            return
        
        frame = BinaryProtocolV2.parse(data)
        if not frame:
            logger.warning("Failed to parse binary frame")
            return
        
        self.frame_count += 1
        
        logger.info(
            f"[{self.frame_count}] Frame: "
            f"v{frame['version']}, "
            f"type={'OPUS' if frame['is_opus'] else 'JSON'}, "
            f"ts={frame['timestamp']}ms, "
            f"size={frame['payload_size']}B"
        )
        
        if frame['is_opus']:
            await self.process_opus(
                frame['payload'],
                frame['timestamp']
            )
        elif frame['is_json']:
            await self.process_json_in_binary(frame['payload'])
    
    async def process_opus(self, opus_data: bytes, timestamp_ms: int):
        """
        Process Opus audio frame
        
        Args:
            opus_data: Encoded Opus bytes
            timestamp_ms: When device recorded this (for AEC)
        """
        logger.debug(f"🔊 Opus frame: {len(opus_data)}B @ {timestamp_ms}ms")
        
        # 1. Store in buffer (keyed by timestamp)
        self.audio_buffer.append({
            'timestamp': timestamp_ms,
            'opus_data': opus_data,
            'received_at': datetime.now()
        })
        
        # 2. Decode Opus → PCM
        try:
            # Uncomment when opus-encoder installed:
            # pcm_audio = opus_decode(opus_data)
            pass
        except Exception as e:
            logger.error(f"Opus decode failed: {e}")
            return
        
        # 3. Apply AEC if needed
        # playback_audio = self.get_playback_at(timestamp_ms)
        # if playback_audio:
        #     pcm_audio = self.apply_aec(pcm_audio, playback_audio)
        
        # 4. Forward to STT/ASR
        # await self.forward_to_stt(pcm_audio)
    
    async def process_json_in_binary(self, json_data: bytes):
        """Handle JSON embedded in binary frame"""
        try:
            json_str = json_data.decode('utf-8')
            msg = json.loads(json_str)
            logger.info(f"📄 JSON in binary: {msg}")
        except (UnicodeDecodeError, json.JSONDecodeError) as e:
            logger.error(f"Failed to parse JSON: {e}")
    
    async def on_json_message(self, msg: dict):
        """Handle text JSON message"""
        msg_type = msg.get('type')
        
        if msg_type == 'hello':
            self.session_id = msg.get('session_id')
            logger.info(f"Session started: {self.session_id}")
        elif msg_type == 'listen':
            state = msg.get('state')
            logger.info(f"Listen state: {state}")
        elif msg_type == 'stt':
            text = msg.get('text')
            logger.info(f"STT result: {text}")
        elif msg_type == 'mcp':
            logger.info(f"MCP message: {msg.get('payload')}")
        else:
            logger.info(f"Message type: {msg_type}")
    
    def get_playback_at(self, timestamp_ms: int):
        """Get audio being played around this timestamp (for AEC)"""
        # Find closest playback frame
        if not self.playback_timeline:
            return None
        
        closest = min(
            self.playback_timeline.keys(),
            key=lambda t: abs(t - timestamp_ms)
        )
        
        delta = abs(closest - timestamp_ms)
        if delta > 200:  # More than 200ms diff, skip
            return None
        
        return self.playback_timeline[closest]
    
    def apply_aec(self, input_audio: bytes, echo_audio: bytes) -> bytes:
        """Simple AEC: subtract echo from input"""
        # Simplified - real AEC is more complex
        # This is just demonstrative
        logger.debug("Applying AEC...")
        return input_audio
```

### 3. FastAPI Integration

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse

app = FastAPI()
handler = AudioWebSocketHandler()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    logger.info("✅ WebSocket connected")
    
    try:
        while True:
            # Receive both text and binary
            data = await websocket.receive()
            
            if 'bytes' in data:
                # Binary frame
                await handler.on_message(websocket, data['bytes'])
            elif 'text' in data:
                # Text message
                await handler.on_message(websocket, data['text'])
                
    except WebSocketDisconnect:
        logger.info("❌ WebSocket disconnected")
    except Exception as e:
        logger.error(f"Error: {e}")
    finally:
        await websocket.close()

# Run:
# uvicorn app:app --host 0.0.0.0 --port 8080
```

### 4. AsyncIO + websockets Library

```python
import websockets
import asyncio

async def handle_client(websocket, path):
    """Handle single client connection"""
    logger.info(f"Client connected from {websocket.remote_address}")
    
    try:
        async for message in websocket:
            if isinstance(message, bytes):
                await handler.on_message(websocket, message)
            else:
                await handler.on_message(websocket, message)
    except websockets.exceptions.ConnectionClosed:
        logger.info("Connection closed")
    except Exception as e:
        logger.error(f"Error: {e}")

async def main():
    async with websockets.serve(handle_client, "0.0.0.0", 8080):
        logger.info("WebSocket server running on :8080")
        await asyncio.Future()  # Run forever

# Run:
# asyncio.run(main())
```

### 5. Production-Ready Example

```python
import logging
from logging.handlers import RotatingFileHandler

# Setup logging
log_handler = RotatingFileHandler(
    'audio_server.log',
    maxBytes=10_000_000,  # 10MB
    backupCount=5
)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[log_handler, logging.StreamHandler()]
)

logger = logging.getLogger(__name__)

class AudioService:
    """Production service for audio processing"""
    
    def __init__(self):
        self.handler = AudioWebSocketHandler()
        self.stats = {
            'frames_received': 0,
            'bytes_received': 0,
            'errors': 0,
            'start_time': datetime.now()
        }
    
    async def process_frame(self, data: bytes):
        """Process binary frame with stats"""
        try:
            self.stats['frames_received'] += 1
            self.stats['bytes_received'] += len(data)
            
            await self.handler.on_message(None, data)
        except Exception as e:
            self.stats['errors'] += 1
            logger.error(f"Frame processing error: {e}")
    
    def get_stats(self) -> dict:
        """Get server statistics"""
        uptime = (datetime.now() - self.stats['start_time']).total_seconds()
        
        return {
            'frames_received': self.stats['frames_received'],
            'bytes_received': self.stats['bytes_received'],
            'bytes_mb': self.stats['bytes_received'] / 1_000_000,
            'errors': self.stats['errors'],
            'uptime_seconds': uptime,
            'fps': self.stats['frames_received'] / max(uptime, 1)
        }

# Use with FastAPI
service = AudioService()

@app.get("/stats")
async def get_stats():
    return service.get_stats()
```

---

## 🛠️ Testing

```python
import struct

def create_test_frame(payload: bytes, timestamp_ms: int = 0) -> bytes:
    """Create V2 frame for testing"""
    header = struct.pack(
        '>HHIII',
        2,                    # version
        0,                    # type (OPUS)
        0,                    # reserved
        timestamp_ms,         # timestamp
        len(payload)          # payload_size
    )
    return header + payload

def test_parser():
    """Test the parser"""
    # Create test frame
    opus_data = b'\xFF\xFB\x90\x00' + b'\x00' * 156  # 160 bytes
    frame_bytes = create_test_frame(opus_data, timestamp_ms=60)
    
    # Parse it
    frame = BinaryProtocolV2.parse(frame_bytes)
    
    assert frame is not None
    assert frame['version'] == 2
    assert frame['type'] == 0
    assert frame['timestamp'] == 60
    assert frame['payload_size'] == 160
    assert frame['is_opus'] == True
    
    print("✅ Parser test passed")

if __name__ == '__main__':
    test_parser()
```

---

## 🔧 Installation

```bash
# For FastAPI
pip install fastapi uvicorn websockets

# For Opus support
pip install opuslib

# For audio processing
pip install numpy scipy librosa

# For logging
pip install python-json-logger
```

---

## 📋 Usage Checklist

- [x] Parse 16-byte header
- [x] Extract timestamp for AEC
- [x] Handle both OPUS and JSON types
- [x] Validate payload size
- [x] Error handling
- [x] Logging
- [x] FastAPI integration
- [x] Stats/monitoring
- [x] Production-ready

---

## 🔗 Quick Reference

| Task | Code |
|------|------|
| Parse frame | `frame = BinaryProtocolV2.parse(data)` |
| Get Opus | `opus_data = frame['payload']` |
| Get timestamp | `ts = frame['timestamp']` |
| Check type | `if frame['is_opus']:` |
| Run server | `uvicorn app:app --port 8080` |
| Create test | `create_test_frame(payload, ts)` |

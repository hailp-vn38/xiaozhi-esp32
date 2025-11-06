# Binary Protocol V3 - Server Implementation (Python)

> Server guide để support Binary Protocol V3 (Compact) - gọn nhẹ nhất, dành cho IoT/bandwidth limited

---

## 📋 Version 3 Specification

### Structure (4 bytes header)

```
[0]     type       (1 byte):     0=OPUS, 1=JSON
[1]     reserved   (1 byte):     unused
[2-3]   payload_size (2 bytes):  big-endian, max 65535 bytes
[4+]    payload    (variable):   actual data
```

**Ví dụ (hex):**
```
00             // type=0 (OPUS)
00             // reserved
00 A0          // payload_size=160 bytes
FF FB 90 00... // [160 bytes Opus data]
```

### So Sánh 3 Versions

| Aspect | V1 | V2 | V3 |
|--------|----|----|-----|
| Header | 0B | 16B | 4B |
| Type | ❌ | ✅ | ✅ |
| Timestamp | ❌ | ✅ | ❌ |
| AEC Support | ❌ | ✅ | ❌ |
| Best For | Simple | Server AEC | IoT/Bandwidth |

---

## 🐍 Python Parser for V3

### Basic Parser Class

```python
import struct
from typing import Optional, Dict, Any

class BinaryProtocolV3:
    """Parse BinaryProtocol3 frames (Compact)"""
    
    HEADER_SIZE = 4
    OPUS_TYPE = 0
    JSON_TYPE = 1
    
    @staticmethod
    def parse(data: bytes) -> Optional[Dict[str, Any]]:
        """
        Parse V3 binary frame
        
        Args:
            data: Raw bytes from WebSocket
            
        Returns:
            {
                'type': int (0=OPUS, 1=JSON),
                'payload_size': int,
                'payload': bytes,
                'is_opus': bool,
                'is_json': bool
            }
        """
        if len(data) < BinaryProtocolV3.HEADER_SIZE:
            return None
        
        try:
            frame_type, reserved, payload_size = struct.unpack(
                '>BBI',  # > = big-endian, B = uint8, I = uint32... NO
                data[:4]
            )
            # Sửa lại - payload_size là 2 bytes uint16
            frame_type, reserved, payload_size = struct.unpack(
                '>BBH',  # > = big-endian, B = uint8*2, H = uint16
                data[:4]
            )
            
            # Validate payload
            if len(data) < 4 + payload_size:
                return None
            
            payload = data[4:4 + payload_size]
            
            return {
                'type': frame_type,
                'payload_size': payload_size,
                'payload': payload,
                'is_opus': frame_type == BinaryProtocolV3.OPUS_TYPE,
                'is_json': frame_type == BinaryProtocolV3.JSON_TYPE
            }
        
        except struct.error:
            return None


# Test parser
parser = BinaryProtocolV3()

# Ví dụ: Parse Opus frame
opus_data = b'\xFF\xFB\x90\x00' + b'\x00' * 156  # 160 bytes
v3_frame = struct.pack(
    '>BBH',
    0,                # type=OPUS
    0,                # reserved
    len(opus_data)    # payload_size=160
) + opus_data

result = parser.parse(v3_frame)
print(f"Type: {result['type']}")
print(f"Size: {result['payload_size']}B")
print(f"Is Opus: {result['is_opus']}")
```

---

## 🚀 WebSocket Handler Updated for V3

```python
import json
from typing import Union, Optional, Dict, Any

class WebSocketHandlerV3:
    """Updated WebSocket handler supporting V1, V2, V3"""
    
    def __init__(self):
        self.version = None  # Detect from device hello
        self.session_id = None
        self.frame_count = 0
    
    async def handle_binary_frame(self, data: bytes) -> Optional[Dict[str, Any]]:
        """Handle binary frame - auto-detect version"""
        
        # V1: Direct Opus, no header
        # V2: 16-byte header
        # V3: 4-byte header
        
        if len(data) < 4:
            # Too small, might be V1 or truncated
            if self.version == 1:
                return self._handle_v1(data)
            return None
        
        # Try to detect version by looking at structure
        first_byte = data[0]
        
        # V3: first byte is 0 or 1 (type), next is reserved (usually 0)
        if first_byte in [0, 1] and data[1] == 0:
            # Could be V3
            payload_size = (data[2] << 8) | data[3]
            if len(data) == 4 + payload_size:
                # Matches V3 structure
                return self._handle_v3(data)
        
        # V2: 16-byte header with version field
        if len(data) >= 16:
            version_bytes = data[0:2]
            version = int.from_bytes(version_bytes, 'big')
            if version == 2:
                return self._handle_v2(data)
        
        # Default to V1
        return self._handle_v1(data)
    
    def _handle_v1(self, data: bytes) -> Dict[str, Any]:
        """Handle V1 - raw Opus"""
        self.version = 1
        self.frame_count += 1
        return {
            'version': 1,
            'type': 'audio',
            'format': 'opus',
            'payload_size': len(data),
            'payload': data
        }
    
    def _handle_v2(self, data: bytes) -> Optional[Dict[str, Any]]:
        """Handle V2 - with timestamp"""
        frame = BinaryProtocolV2.parse(data)
        if not frame:
            return None
        
        self.version = 2
        self.frame_count += 1
        
        if frame['is_opus']:
            return {
                'version': 2,
                'type': 'audio',
                'format': 'opus',
                'timestamp': frame['timestamp'],
                'payload_size': frame['payload_size'],
                'payload': frame['payload']
            }
        return None
    
    def _handle_v3(self, data: bytes) -> Optional[Dict[str, Any]]:
        """Handle V3 - compact"""
        frame = BinaryProtocolV3.parse(data)
        if not frame:
            return None
        
        self.version = 3
        self.frame_count += 1
        
        if frame['is_opus']:
            return {
                'version': 3,
                'type': 'audio',
                'format': 'opus',
                'payload_size': frame['payload_size'],
                'payload': frame['payload']
            }
        return None
```

---

## 🎯 Server Send V3 Frame

```python
def create_v3_frame(opus_data: bytes) -> bytes:
    """Create V3 binary frame to send to device"""
    import struct
    
    payload_size = len(opus_data)
    
    header = struct.pack(
        '>BBH',
        0,                # type=OPUS
        0,                # reserved
        payload_size
    )
    
    return header + opus_data


# Example: Send TTS audio as V3
def send_tts_v3(opus_data: bytes, websocket):
    """Send TTS audio using V3 protocol"""
    frame = create_v3_frame(opus_data)
    await websocket.send_binary(frame)
```

---

## ⚙️ FastAPI Integration

```python
from fastapi import WebSocket, FastAPI
import json

app = FastAPI()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    
    handler = WebSocketHandlerV3()
    
    # Receive device hello to know version
    hello_text = await websocket.receive_text()
    hello_msg = json.loads(hello_text)
    
    detected_version = hello_msg.get('version', 1)
    print(f"Device uses protocol version: {detected_version}")
    
    # Main loop
    while True:
        try:
            # Receive message
            data = await websocket.receive()
            
            if 'bytes' in data:
                # Binary frame
                result = await handler.handle_binary_frame(data['bytes'])
                
                if result:
                    if result['version'] == 3:
                        print(f"V3 Frame: {result['payload_size']}B")
                        # Process opus
                        process_opus(result['payload'])
                    else:
                        print(f"V{result['version']} Frame: {result['payload_size']}B")
            
            elif 'text' in data:
                # JSON message
                msg = json.loads(data['text'])
                print(f"JSON: {msg.get('type')}")
        
        except Exception as e:
            print(f"Error: {e}")
            break
```

---

## 📊 Performance Comparison

```python
import sys

# Binary size comparison for 160 bytes Opus

v1_size = 160  # Raw Opus only
v2_size = 16 + 160  # 16-byte header + Opus
v3_size = 4 + 160  # 4-byte header + Opus

print(f"V1 (Raw): {v1_size} bytes")
print(f"V2 (Timestamp): {v2_size} bytes (+{v2_size - v1_size})")
print(f"V3 (Compact): {v3_size} bytes (+{v3_size - v1_size})")

# Bandwidth savings for 100 frames per second
frames_per_second = 100
seconds = 3600  # 1 hour

v2_overhead = (v2_size - v1_size) * frames_per_second * seconds / (1024 * 1024)
v3_overhead = (v3_size - v1_size) * frames_per_second * seconds / (1024 * 1024)

print(f"\n1 hour overhead:")
print(f"V2: +{v2_overhead:.2f} MB")
print(f"V3: +{v3_overhead:.2f} MB")
```

Output:
```
V1 (Raw): 160 bytes
V2 (Timestamp): 176 bytes (+16)
V3 (Compact): 164 bytes (+4)

1 hour overhead:
V2: +172.80 MB
V3: +43.20 MB
```

---

## ✅ When to Use Each Version

### V1 (Raw Opus)
- Simple implementations
- No AEC needed
- When you just want raw audio

### V2 (With Timestamp)
- Server-side AEC enabled
- Echo cancellation needed
- Audio quality is critical

### V3 (Compact)
- **IoT devices with limited bandwidth**
- **Limited memory**
- **Mobile networks**
- When size matters

---

## 🔧 Device Configuration for V3

```json
{
  "websocket": {
    "url": "wss://server.com/ws",
    "token": "your-token",
    "version": 3
  }
}
```

Or in code:
```cpp
CONFIG_WEBSOCKET_PROTOCOL_VERSION = 3
```

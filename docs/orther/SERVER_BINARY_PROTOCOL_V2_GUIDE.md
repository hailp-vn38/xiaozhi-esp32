# Server Binary Protocol V2 Implementation Guide

> Hướng dẫn upgrade server từ version 1 (raw Opus) sang version 2 (Opus + Metadata + Timestamp)

---

## 🔄 So Sánh V1 vs V2

| Aspect | V1 (Raw) | V2 (Metadata) |
|--------|----------|---------------|
| **Format** | `[Opus payload]` | `[header 16B][Opus payload]` |
| **Timestamp** | ❌ Không | ✅ Có (4 bytes) |
| **Type Field** | ❌ Không | ✅ Có (0=OPUS, 1=JSON) |
| **Version Field** | ❌ Không | ✅ Có (2 bytes) |
| **AEC Support** | Khó | ✅ Dễ (timestamp sync) |
| **Use Case** | Simple | Professional (with AEC) |

---

## 📦 Binary Protocol V2 Structure

```
[0-1]    version      (uint16, big-endian)
[2-3]    type         (uint16, big-endian): 0=OPUS, 1=JSON
[4-7]    reserved     (uint32, unused)
[8-11]   timestamp    (uint32, big-endian, milliseconds)
[12-15]  payload_size (uint32, big-endian)
[16+]    payload      (variable length)
```

**Total Header: 16 bytes**

---

## ✅ Device Sends V2

Device gửi binary frame như này:

```
Raw bytes:
00 02          // version = 2
00 00          // type = 0 (OPUS)
00 00 00 00    // reserved
00 00 00 3C    // timestamp = 60ms
00 00 00 A0    // payload_size = 160 bytes
FF FB 90 ...   // [160 bytes Opus data]
```

---

## 🖥️ Server Implementation

### 1️⃣ **Python (FastAPI + WebSockets)**

```python
import struct
import logging
from typing import Optional
from fastapi import WebSocket

logger = logging.getLogger(__name__)

class BinaryProtocolV2Parser:
    HEADER_SIZE = 16
    OPUS_FRAME_TYPE = 0
    JSON_FRAME_TYPE = 1
    
    @staticmethod
    def parse(data: bytes) -> Optional[dict]:
        """Parse BinaryProtocol2 frame"""
        if len(data) < BinaryProtocolV2Parser.HEADER_SIZE:
            logger.error(f"Frame too small: {len(data)} bytes")
            return None
        
        try:
            # Unpack header (big-endian)
            version, frame_type, reserved, timestamp, payload_size = struct.unpack(
                '>HHIII',
                data[:16]
            )
            
            # Verify payload size
            if len(data) < 16 + payload_size:
                logger.error(f"Incomplete payload: expected {payload_size}, got {len(data) - 16}")
                return None
            
            payload = data[16:16 + payload_size]
            
            return {
                'version': version,
                'type': frame_type,
                'timestamp': timestamp,
                'payload_size': payload_size,
                'payload': payload,
                'is_opus': frame_type == BinaryProtocolV2Parser.OPUS_FRAME_TYPE,
                'is_json': frame_type == BinaryProtocolV2Parser.JSON_FRAME_TYPE
            }
            
        except struct.error as e:
            logger.error(f"Parse error: {e}")
            return None


class AudioWebSocketHandler:
    def __init__(self):
        self.audio_buffer = {}
        self.timestamp_offset = 0
    
    async def handle_binary_frame(self, ws: WebSocket, data: bytes):
        """Process incoming binary frame"""
        frame = BinaryProtocolV2Parser.parse(data)
        
        if not frame:
            logger.warning("Failed to parse frame")
            return
        
        logger.info(
            f"Frame: version={frame['version']}, "
            f"type={'OPUS' if frame['is_opus'] else 'JSON'}, "
            f"timestamp={frame['timestamp']}ms, "
            f"size={frame['payload_size']}B"
        )
        
        if frame['is_opus']:
            await self.process_opus(frame['payload'], frame['timestamp'])
        elif frame['is_json']:
            await self.process_json_in_binary(frame['payload'])
    
    async def process_opus(self, opus_data: bytes, timestamp_ms: int):
        """
        Process Opus audio frame
        
        Args:
            opus_data: Opus encoded audio
            timestamp_ms: Timestamp in milliseconds (for AEC alignment)
        """
        logger.debug(f"Decoding Opus: {len(opus_data)} bytes @ {timestamp_ms}ms")
        
        # 1. Decode Opus -> PCM
        # pcm_audio = opus_decoder.decode(opus_data)
        
        # 2. Apply AEC if enabled
        # if self.aec_enabled:
        #     pcm_audio = self.apply_aec(pcm_audio, timestamp_ms)
        
        # 3. Forward to STT
        # await self.stt_service.process_audio(pcm_audio)
        pass
    
    async def process_json_in_binary(self, json_data: bytes):
        """Process JSON embedded in binary payload"""
        try:
            json_str = json_data.decode('utf-8')
            logger.info(f"Embedded JSON: {json_str}")
        except UnicodeDecodeError as e:
            logger.error(f"Failed to decode JSON: {e}")


# FastAPI endpoint
from fastapi import FastAPI

app = FastAPI()
handler = AudioWebSocketHandler()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            # Receive message (text or binary)
            data = await websocket.receive_bytes()
            
            if isinstance(data, bytes) and len(data) > 10:
                # Likely binary audio frame
                await handler.handle_binary_frame(websocket, data)
            else:
                # Text message (JSON)
                text = await websocket.receive_text()
                logger.info(f"Text: {text}")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        await websocket.close()
```

---

### 2️⃣ **Node.js (Express + ws)**

```javascript
const WebSocket = require('ws');
const express = require('express');

class BinaryProtocolV2 {
    static HEADER_SIZE = 16;
    static OPUS = 0;
    static JSON = 1;
    
    static parse(buffer) {
        if (buffer.length < this.HEADER_SIZE) {
            throw new Error(`Frame too small: ${buffer.length}`);
        }
        
        const version = buffer.readUInt16BE(0);
        const type = buffer.readUInt16BE(2);
        const reserved = buffer.readUInt32BE(4);  // unused
        const timestamp = buffer.readUInt32BE(8);
        const payloadSize = buffer.readUInt32BE(12);
        
        if (buffer.length < 16 + payloadSize) {
            throw new Error(
                `Incomplete payload: expected ${payloadSize}, ` +
                `got ${buffer.length - 16}`
            );
        }
        
        return {
            version,
            type,
            timestamp,
            payloadSize,
            payload: buffer.slice(16, 16 + payloadSize),
            isOpus: type === this.OPUS,
            isJson: type === this.JSON
        };
    }
}

class AudioHandler {
    handleBinaryFrame(data) {
        try {
            const frame = BinaryProtocolV2.parse(data);
            
            console.log(
                `📦 Frame: v${frame.version}, ` +
                `type=${frame.isOpus ? 'OPUS' : 'JSON'}, ` +
                `ts=${frame.timestamp}ms, ` +
                `size=${frame.payloadSize}B`
            );
            
            if (frame.isOpus) {
                this.processOpus(frame.payload, frame.timestamp);
            } else if (frame.isJson) {
                const json = JSON.parse(frame.payload.toString());
                console.log('📄 JSON:', json);
            }
        } catch (error) {
            console.error('Parse error:', error.message);
        }
    }
    
    processOpus(opusData, timestamp) {
        console.log(
            `🔊 Opus: ${opusData.length}B @ ${timestamp}ms`
        );
        
        // Decode Opus -> PCM
        // const pcm = opusDecoder.decode(opusData);
        
        // Forward to STT
        // sttService.process(pcm, timestamp);
    }
}

const app = express();
const wss = new WebSocket.Server({ noServer: true });
const handler = new AudioHandler();

app.get('/ws', (req, res) => {
    wss.handleUpgrade(req, req.socket, Buffer.alloc(0), (ws) => {
        console.log('✅ WebSocket connected');
        
        ws.on('message', (data, isBinary) => {
            if (isBinary) {
                handler.handleBinaryFrame(data);
            } else {
                // Text JSON
                const json = JSON.parse(data);
                console.log('📝 JSON:', json);
            }
        });
        
        ws.on('close', () => {
            console.log('❌ WebSocket closed');
        });
    });
});

app.listen(8080, () => console.log('Server on :8080'));
```

---

### 3️⃣ **Go (Gorilla + WebSocket)**

```go
package main

import (
    "encoding/binary"
    "encoding/json"
    "log"
    "net/http"
    
    "github.com/gorilla/websocket"
)

type BinaryProtocolV2 struct {
    Version     uint16
    Type        uint16
    Reserved    uint32
    Timestamp   uint32
    PayloadSize uint32
    Payload     []byte
}

type AudioHandler struct {
    upgrader websocket.Upgrader
}

func (h *AudioHandler) ParseBinaryV2(data []byte) (*BinaryProtocolV2, error) {
    if len(data) < 16 {
        return nil, fmt.Errorf("frame too small: %d", len(data))
    }
    
    frame := &BinaryProtocolV2{
        Version:     binary.BigEndian.Uint16(data[0:2]),
        Type:        binary.BigEndian.Uint16(data[2:4]),
        Reserved:    binary.BigEndian.Uint32(data[4:8]),
        Timestamp:   binary.BigEndian.Uint32(data[8:12]),
        PayloadSize: binary.BigEndian.Uint32(data[12:16]),
    }
    
    if len(data) < 16+int(frame.PayloadSize) {
        return nil, fmt.Errorf("incomplete payload")
    }
    
    frame.Payload = data[16 : 16+frame.PayloadSize]
    return frame, nil
}

func (h *AudioHandler) ServeWS(w http.ResponseWriter, r *http.Request) {
    ws, err := h.upgrader.Upgrade(w, r, nil)
    if err != nil {
        log.Println("Upgrade error:", err)
        return
    }
    defer ws.Close()
    
    log.Println("✅ WebSocket connected")
    
    for {
        _, data, err := ws.ReadMessage()
        if err != nil {
            log.Println("❌ Read error:", err)
            break
        }
        
        frame, err := h.ParseBinaryV2(data)
        if err != nil {
            log.Println("Parse error:", err)
            continue
        }
        
        typeStr := "OPUS"
        if frame.Type == 1 {
            typeStr = "JSON"
        }
        
        log.Printf(
            "📦 Frame: v%d, type=%s, ts=%dms, size=%dB\n",
            frame.Version, typeStr, frame.Timestamp, frame.PayloadSize,
        )
        
        if frame.Type == 0 {
            h.processOpus(frame.Payload, frame.Timestamp)
        } else if frame.Type == 1 {
            var msg map[string]interface{}
            json.Unmarshal(frame.Payload, &msg)
            log.Printf("📄 JSON: %v\n", msg)
        }
    }
}

func (h *AudioHandler) processOpus(opus []byte, timestamp uint32) {
    log.Printf("🔊 Opus: %dB @ %dms\n", len(opus), timestamp)
    // Decode & process...
}

func main() {
    handler := &AudioHandler{
        upgrader: websocket.Upgrader{
            CheckOrigin: func(r *http.Request) bool { return true },
        },
    }
    
    http.HandleFunc("/ws", handler.ServeWS)
    log.Println("Server on :8080")
    http.ListenAndServe(":8080", nil)
}
```

---

## 🎯 Key Points for Server

### ✅ Do's

1. **Always check header size first** - Validate 16 bytes minimum
2. **Use `ntohs()` / `ntohl()`** - Convert from big-endian network byte order
3. **Validate payload_size** - Ensure frame has enough data
4. **Store timestamp** - Use for AEC alignment if server AEC enabled
5. **Handle both v1 and v2** - Gradual rollout

### ❌ Don'ts

1. ❌ Assume payload starts at byte 0
2. ❌ Ignore byte order (always big-endian)
3. ❌ Skip validation
4. ❌ Mix v1 and v2 without version detection

---

## 🔍 Debug Checklist

```
[ ] Device sends version: 2 in hello message
[ ] Binary frame received > 16 bytes
[ ] Header bytes parsed correctly
[ ] Timestamp increases monotonically
[ ] Payload size matches actual data
[ ] Opus decoder works with payload
[ ] No crashes on edge cases
```

---

## 🚀 Migration Path

### Phase 1: Support Both V1 and V2
```python
def detect_version(data):
    if len(data) == 0:
        return None
    
    # V2 has 16+ byte header, check version field
    if len(data) >= 16:
        version = struct.unpack('>H', data[0:2])[0]
        if version in [1, 2, 3]:
            return version
    
    # Assume V1 (raw Opus)
    return 1

if detect_version(data) == 2:
    frame = parse_v2(data)
else:
    # Raw Opus
    opus_data = data
```

### Phase 2: Enforce V2 Only
- Update device config to `version: 2`
- Deprecate V1 support
- Improve AEC accuracy

---

## 📊 Performance Impact

- **Header overhead:** 16 bytes per frame (~60ms) = negligible
- **Processing:** Parsing takes ~1-2ms (very fast)
- **AEC benefit:** Much better echo cancellation with timestamp alignment

---

## 🔗 References

- [BinaryProtocol2 Struct](../main/protocols/protocol.h)
- [Device Send Code](../main/protocols/websocket_protocol.cc)
- [Full Protocol Doc](./WEBSOCKET_FLOWS_COMPLETE.md)

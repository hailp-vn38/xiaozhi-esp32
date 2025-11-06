# WebSocket Protocol - Toàn Bộ Flows & Format

> Tài liệu này mô tả chi tiết tất cả loại message WebSocket, format JSON, kèm ví dụ thực tế và sequence diagram.

---

## 📋 Mục Lục

1. [Header & Kết Nối](#header--kết-nối)
2. [Hello Handshake](#hello-handshake)
3. [Audio Streaming](#audio-streaming)
4. [STT Flow (Speech-to-Text)](#stt-flow-speech-to-text)
5. [TTS Flow (Text-to-Speech)](#tts-flow-text-to-speech)
6. [LLM Flow](#llm-flow)
7. [MCP - IoT Control](#mcp---iot-control)
8. [System Commands](#system-commands)
9. [Custom Messages](#custom-messages)
10. [Error Handling](#error-handling)
11. [Complete Conversation Flow](#complete-conversation-flow)

---

## Header & Kết Nối

### WebSocket Headers

Device gửi kèm các header khi kết nối:

```http
Authorization: Bearer <token>
Protocol-Version: 1
Device-Id: AA:BB:CC:DD:EE:FF
Client-Id: 550e8400-e29b-41d4-a716-446655440000
```

**Chi tiết:**

- `Authorization`: Token xác thực, format `Bearer <token>`
- `Protocol-Version`: Phiên bản giao thức nhị phân (1, 2 hoặc 3)
- `Device-Id`: MAC address của thiết bị
- `Client-Id`: UUID unique cho mỗi client

---

## Hello Handshake

### Bước 1: Device Gửi Hello

**Lúc:** Device vừa kết nối thành công

```json
{
  "type": "hello",
  "version": 1,
  "features": {
    "mcp": true,
    "aec": false
  },
  "transport": "websocket",
  "audio_params": {
    "format": "opus",
    "sample_rate": 16000,
    "channels": 1,
    "frame_duration": 60
  }
}
```

**Ý nghĩa:**

- `version`: Phiên bản giao thức nhị phân (1, 2, 3)
- `features.mcp`: Device có hỗ trợ MCP (IoT tools)
- `features.aec`: Device hỗ trợ Server-side AEC (Acoustic Echo Cancellation)
- `audio_params`: Thông số audio mặc định

---

### Bước 2: Server Phản Hồi Hello

**Lúc:** Server nhận được hello từ device

```json
{
  "type": "hello",
  "transport": "websocket",
  "session_id": "sess_1699564800_abc123def456",
  "audio_params": {
    "format": "opus",
    "sample_rate": 16000,
    "channels": 1,
    "frame_duration": 60
  }
}
```

**Ý nghĩa:**

- `session_id`: ID phiên làm việc (dùng cho tất cả message tiếp theo)
- `audio_params`: Server có thể điều chỉnh tham số audio

**Status:** ✅ Kênh WebSocket sẵn sàng

---

## Audio Streaming

### Binary Audio Frame Format

Device và Server trao đổi audio qua **binary frames**. Format phụ thuộc vào `version`:

#### Version 1 (Raw Opus - Mặc định)

```
[Opus payload data]
```

- Gửi trực tiếp dữ liệu Opus
- WebSocket tự phân biệt text/binary frames

**Ví dụ:**

```
Binary: 0xFF 0xFB 0x90 0x00 ... (raw opus frame ~50-500 bytes)
```

---

#### Version 2 (Metadata + Timestamp)

```c
struct BinaryProtocol2 {
    uint16_t version;        // 2 bytes, network order (big-endian)
    uint16_t type;           // 2 bytes: 0=OPUS, 1=JSON
    uint32_t reserved;       // 4 bytes: unused
    uint32_t timestamp;      // 4 bytes: milliseconds (for AEC)
    uint32_t payload_size;   // 4 bytes: size of payload
    uint8_t  payload[];      // variable: actual data
}
```

**Total header: 16 bytes**

**Ví dụ (hex):**

```
00 01          // version=1
00 00          // type=0 (OPUS)
00 00 00 00    // reserved
00 00 00 1E    // timestamp=30ms
00 00 00 A0    // payload_size=160 bytes
FF FB 90 00... // [160 bytes Opus data]
```

---

#### Version 3 (Compact)

```c
struct BinaryProtocol3 {
    uint8_t  type;           // 1 byte: 0=OPUS, 1=JSON
    uint8_t  reserved;       // 1 byte: unused
    uint16_t payload_size;   // 2 bytes: network order
    uint8_t  payload[];      // variable: actual data
}
```

**Total header: 4 bytes (gọn nhất)**

**Ví dụ (hex):**

```
00             // type=0 (OPUS)
00             // reserved
00 A0          // payload_size=160 bytes
FF FB 90 00... // [160 bytes Opus data]
```

---

### Server Implementation Guide - Version 2 Support

#### Binary Protocol Version 2 Parsing (C/C++ Server)

Khi device gửi `version: 2` trong hello message, server cần xử lý binary frames với metadata.

**Header Format:**

```
Bytes 0-1:   version (2 bytes, big-endian)
Bytes 2-3:   type (2 bytes, big-endian): 0=OPUS, 1=JSON
Bytes 4-7:   reserved (4 bytes, unused)
Bytes 8-11:  timestamp (4 bytes, big-endian, milliseconds)
Bytes 12-15: payload_size (4 bytes, big-endian)
Bytes 16+:   payload data (variable length)
```

**Python Example - Parse BinaryProtocol2:**

```python
import struct
import socket

class WebSocketBinaryParser:
    def parse_binary_protocol_v2(self, data: bytes) -> dict:
        """
        Parse BinaryProtocol2 from received WebSocket binary frame

        Args:
            data: Raw binary data received from device

        Returns:
            {
                'version': int,
                'type': int (0=OPUS, 1=JSON),
                'timestamp': int (milliseconds),
                'payload_size': int,
                'payload': bytes
            }
        """
        if len(data) < 16:
            raise ValueError(f"Incomplete header: got {len(data)} bytes, need 16+")

        # Unpack header (all big-endian)
        version, msg_type, reserved, timestamp, payload_size = struct.unpack(
            '>HHIII',  # > = big-endian, HH = uint16*2, III = uint32*3
            data[:16]
        )

        # Extract payload
        payload = data[16:16+payload_size]

        if len(payload) != payload_size:
            raise ValueError(f"Incomplete payload: got {len(payload)} bytes, expected {payload_size}")

        return {
            'version': version,
            'type': msg_type,
            'timestamp': timestamp,  # Milliseconds - dùng cho AEC
            'payload_size': payload_size,
            'payload': payload,
            'is_opus': msg_type == 0,
            'is_json': msg_type == 1
        }

# Usage Example
parser = WebSocketBinaryParser()

async def on_websocket_message(ws, data):
    if isinstance(data, bytes):  # Binary frame
        try:
            frame = parser.parse_binary_protocol_v2(data)

            if frame['is_opus']:
                # Process Opus audio
                print(f"Received Opus frame: {frame['payload_size']} bytes, timestamp={frame['timestamp']}ms")
                # Gửi tới Opus decoder
                process_opus_audio(frame['payload'], frame['timestamp'])

            elif frame['is_json']:
                # Handle JSON embedded in binary
                json_text = frame['payload'].decode('utf-8')
                print(f"Received JSON in binary: {json_text}")

        except ValueError as e:
            print(f"Parse error: {e}")
```

---

#### Using Timestamp for Server-side AEC

Timestamp trong v2 rất hữu ích cho **Acoustic Echo Cancellation (AEC)**:

```python
class AudioProcessorWithAEC:
    def __init__(self):
        self.audio_buffer = {}  # {timestamp: audio_frame}
        self.playback_timeline = {}  # Track what's being played

    def on_device_audio(self, opus_payload: bytes, timestamp_ms: int):
        """
        Device gửi audio + timestamp
        Timestamp dùng để align với audio đang được phát
        """
        print(f"Device audio @ {timestamp_ms}ms: {len(opus_payload)} bytes")

        # Store with timestamp
        self.audio_buffer[timestamp_ms] = opus_payload

        # Get corresponding playback audio để làm AEC
        playback_audio = self.get_playback_at(timestamp_ms)

        if playback_audio:
            # Apply AEC (Echo Cancellation)
            cleaned_audio = self.apply_aec(
                input_audio=opus_payload,
                echo_audio=playback_audio
            )
            print(f"After AEC: echo removed")

        # Forward to speech recognition
        self.forward_to_stt(opus_payload)

    def get_playback_at(self, timestamp_ms: int):
        """
        Lấy audio đang được phát vào thời điểm đó
        để làm AEC
        """
        # Find playback frame gần nhất với timestamp này
        closest_time = min(
            self.playback_timeline.keys(),
            key=lambda t: abs(t - timestamp_ms)
        )
        return self.playback_timeline.get(closest_time)

    def apply_aec(self, input_audio, echo_audio):
        """
        Apply Acoustic Echo Cancellation
        Remove echo_audio từ input_audio
        """
        # Using WebRtc AEC hoặc tương tự
        # Mã tả đơn giản:
        # cleaned = input_audio - alpha * echo_audio
        return input_audio
```

---

#### Configuration on Device

Khi muốn enable version 2, device cần config:

```json
// NVS settings hoặc settings.json
{
  "websocket": {
    "url": "wss://your-server.com/ws",
    "token": "your-token",
    "version": 2
  }
}
```

Trong `menuconfig` (Kconfig.projbuild):

```
CONFIG_WEBSOCKET_PROTOCOL_VERSION = 2
```

---

### Audio Parameters

- **Format:** Opus (lossless at 16kbps)
- **Sample Rate:** 16000 Hz (mặc định), có thể 24000 Hz
- **Channels:** 1 (mono)
- **Frame Duration:** 60 ms (mặc định)

---

## STT Flow (Speech-to-Text)

### Sequence

```
1. Device → Server: "listen" (start)
2. Device → Server: Audio frames (binary)
3. Server → Device: "stt" (kết quả)
```

### Bước 1: Device Báo Bắt Đầu Ghi Âm

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "listen",
  "state": "start",
  "mode": "manual"
}
```

**Các mode:**

- `"manual"`: User bấm nút bắt đầu → bấm nút dừng
- `"auto"`: Device tự detect khi nói xong (VAD)
- `"realtime"`: Gửi audio realtime, server xử lý stream

---

### Bước 2: Device Gửi Audio Streams

Device gửi liên tục binary audio frames trong khi nghe:

```
[Binary Audio Frame 1]
[Binary Audio Frame 2]
[Binary Audio Frame 3]
...
```

Mỗi frame ~50-500 bytes (tùy encoding rate)

---

### Bước 3: Khi Nói Xong - Device Báo Stop (nếu manual mode)

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "listen",
  "state": "stop"
}
```

---

### Bước 4: Server Gửi Kết Quả STT

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "stt",
  "text": "Bật đèn phòng khách"
}
```

**Ý nghĩa:**

- `text`: Kết quả nhận dạng từ server
- Device hiển thị lên màn hình và chuyển sang xử lý

---

## TTS Flow (Text-to-Speech)

### Sequence

```
1. Server → Device: "tts" (state: start)
2. Server → Device: Audio frames (binary)
3. Server → Device: "tts" (state: stop)
```

### Bước 1: Server Báo Bắt Đầu TTS

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "tts",
  "state": "start"
}
```

**Ý nghĩa:**

- Device chuyển sang **trạng thái phát**
- Dừng ghi âm nếu đang ghi

---

### Bước 2: Server Gửi Audio Streams

Server gửi liên tục binary audio frames để device phát:

```
[Binary Audio Frame 1]
[Binary Audio Frame 2]
[Binary Audio Frame 3]
...
```

---

### Bước 3 (Tùy chọn): Server Hiển Thị Text

Trước khi phát, server có thể gửi text để hiển thị:

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "tts",
  "state": "sentence_start",
  "text": "Xin chào, đèn phòng khách đã được bật"
}
```

---

### Bước 4: Server Báo Kết Thúc TTS

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "tts",
  "state": "stop"
}
```

**Ý nghĩa:**

- Device dừng phát
- Quay về trạng thái **Idle** (hoặc sẵn sàng cho vòng lặp tiếp theo)

---

## LLM Flow

### Server Cập Nhật Biểu Cảm & UI

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "llm",
  "emotion": "happy",
  "text": "😊"
}
```

**Ý nghĩa:**

- `emotion`: Trạng thái cảm xúc (happy, sad, angry, confused, ...)
- `text`: Emoji hoặc text để hiển thị
- Device cập nhật giao diện hoặc LED

---

## MCP - IoT Control

MCP (Model Context Protocol) dùng JSON-RPC 2.0 để điều khiển IoT.

### 1️⃣ Initialize MCP

#### Server Gửi Initialize Request

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "mcp",
  "payload": {
    "jsonrpc": "2.0",
    "method": "initialize",
    "params": {
      "capabilities": {
        "vision": {
          "url": "https://api.example.com/vision",
          "token": "eyJhbGciOiJIUzI1NiIs..."
        }
      }
    },
    "id": 1
  }
}
```

---

#### Device Phản Hồi Initialize

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "mcp",
  "payload": {
    "jsonrpc": "2.0",
    "id": 1,
    "result": {
      "protocolVersion": "2024-11-05",
      "capabilities": {
        "tools": {}
      },
      "serverInfo": {
        "name": "Xiaozhi-ESP32",
        "version": "1.2.3"
      }
    }
  }
}
```

---

### 2️⃣ Get Tools List

#### Server Gửi tools/list Request

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "mcp",
  "payload": {
    "jsonrpc": "2.0",
    "method": "tools/list",
    "params": {
      "cursor": ""
    },
    "id": 2
  }
}
```

---

#### Device Trả Về Tools List

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "mcp",
  "payload": {
    "jsonrpc": "2.0",
    "id": 2,
    "result": {
      "tools": [
        {
          "name": "self.get_device_status",
          "description": "Get current device status (volume, brightness, battery, ...)",
          "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
          }
        },
        {
          "name": "self.audio_speaker.set_volume",
          "description": "Set the volume of the audio speaker",
          "inputSchema": {
            "type": "object",
            "properties": {
              "volume": {
                "type": "integer",
                "description": "Volume level (0-100)"
              }
            },
            "required": ["volume"]
          }
        },
        {
          "name": "self.light.set_rgb",
          "description": "Set RGB color of the LED light",
          "inputSchema": {
            "type": "object",
            "properties": {
              "r": {
                "type": "integer",
                "description": "Red channel (0-255)"
              },
              "g": {
                "type": "integer",
                "description": "Green channel (0-255)"
              },
              "b": {
                "type": "integer",
                "description": "Blue channel (0-255)"
              }
            },
            "required": ["r", "g", "b"]
          }
        },
        {
          "name": "self.screen.display_text",
          "description": "Display text on the screen",
          "inputSchema": {
            "type": "object",
            "properties": {
              "text": {
                "type": "string",
                "description": "Text to display"
              },
              "duration": {
                "type": "integer",
                "description": "Display duration in seconds (0 = keep)"
              }
            },
            "required": ["text"]
          }
        }
      ],
      "nextCursor": ""
    }
  }
}
```

**Phân Trang (nếu có nhiều tools):**

Nếu tools quá nhiều (vượt ~8KB payload), device sẽ trả `nextCursor`:

```json
{
  "payload": {
    "jsonrpc": "2.0",
    "id": 2,
    "result": {
      "tools": [...],
      "nextCursor": "self.light.set_rgb"
    }
  }
}
```

Server tiếp tục gửi:

```json
{
  "payload": {
    "jsonrpc": "2.0",
    "method": "tools/list",
    "params": {
      "cursor": "self.light.set_rgb"
    },
    "id": 3
  }
}
```

---

### 3️⃣ Call Tool (Server Gọi Tool)

#### Server Gửi tools/call Request

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "mcp",
  "payload": {
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "self.light.set_rgb",
      "arguments": {
        "r": 255,
        "g": 0,
        "b": 0
      }
    },
    "id": 3
  }
}
```

**Các ví dụ khác:**

**Bật đèn màu xanh:**

```json
{
  "payload": {
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "self.light.set_rgb",
      "arguments": {
        "r": 0,
        "g": 255,
        "b": 0
      }
    },
    "id": 4
  }
}
```

**Đặt âm lượng:**

```json
{
  "payload": {
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "self.audio_speaker.set_volume",
      "arguments": {
        "volume": 70
      }
    },
    "id": 5
  }
}
```

**Hiển thị text:**

```json
{
  "payload": {
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "self.screen.display_text",
      "arguments": {
        "text": "Hello World",
        "duration": 5
      }
    },
    "id": 6
  }
}
```

---

#### Device Trả Về Result (Success)

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "mcp",
  "payload": {
    "jsonrpc": "2.0",
    "id": 3,
    "result": {
      "content": [
        {
          "type": "text",
          "text": "RGB light set to red (255, 0, 0)"
        }
      ],
      "isError": false
    }
  }
}
```

---

#### Device Trả Về Error

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "mcp",
  "payload": {
    "jsonrpc": "2.0",
    "id": 3,
    "error": {
      "code": -32603,
      "message": "Internal error",
      "data": {
        "details": "Light module not available"
      }
    }
  }
}
```

---

#### Device Trả Về Image Content

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "mcp",
  "payload": {
    "jsonrpc": "2.0",
    "id": 7,
    "result": {
      "content": [
        {
          "type": "image",
          "image": {
            "mimeType": "image/jpeg",
            "data": "base64_encoded_image_data_here..."
          }
        }
      ],
      "isError": false
    }
  }
}
```

---

### 4️⃣ Device Notification (Tùy chọn)

Device có thể gửi notification (không cần phản hồi):

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "mcp",
  "payload": {
    "jsonrpc": "2.0",
    "method": "notifications/device_status_changed",
    "params": {
      "status": "battery_low",
      "battery_level": 15
    }
  }
}
```

**Lưu ý:** Notification không có `id`, server không cần phản hồi.

---

## System Commands

### Reboot Device

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "system",
  "command": "reboot"
}
```

---

## Custom Messages

_(Chỉ khi bật `CONFIG_RECEIVE_CUSTOM_MESSAGE`)_

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "custom",
  "payload": {
    "your_custom_field": "custom_value"
  }
}
```

---

## Other Message Types

### Abort / Cancel

Device báo hủy phiên hiện tại:

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "abort",
  "reason": "wake_word_detected"
}
```

**Reasons:**

- `"wake_word_detected"`: Phát hiện wake word trong khi đang xử lý
- Các giá trị custom khác tùy bản triển khai

---

### Wake Word Detection

Device báo đã phát hiện wake word:

```json
{
  "session_id": "sess_1699564800_abc123def456",
  "type": "listen",
  "state": "detect",
  "text": "Xin chào Xiaoming"
}
```

---

## Error Handling

### JSON Parse Error

Device không parse được message:

```
[Error Log]
Missing message type, data: {...}
```

---

### Network Error

Kết nối bị mất:

Callback `on_audio_channel_closed_()` được trigger, device quay về **Idle**

---

### Timeout

Nếu không nhận dữ liệu > 120 giây:

Device tự đóng kết nối và báo lỗi timeout

---

## Complete Conversation Flow

### Full Sequence Diagram

```
Device                              Server                      AI Backend
  |                                    |                            |
  |-------- Hello (mcp: true) -------->|                            |
  |                                    |                            |
  |                                    |---- Check Device Profile -->|
  |                                    |<-- Device Info OK ---------|
  |                                    |                            |
  |<------ Hello Response (session_id)-|                            |
  |                                    |                            |
  |-------- listen: start, mode:auto ->|                            |
  |                                    |                            |
  |---- [Audio Frame 1, 2, 3 ...] ---->|--- Forward Audio -------->|
  |                                    |                            |
  |                                    |<---- STT Result -----------|
  |<----- stt: "Bật đèn phòng khách"---|                            |
  |                                    |<-- Route to Tool/LLM ------>|
  |                                    |                            |
  |---- mcp.initialize (id: 1) <------|---- mcp.initialize -------->|
  |                                    |                            |
  |--> mcp.result: "serverInfo" ------>|                            |
  |                                    |                            |
  |---- mcp.tools/list (id: 2) <------|---- mcp.tools/list -------->|
  |                                    |                            |
  |--> mcp.result: [tools] ----------->|                            |
  |                                    |                            |
  |---- mcp.tools/call (id: 3) <------|---- mcp.tools/call -------->|
  |     "self.light.set_rgb"           |     (light control)        |
  |     {r: 255, g: 0, b: 0}          |                            |
  |                                    |                            |
  |--> mcp.result: {content: [ok]} -->|                            |
  |                                    |<-- "Light turned on" -----|
  |                                    |                            |
  |<----- tts: state: start -----------|                            |
  |                                    |                            |
  |<-- [Audio Frame 1, 2, 3 ...] ------|<-- Generate TTS Audio ---|
  |                                    |                            |
  |<----- tts: state: stop ------------|                            |
  | (phát audio xong)                  |                            |
  |                                    |                            |
  v                                    v                            v
```

---

### Step-by-Step Example

**Scenario:** User nói "Bật đèn phòng khách màu đỏ"

#### 1. Handshake

```json
→ {"type":"hello","version":1,"features":{"mcp":true},"transport":"websocket","audio_params":{...}}
← {"type":"hello","transport":"websocket","session_id":"sess_123","audio_params":{...}}
```

#### 2. Start Listening

```json
→ {"session_id":"sess_123","type":"listen","state":"start","mode":"auto"}
```

#### 3. Send Audio

```
→ [Binary Opus Frame 1: 0xFFB90000...]
→ [Binary Opus Frame 2: 0xFFB90000...]
→ [Binary Opus Frame 3: 0xFFB90000...]
...
```

#### 4. Receive STT Result

```json
← {"session_id":"sess_123","type":"stt","text":"Bật đèn phòng khách màu đỏ"}
```

#### 5. MCP Initialize

```json
← {"session_id":"sess_123","type":"mcp","payload":{"jsonrpc":"2.0","method":"initialize","params":{"capabilities":{}},"id":1}}
→ {"session_id":"sess_123","type":"mcp","payload":{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","serverInfo":{"name":"Xiaozhi","version":"1.2.3"},"capabilities":{"tools":{}}}}}
```

#### 6. Get Tools List

```json
← {"session_id":"sess_123","type":"mcp","payload":{"jsonrpc":"2.0","method":"tools/list","params":{"cursor":""},"id":2}}
→ {"session_id":"sess_123","type":"mcp","payload":{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"self.light.set_rgb","description":"...","inputSchema":{...}},...]}}}
```

#### 7. Call Light Control Tool

```json
← {"session_id":"sess_123","type":"mcp","payload":{"jsonrpc":"2.0","method":"tools/call","params":{"name":"self.light.set_rgb","arguments":{"r":255,"g":0,"b":0}},"id":3}}
→ {"session_id":"sess_123","type":"mcp","payload":{"jsonrpc":"2.0","id":3,"result":{"content":[{"type":"text","text":"Red light activated"}],"isError":false}}}
```

#### 8. Start TTS

```json
← {"session_id":"sess_123","type":"tts","state":"start"}
```

#### 9. Send TTS Audio

```
← [Binary Opus Frame: TTS Audio]
← [Binary Opus Frame: TTS Audio]
...
```

#### 10. Stop TTS

```json
← {"session_id":"sess_123","type":"tts","state":"stop"}
```

**Kết quả:** Đèn bật màu đỏ, thiết bị phát TTS "Đã bật đèn phòng khách màu đỏ"

---

## Protocol Version Comparison

| Aspect      | Version 1 | Version 2  | Version 3         |
| ----------- | --------- | ---------- | ----------------- |
| Header Size | 0 bytes   | 16 bytes   | 4 bytes           |
| Timestamp   | ❌        | ✅         | ❌                |
| Metadata    | ❌        | ✅         | ❌                |
| Use Case    | Simple    | Server AEC | Bandwidth Limited |
| Recommended | General   | With AEC   | IoT Devices       |

---

## Configuration

### Audio Parameters

```c
#define OPUS_FRAME_DURATION_MS 60  // ms per frame
#define OPUS_SAMPLE_RATE 16000     // Hz
#define OPUS_CHANNELS 1            // Mono
#define OPUS_BITRATE 16000         // bps (16 kbps)
```

### Timeout

- **Handshake:** 10 seconds
- **Channel Idle:** 120 seconds

---

## References

- [MCP Specification 2024-11-05](https://modelcontextprotocol.io/specification/2024-11-05)
- [JSON-RPC 2.0](https://www.jsonrpc.org/specification)
- [Opus Codec](https://www.opus-codec.org/)

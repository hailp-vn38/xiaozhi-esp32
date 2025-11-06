# 📱 Device Activation Flow - Tài Liệu Đầy Đủ

**Spec Reference:** https://ccnphfhqs21z.feishu.cn/wiki/FjW6wZmisimNBBkov6OcmfvknVd

---

## 📊 Sơ đồ Tổng Quan

```
Device Start
    ↓
┌───────────────────────────────────────────────────────────────┐
│                    STEP 1: CHECK VERSION                      │
│                   (Device khởi động)                          │
│  POST/GET {CONFIG_OTA_URL}                                    │
│  ← Nhận: activation code, challenge, token, config            │
└───────────────────────────────────────────────────────────────┘
    ↓
    ├─ Has activation code/challenge? 
    │
    ├─ YES → Flow A: CHƯA ACTIVATE
    │  │
    │  ├─ Hiển thị code trên screen
    │  ├─ Phát âm code qua loa
    │  │
    │  └─┌──────────────────────────────────────────────────────┐
    │    │         STEP 2: ACTIVATE (HMAC Verification)         │
    │    │       POST {CONFIG_OTA_URL}/activate                 │
    │    │       Retry 10 lần (timeout/error)                   │
    │    │  ← Success: Device activated ✓                       │
    │    └──────────────────────────────────────────────────────┘
    │  │
    │  └─ Activation done
    │
    └─ NO → Flow B: ĐÃ ACTIVATE (hoặc không cần)
       │
       └─ Device ready, có token
          → User có thể gọi/chat
```

---

## 🔄 FLOW A: DEVICE CHƯA ACTIVATE

### **Step 1: CHECK VERSION REQUEST**

**URL:**
```
POST/GET {CONFIG_OTA_URL}
```

**Example:**
```
https://api.server.com/ota
```

**Headers:**
```http
Activation-Version: 2
Device-Id: aa:bb:cc:dd:ee:ff
Client-Id: 550e8400-e29b-41d4-a716-446655440000
Serial-Number: ABC123XYZ789
User-Agent: xiaozhi-esp32/1.0.0
Accept-Language: vi
Content-Type: application/json
```

**Request Body (POST):**
```json
{
  "version": 2,
  "language": "vi",
  "flash_size": 4194304,
  "minimum_free_heap_size": "512000",
  "mac_address": "aa:bb:cc:dd:ee:ff",
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "chip_model_name": "esp32s3",
  "chip_info": {
    "model": 1,
    "cores": 2,
    "revision": 0,
    "features": 0
  },
  "application": {
    "name": "xiaozhi",
    "version": "1.0.0",
    "compile_time": "2024-01-15T10:30:45Z",
    "idf_version": "5.0",
    "elf_sha256": "abcdef0123456789..."
  },
  "partition_table": [
    {
      "label": "factory",
      "type": 1,
      "subtype": 0,
      "address": 4096,
      "size": 1048576
    },
    {
      "label": "ota_0",
      "type": 1,
      "subtype": 16,
      "address": 1052672,
      "size": 1048576
    }
  ],
  "ota": {
    "label": "ota_0"
  },
  "display": {
    "monochrome": false,
    "width": 240,
    "height": 240
  }
}
```

**Response (Status 200):**
```json
{
  "firmware": {
    "version": "1.0.1",
    "url": "https://firmware.server.com/xiaozhi-v1.0.1.bin",
    "force": 0
  },
  "activation": {
    "message": "Vui lòng nhập mã kích hoạt trên ứng dụng di động",
    "code": "123456",
    "challenge": "abcdef0123456789abcdef0123456789",
    "timeout_ms": 30000
  },
  "mqtt": {
    "host": "mqtt.server.com",
    "port": 1883,
    "username": "device_user",
    "password": "device_pass",
    "topic": "xiaozhi/device_id"
  },
  "websocket": {
    "url": "wss://ws.server.com/chat",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "version": 3
  },
  "server_time": {
    "timestamp": 1705316445000,
    "timezone_offset": 420
  }
}
```

**Code từ project:**
```
main/ota.cc:74-241    (CheckVersion method)
main/boards/common/board.cc:70-200  (GetSystemInfoJson method)
```

---

### **Step 2: DEVICE HỌC (LEARNING)**

**Device làm:**
1. Lưu activation code vào bộ nhớ
2. Lưu activation challenge vào bộ nhớ
3. Lưu websocket token + URL vào NVS (Settings)
4. Hiển thị message + code trên màn hình
5. Phát âm từng chữ số của code

**Code:**
```
main/application.cc:175-226  (ShowActivationCode method)
├─ Alert(): Hiển thị message
└─ PlaySound(): Phát từng digit
```

**Giao diện:**
```
┌─────────────────────────┐
│     ACTIVATION          │
├─────────────────────────┤
│  Vui lòng nhập mã      │
│  kích hoạt trên ứng dụng│
├─────────────────────────┤
│  🔗 Activation Link     │
└─────────────────────────┘

[Audio playing: "1", "2", "3", "4", "5", "6"]
```

---

### **Step 3: ACTIVATE REQUEST**

**URL:**
```
POST {CONFIG_OTA_URL}/activate
```

**Example:**
```
https://api.server.com/ota/activate
```

**Headers:**
```http
Activation-Version: 2
Device-Id: aa:bb:cc:dd:ee:ff
Client-Id: 550e8400-e29b-41d4-a716-446655440000
Serial-Number: ABC123XYZ789
User-Agent: xiaozhi-esp32/1.0.0
Accept-Language: vi
Content-Type: application/json
```

**Request Body:**
```json
{
  "algorithm": "hmac-sha256",
  "serial_number": "ABC123XYZ789",
  "challenge": "abcdef0123456789abcdef0123456789",
  "hmac": "1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p"
}
```

**Giải thích HMAC:**
```
HMAC = HMAC-SHA256(HMAC_KEY0, challenge)
HMAC_KEY0 = Secret key từ eFuse của device (read-only)

Tính toán:
1. Lấy challenge từ Step 1 response
2. Tính HMAC-SHA256(secret_key, challenge)
3. Convert kết quả thành hex string
4. Gửi trong request
```

**Response (Status 200) - Success:**
```json
{
  "status": "success"
}
```

**Response (Status 202) - Pending:**
```json
{
  "status": "pending",
  "message": "Chờ xác nhận từ user"
}
```
→ Device retry sau 3 giây

**Response (Status 400) - Error:**
```json
{
  "code": "invalid_challenge",
  "message": "HMAC không hợp lệ"
}
```
→ Device retry sau 10 giây

**Retry Logic:**
```cpp
// application.cc:180-194
for (int i = 0; i < 10; ++i) {
    esp_err_t err = ota.Activate();
    if (err == ESP_OK) {
        break;  // ← Success
    } else if (err == ESP_ERR_TIMEOUT) {
        vTaskDelay(3000);  // Retry sau 3s
    } else {
        vTaskDelay(10000); // Retry sau 10s
    }
}
```

**Code từ project:**
```
main/ota.cc:406-477  (Activate + GetActivationPayload methods)
```

---

### **Flow A Timeline:**

```
t=0s     │ Device khởi động → CheckVersion
         │
t=1s     │ ← Server response (activation + token)
         │
t=1.5s   │ Hiển thị code "123456"
         │ Phát âm: "1", "2", "3", "4", "5", "6" (2 giây)
         │
t=3.5s   │ Gửi Activate request #1
         │ (User đang nhập code trên app)
         │
t=4s     │ ← Status 202 (Pending - chờ user xác nhận)
         │
t=7s     │ Gửi Activate request #2
         │
t=7.5s   │ ← Status 200 Success ✓
         │
t=7.5s+  │ Activation done
         │ Device ready, có token
         │ User có thể gọi/chat
```

---

## ✅ FLOW B: DEVICE ĐÃ ACTIVATE

### **Step 1: CHECK VERSION REQUEST** (Giống Flow A)

**Response: KHÔNG có activation section**
```json
{
  "firmware": {
    "version": "1.0.1",
    "url": "https://firmware.server.com/xiaozhi-v1.0.1.bin",
    "force": 0
  },
  "websocket": {
    "url": "wss://ws.server.com/chat",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "version": 3
  },
  "mqtt": {
    "host": "mqtt.server.com",
    "port": 1883,
    "username": "device_user",
    "password": "device_pass"
  },
  "server_time": {
    "timestamp": 1705316445000,
    "timezone_offset": 420
  }
}
```

**Device:**
```cpp
// application.cc:167
if (!ota.HasActivationCode() && !ota.HasActivationChallenge()) {
    // ← Không có activation
    // Device bỏ qua Step 2 Activate
    // Đã sẵn sàng
    break;
}
```

**Kết quả:**
- ✓ Không hiển thị code
- ✓ Không phát âm code
- ✓ Không gửi Activate request
- ✓ Device ready ngay
- ✓ Token từ server lưu vào NVS
- ✓ User có thể gọi/chat

---

## 🔐 Security Headers

Tất cả requests đều gửi headers này:

| Header | Giá trị | Ý nghĩa |
|--------|--------|---------|
| `Activation-Version` | 1 hoặc 2 | Protocol version (2 = có serial) |
| `Device-Id` | MAC address | Định danh device |
| `Client-Id` | UUID | Định danh software instance |
| `Serial-Number` | (optional) | Serial từ eFuse (nếu có) |
| `User-Agent` | `BOARD/VERSION` | Device info |
| `Accept-Language` | Lang code | Ngôn ngữ |
| `Content-Type` | `application/json` | Format |

---

## 📱 WebSocket Connection (Sau activation)

**Khi User gọi (wake word):**
```cpp
// application.cc:615-630
OnWakeWordDetected()
    ↓
protocol_->OpenAudioChannel()
    ↓
WebsocketProtocol::OpenAudioChannel() [websocket_protocol.cc:82-109]
    ├─ Lấy token từ Settings ("websocket" namespace)
    ├─ SetHeader("Authorization", "Bearer " + token)
    ├─ websocket_->Connect(url)
    └─ Gửi hello message
```

**WebSocket Headers:**
```http
GET /chat HTTP/1.1
Host: ws.server.com
Upgrade: websocket
Connection: Upgrade
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Protocol-Version: 3
Device-Id: aa:bb:cc:dd:ee:ff
Client-Id: 550e8400-e29b-41d4-a716-446655440000
```

**First Message (hello):**
```json
{
  "type": "hello",
  "version": 3,
  "features": {
    "mcp": true
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

**Code:**
```
main/protocols/websocket_protocol.cc:82-190
```

---

## 🔄 Settings Storage (NVS)

Device lưu các config vào NVS:

```
Namespace: "websocket"
├─ url: "wss://ws.server.com/chat"
├─ token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
└─ version: 3

Namespace: "mqtt"
├─ host: "mqtt.server.com"
├─ port: 1883
├─ username: "device_user"
└─ password: "device_pass"

Namespace: "wifi"
├─ ota_url: "https://api.server.com/ota"
└─ ...
```

**Code:**
```
main/settings.cc  (Settings class)
main/ota.cc:145-182  (Parse + Save settings)
```

---

## 📊 Request/Response Summary Table

| Step | Method | URL | Input | Output |
|------|--------|-----|-------|--------|
| 1 | POST/GET | `{OTA_URL}` | System info | Activation code + token |
| 2 | POST | `{OTA_URL}/activate` | HMAC challenge | Success/Pending/Error |
| 3 | GET | `wss://{WS_URL}` | Token header | WebSocket connection |

---

## ⏱️ Timing Reference

| Event | Duration |
|-------|----------|
| CheckVersion request | ~1s |
| Parse response | <100ms |
| Show activation code | ~2s (audio) |
| Activate retry interval (timeout) | 3s |
| Activate retry interval (error) | 10s |
| Max activate retries | 10 lần |
| WebSocket handshake timeout | 10s |

---

## 🛠️ Code References

**Core Files:**
- `main/ota.cc` (lines 74-477) - Activation logic
- `main/ota.h` (lines 1-60) - Headers
- `main/application.cc` (lines 123-196) - CheckNewVersion flow
- `main/boards/common/board.cc` (lines 70-200) - GetSystemInfoJson
- `main/protocols/websocket_protocol.cc` (lines 82-190) - WebSocket connection

**Related:**
- `main/settings.cc` - NVS storage
- `main/system_info.cc` - Device info
- `main/protocols/protocol.h` - Protocol interface


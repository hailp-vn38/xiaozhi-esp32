# 📚 TÀI LIỆU XIAOZHI ESP32 - TIẾNG VIỆT

**Ngày tạo:** 2024
**Ngôn ngữ:** Tiếng Việt

---

## 📋 MỤC LỤC

1. [Quy trình kích hoạt device](#quy-trình-kích-hoạt)
2. [Kết nối MQTT](#kết-nối-mqtt)
3. [Cập nhật từ xa](#cập-nhật-từ-xa)
4. [Cấu hình từ thức tỉnh](#cấu-hình-từ-thức-tỉnh)
5. [Thông tin máy chủ](#thông-tin-máy-chủ)

---

## 🔄 QUY TRÌNH KÍCH HOẠT DEVICE

### **Trường hợp 1: Device Chưa Kích Hoạt**

#### **Bước 1: Gửi Kiểm Tra Phiên Bản**

**Lúc nào:** Khi device khởi động
**Phương pháp:** POST/GET
**URL:** `{CONFIG_OTA_URL}`
**Ví dụ:** `https://api.server.com/ota`

**Headers:**
```
Activation-Version: 2
Device-Id: aa:bb:cc:dd:ee:ff (MAC address)
Client-Id: 550e8400-e29b-41d4-a716-446655440000 (UUID)
Serial-Number: ABC123XYZ789 (nếu có)
User-Agent: xiaozhi-esp32/1.0.0
Accept-Language: vi
Content-Type: application/json
```

**Dữ liệu gửi:**
```json
{
  "version": 2,
  "language": "vi",
  "flash_size": 4194304,
  "mac_address": "aa:bb:cc:dd:ee:ff",
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "chip_model_name": "esp32s3",
  "application": {
    "name": "xiaozhi",
    "version": "1.0.0",
    "compile_time": "2024-01-15T10:30:45Z",
    "idf_version": "5.0",
    "elf_sha256": "abc123..."
  }
}
```

**Phản hồi từ máy chủ:**
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
    "endpoint": "mqtt.server.com:1883",
    "client_id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "device_user",
    "password": "device_pass",
    "keepalive": 240,
    "publish_topic": "xiaozhi/device_id/audio"
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

#### **Bước 2: Device Hiển Thị Mã Kích Hoạt**

**Device làm gì:**
- ✓ Hiển thị message trên màn hình
- ✓ Phát âm từng chữ số (ví dụ: "1", "2", "3", "4", "5", "6")
- ✓ Lưu cấu hình MQTT, WebSocket vào bộ nhớ

**Giao diện:**
```
┌─────────────────────────┐
│     KÍCH HOẠT DEVICE    │
├─────────────────────────┤
│ Vui lòng nhập mã trên   │
│ ứng dụng di động        │
├─────────────────────────┤
│  🔗 Liên kết Kích Hoạt  │
└─────────────────────────┘

[Phát âm: "1", "2", "3", "4", "5", "6"]
```

#### **Bước 3: Gửi Yêu Cầu Kích Hoạt (HMAC)**

**Lúc nào:** Ngay sau khi nhận `code` và `challenge`
**Phương pháp:** POST
**URL:** `{CONFIG_OTA_URL}/activate`
**Ví dụ:** `https://api.server.com/ota/activate`

**Headers:** (Giống bước 1)

**Dữ liệu gửi:**
```json
{
  "algorithm": "hmac-sha256",
  "serial_number": "ABC123XYZ789",
  "challenge": "abcdef0123456789abcdef0123456789",
  "hmac": "1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p"
}
```

**Cách tính HMAC:**
```
1. Lấy challenge từ bước 1 response
2. Tính HMAC-SHA256(HMAC_KEY0, challenge)
   - HMAC_KEY0 = Secret key từ eFuse của chip (không thể đọc)
3. Convert kết quả thành hex string
4. Gửi trong request
```

**Phản hồi:**
```json
{
  "status": "success"
}
```

**Mã trạng thái:**
- `200` → Thành công ✓
- `202` → Chờ xử lý (retry sau 3 giây)
- `400` → Lỗi (retry sau 10 giây)
- Retry tối đa 10 lần

---

### **Trường hợp 2: Device Đã Kích Hoạt**

**Phản hồi từ máy chủ sẽ KHÔNG có phần `activation`:**
```json
{
  "firmware": {...},
  "mqtt": {...},
  "websocket": {...}
}
```

**Device:**
- ✓ Bỏ qua bước 2 và 3
- ✓ Sử dụng token từ websocket
- ✓ Sẵn sàng ngay

---

## 🔌 KẾT NỐI MQTT

### **Cấu hình MQTT**

**Nhận từ máy chủ:**
```json
{
  "mqtt": {
    "endpoint": "mqtt.server.com:1883",
    "client_id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "device_user",
    "password": "device_pass",
    "keepalive": 240,
    "publish_topic": "xiaozhi/device_id/audio"
  }
}
```

### **Parse Endpoint**

```
endpoint = "mqtt.server.com:1883"
           ↓
Tách ở dấu ':'
           ↓
Host: "mqtt.server.com" (trước dấu ':')
Port: 1883              (sau dấu ':')
```

### **Kết Nối MQTT**

```
mqtt_->Connect(
    "mqtt.server.com",                    // Host
    1883,                                 // Port
    "550e8400-e29b-41d4-a716-...",      // Client ID (UUID)
    "device_user",                        // Username
    "device_pass"                         // Password
)
```

### **Thông Số MQTT**

| Tham Số | Giá Trị | Ý Nghĩa |
|---------|--------|---------|
| **Phiên bản** | MQTT 3.1.1 | Protocol chuẩn |
| **Keep-alive** | 240 giây | Server ngắt nếu không ping |
| **QoS** | 0 | Fire and forget |
| **Port mặc định** | 1883 | Plain text / 8883 = TLS |

### **Lưu Trữ Cấu Hình**

**Nơi lưu:** NVS (bộ nhớ não device)
**Namespace:** "mqtt"
```
endpoint: "mqtt.server.com:1883"
client_id: "550e8400-..."
username: "device_user"
password: "device_pass"
keepalive: 240
publish_topic: "xiaozhi/device_id/audio"
```

**Được sử dụng khi:** `MqttProtocol::Start()` được gọi

---

## 📡 KẾT NỐI WEBSOCKET

### **Khi Nào Kết Nối**

**Lúc nào:** Khi người dùng gọi (nhận diện từ thức tỉnh)
**URL:** Từ settings ("websocket" namespace)
**Token:** Gửi trong header Authorization

### **Headers WebSocket**

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

### **Thông Điệp Đầu Tiên (Hello)**

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

---

## 🔄 CẬP NHẬT TỪ XA

### **Loại 1: Cập Nhật Firmware (OTA)**

**Nhận từ:** CheckVersion response → phần `firmware`
**Tải:** HTTP GET firmware binary
**Cài đặt:** Flash vào partition OTA
**Khởi động lại:** CÓ (bắt buộc)
**Khôi phục:** CÓ (có thể boot partition factory)

**Dữ liệu:**
```json
{
  "firmware": {
    "version": "1.0.1",
    "url": "https://firmware.server.com/xiaozhi-v1.0.1.bin",
    "force": 0
  }
}
```

**Quy trình:**
1. Kiểm tra phiên bản
2. Nếu mới hơn hoặc force=1 → Download
3. Flash vào partition ota_1
4. Đặt boot từ ota_1
5. Khởi động lại

### **Loại 2: Cập Nhật Assets (Âm thanh, Ngôn ngữ)**

**Nhận từ:** Settings ("assets" namespace) - Server push
**Tải:** HTTP GET assets file
**Cài đặt:** Erase + Write partition assets
**Khởi động lại:** KHÔNG
**Khôi phục:** KHÔNG

**Cách hoạt động:**
1. Server gửi `download_url` → Device lưu
2. Khi restart → `CheckAssetsVersion()` download
3. Ghi vào partition assets
4. Verify checksum
5. Reload assets

### **Loại 3: Cập Nhật Cấu Hình**

**Nhận từ:** CheckVersion response (mqtt, websocket, server_time)
**Tải:** KHÔNG (có sẵn trong response)
**Cài đặt:** Lưu vào NVS Settings tự động
**Khởi động lại:** KHÔNG

**Áp dụng khi:**
- MQTT: `MqttProtocol::Start()` được gọi
- WebSocket: Khi người dùng gọi
- Server Time: Ngay sau CheckVersion

---

## 🎙️ CẤU HÌNH TỪ THỨC TỈNH

### **Các Loại Từ Thức Tỉnh**

| Loại | Tên | Đặc Điểm | CPU | Tuỳ Chỉnh |
|------|-----|----------|-----|----------|
| 1 | **Tắt** | Không dùng | Bất kỳ | Không |
| 2 | **Wakenet** | Model cố định, nhanh | C3/C5/C6/ESP32 | Không |
| 3 | **Wakenet + AFE** | + Lọc nhiễu | S3/P4 + PSRAM | Không |
| 4 | **Multinet** | Custom từ khóa | S3/P4 + PSRAM | Có |

### **Cấu Hình (Kconfig.projbuild)**

```kconfig
choice WAKE_WORD_TYPE
    prompt "Loại Cài Đặt Từ Thức Tỉnh"
    default USE_AFE_WAKE_WORD
    
    config WAKE_WORD_DISABLED
        bool "Tắt"
    
    config USE_ESP_WAKE_WORD
        bool "Wakenet không AFE"
    
    config USE_AFE_WAKE_WORD
        bool "Wakenet có AFE (Khuyên dùng)"
    
    config USE_CUSTOM_WAKE_WORD
        bool "Từ Khóa Tuỳ Chỉnh (Multinet)"
```

### **Nếu Dùng Từ Khóa Tuỳ Chỉnh**

```kconfig
config CUSTOM_WAKE_WORD
    string "Từ Khóa Thức Tỉnh"
    default "xiao tu dou"
    help
        Ví dụ:
        ├─ "xiao tu dou" → 小土豆
        ├─ "xiao zhi" → 小志
        └─ "hey google" (Tiếng Anh)

config CUSTOM_WAKE_WORD_DISPLAY
    string "Văn Bản Hiển Thị"
    default "小土豆"
    help
        Lời chào hiển thị sau khi phát hiện

config CUSTOM_WAKE_WORD_THRESHOLD
    int "Độ Nhạy (%)"
    default 20
    range 1 99
    help
        1 = Rất nhạy (nhiều cảnh báo sai)
        20 = Cân bằng (mặc định)
        99 = Kém nhạy (bỏ lỡ nhiều)
```

### **Cấu Hình Nhanh**

**Cách 1: Chỉnh sửa trực tiếp**
```bash
nano sdkconfig

# Thêm các dòng:
CONFIG_USE_CUSTOM_WAKE_WORD=y
CONFIG_CUSTOM_WAKE_WORD="xiao tu dou"
CONFIG_CUSTOM_WAKE_WORD_DISPLAY="小土豆"
CONFIG_CUSTOM_WAKE_WORD_THRESHOLD=20
```

**Cách 2: Giao diện đồ họa**
```bash
idf.py menuconfig
→ Cấu Hình Ứng Dụng Xiaozhi
→ Loại Cài Đặt Từ Thức Tỉnh
→ Chọn tuỳ chọn
→ Lưu & Thoát
```

### **Khi Phát Hiện Từ Thức Tỉnh**

**Device làm:**
1. Mã hóa audio từ thức tỉnh
2. Mở kết nối tới server
3. Gửi audio + tên từ thức tỉnh
4. Chuyển sang chế độ lắng nghe
5. Người dùng nói → Gửi streaming tới server

---

## 🔐 HMAC_KEY - Khóa Bí Mật

### **HMAC_KEY Được Sinh Ra Ở Đâu**

**KHÔNG phải từ server!** Được sinh tại nhà máy sản xuất.

### **Quy Trình Sản Xuất**

```
1. Nhà máy:
   ├─ Sinh random 32 bytes HMAC_KEY
   ├─ Ghi vào eFuse của chip ESP32
   ├─ Đặt bảo vệ đọc (read-protected)
   └─ Tạo CSV: serial_number ↔ HMAC_KEY

2. Server:
   ├─ Import CSV vào database
   └─ Lưu: (serial_number, HMAC_KEY)

3. Device kích hoạt:
   ├─ Dùng HMAC_KEY từ eFuse
   ├─ Tính HMAC = SHA256(HMAC_KEY, challenge)
   └─ Gửi HMAC tới server

4. Server xác nhận:
   ├─ Lookup serial_number → Lấy HMAC_KEY từ DB
   ├─ Tính HMAC = SHA256(HMAC_KEY, challenge)
   ├─ So sánh HMAC
   └─ Match → Device genuine ✓
```

### **Bảo Mật**

✓ HMAC_KEY nằm trong eFuse (read-protected)
✓ Không thể đọc được
✓ Không thể copy device
✓ Attacker không biết secret key
✓ Challenge là one-time use

---

## 📊 BẢNG SO SÁNH CẬP NHẬT

| Tính Năng | Firmware | Assets | Cấu Hình |
|----------|----------|--------|---------|
| **Kích hoạt** | CheckVersion | Settings + push | CheckVersion |
| **Tải xuống** | Có (HTTP GET) | Có (HTTP GET) | Không (trong response) |
| **Kích thước** | 1-5 MB | 10-50 MB | KB |
| **Vị trí lưu** | Partition OTA | Partition assets | NVS |
| **Khởi động lại** | Có | Không | Không |
| **Thông báo** | Có | Có | Im lặng |
| **Khôi phục** | Có (factory) | Không | Không |

---

## 📁 CẤU TRÚC FLASH MEMORY

```
┌─────────────────────────────────────────┐
│  Flash Memory (ESP32)                   │
├─────────────────────────────────────────┤
│ Bootloader (16KB)                       │
├─────────────────────────────────────────┤
│ Bảng Partition                          │
├─────────────────────────────────────────┤
│ factory (Firmware gốc)                  │
├─────────────────────────────────────────┤
│ ota_0 (OTA app) ← Hiện tại đang chạy    │
├─────────────────────────────────────────┤
│ ota_1 (OTA app) ← Mục tiêu cập nhật     │
├─────────────────────────────────────────┤
│ NVS (Cấu hình MQTT, WebSocket)          │
├─────────────────────────────────────────┤
│ Assets (Âm thanh, Ngôn ngữ, Mô hình)    │
└─────────────────────────────────────────┘
```

---

## ⏱️ LỊCH KHỞI ĐỘNG HOÀN CHỈNH

```
t=0s     │ Device khởi động

t=0.5s   │ CheckAssetsVersion()
         │ ├─ Kiểm tra cập nhật assets
         │ └─ Nếu có → Tải + Cài đặt

t=5s     │ CheckNewVersion()
         │ ├─ POST system info → Server
         │ ├─ Parse response:
         │ │  ├─ activation section
         │ │  ├─ mqtt/websocket config
         │ │  ├─ server_time
         │ │  └─ firmware section
         │ │
         │ ├─ Lưu cấu hình
         │ └─ Nếu firmware mới:
         │    ├─ Tải firmware
         │    ├─ Flash to ota_1
         │    ├─ Khởi động lại ← RESTART
         │    └─ (Boot tiếp theo dùng firmware mới)

t=10s    │ Kích hoạt device (nếu cần)
         │ ├─ Hiển thị mã
         │ ├─ Phát âm từng chữ số
         │ ├─ Gửi HMAC verify
         │ └─ Chờ server xác nhận

t=15s    │ MqttProtocol::Start()
         │ ├─ Đọc cấu hình MQTT từ NVS
         │ ├─ Kết nối tới broker
         │ └─ Sẵn sàng subscribe

t=20s    │ Device sẵn sàng
         │ ├─ Chờ lệnh gọi
         │ ├─ Phát hiện từ thức tỉnh
         │ └─ Xử lý tin nhắn
```

---

## 📁 VỊ TRÍ FILE QUAN TRỌNG

**Kích hoạt:**
- `main/ota.cc:74-477` - Tất cả logic kích hoạt
- `main/application.cc:123-196` - CheckNewVersion flow
- `main/boards/common/board.cc:70-200` - GetSystemInfoJson

**MQTT:**
- `main/protocols/mqtt_protocol.cc:52-141` - StartMqttClient
- `main/ota.cc:143-161` - Parse MQTT từ response

**Assets:**
- `main/application.cc:72-121` - CheckAssetsVersion
- `main/assets.cc:370-501` - Tải assets

**Từ Thức Tỉnh:**
- `main/Kconfig.projbuild:562-622` - Cấu hình
- `main/audio/wake_word.h` - Interface
- `main/audio/wake_words/custom_wake_word.cc` - Multinet
- `main/application.cc:615-651` - Xử lý phát hiện

---

## 🚀 TÓM TẮT NHANH

| Bước | Lúc Nào | Làm Gì |
|------|---------|--------|
| 1 | Khởi động | POST system info → Nhận mã kích hoạt + cấu hình |
| 2 | Nếu cần kích hoạt | Hiển thị mã + phát âm |
| 3 | Ngay sau | Gửi HMAC verify |
| 4 | Cấu hình nhận được | Lưu vào NVS (MQTT, WebSocket) |
| 5 | Người dùng gọi | Mở kết nối + phát hiện từ thức tỉnh |
| 6 | Âm thanh đến | Gửi streaming → Server |
| 7 | Server xử lý | Trả lời + phát âm |

---

## ⚡ TỔNG HỢP TÀI LIỆU

Đã tạo các file tài liệu:
1. ✅ `DEVICE_ACTIVATION_FLOW.md` - Chi tiết quy trình kích hoạt
2. ✅ `MQTT_CONNECTION_FORMAT.md` - Chi tiết kết nối MQTT
3. ✅ `MQTT_QUICK_REFERENCE.md` - Tham chiếu nhanh MQTT
4. ✅ `REMOTE_UPDATE_MECHANISMS.md` - Chi tiết cập nhật từ xa
5. ✅ `WAKE_WORD_CONFIGURATION.md` - Chi tiết từ thức tỉnh
6. ✅ `TAI_LIEU_TOAN_BO_TIENG_VIET.md` - File này (Tiếng Việt)


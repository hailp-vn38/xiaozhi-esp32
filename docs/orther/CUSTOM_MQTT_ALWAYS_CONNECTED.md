# 🔌 Custom MQTT - Luôn Kết Nối & Remote Wake-up

**Mục tiêu:** MQTT luôn kết nối, device có thể thức tỉnh từ xa khi server gửi message

---

## 📊 KIẾN TRÚC HIỆN TẠI vs CUSTOM

### **Hiện Tại (Chỉ Khi Cần)**

```
Device khởi động
    ↓
MQTT chỉ kết nối khi OpenAudioChannel()
(user gọi qua wake word hoặc nút)
    ↓
Nghe/nói xong → Disconnect
```

**Vấn đề:** Server không thể gừi message khi device offline

### **Custom (Luôn Kết Nối)**

```
Device khởi động
    ↓
MqttProtocol::Start() ngay
    ↓
MQTT kết nối persistent
    ├─ Subscribe control topic
    └─ Keep-alive 240s
    ↓
Server gửi message
    ↓
Device nhận → Parse type
    ├─ "wake" → Kích hoạt listening
    ├─ "call" → Gọi đến
    ├─ "command" → Thực thi lệnh
    └─ "notify" → Thông báo
    ↓
OpenAudioChannel() + Listening
```

---

## 🔧 CUSTOM MQTT PROTOCOL - BƯỚC 1: MODIFY CODE

### **File: main/protocols/mqtt_protocol.h**

```cpp
// Thêm vào private section:
private:
    std::string subscribe_topic_;  // ← Topic để nghe từ server
    bool always_connected_ = true;  // ← Flag luôn kết nối
    
    // Xử lý remote wake-up commands
    void HandleRemoteWakeupMessage(const cJSON* root);
```

### **File: main/protocols/mqtt_protocol.cc**

**1. Modify StartMqttClient - Subscribe Topic**

```cpp
bool MqttProtocol::StartMqttClient(bool report_error) {
    // ... existing code ...
    
    mqtt_->OnConnected([this]() {
        if (on_connected_ != nullptr) {
            on_connected_();
        }
        esp_timer_stop(reconnect_timer_);
        
        // ← THÊMTOPIC
        // Subscribe control topic để remote wake-up
        if (!subscribe_topic_.empty()) {
            if (mqtt_->Subscribe(subscribe_topic_)) {
                ESP_LOGI(TAG, "Subscribed to topic: %s", subscribe_topic_.c_str());
            } else {
                ESP_LOGW(TAG, "Failed to subscribe to topic: %s", subscribe_topic_.c_str());
            }
        }
    });
    
    // ... rest of code ...
}
```

**2. Parse Subscribe Topic từ Settings**

```cpp
// Thêm vào StartMqttClient sau line 64:
Settings settings("mqtt", false);
auto endpoint = settings.GetString("endpoint");
auto client_id = settings.GetString("client_id");
auto username = settings.GetString("username");
auto password = settings.GetString("password");
int keepalive_interval = settings.GetInt("keepalive", 240);
publish_topic_ = settings.GetString("publish_topic");
subscribe_topic_ = settings.GetString("subscribe_topic");  // ← THÊM
```

**3. Handle Remote Wakeup Messages**

```cpp
// Modify OnMessage callback (thay thế phần hiện tại):
mqtt_->OnMessage([this](const std::string& topic, const std::string& payload) {
    ESP_LOGI(TAG, "Received message on topic: %s, payload: %s", topic.c_str(), payload.c_str());
    
    cJSON* root = cJSON_Parse(payload.c_str());
    if (root == nullptr) {
        ESP_LOGE(TAG, "Failed to parse json message %s", payload.c_str());
        return;
    }
    
    cJSON* type = cJSON_GetObjectItem(root, "type");
    if (!cJSON_IsString(type)) {
        ESP_LOGE(TAG, "Message type is invalid");
        cJSON_Delete(root);
        return;
    }

    // Xử lý các message type khác nhau
    if (strcmp(type->valuestring, "hello") == 0) {
        ParseServerHello(root);
    } 
    else if (strcmp(type->valuestring, "goodbye") == 0) {
        auto session_id = cJSON_GetObjectItem(root, "session_id");
        if (session_id == nullptr || session_id_ == session_id->valuestring) {
            Application::GetInstance().Schedule([this]() {
                CloseAudioChannel();
            });
        }
    }
    // ← THÊM REMOTE WAKE-UP HANDLING
    else if (strcmp(type->valuestring, "wake") == 0) {
        HandleRemoteWakeupMessage(root);
    }
    else if (strcmp(type->valuestring, "call") == 0) {
        HandleRemoteCall(root);
    }
    else if (strcmp(type->valuestring, "command") == 0) {
        HandleRemoteCommand(root);
    }
    else if (on_incoming_json_ != nullptr) {
        on_incoming_json_(root);
    }
    
    cJSON_Delete(root);
    last_incoming_time_ = std::chrono::steady_clock::now();
});
```

**4. Implement Remote Wake-up Handler**

```cpp
// Thêm vào mqtt_protocol.cc (trước closing brace):
void MqttProtocol::HandleRemoteWakeupMessage(const cJSON* root) {
    ESP_LOGI(TAG, "Remote wake-up command received");
    
    // Parse message parameters
    cJSON* message = cJSON_GetObjectItem(root, "message");
    const char* wake_message = cJSON_IsString(message) ? message->valuestring : "";
    
    // Schedule wake-up on main application
    Application::GetInstance().Schedule([this, wake_message = std::string(wake_message)]() {
        ESP_LOGI(TAG, "Executing remote wake-up: %s", wake_message.c_str());
        
        if (!IsAudioChannelOpened()) {
            SetDeviceState(kDeviceStateConnecting);
            if (!OpenAudioChannel()) {
                ESP_LOGE(TAG, "Failed to open audio channel");
                return;
            }
        }
        
        // Set listening mode
        // Có thể thêm tên người gọi, nội dung tin nhắn, etc
        auto& app = Application::GetInstance();
        app.SetListeningMode(kListeningModeAutoStop);
    });
}

void MqttProtocol::HandleRemoteCall(const cJSON* root) {
    // Xử lý gọi từ remote
    cJSON* caller_name = cJSON_GetObjectItem(root, "caller_name");
    ESP_LOGI(TAG, "Remote call from: %s", caller_name->valuestring);
    
    Application::GetInstance().Schedule([this]() {
        auto& app = Application::GetInstance();
        
        // Phát thông báo có cuộc gọi đến
        auto display = Board::GetInstance().GetDisplay();
        if (display && caller_name) {
            display->SetChatMessage("system", caller_name->valuestring);
        }
        
        // Mở audio channel
        if (!IsAudioChannelOpened()) {
            OpenAudioChannel();
        }
    });
}

void MqttProtocol::HandleRemoteCommand(const cJSON* root) {
    // Xử lý lệnh từ remote
    cJSON* command = cJSON_GetObjectItem(root, "command");
    if (!cJSON_IsString(command)) {
        return;
    }
    
    ESP_LOGI(TAG, "Remote command: %s", command->valuestring);
    
    // Thực thi lệnh (ví dụ: "reboot", "update", "play_sound")
    if (strcmp(command->valuestring, "reboot") == 0) {
        Application::GetInstance().Schedule([]() {
            Application::GetInstance().Reboot();
        });
    }
}
```

---

## 🔌 BƯỚC 2: CONFIGURE MQTT SETTINGS

**Server gửi trong CheckVersion response:**

```json
{
  "mqtt": {
    "endpoint": "mqtt.server.com:1883",
    "client_id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "device_user",
    "password": "device_pass",
    "keepalive": 240,
    "publish_topic": "xiaozhi/device_id/audio",
    "subscribe_topic": "xiaozhi/device_id/control"  // ← THÊM MỚI
  }
}
```

**Device tự động:**
- Lưu vào Settings ("mqtt" namespace)
- Subscribe `xiaozhi/device_id/control` topic
- Luôn lắng nghe messages

---

## 📨 SERVER GỬIP MESSAGE - CÁC MESSAGE TYPE

### **1. Remote Wake-up**

**Server gửi:**
```json
{
  "type": "wake",
  "message": "Tin nhắn từ máy chủ",
  "session_id": "xyz123"
}
```

**Device:**
- Mở audio channel
- Phát message
- Chuyển sang listening mode
- Sẵn sàng nhận lệnh

### **2. Remote Call**

**Server gửi:**
```json
{
  "type": "call",
  "caller_name": "An",
  "caller_id": "user_123",
  "priority": "high"
}
```

**Device:**
- Hiển thị tên người gọi trên màn hình
- Phát thông báo âm thanh "Có cuộc gọi đến"
- Mở audio channel
- User nhấn để nhận

### **3. Remote Command**

**Server gửi:**
```json
{
  "type": "command",
  "command": "reboot",
  "reason": "Firmware update"
}
```

**Device:**
- Thực thi lệnh
- Log lý do

### **4. Notification**

**Server gửi:**
```json
{
  "type": "notify",
  "title": "Thông báo",
  "content": "Bạn có 3 tin nhắn mới",
  "icon": "message"
}
```

**Device:**
- Hiển thị trên màn hình
- Không tự động mở audio

---

## 🎯 MODIFY APPLICATION - BƯỚC 3

**File: main/application.cc**

```cpp
// Modify trong Application::Start() - line 405-412
if (ota.HasMqttConfig()) {
    protocol_ = std::make_unique<MqttProtocol>();
    
    // ← THÊM: Start MQTT ngay (luôn kết nối)
    protocol_->Start();  
    
    // Schedule thành background task
    Schedule([this]() {
        if (!protocol_->IsAudioChannelOpened()) {
            // Mở connection to broker nhưng không mở audio yet
            // MQTT sẽ luôn lắng nghe
        }
    });
} else if (ota.HasWebsocketConfig()) {
    protocol_ = std::make_unique<WebsocketProtocol>();
}
```

**Thêm callback xử lý incoming JSON từ MQTT:**

```cpp
protocol_->OnIncomingJson([this, display](const cJSON* root) {
    // Hiện tại xử lý tin nhắn từ server
    cJSON* type = cJSON_GetObjectItem(root, "type");
    if (cJSON_IsString(type)) {
        if (strcmp(type->valuestring, "text") == 0) {
            // Chat message từ server
            cJSON* text = cJSON_GetObjectItem(root, "text");
            if (cJSON_IsString(text)) {
                display->SetChatMessage("server", text->valuestring);
            }
        }
    }
});
```

---

## 📋 SERVER SIDE - GỬI MESSAGE ĐẠT DEVICE

**Python/Node.js:**

```python
import paho.mqtt.client as mqtt
import json
import time

client = mqtt.Client()
client.connect("mqtt.server.com", 1883, 60)

# Remote wake-up
device_id = "550e8400-e29b-41d4-a716-446655440000"
topic = f"xiaozhi/{device_id}/control"

message = {
    "type": "wake",
    "message": "Đã có cuộc gọi từ An",
    "session_id": "abc123"
}

client.publish(topic, json.dumps(message))

# Remote call
call_message = {
    "type": "call",
    "caller_name": "An",
    "caller_id": "user_123",
    "priority": "high"
}

client.publish(topic, json.dumps(call_message))

# Reboot device
reboot_message = {
    "type": "command",
    "command": "reboot",
    "reason": "Firmware update"
}

client.publish(topic, json.dumps(reboot_message))
```

---

## 🔄 FLOW DIAGRAM

```
┌─ Server ────────────────────────────────────────────────┐
│                                                         │
│  Gửi message tới:                                       │
│  TOPIC: xiaozhi/{device_id}/control                    │
│                                                         │
└────────────────┬──────────────────────────────────────┘
                 │
                 │ Publish via MQTT
                 ↓
┌─ MQTT Broker ────────────────────────────────────────────┐
│                                                          │
│  Lưu message trong message queue                        │
│  Device nghe trên topic                                 │
│                                                          │
└────────────────┬─────────────────────────────────────────┘
                 │
                 │ Subscribe on startup
                 ↓
┌─ Device ─────────────────────────────────────────────────┐
│                                                         │
│ MqttProtocol::Start()                                  │
│   ↓                                                     │
│ Kết nối MQTT                                           │
│   ↓                                                     │
│ Subscribe control topic                                │
│   ↓                                                     │
│ OnMessage callback                                     │
│   ├─ Parse JSON                                        │
│   ├─ Check type field                                  │
│   └─ Handle:                                           │
│       ├─ "wake" → HandleRemoteWakeup                  │
│       ├─ "call" → HandleRemoteCall                    │
│       ├─ "command" → HandleRemoteCommand              │
│       └─ "notify" → Show notification                 │
│   ↓                                                     │
│ Device responds (listening/execute/etc)               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## ⚙️ CONFIGURATION CHECKLIST

- [ ] Thêm subscribe_topic vào mqtt section trong CheckVersion response
- [ ] Modify mqtt_protocol.h - thêm handler methods
- [ ] Modify mqtt_protocol.cc - implement subscription + handlers
- [ ] Modify application.cc - call protocol_->Start() ngay
- [ ] Test MQTT luôn kết nối (monitor log)
- [ ] Test remote wake-up message
- [ ] Test remote call message
- [ ] Test remote command message

---

## 🧪 TEST COMMANDS

**Monitor device log:**
```bash
idf.py -p /dev/ttyUSB0 monitor | grep MQTT
```

**Gửi wake-up từ MQTT CLI:**
```bash
mosquitto_pub -h mqtt.server.com -u device_user -P device_pass \
  -t "xiaozhi/550e8400-e29b-41d4-a716-446655440000/control" \
  -m '{"type":"wake","message":"Cuộc gọi từ An"}'
```

**Subscribe để theo dõi:**
```bash
mosquitto_sub -h mqtt.server.com -u device_user -P device_pass \
  -t "xiaozhi/+/control"
```

---

## 💡 CÓ THỂ THÊM

1. **Persistence** - Lưu message nếu device offline
2. **QoS Levels** - QoS=2 cho important messages
3. **Retain** - Server retain last message
4. **Timeout** - Auto disconnect after idle
5. **Encryption** - TLS/SSL connection
6. **Acknowledgment** - Device phản hồi lại server

---

## 📝 TỔNG KẾT

| Bước | Làm Gì | File |
|------|--------|------|
| 1 | Thêm handler methods | mqtt_protocol.h/cc |
| 2 | Subscribe control topic | mqtt_protocol.cc |
| 3 | Parse incoming messages | mqtt_protocol.cc |
| 4 | Call protocol_->Start() | application.cc |
| 5 | Configure server response | Server code |
| 6 | Test |  |


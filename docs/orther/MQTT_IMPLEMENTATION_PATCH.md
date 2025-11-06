# 🔧 PATCH CODE - Triển Khai MQTT Persistent Connection

## 📝 PATCH 1: mqtt_protocol.h

```cpp
// Thêm vào private section (sau line 56):

private:
    std::string subscribe_topic_;
    
    // Xử lý các loại message từ server
    void HandleRemoteWakeupMessage(const cJSON* root);
    void HandleRemoteCall(const cJSON* root);
    void HandleRemoteCommand(const cJSON* root);
```

---

## 📝 PATCH 2: mqtt_protocol.cc - StartMqttClient()

**Thêm dòng này sau line 64:**

```cpp
    publish_topic_ = settings.GetString("publish_topic");
    subscribe_topic_ = settings.GetString("subscribe_topic");  // ← THÊM
```

**Modify OnConnected callback (line 86-91):**

```cpp
    mqtt_->OnConnected([this]() {
        if (on_connected_ != nullptr) {
            on_connected_();
        }
        esp_timer_stop(reconnect_timer_);
        
        // ← THÊM: Subscribe control topic
        if (!subscribe_topic_.empty()) {
            if (mqtt_->Subscribe(subscribe_topic_)) {
                ESP_LOGI(TAG, "Subscribed to topic: %s", subscribe_topic_.c_str());
            } else {
                ESP_LOGW(TAG, "Failed to subscribe to topic: %s", subscribe_topic_.c_str());
            }
        }
    });
```

---

## 📝 PATCH 3: mqtt_protocol.cc - OnMessage Callback

**Thay thế hoàn toàn OnMessage callback (line 93-121):**

```cpp
    mqtt_->OnMessage([this](const std::string& topic, const std::string& payload) {
        ESP_LOGI(TAG, "Received message on topic: %s", topic.c_str());
        
        cJSON* root = cJSON_Parse(payload.c_str());
        if (root == nullptr) {
            ESP_LOGE(TAG, "Failed to parse json message");
            return;
        }
        
        cJSON* type = cJSON_GetObjectItem(root, "type");
        if (!cJSON_IsString(type)) {
            ESP_LOGE(TAG, "Message type is invalid");
            cJSON_Delete(root);
            return;
        }

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
        // ← THÊM: Remote wake-up handling
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

---

## 📝 PATCH 4: Thêm Handler Methods

**Thêm vào cuối mqtt_protocol.cc (trước closing brace):**

```cpp
void MqttProtocol::HandleRemoteWakeupMessage(const cJSON* root) {
    ESP_LOGI(TAG, "Remote wake-up command received");
    
    cJSON* message = cJSON_GetObjectItem(root, "message");
    std::string wake_msg = cJSON_IsString(message) ? message->valuestring : "";
    
    Application::GetInstance().Schedule([this, wake_msg]() {
        ESP_LOGI(TAG, "Opening audio channel for remote wake-up");
        
        if (!IsAudioChannelOpened()) {
            if (!OpenAudioChannel()) {
                ESP_LOGE(TAG, "Failed to open audio channel");
                return;
            }
        }
        
        // Set listening mode if audio is open
        if (IsAudioChannelOpened()) {
            // Send notification message
            auto notify_msg = cJSON_CreateObject();
            cJSON_AddStringToObject(notify_msg, "type", "remote_wakeup");
            cJSON_AddStringToObject(notify_msg, "message", wake_msg.c_str());
            
            char* json_str = cJSON_Print(notify_msg);
            if (json_str) {
                SendText(json_str);
                free(json_str);
            }
            cJSON_Delete(notify_msg);
        }
    });
}

void MqttProtocol::HandleRemoteCall(const cJSON* root) {
    cJSON* caller_name = cJSON_GetObjectItem(root, "caller_name");
    
    if (!cJSON_IsString(caller_name)) {
        ESP_LOGW(TAG, "Invalid caller_name in call message");
        return;
    }
    
    ESP_LOGI(TAG, "Remote call from: %s", caller_name->valuestring);
    
    std::string name = caller_name->valuestring;
    Application::GetInstance().Schedule([this, name]() {
        auto display = Board::GetInstance().GetDisplay();
        if (display) {
            display->SetChatMessage("system", std::string("Cuộc gọi từ: ") + name);
        }
        
        if (!IsAudioChannelOpened()) {
            OpenAudioChannel();
        }
    });
}

void MqttProtocol::HandleRemoteCommand(const cJSON* root) {
    cJSON* command = cJSON_GetObjectItem(root, "command");
    if (!cJSON_IsString(command)) {
        ESP_LOGW(TAG, "Invalid command field");
        return;
    }
    
    ESP_LOGI(TAG, "Remote command: %s", command->valuestring);
    
    std::string cmd = command->valuestring;
    Application::GetInstance().Schedule([this, cmd]() {
        if (cmd == "reboot") {
            ESP_LOGI(TAG, "Rebooting device");
            esp_restart();
        }
        else if (cmd == "disconnect") {
            ESP_LOGI(TAG, "Disconnecting audio channel");
            CloseAudioChannel();
        }
        else if (cmd == "update") {
            ESP_LOGI(TAG, "Starting update process");
            // Call your update function
        }
    });
}
```

---

## 📝 PATCH 5: application.cc - Start MQTT on Boot

**Thay thế line 405-412:**

```cpp
    // ← BEFORE:
    // if (ota.HasMqttConfig()) {
    //     protocol_ = std::make_unique<MqttProtocol>();
    // }

    // ← AFTER:
    if (ota.HasMqttConfig()) {
        protocol_ = std::make_unique<MqttProtocol>();
        
        // Start MQTT connection immediately (always connected)
        if (!protocol_->Start()) {
            ESP_LOGW(TAG, "Failed to start MQTT protocol");
        } else {
            ESP_LOGI(TAG, "MQTT protocol started");
        }
    } 
    else if (ota.HasWebsocketConfig()) {
        protocol_ = std::make_unique<WebsocketProtocol>();
    }
```

---

## 📊 SERVER-SIDE: Gửi Message ĐẠT Device

### **Python Example:**

```python
import paho.mqtt.client as mqtt
import json
import time

def send_to_device(device_id, message_type, data):
    """Gửi message tới device qua MQTT"""
    
    client = mqtt.Client()
    client.connect("mqtt.server.com", 1883, 60)
    
    topic = f"xiaozhi/{device_id}/control"
    
    payload = {
        "type": message_type,
        **data  # Merge thêm dữ liệu
    }
    
    client.publish(topic, json.dumps(payload))
    client.disconnect()
    print(f"Sent to {topic}: {payload}")

# Ví dụ 1: Remote wake-up
send_to_device(
    "550e8400-e29b-41d4-a716-446655440000",
    "wake",
    {
        "message": "Tin nhắn từ máy chủ",
        "session_id": "abc123"
    }
)

# Ví dụ 2: Remote call
send_to_device(
    "550e8400-e29b-41d4-a716-446655440000",
    "call",
    {
        "caller_name": "An",
        "caller_id": "user_123",
        "priority": "high"
    }
)

# Ví dụ 3: Remote command
send_to_device(
    "550e8400-e29b-41d4-a716-446655440000",
    "command",
    {
        "command": "reboot",
        "reason": "Firmware update"
    }
)
```

### **Node.js Example:**

```javascript
const mqtt = require('mqtt');

function sendToDevice(deviceId, messageType, data) {
    const client = mqtt.connect('mqtt://mqtt.server.com:1883', {
        username: 'device_user',
        password: 'device_pass'
    });

    client.on('connect', () => {
        const topic = `xiaozhi/${deviceId}/control`;
        const payload = {
            type: messageType,
            ...data
        };
        
        client.publish(topic, JSON.stringify(payload), { qos: 1 }, () => {
            console.log(`Sent to ${topic}:`, payload);
            client.end();
        });
    });
}

// Remote wake-up
sendToDevice('550e8400-e29b-41d4-a716-446655440000', 'wake', {
    message: 'Tin nhắn từ máy chủ',
    session_id: 'abc123'
});

// Remote call
sendToDevice('550e8400-e29b-41d4-a716-446655440000', 'call', {
    caller_name: 'An',
    caller_id: 'user_123',
    priority: 'high'
});
```

---

## 🧪 TEST & VERIFY

### **1. Build & Flash**

```bash
idf.py build
idf.py -p /dev/ttyUSB0 -b 460800 flash
```

### **2. Monitor Log**

```bash
idf.py -p /dev/ttyUSB0 monitor | grep -E "(MQTT|Remote|wake|call)"
```

**Expected output:**
```
I (12345) mqtt_protocol: Connected to endpoint
I (12346) mqtt_protocol: Subscribed to topic: xiaozhi/550e8400-e29b-41d4-a716-446655440000/control
I (12347) mqtt_protocol: MQTT keep-alive: 240s
```

### **3. Send Test Message**

```bash
mosquitto_pub -h mqtt.server.com \
  -u device_user \
  -P device_pass \
  -t "xiaozhi/550e8400-e29b-41d4-a716-446655440000/control" \
  -m '{"type":"wake","message":"Test wake-up","session_id":"test123"}'
```

**Expected device response:**
```
I (34567) mqtt_protocol: Received message on topic: xiaozhi/.../control
I (34568) mqtt_protocol: Remote wake-up command received
I (34569) mqtt_protocol: Opening audio channel for remote wake-up
I (34570) mqtt_protocol: SendText: {"type":"remote_wakeup",...}
```

### **4. Check MQTT Subscription**

```bash
mosquitto_sub -h mqtt.server.com \
  -u device_user \
  -P device_pass \
  -t "xiaozhi/+/control" \
  -v
```

---

## ✅ INTEGRATION CHECKLIST

- [ ] Patch mqtt_protocol.h (thêm handler methods)
- [ ] Patch mqtt_protocol.cc - line 64 (subscribe_topic)
- [ ] Patch mqtt_protocol.cc - OnConnected callback (subscribe)
- [ ] Patch mqtt_protocol.cc - OnMessage callback (new message types)
- [ ] Patch mqtt_protocol.cc - thêm handler implementations
- [ ] Patch application.cc - call protocol_->Start()
- [ ] Build & test
- [ ] Monitor log để verify
- [ ] Send test message từ server

---

## 🎯 EXPECTED BEHAVIOR

**Scenario 1: Device Boot**
```
Device starts
  → CheckVersion & Activate
  → Get MQTT config (including subscribe_topic)
  → MqttProtocol::Start() called
  → Connect MQTT broker
  → Subscribe to control topic
  → MQTT stays connected (keep-alive 240s)
```

**Scenario 2: Server Send Wake-up**
```
Server publishes: {"type":"wake", "message":"..."}
  → MQTT broker routes to device
  → OnMessage callback triggered
  → Parse JSON + type check
  → HandleRemoteWakeupMessage()
  → Schedule to open audio channel
  → Device listening for user input
```

**Scenario 3: Device Offline Reconnect**
```
Device loses connection
  → OnDisconnected callback
  → Schedule reconnect in 60s
  → Auto reconnect
  → Subscribe again
  → Ready to receive messages
```


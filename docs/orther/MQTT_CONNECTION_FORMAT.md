# 📡 MQTT Connection Format - Tài Liệu Đầy Đủ

---

## 📊 Tổng Quan

Khi device nhận được mqtt section từ CheckVersion response, nó sẽ:
1. **Lưu** vào NVS Settings
2. **Parse** endpoint để tách host + port
3. **Connect** tới MQTT broker

---

## 🔄 Luồng MQTT Connection

```
Device khởi động
    ↓
CheckVersion response
    ↓
Parse mqtt section:
{
  "mqtt": {
    "endpoint": "mqtt.server.com:1883",
    "client_id": "device_uuid",
    "username": "device_user",
    "password": "device_pass",
    "keepalive": 240,
    "publish_topic": "xiaozhi/device_id/audio"
  }
}
    ↓
Lưu vào Settings ("mqtt" namespace)
    ↓
StartMqttClient() [mqtt_protocol.cc:52]
    ├─ Lấy endpoint từ Settings
    ├─ Parse "host:port"
    ├─ Call mqtt_->Connect(host, port, client_id, username, password)
    └─ Kết nối MQTT
```

---

## 📦 MQTT Settings Parameters

**Namespace:** `"mqtt"` (read-write mode)

| Key | Type | Example | Ý nghĩa |
|-----|------|---------|---------|
| `endpoint` | string | `mqtt.server.com:1883` | MQTT broker address + port |
| `client_id` | string | `550e8400-e29b-41d4-a716-446655440000` | MQTT client ID (device UUID) |
| `username` | string | `device_user` | MQTT username |
| `password` | string | `device_pass` | MQTT password |
| `keepalive` | int | `240` | Keep-alive interval (seconds) |
| `publish_topic` | string | `xiaozhi/device_id/audio` | Topic để publish audio |

---

## 🔌 Connection Code

**Source:** `main/protocols/mqtt_protocol.cc:52-141`

```cpp
bool MqttProtocol::StartMqttClient(bool report_error) {
    // Lấy settings từ NVS
    Settings settings("mqtt", false);
    auto endpoint = settings.GetString("endpoint");           // "mqtt.server.com:1883"
    auto client_id = settings.GetString("client_id");         // UUID
    auto username = settings.GetString("username");           // Username
    auto password = settings.GetString("password");           // Password
    int keepalive_interval = settings.GetInt("keepalive", 240); // Default 240s
    publish_topic_ = settings.GetString("publish_topic");     // Topic

    if (endpoint.empty()) {
        ESP_LOGW(TAG, "MQTT endpoint is not specified");
        return false;
    }

    // Parse endpoint: "host:port"
    std::string broker_address;
    int broker_port = 8883;  // Default port
    size_t pos = endpoint.find(':');
    if (pos != std::string::npos) {
        broker_address = endpoint.substr(0, pos);      // "mqtt.server.com"
        broker_port = std::stoi(endpoint.substr(pos + 1)); // 1883
    } else {
        broker_address = endpoint;  // Nếu không có port, dùng host
    }

    // Tạo MQTT client
    auto network = Board::GetInstance().GetNetwork();
    mqtt_ = network->CreateMqtt(0);
    mqtt_->SetKeepAlive(keepalive_interval);

    // Setup callbacks
    mqtt_->OnDisconnected([this]() {
        // Reconnect sau 60s
        esp_timer_start_once(reconnect_timer_, MQTT_RECONNECT_INTERVAL_MS * 1000);
    });

    mqtt_->OnConnected([this]() {
        // Stop reconnect timer
        esp_timer_stop(reconnect_timer_);
    });

    mqtt_->OnMessage([this](const std::string& topic, const std::string& payload) {
        // Xử lý incoming messages
    });

    // Connect tới MQTT broker
    ESP_LOGI(TAG, "Connecting to endpoint %s", endpoint.c_str());
    if (!mqtt_->Connect(
        broker_address,  // "mqtt.server.com"
        broker_port,     // 1883
        client_id,       // Device UUID
        username,        // Device username
        password         // Device password
    )) {
        ESP_LOGE(TAG, "Failed to connect to endpoint");
        return false;
    }

    ESP_LOGI(TAG, "Connected to endpoint");
    return true;
}
```

---

## 📨 Connection Parameters

### **Endpoint Format:**

```
{host}:{port}

Examples:
├─ mqtt.server.com:1883
├─ 192.168.1.100:1883
├─ mqtt.example.com:8883 (TLS)
└─ broker.hivemq.com:1883
```

**Parse Logic:**
```python
endpoint = "mqtt.server.com:1883"

# Find colon
pos = endpoint.find(':')  # pos = 17

# Split
host = endpoint[:17]     # "mqtt.server.com"
port = int(endpoint[18:]) # 1883
```

### **MQTT Connect Parameters:**

```cpp
mqtt_->Connect(
    broker_address,  // "mqtt.server.com" (hostname)
    broker_port,     // 1883 (port number)
    client_id,       // "550e8400-e29b-41d4-a716-446655440000" (unique ID)
    username,        // "device_user" (authentication)
    password         // "device_pass" (authentication)
)
```

**MQTT Protocol Details:**
- **Protocol:** MQTT 3.1.1
- **Keep-alive:** 240 seconds (default)
- **QoS:** 0 or 1 (configurable per message)
- **Clean Session:** true (default)

---

## 📥 Server Response → NVS Storage

**From Server (CheckVersion):**
```json
{
  "mqtt": {
    "endpoint": "mqtt.server.com:1883",
    "client_id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "device_user",
    "password": "device_pass",
    "keepalive": 240,
    "publish_topic": "xiaozhi/550e8400-e29b-41d4-a716-446655440000/audio"
  }
}
```

**Stored in NVS:**
```
Namespace: "mqtt"
├─ endpoint: "mqtt.server.com:1883"
├─ client_id: "550e8400-e29b-41d4-a716-446655440000"
├─ username: "device_user"
├─ password: "device_pass"
├─ keepalive: 240
└─ publish_topic: "xiaozhi/550e8400-e29b-41d4-a716-446655440000/audio"
```

**Code:** `main/ota.cc:143-161`
```cpp
has_mqtt_config_ = false;
cJSON *mqtt = cJSON_GetObjectItem(root, "mqtt");
if (cJSON_IsObject(mqtt)) {
    Settings settings("mqtt", true);  // Read-write mode
    cJSON *item = NULL;
    cJSON_ArrayForEach(item, mqtt) {  // Iterate all fields
        if (cJSON_IsString(item)) {
            settings.SetString(item->string, item->valuestring);  // Save string
        } else if (cJSON_IsNumber(item)) {
            settings.SetInt(item->string, item->valueint);        // Save int
        }
    }
    has_mqtt_config_ = true;
}
```

---

## 🔄 Full MQTT Connection Timeline

```
t=0s     │ Device startup
         │
t=0.5s   │ Application::Start()
         │ ├─ Create MqttProtocol instance
         │ └─ Call protocol_->Start()
         │
t=0.5s   │ MqttProtocol::Start()
         │ └─ Call StartMqttClient(false)
         │
t=0.6s   │ StartMqttClient()
         │ ├─ Read settings from NVS:
         │ │  ├─ endpoint: "mqtt.server.com:1883"
         │ │  ├─ client_id: "550e8400..."
         │ │  ├─ username: "device_user"
         │ │  ├─ password: "device_pass"
         │ │  ├─ keepalive: 240
         │ │  └─ publish_topic: "xiaozhi/..."
         │ │
         │ ├─ Parse endpoint:
         │ │  ├─ broker_address = "mqtt.server.com"
         │ │  └─ broker_port = 1883
         │ │
         │ ├─ Create MQTT client
         │ └─ Setup callbacks (OnConnected, OnDisconnected, OnMessage)
         │
t=1s     │ mqtt_->Connect(
         │   "mqtt.server.com",
         │   1883,
         │   "550e8400-e29b-41d4-a716-446655440000",
         │   "device_user",
         │   "device_pass"
         │ )
         │
t=1.5s   │ ← TCP connection established
         │
t=1.6s   │ ← MQTT CONNECT packet sent
         │   ├─ Client ID: 550e8400-e29b-41d4-a716-446655440000
         │   ├─ Username: device_user
         │   ├─ Password: device_pass
         │   ├─ Keep-alive: 240s
         │   └─ Clean session: true
         │
t=1.7s   │ ← Server response: CONNACK
         │
t=1.8s   │ OnConnected() callback
         │ ├─ Device is ready
         │ └─ Stop reconnect timer
         │
t=1.8s+  │ Device waiting for events
         │ ├─ OpenAudioChannel() when needed
         │ ├─ Subscribe to topics
         │ └─ Publish to publish_topic
         │
[Error]  │ ← TCP disconnected
         │
t=61s    │ OnDisconnected() callback
         │ └─ Schedule reconnect in 60s
         │
t=121s   │ Retry StartMqttClient()
```

---

## 🔐 MQTT Connection Security

| Feature | Value | Details |
|---------|-------|---------|
| **Protocol** | MQTT 3.1.1 | Standard protocol |
| **Port** | 1883 / 8883 | 1883=plain, 8883=TLS |
| **Authentication** | Username + Password | Basic auth |
| **Keep-Alive** | 240s (default) | Server disconnects if no ping |
| **QoS** | 0 (default) | Fire and forget |
| **Retain** | false | Messages not retained |

---

## 📊 Connection State Machine

```
┌─────────┐
│ INIT    │ Device started
└────┬────┘
     │ StartMqttClient()
     ↓
┌─────────────────────────────────┐
│ CONNECTING                      │
│ ├─ Resolve hostname             │
│ ├─ TCP connect                  │
│ └─ Send MQTT CONNECT            │
└────┬────────────────┬───────────┘
     │                │
  Success         Fail
     │                │
     ↓                ↓
┌─────────┐      ┌──────────┐
│CONNECTED│      │FAILED    │
│ Ready   │      │ Retry in │
│ to use  │      │ 60s      │
└────┬────┘      └──────────┘
     │
     ├─ Subscribe to topics
     ├─ Publish to topics
     └─ Wait for messages
     │
  [Timeout/Error]
     │
     ↓
┌─────────────────────┐
│ DISCONNECTING       │
│ ├─ Close TCP        │
│ └─ Schedule reconnect
└─────┬───────────────┘
      │
      └─→ CONNECTING (retry)
```

---

## 🛠️ Code References

**Main Files:**
- `main/protocols/mqtt_protocol.cc` (lines 52-141) - StartMqttClient()
- `main/protocols/mqtt_protocol.h` (lines 1-60) - Header
- `main/ota.cc` (lines 143-161) - Parse mqtt from response
- `main/settings.cc` - NVS storage

**Related:**
- `main/application.cc:405-408` - MqttProtocol initialization
- `main/protocols/protocol.h` - Protocol interface

---

## ⚡ Quick Summary

| Item | Value |
|------|-------|
| **Namespace** | "mqtt" |
| **Key Fields** | endpoint, client_id, username, password, keepalive, publish_topic |
| **Endpoint Format** | `host:port` |
| **Default Port** | 8883 |
| **Keep-alive** | 240s |
| **Reconnect** | 60s |
| **Protocol** | MQTT 3.1.1 |


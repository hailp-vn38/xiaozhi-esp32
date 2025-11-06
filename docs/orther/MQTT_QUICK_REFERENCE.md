# 🚀 MQTT Connection - Quick Reference

## 📥 Server Response Format

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

## 🔄 Parse & Parse Endpoint

```cpp
// Input: "mqtt.server.com:1883"

std::string endpoint = "mqtt.server.com:1883";
size_t pos = endpoint.find(':');

std::string broker_address = endpoint.substr(0, pos);      // "mqtt.server.com"
int broker_port = std::stoi(endpoint.substr(pos + 1));      // 1883
```

## 🔌 MQTT Connect Call

```cpp
mqtt_->Connect(
    "mqtt.server.com",  // broker_address
    1883,               // broker_port
    "550e8400-...",    // client_id (device UUID)
    "device_user",      // username
    "device_pass"       // password
)
```

## 📊 Parameters Table

| Parameter | Value | Example |
|-----------|-------|---------|
| **Host** | From endpoint before `:` | mqtt.server.com |
| **Port** | From endpoint after `:` | 1883 |
| **Client ID** | Device UUID | 550e8400-e29b-41d4-a716-446655440000 |
| **Username** | Authentication | device_user |
| **Password** | Authentication | device_pass |
| **Keep-Alive** | Seconds (default 240) | 240 |
| **Topic** | Publish topic | xiaozhi/device_id/audio |

## ⏱️ Connection Timing

- **Resolve hostname:** ~100ms
- **TCP connect:** ~500ms  
- **MQTT handshake:** ~100ms
- **Total:** ~700ms-1s
- **Reconnect timeout:** 60s

## 🔐 Protocol Details

- **MQTT Version:** 3.1.1
- **Default Port:** 1883 (plain) / 8883 (TLS)
- **Default Keep-Alive:** 240 seconds
- **QoS:** 0 (fire and forget)
- **Clean Session:** true

## 🛠️ Code Location

```
main/protocols/mqtt_protocol.cc:52-141  → StartMqttClient()
main/ota.cc:143-161                      → Parse mqtt section
main/settings.cc                         → NVS storage
main/protocols/mqtt_protocol.h           → Header
```


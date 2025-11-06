# 🔄 Remote Update Mechanisms - Tài Liệu Đầy Đủ

Xiaozhi ESP32 hỗ trợ **3 loại update từ xa**:

1. **Firmware Update** - Cập nhật firmware chính
2. **Assets Update** - Cập nhật audio/language files
3. **Configuration Update** - Cập nhật cấu hình MQTT/WebSocket

---

## 1️⃣ FIRMWARE UPDATE (OTA)

### **Luồng Update:**

```
CheckVersion response
    ↓
{
  "firmware": {
    "version": "1.0.1",
    "url": "https://firmware.server.com/xiaozhi-v1.0.1.bin",
    "force": 0
  }
}
    ↓
Device kiểm tra version
├─ Nếu force=1 → Cập nhật ngay
└─ Nếu version newer → Cập nhật ngay
    ↓
UpgradeFirmware()
├─ Close audio channel
├─ Stop audio service
├─ Download firmware từ URL
├─ Flash vào OTA partition
└─ Reboot
```

### **Response Format:**

```json
{
  "firmware": {
    "version": "1.0.1",
    "url": "https://firmware.server.com/xiaozhi-v1.0.1.bin",
    "force": 0
  }
}
```

| Field | Type | Ý nghĩa |
|-------|------|---------|
| `version` | string | Phiên bản firmware (e.g., "1.0.1") |
| `url` | string | URL download firmware binary |
| `force` | int | 0 = check version, 1 = force update |

### **Download & Flash Process:**

**Source:** `main/ota.cc:263-367`

```cpp
bool Ota::Upgrade(const std::string& firmware_url) {
    // 1. Get OTA partition
    auto update_partition = esp_ota_get_next_update_partition(NULL);
    
    // 2. HTTP GET firmware
    auto http = network->CreateHttp(0);
    if (!http->Open("GET", firmware_url)) {
        return false;
    }
    
    // 3. Stream download + write to flash
    char buffer[512];
    while (true) {
        int ret = http->Read(buffer, sizeof(buffer));
        if (ret == 0) break;
        
        // Write to OTA partition
        esp_ota_write(update_handle, buffer, ret);
        
        // Calculate progress
        size_t progress = total_read * 100 / content_length;
        if (upgrade_callback_) {
            upgrade_callback_(progress, speed);  // Progress update
        }
    }
    
    // 4. Finalize OTA
    esp_ota_end(update_handle);
    esp_ota_set_boot_partition(update_partition);
    
    // 5. Reboot
    esp_restart();
}
```

### **Application Flow:**

**Source:** `main/application.cc:737-788`

```cpp
bool Application::UpgradeFirmware(Ota& ota, const std::string& url) {
    // Close connection
    if (protocol_->IsAudioChannelOpened()) {
        protocol_->CloseAudioChannel();
    }
    
    // Alert user
    Alert(Lang::Strings::OTA_UPGRADE, Lang::Strings::UPGRADING, 
          "download", Lang::Sounds::OGG_UPGRADE);
    
    SetDeviceState(kDeviceStateUpgrading);
    board.SetPowerSaveMode(false);
    audio_service_.Stop();
    
    // Start upgrade
    bool upgrade_success = ota.StartUpgradeFromUrl(upgrade_url, 
        [display](int progress, size_t speed) {
            // Display progress: "85% 256KB/s"
            display->SetChatMessage("system", buffer);
        }
    );
    
    if (upgrade_success) {
        // Reboot immediately
        esp_restart();
    } else {
        // Restore service
        audio_service_.Start();
        Alert(Lang::Strings::ERROR, Lang::Strings::UPGRADE_FAILED);
    }
}
```

### **Partition Layout:**

```
┌─────────────────────────────────────────────┐
│  Flash Memory (ESP32)                       │
├─────────────────────────────────────────────┤
│ factory (factory app)                       │
│   - Bootloader (16KB)                       │
│   - Partition table                         │
│   - App code                                │
├─────────────────────────────────────────────┤
│ ota_0 (OTA app)  ← Current running           │
├─────────────────────────────────────────────┤
│ ota_1 (OTA app)  ← Next update target       │
│                                             │
│  Device downloads firmware → ota_1          │
│  esp_ota_set_boot_partition(ota_1)          │
│  esp_restart() → Boot from ota_1            │
├─────────────────────────────────────────────┤
│ mqtt, websocket, nvs (config)               │
├─────────────────────────────────────────────┤
│ assets (audio, language, models)            │
└─────────────────────────────────────────────┘
```

### **Version Check Logic:**

```cpp
bool Ota::IsNewVersionAvailable(const std::string& current, const std::string& newVersion) {
    std::vector<int> curr = ParseVersion(current);    // "1.0.0" → [1, 0, 0]
    std::vector<int> newer = ParseVersion(newVersion); // "1.0.1" → [1, 0, 1]
    
    // Compare version by version
    for (size_t i = 0; i < min(curr.size(), newer.size()); ++i) {
        if (newer[i] > curr[i]) return true;   // 1 > 0 → update
        if (newer[i] < curr[i]) return false;  // 0 < 1 → don't update
    }
    
    // More segments in newer → update (1.0.1 > 1.0)
    return newer.size() > curr.size();
}
```

---

## 2️⃣ ASSETS UPDATE

### **Luồng Update:**

```
Application::Start()
    ↓
CheckAssetsVersion()
    ↓
Kiểm tra Settings ("assets" namespace)
    ├─ download_url có giá trị?
    │
    ├─ YES:
    │  ├─ Alert user "Tải assets"
    │  ├─ Download từ URL
    │  ├─ Erase + Write vào assets partition
    │  ├─ Verify checksum
    │  └─ Apply (reload assets)
    │
    └─ NO:
       └─ Skip
```

### **How Server Trigger Assets Update:**

Server tạo task push download_url vào device:

```json
{
  "download_url": "https://assets.server.com/assets-v2024-01-15.bin"
}
```

Device sẽ:
1. Lưu `download_url` vào Settings ("assets" namespace)
2. Khi restart → CheckAssetsVersion() sẽ download

### **Download Code:**

**Source:** `main/assets.cc:370-501`

```cpp
bool Assets::Download(std::string url, std::function<void(int progress, size_t speed)> callback) {
    // 1. Get assets partition
    const esp_partition_t* partition = esp_partition_find_first(...);
    
    // 2. HTTP GET assets
    auto http = network->CreateHttp(0);
    if (!http->Open("GET", url)) return false;
    
    // 3. Calculate sectors to erase (4KB each)
    const size_t SECTOR_SIZE = esp_partition_get_main_flash_sector_size();
    size_t sectors_to_erase = (content_length + SECTOR_SIZE - 1) / SECTOR_SIZE;
    
    // 4. Erase + Write partition
    char buffer[512];
    size_t total_written = 0;
    size_t current_sector = 0;
    
    while (true) {
        int ret = http->Read(buffer, sizeof(buffer));
        if (ret == 0) break;
        
        // Erase sector if needed
        if (total_written % SECTOR_SIZE == 0) {
            esp_partition_erase_range(partition, total_written, SECTOR_SIZE);
            current_sector++;
        }
        
        // Write to partition
        esp_partition_write(partition, total_written, buffer, ret);
        total_written += ret;
        
        // Progress
        size_t progress = total_written * 100 / content_length;
        callback(progress, speed);
    }
    
    // 5. Reinitialize
    InitializePartition();
    return true;
}
```

### **Assets Partition:**

```
┌─────────────────────────────────────────────┐
│  Assets Partition (SPIFFS/Embedded FS)      │
├─────────────────────────────────────────────┤
│ Header                                      │
│ ├─ Magic: "ZZ"                              │
│ ├─ Checksum                                 │
│ └─ File index                               │
├─────────────────────────────────────────────┤
│ Audio files (OGG format)                    │
│ ├─ 0.ogg (audio number 0)                   │
│ ├─ 1.ogg                                    │
│ ├─ activation.ogg                           │
│ └─ ...                                      │
├─────────────────────────────────────────────┤
│ Language files (JSON locales)               │
│ ├─ en.json                                  │
│ ├─ vi.json                                  │
│ └─ ...                                      │
├─────────────────────────────────────────────┤
│ Models / ML files (if any)                  │
└─────────────────────────────────────────────┘
```

### **Application Flow:**

**Source:** `main/application.cc:72-121`

```cpp
void Application::CheckAssetsVersion() {
    Settings settings("assets", true);
    std::string download_url = settings.GetString("download_url");
    
    if (!download_url.empty()) {
        settings.EraseKey("download_url");
        
        // Alert user
        Alert(Lang::Strings::LOADING_ASSETS, 
              "Tải xuống assets...", 
              "cloud_arrow_down", 
              Lang::Sounds::OGG_UPGRADE);
        
        vTaskDelay(pdMS_TO_TICKS(3000));
        SetDeviceState(kDeviceStateUpgrading);
        board.SetPowerSaveMode(false);
        
        // Download
        bool success = assets.Download(download_url, 
            [display](int progress, size_t speed) {
                display->SetChatMessage("system", "85% 100KB/s");
            }
        );
        
        if (success) {
            // Apply new assets
            assets.Apply();
            ESP_LOGI(TAG, "Assets updated successfully");
        } else {
            Alert(Lang::Strings::ERROR, "Tải assets thất bại");
        }
    }
}
```

---

## 3️⃣ CONFIGURATION UPDATE

### **What is Updated:**

Không cần download, server trả trong CheckVersion response:

```json
{
  "mqtt": {...},
  "websocket": {...},
  "server_time": {...}
}
```

Device **tự động lưu vào Settings (NVS)**:

```
Namespace: "mqtt"
├─ endpoint, client_id, username, password
└─ ...

Namespace: "websocket"
├─ url, token, version
└─ ...
```

### **When Applied:**

| Config | When Applied |
|--------|-------------|
| MQTT | Khi MqttProtocol::Start() |
| WebSocket | Khi user gọi (wake word) |
| Server Time | Ngay sau CheckVersion |

### **Update Code:**

**Source:** `main/ota.cc:143-207`

```cpp
// Parse MQTT config
cJSON *mqtt = cJSON_GetObjectItem(root, "mqtt");
if (cJSON_IsObject(mqtt)) {
    Settings settings("mqtt", true);
    cJSON *item = NULL;
    cJSON_ArrayForEach(item, mqtt) {
        if (cJSON_IsString(item)) {
            settings.SetString(item->string, item->valuestring);  // Auto-save
        }
    }
}

// Parse WebSocket config
cJSON *websocket = cJSON_GetObjectItem(root, "websocket");
if (cJSON_IsObject(websocket)) {
    Settings settings("websocket", true);
    cJSON *item = NULL;
    cJSON_ArrayForEach(item, websocket) {
        if (cJSON_IsString(item)) {
            settings.SetString(item->string, item->valuestring);  // Auto-save
        }
    }
}

// Update server time
cJSON *server_time = cJSON_GetObjectItem(root, "server_time");
if (cJSON_IsObject(server_time)) {
    cJSON *timestamp = cJSON_GetObjectItem(server_time, "timestamp");
    if (cJSON_IsNumber(timestamp)) {
        struct timeval tv;
        tv.tv_sec = (time_t)(timestamp->valuedouble / 1000);
        settimeofday(&tv, NULL);  // Set system time
    }
}
```

---

## 📊 Update Comparison Table

| Feature | Firmware | Assets | Config |
|---------|----------|--------|--------|
| **Trigger** | CheckVersion response | Settings + push | CheckVersion response |
| **Download** | Yes (HTTP GET) | Yes (HTTP GET) | No (in response) |
| **Size** | 1-5 MB | 10-50 MB | KB |
| **Partition** | ota_0 / ota_1 | assets | NVS |
| **Reboot** | Yes (required) | No | No |
| **User Alert** | Yes | Yes | Silent |
| **Rollback** | Yes (boot factory) | No (erase partition) | No (just revert) |

---

## 🔄 Full Update Timeline (During Startup)

```
t=0s     │ Device startup
         │
t=0.5s   │ CheckAssetsVersion()
         │ ├─ Check Settings "assets"/"download_url"
         │ └─ If has URL → Download + Apply
         │
t=5s     │ CheckNewVersion()
         │ ├─ POST system info → Server
         │ ├─ Parse response:
         │ │  ├─ activation section
         │ │  ├─ mqtt/websocket config
         │ │  ├─ server_time
         │ │  └─ firmware section
         │ │
         │ ├─ Save configs to NVS
         │ ├─ If firmware version newer:
         │ │  ├─ Download firmware
         │ │  ├─ Flash to OTA partition
         │ │  ├─ Reboot ← Restart here
         │ │  └─ (Next boot uses new firmware)
         │ │
         │ └─ If no firmware update:
         │    ├─ Activate (if needed)
         │    └─ Continue to protocol init
         │
t=15s    │ MqttProtocol::Start() or WebSocket setup
         │ ├─ Read MQTT/WS config from NVS
         │ └─ Connect to server
         │
t=20s    │ Device ready
```

---

## 🛠️ Code References

**Firmware Update:**
- `main/ota.cc:263-367` - Upgrade process
- `main/ota.cc:74-241` - CheckVersion
- `main/application.cc:737-788` - UpgradeFirmware
- `main/application.cc:158-163` - Version check trigger

**Assets Update:**
- `main/application.cc:72-121` - CheckAssetsVersion
- `main/assets.cc:370-501` - Download process
- `main/assets.h` - Header

**Config Update:**
- `main/ota.cc:143-207` - Parse & save config
- `main/settings.cc` - NVS storage

---

## ⚡ Quick Summary

| Update Type | Mechanism | Trigger | Storage |
|------------|-----------|---------|---------|
| **Firmware** | HTTP GET + Flash OTA | CheckVersion | Partition |
| **Assets** | HTTP GET + Write Partition | Settings flag | SPIFFS |
| **Config** | In JSON response | Auto-parse | NVS |

All updates are **automatic** and device can update without user intervention!


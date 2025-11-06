# 🎙️ Wake Word Configuration - Tài Liệu Đầy Đủ

**Wake Word** (từ khóa thức tỉnh) là từ dùng để kích hoạt device (ví dụ: "Xiao Tu Dou", "Hey Google")

---

## 🔄 Loại Wake Word

Xiaozhi hỗ trợ **3 loại**:

```
┌─────────────────────────────────────────────────────────┐
│         WAKE WORD TYPES (Kconfig.projbuild:562-592)    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 1. WAKE_WORD_DISABLED                                   │
│    └─ Tắt hoàn toàn                                     │
│                                                         │
│ 2. USE_ESP_WAKE_WORD (Wakenet without AFE)             │
│    └─ Model cố định (ví dụ: "xiao zhi", "alexa")       │
│    └─ Không có noise cancellation                       │
│    └─ CPU: ESP32 C3/C5/C6, ESP32 (with PSRAM)          │
│                                                         │
│ 3. USE_AFE_WAKE_WORD (Wakenet with AFE)               │
│    └─ Model cố định + Noise cancellation               │
│    └─ AFE = Acoustic Front-End                          │
│    └─ CPU: ESP32 S3, ESP32 P4 (with PSRAM)             │
│                                                         │
│ 4. USE_CUSTOM_WAKE_WORD (Multinet - Custom)           │
│    └─ Custom từ khóa (user định nghĩa)                │
│    └─ CPU: ESP32 S3, ESP32 P4 (with PSRAM)             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## ⚙️ Configuration in Kconfig.projbuild

### **1. Choose Wake Word Type:**

```kconfig
choice WAKE_WORD_TYPE
    prompt "Wake Word Implementation Type"
    default USE_AFE_WAKE_WORD
    
    config WAKE_WORD_DISABLED
        bool "Disabled"
    
    config USE_ESP_WAKE_WORD
        bool "Wakenet model without AFE"
        depends on IDF_TARGET_ESP32C3 || ... || (IDF_TARGET_ESP32 && SPIRAM)
    
    config USE_AFE_WAKE_WORD
        bool "Wakenet model with AFE"
        depends on (IDF_TARGET_ESP32S3 || IDF_TARGET_ESP32P4) && SPIRAM
    
    config USE_CUSTOM_WAKE_WORD
        bool "Multinet model (Custom Wake Word)"
        depends on (IDF_TARGET_ESP32S3 || IDF_TARGET_ESP32P4) && SPIRAM
```

### **2. If USE_CUSTOM_WAKE_WORD Selected:**

```kconfig
config CUSTOM_WAKE_WORD
    string "Custom Wake Word"
    default "xiao tu dou"
    depends on USE_CUSTOM_WAKE_WORD
    help
        Custom Wake Word, use pinyin for Chinese, separated by spaces
        Examples:
        ├─ "xiao tu dou" → 小土豆
        ├─ "xiao zhi" → 小志
        └─ "hey google" (English)

config CUSTOM_WAKE_WORD_DISPLAY
    string "Custom Wake Word Display"
    default "小土豆"
    depends on USE_CUSTOM_WAKE_WORD
    help
        Greeting/Display text shown to user after detection

config CUSTOM_WAKE_WORD_THRESHOLD
    int "Custom Wake Word Threshold (%)"
    default 20
    range 1 99
    depends on USE_CUSTOM_WAKE_WORD
    help
        Sensitivity range 1-99:
        ├─ 1 = Most sensitive (more false positives)
        ├─ 20 = Balanced (default)
        └─ 99 = Least sensitive (more misses)
```

### **3. Optional Settings:**

```kconfig
config SEND_WAKE_WORD_DATA
    bool "Send Wake Word Data"
    default y
    depends on USE_AFE_WAKE_WORD || USE_CUSTOM_WAKE_WORD
    help
        ├─ If yes: Send recorded wake word audio to server
        ├─ Server processes it
        └─ Improves accuracy
```

---

## 📝 Configuration Methods

### **Method 1: Edit `sdkconfig` (Direct)**

```bash
# Open sdkconfig
nano sdkconfig

# Add/change these lines:
CONFIG_WAKE_WORD_DISABLED=n
CONFIG_USE_CUSTOM_WAKE_WORD=y
CONFIG_CUSTOM_WAKE_WORD="xiao tu dou"
CONFIG_CUSTOM_WAKE_WORD_DISPLAY="小土豆"
CONFIG_CUSTOM_WAKE_WORD_THRESHOLD=20
CONFIG_SEND_WAKE_WORD_DATA=y
```

### **Method 2: Build System GUI**

```bash
idf.py menuconfig

# Navigate to:
# → Xiaozhi Application Configuration
# → Wake Word Implementation Type
# → Select option
# → Set Custom Wake Word (if needed)
# → Save & Exit
```

### **Method 3: CMakeLists.txt Defaults**

```cmake
# main/CMakeLists.txt hoặc board-specific file
set(CUSTOM_WAKE_WORD "xiao tu dou")
set(CUSTOM_WAKE_WORD_DISPLAY "小土豆")
set(CUSTOM_WAKE_WORD_THRESHOLD 20)
```

---

## 🔧 Implementation in Code

### **Wake Word Initialization:**

**Source:** `main/audio/audio_service.cc:455-475`

```cpp
void AudioService::EnableWakeWordDetection(bool enable) {
    if (!wake_word_) {
        return;
    }

    if (enable) {
        // Initialize if not already done
        if (!wake_word_initialized_) {
            if (!wake_word_->Initialize(codec_, models_list_)) {
                ESP_LOGE(TAG, "Failed to initialize wake word");
                return;
            }
            wake_word_initialized_ = true;
        }
        wake_word_->Start();
        xEventGroupSetBits(event_group_, AS_EVENT_WAKE_WORD_RUNNING);
    } else {
        wake_word_->Stop();
        xEventGroupClearBits(event_group_, AS_EVENT_WAKE_WORD_RUNNING);
    }
}
```

### **Wake Word Detection Flow:**

```cpp
// Audio data comes in
AudioService::Feed(data)
    ↓
wake_word_->Feed(data)  // Pass to wake word detector
    ↓
Model processing
    ├─ Wakenet: Matches pre-trained keyword
    └─ Multinet: Matches custom keywords
    ↓
if (confidence > threshold) {
    wake_word_detected_callback_(keyword_name)
        ↓
        Application::OnWakeWordDetected()
}
```

### **Custom Wake Word Setup (Multinet):**

**Source:** `main/audio/wake_words/custom_wake_word.cc:96-130`

```cpp
bool CustomWakeWord::Initialize(AudioCodec* codec, srmodel_list_t* models_list) {
    // 1. Get model
    multinet_ = esp_mn_handle_from_name(mn_name_);
    multinet_model_data_ = multinet_->create(mn_name_, duration_);
    
    // 2. Set sensitivity threshold
    multinet_->set_det_threshold(multinet_model_data_, CONFIG_CUSTOM_WAKE_WORD_THRESHOLD);
    
    // 3. Clear and add commands
    esp_mn_commands_clear();
    
#ifdef CONFIG_USE_CUSTOM_WAKE_WORD
    // Add custom wake word
    commands_.push_back({
        CONFIG_CUSTOM_WAKE_WORD,          // "xiao tu dou"
        CONFIG_CUSTOM_WAKE_WORD_DISPLAY,  // "小土豆"
        "wake"                             // Type
    });
#endif
    
    // 4. Register all commands
    for (int i = 0; i < commands_.size(); i++) {
        esp_mn_commands_add(i + 1, commands_[i].command.c_str());
    }
    esp_mn_commands_update();
    
    // 5. Print active commands
    multinet_->print_active_speech_commands(multinet_model_data_);
    
    return true;
}
```

---

## 📊 Wake Word Types Comparison

| Feature | Wakenet (Fixed) | Wakenet + AFE | Multinet (Custom) |
|---------|-----------------|---------------|-------------------|
| **Wake Words** | Pre-trained | Pre-trained | Custom defined |
| **Examples** | "xiao zhi", "alexa" | Same + better audio | "你好小志" |
| **Noise Cancellation** | No | Yes (AFE) | Yes (Multi-mic) |
| **CPU Requirements** | C3/C5/C6/ESP32 | S3/P4 + PSRAM | S3/P4 + PSRAM |
| **Sensitivity Control** | No | No | Yes (1-99%) |
| **Customizable** | No | No | Yes |
| **Latency** | Fast | Medium | Slower |
| **Accuracy** | Good | Better | Best (trained) |

---

## 🎯 When Wake Word Detected

**Flow:**

```
1. Audio comes in → Feed to wake word model
2. Model matches keyword → Callback triggered
3. Application::OnWakeWordDetected()
   ├─ Encode wake word audio (if CONFIG_SEND_WAKE_WORD_DATA=y)
   ├─ Open audio channel (WebSocket/MQTT)
   ├─ Send wake word data to server
   ├─ Start listening for user speech
   └─ Update UI
4. User speaks → Streaming to server
5. Server responds → Play response audio
```

**Code:** `main/application.cc:615-651`

```cpp
void Application::OnWakeWordDetected() {
    if (device_state_ == kDeviceStateIdle) {
        // 1. Encode detected wake word
        audio_service_.EncodeWakeWord();
        
        // 2. Open connection to server
        if (!protocol_->IsAudioChannelOpened()) {
            SetDeviceState(kDeviceStateConnecting);
            if (!protocol_->OpenAudioChannel()) {
                audio_service_.EnableWakeWordDetection(true);
                return;
            }
        }
        
        // 3. Get detected wake word name
        auto wake_word = audio_service_.GetLastWakeWord();
        ESP_LOGI(TAG, "Wake word detected: %s", wake_word.c_str());
        
#if CONFIG_SEND_WAKE_WORD_DATA
        // 4. Send wake word audio to server
        while (auto packet = audio_service_.PopWakeWordPacket()) {
            protocol_->SendAudio(std::move(packet));
        }
        
        // 5. Notify server
        protocol_->SendWakeWordDetected(wake_word);
        
        // 6. Start listening
        SetListeningMode(...);
#endif
    }
}
```

---

## 📋 Example Configurations

### **Configuration 1: Fixed Wake Word (Wakenet with AFE)**

```
🎧 USE_AFE_WAKE_WORD = y
📍 CPU: ESP32 S3 / P4 with PSRAM
🎯 Wake Words: "xiao zhi", "alexa" (pre-defined)
🔊 Noise Cancellation: Yes
⚙️ User Customization: No
```

**Use Case:** Production device, good audio quality needed

### **Configuration 2: Custom Wake Word (Multinet)**

```
🎧 USE_CUSTOM_WAKE_WORD = y
📍 CPU: ESP32 S3 / P4 with PSRAM
🎯 Wake Words: "xiao tu dou" (custom)
🔊 Sensitivity: 20% (configurable)
⚙️ User Customization: Yes
```

**Use Case:** Customizable device, user-specific keywords

### **Configuration 3: No Wake Word**

```
🎧 WAKE_WORD_DISABLED = y
📍 CPU: Any
🎯 Wake Words: None
🔊 Detection: Manual (button press)
⚙️ User Customization: N/A
```

**Use Case:** Testing, button-controlled devices

---

## 🛠️ Code References

**Configuration:**
- `main/Kconfig.projbuild:562-622` - Configuration options
- `main/CMakeLists.txt` - Build configuration

**Implementation:**
- `main/audio/wake_word.h` - Interface
- `main/audio/wake_words/esp_wake_word.cc` - Wakenet implementation
- `main/audio/wake_words/afe_wake_word.cc` - Wakenet + AFE
- `main/audio/wake_words/custom_wake_word.cc` - Multinet (Custom)
- `main/audio/audio_service.cc:455-475` - Enable/Disable
- `main/application.cc:615-651` - Detection handler

**Build Scripts:**
- `scripts/build_default_assets.py` - Asset generation with wake word config

---

## ⚡ Quick Setup Steps

1. **Choose Type:**
   ```bash
   idf.py menuconfig
   → Xiaozhi → Wake Word Type → Select
   ```

2. **If Custom Wake Word:**
   ```
   CONFIG_USE_CUSTOM_WAKE_WORD = y
   CONFIG_CUSTOM_WAKE_WORD = "your wake word"
   CONFIG_CUSTOM_WAKE_WORD_DISPLAY = "Display text"
   CONFIG_CUSTOM_WAKE_WORD_THRESHOLD = 20
   ```

3. **Build & Flash:**
   ```bash
   idf.py build
   idf.py flash
   ```

4. **Test:**
   - Speak the configured wake word
   - Device should respond (LED light, sound)

---

## 🔐 Supported Languages (for Custom Wake Word)

- **Chinese:** Pinyin format (e.g., "xiao tu dou" → 小土豆)
- **English:** Direct (e.g., "hey google")
- **Others:** Depend on model support

---

## 📱 User Interaction

```
Device powered on
    ↓
Wake word detection enabled
    ↓
[Waiting for wake word...]
    ↓
User speaks: "Xiao Tu Dou"
    ↓
✓ Wake word matched!
    ↓
- LED lights up
- Pop sound plays
- Listening mode activated
- User can speak
    ↓
Server processes speech
    ↓
Device plays response
```


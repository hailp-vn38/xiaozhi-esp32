# ⚙️ Hướng Dẫn Cấu Hình Chi Tiết - XiaoZhi ESP32

## 📌 Tổng Quan Cấu Hình

Dự án XiaoZhi ESP32 có rất nhiều tùy chọn cấu hình qua `menuconfig`. Hướng dẫn này giúp bạn hiểu từng phần.

---

## 🎯 Truy Cập Menu Cấu Hình

```bash
# Kích hoạt SDK
source ~/esp-idf-5.4/export.sh

# Di chuyển đến project
cd /Users/lamphuchai/Downloads/xiaozhi-esp32-main

# Mở menu cấu hình
idf.py menuconfig
```

### Cách Sử Dụng Menu

- **↑↓**: Di chuyển lên/xuống
- **Enter**: Vào submenu hoặc bật/tắt option
- **Spacebar**: Tích/bỏ tích checkbox
- **?**: Xem giúp đỡ
- **ESC**: Quay lại hoặc thoát
- **Q**: Thoát (không lưu)
- **S**: Lưu và thoát

---

## 🔧 Các Phần Cấu Hình Quan Trọng

### 1️⃣ XiaoZhi Configuration

```
XiaoZhi Configuration
├── Wi-Fi
│   ├── Wi-Fi SSID: [nhập tên Wi-Fi của bạn]
│   └── Wi-Fi Password: [nhập mật khẩu Wi-Fi]
├── Communication Protocol
│   ├── WebSocket (mặc định)
│   └── MQTT + UDP
├── Language
│   ├── English
│   ├── 中文 (Tiếng Trung)
│   └── 日本語 (Tiếng Nhật)
└── Audio
    ├── OPUS Codec
    └── Sample Rate: 16kHz / 8kHz
```

**Cách cấu hình**:

1. Tìm `XiaoZhi Configuration`
2. Nhập SSID Wi-Fi
3. Nhập mật khẩu Wi-Fi
4. Chọn giao thức (WebSocket hoặc MQTT)
5. Chọn ngôn ngữ

---

### 2️⃣ Component Config → Wi-Fi

```
Component config
└── Wi-Fi
    ├── Station mode
    │   └── [x] Enable
    ├── SoftAP mode (Access Point)
    │   └── [x] Enable (để cấu hình lần đầu)
    └── NVS Flash
        └── [x] Enable
```

**Lưu ý**:

- Station mode: Kết nối đến router Wi-Fi
- SoftAP mode: Board tạo Wi-Fi riêng (dùng để cấu hình)

---

### 3️⃣ Component Config → MQTT

```
Component config
└── MQTT
    ├── Broker URL: mqtt://your-server.com:1883
    ├── Client ID: xiaozhi_device_1
    └── Username/Password (nếu cần)
```

**Chỉ cần cấu hình nếu dùng MQTT + UDP**

---

### 4️⃣ Component Config → Audio

```
Component config
└── Audio
    ├── Codec
    │   ├── OPUS (mặc định, tốt nhất)
    │   └── Other codecs
    ├── Sample Rate
    │   ├── 16000 Hz (mặc định)
    │   └── 8000 Hz
    └── Microphone
        └── ADC Channel: GPIO pin của mic
```

---

### 5️⃣ Component Config → ESP LCD

Cấu hình cho màn hình display (nếu có):

```
Component config
└── ESP LCD
    ├── Display Driver
    │   ├── ILI9341 (2.4" TFT)
    │   ├── ST7796 (3.5" TFT)
    │   ├── GC9A01 (1.28" Round)
    │   └── Các driver khác
    └── Pin Assignments
        ├── Data pins (D0-D7/D4-D7)
        ├── Control pins (CS, DC, RST)
        └── SPI pins
```

---

### 6️⃣ Component Config → LVGL

Cấu hình GUI framework LVGL:

```
Component config
└── LVGL
    ├── Display size
    │   ├── Horizontal resolution (px)
    │   └── Vertical resolution (px)
    ├── Theme
    │   ├── Material Design
    │   └── Other themes
    └── Font
        └── Font size (12, 14, 16, ...)
```

---

### 7️⃣ Bootloader Options

```
Bootloader options
├── Bootloader log verbosity
│   ├── Error
│   ├── Warning
│   ├── Info
│   └── Debug
└── Watchdog timeout
    └── Watchdog timeout (ms)
```

---

### 8️⃣ Compiler Options

```
Compiler options
├── Optimization level
│   ├── -O0 (debug, chậm)
│   ├── -O1
│   ├── -O2 (tốc độ)
│   └── -Os (kích thước nhỏ)
└── Stack smashing protection
    ├── Disabled
    ├── Inline
    └── Strong
```

**Khuyến nghị**:

- **Phát triển**: `-O0` (debug dễ hơn)
- **Production**: `-O2` (nhanh hơn)

---

## 📱 Cấu Hình Cho Các Board Phổ Biến

### ESP32-S3-BOX3

```
Bootloader options
└── Partition Table: 16MB flash

Component config → ESP LCD
└── Display Driver: ILI9341 (2.4" TFT)
    ├── SPI frequency: 80MHz
    └── Pin assignments: Default

Component config → LVGL
├── Horizontal resolution: 320
├── Vertical resolution: 240
└── Font size: 16
```

---

### M5Stack CoreS3

```
Bootloader options
└── Partition Table: 16MB flash

Component config → ESP LCD
└── Display Driver: ILI9342 (2.4" TFT)

Component config → LVGL
├── Horizontal resolution: 320
├── Vertical resolution: 240
```

---

### LILYGO T-Circle-S3

```
Bootloader options
└── Partition Table: 8MB flash

Component config → ESP LCD
└── Display Driver: GC9A01 (1.28" Round)

Component config → LVGL
├── Horizontal resolution: 240
├── Vertical resolution: 240
```

---

## 🔐 Cấu Hình Bảo Mật

### Enable Flash Encryption

```
Security features → Enable flash encryption
└── Select flash encryption mode:
    ├── Development
    └── Release
```

### Enable Secure Boot

```
Security features → Enable Secure Boot
└── Select Secure Boot signing mode:
    ├── One-time burn
    └── Reflashable key (dev mode)
```

⚠️ **Cảnh báo**: Chỉ dùng cho production, có thể làm firmware không thể flash lại!

---

## 🛠️ Cấu Hình Debug

### Serial Debug Output

```
Component config
└── Logging
    ├── Default log verbosity
    │   ├── None
    │   ├── Error
    │   ├── Warning
    │   ├── Info
    │   ├── Debug (khuyến khích)
    │   └── Very verbose
    └── Per-component log levels
```

### JTAG Debugging

```
Component config → Hardware Abstraction Layer
└── Enable JTAG debugging
    ├── JTAG frequency (MHz)
    └── Select JTAG pins
```

---

## 📊 Cấu Hình Memory

### Heap Configuration

```
Component config → Heap memory debugging
├── Heap memory task tracking
├── Heap corruption detection
└── Heap size
```

### PSRAM (External Memory)

```
Component config
└── SPIRAM
    ├── Support for external, SPI-connected RAM
    │   └── [x] Enable
    ├── Mode
    │   ├── 80MHz (performance)
    │   └── 40MHz (stable)
    └── Cache allocation
        ├── Code + data
        ├── Code only
        └── Data only
```

---

## 🌐 Cấu Hình Mạng

### TCP/IP

```
Component config → TCP/IP Adapter
├── IP address
├── Gateway
├── Netmask
└── DNS
```

### mDNS (Service Discovery)

```
Component config → mDNS
├── Enable mDNS
└── Hostname: xiaozhi
```

---

## 📝 Cấu Hình Pin (GPIO)

Các pin mặc định (có thể thay đổi):

**Touchscreen/Display**:

- SPI MISO: GPIO 37/13
- SPI MOSI: GPIO 35/14
- SPI CLK: GPIO 36/15
- CS: GPIO 48/10
- DC: GPIO 39/7
- RST: GPIO 40/8

**Microphone (I2S)**:

- I2S Data: GPIO 16
- I2S Clock: GPIO 17
- I2S WS: GPIO 18

**Speaker (I2S)**:

- I2S Data: GPIO 8
- I2S Clock: GPIO 9
- I2S WS: GPIO 19

**Button**:

- Button A: GPIO 0
- Button B: GPIO 1

---

## 💾 Lưu & Load Cấu Hình

### Lưu Cấu Hình Hiện Tại

```bash
# Lưu thành file
idf.py save-defconfig

# File sẽ lưu tại: sdkconfig.defaults
```

### Tạo Backup Cấu Hình

```bash
# Backup
cp sdkconfig sdkconfig.backup

# Restore
cp sdkconfig.backup sdkconfig
```

### Load Cấu Hình Có Sẵn

```bash
# Copy file cấu hình
cp sdkconfig.defaults.esp32s3 sdkconfig

# Cập nhật cấu hình
idf.py reconfigure

# Build
idf.py build
```

---

## 🚀 Cấu Hình Tối Ưu Cho Từng Trường Hợp

### ⚡ Tối Ưu Tốc Độ

```
Compiler options
├── Optimization level: -O2
└── Inline size limit: Max

Bootloader options
├── Bootloader log verbosity: Error
└── Early boot ota selection: disabled

Logging
└── Default log verbosity: None
```

### 💾 Tiết Kiệm Bộ Nhớ

```
Compiler options
├── Optimization level: -Os
└── Inline size limit: Min

Bootloader options
└── Bootloader log verbosity: None

Component config → LittleFS
└── Enable LittleFS (thay vì SPIFFS)
```

### 🔧 Tối Ưu Debug

```
Compiler options
├── Optimization level: -O0
└── Debugging symbols: Enabled

Logging
└── Default log verbosity: Debug

Component config → Heap debugging
├── Enable heap memory tracking: Yes
└── Enable heap memory corruption detection: Yes
```

---

## ✅ Checklist Cấu Hình Lần Đầu

- [ ] Nhập SSID Wi-Fi
- [ ] Nhập Password Wi-Fi
- [ ] Chọn giao thức (WebSocket/MQTT)
- [ ] Chọn ngôn ngữ
- [ ] Chọn display driver (nếu có)
- [ ] Kiểm tra pin assignments
- [ ] Chọn optimization level
- [ ] Enable debug logging
- [ ] Lưu cấu hình

---

## 📚 Tham Khảo Thêm

- [ESP-IDF Menuconfig Guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-reference/kconfig.html)
- [XiaoZhi Custom Board Guide](https://github.com/78/xiaozhi-esp32/docs/custom-board.md)
- [Common Configurations](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-guides/general-notes.html)

---

**Mẹo**: Sau khi cấu hình xong, hãy lưu file `sdkconfig` để dùng lại cho lần sau!

```bash
cp sdkconfig sdkconfig.my_board
```

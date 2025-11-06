# 📚 Hướng Dẫn Cài Đặt & Chạy XiaoZhi ESP32 (Tiếng Việt)

## 📖 Mục Lục

1. [Yêu Cầu Hệ Thống](#yêu-cầu-hệ-thống)
2. [Bước 1: Cài Đặt SDK](#bước-1-cài-đặt-sdk)
3. [Bước 2: Thiết Lập Môi Trường](#bước-2-thiết-lập-môi-trường)
4. [Bước 3: Cấu Hình Dự Án](#bước-3-cấu-hình-dự-án)
5. [Bước 4: Build Firmware](#bước-4-build-firmware)
6. [Bước 5: Flash Firmware](#bước-5-flash-firmware)
7. [Các Lệnh Hữu Ích](#các-lệnh-hữu-ích)
8. [Khắc Phục Sự Cố](#khắc-phục-sự-cố)

---

## 🔧 Yêu Cầu Hệ Thống

### Phần Cứng

- **Máy tính**: macOS, Linux, hoặc Windows (WSL2)
- **Board**: ESP32-S3, ESP32-C3, ESP32 hoặc các chip ESP32 khác
- **Cable**: USB Cable để kết nối board với máy tính

### Phần Mềm

- **Python**: Phiên bản 3.7 trở lên (khuyến khích 3.8-3.13)
- **Git**: Để clone ESP-IDF
- **Công cụ biên dịch**: Sẽ được cài tự động

### Dung Lượng Ổ Đĩa

- **ESP-IDF**: ~5-10 GB
- **Project**: ~2-3 GB
- **Tổng cộng**: ~15-20 GB

---

## 🚀 Bước 1: Cài Đặt SDK

### 1.1 Clone ESP-IDF v5.4

```bash
# Di chuyển đến home directory
cd ~

# Clone ESP-IDF version 5.4
git clone --branch v5.4 --depth 1 https://github.com/espressif/esp-idf.git esp-idf-5.4

# Chuyển vào thư mục
cd esp-idf-5.4
```

**Thời gian**: ~5-10 phút (tùy tốc độ internet)

### 1.2 Cài Đặt Tools & Dependencies

```bash
# Chạy script cài đặt cho tất cả chip
./install.sh all
```

**Những gì được cài**:

- ✅ Xtensa ESP-ELF compiler (cho ESP32-S3)
- ✅ RISC-V ESP-ELF compiler (cho chip RISC-V)
- ✅ OpenOCD debugger
- ✅ Python virtual environment
- ✅ Các thư viện Python cần thiết

**Thời gian**: ~10-20 phút (tùy tốc độ internet và máy)

---

## 🌍 Bước 2: Thiết Lập Môi Trường

### 2.1 Thiết Lập Biến Môi Trường (macOS/Linux)

#### Cách 1: Tạm Thời (cho phiên terminal hiện tại)

```bash
source ~/esp-idf-5.4/export.sh
```

#### Cách 2: Vĩnh Viễn (cho mọi lần mở terminal)

**Nếu dùng Bash** (~/.bash_profile):

```bash
echo 'export IDF_PATH=~/esp-idf-5.4' >> ~/.bash_profile
echo 'source ~/esp-idf-5.4/export.sh' >> ~/.bash_profile
source ~/.bash_profile
```

**Nếu dùng Zsh** (~/.zshrc):

```bash
echo 'export IDF_PATH=~/esp-idf-5.4' >> ~/.zshrc
echo 'source ~/esp-idf-5.4/export.sh' >> ~/.zshrc
source ~/.zshrc
```

### 2.2 Kiểm Tra Cài Đặt

```bash
# Kích hoạt môi trường
source ~/esp-idf-5.4/export.sh

# Kiểm tra phiên bản
idf.py --version

# Kết quả mong đợi:
# ESP-IDF v5.4
```

---

## ⚙️ Bước 3: Cấu Hình Dự Án

### 3.1 Di Chuyển Đến Thư Mục Project

```bash
cd /Users/lamphuchai/Downloads/xiaozhi-esp32-main
```

### 3.2 Chọn Target Board

Danh sách board hỗ trợ:

- `esp32` - ESP32 chip gốc
- `esp32s2` - ESP32-S2
- `esp32s3` - ESP32-S3 ⭐ (khuyến khích)
- `esp32c3` - ESP32-C3
- `esp32c6` - ESP32-C6
- `esp32p4` - ESP32-P4

**Đặt target (ví dụ: ESP32-S3)**:

```bash
source ~/esp-idf-5.4/export.sh
idf.py set-target esp32s3
```

**Đặt target cho chip khác** (thay esp32s3 bằng chip của bạn):

```bash
idf.py set-target esp32c3
# hoặc
idf.py set-target esp32
```

### 3.3 Cấu Hình Dự Án (Tuỳ Chọn)

```bash
# Mở menu cấu hình (dùng phím mũi tên, Enter, ESC để thoát)
idf.py menuconfig
```

**Các cài đặt quan trọng**:

- `Component config` → `Wi-Fi` → Cấu hình Wi-Fi
- `Component config` → `MQTT` → Cấu hình MQTT
- `Component config` → `Audio` → Cấu hình codec OPUS

---

## 🔨 Bước 4: Build Firmware

### 4.1 Build Hoàn Chỉnh

```bash
# Kích hoạt SDK (nếu chưa)
source ~/esp-idf-5.4/export.sh

# Build project
idf.py build
```

**Thời gian**: 5-15 phút (lần đầu lâu hơn)

**Đầu ra mong đợi**:

```
...
[100%] Built target xxx
Build complete. The following files were created:
build/xiaozhi.elf
build/xiaozhi.bin
...
```

### 4.2 Build Nhanh (Rebuild)

```bash
# Chỉ build các file thay đổi
idf.py build
```

### 4.3 Build Sạch

```bash
# Xoá build cũ và build lại từ đầu
idf.py fullclean
idf.py build
```

---

## 📤 Bước 5: Flash Firmware

### 5.1 Kết Nối Board

1. Cắm cable USB vào board
2. Cắm cable vào máy tính
3. Board sẽ được nhận dạng tự động

### 5.2 Kiểm Tra Cổng COM

```bash
# Liệt kê các cổng serial
ls /dev/cu.* 2>/dev/null || ls /dev/ttyUSB* 2>/dev/null

# Kết quả ví dụ:
# /dev/cu.usbserial-14110
# /dev/cu.Bluetooth-Incoming-Port
```

### 5.3 Flash Firmware

```bash
# Flash tự động (tự tìm cổng)
idf.py flash

# Hoặc chỉ định cổng cụ thể
idf.py -p /dev/cu.usbserial-14110 flash
```

**Thời gian**: 2-5 phút

### 5.4 Xem Serial Monitor

```bash
# Theo dõi output từ board
idf.py monitor

# Hoặc chỉ định cổng
idf.py -p /dev/cu.usbserial-14110 monitor

# Thoát: Ctrl + ]
```

### 5.5 Flash + Monitor Một Lúc

```bash
idf.py flash monitor
```

---

## 📋 Các Lệnh Hữu Ích

### Các Lệnh Cơ Bản

```bash
# Kích hoạt SDK
source ~/esp-idf-5.4/export.sh

# Build project
idf.py build

# Flash firmware
idf.py flash

# Monitor serial
idf.py monitor

# Flash + Monitor
idf.py flash monitor

# Xem kích thước binary
idf.py size
```

### Các Lệnh Nâng Cao

```bash
# Xem chi tiết kích thước components
idf.py size-components

# Dọn dẹp build (xoá tất cả)
idf.py fullclean

# Chỉ dọn dẹp (không build)
idf.py clean

# Cấu hình dự án
idf.py menuconfig

# Xem thông tin cấu hình hiện tại
idf.py save-defconfig

# Build từ file config cụ thể
idf.py build --define CONFIG_***=y

# Liệt kê tất cả lệnh
idf.py --help
```

### Flash Nâng Cao

```bash
# Flash với baud rate cao hơn (nhanh hơn)
idf.py -b 921600 flash

# Flash với baud rate thấp hơn (ổn định hơn)
idf.py -b 115200 flash

# Flash từ dòng lệnh (không build)
esptool.py -p /dev/cu.usbserial-14110 write_flash @build/flash_args
```

---

## 🔧 Quy Trình Hoàn Chỉnh Từ Đầu

### Lần Đầu Cài Đặt

```bash
# 1. Clone SDK
cd ~
git clone --branch v5.4 --depth 1 https://github.com/espressif/esp-idf.git esp-idf-5.4
cd esp-idf-5.4
./install.sh all

# 2. Thiết lập môi trường (chọn 1)
# Tạm thời:
source ~/esp-idf-5.4/export.sh

# 3. Di chuyển đến project
cd /Users/lamphuchai/Downloads/xiaozhi-esp32-main

# 4. Đặt target
idf.py set-target esp32s3

# 5. Build
idf.py build

# 6. Flash (cắm board trước)
idf.py flash monitor
```

### Lần Sau (Phát Triển)

```bash
# 1. Kích hoạt SDK
source ~/esp-idf-5.4/export.sh

# 2. Di chuyển đến project
cd /Users/lamphuchai/Downloads/xiaozhi-esp32-main

# 3. Build & Flash
idf.py flash monitor

# Thoát monitor: Ctrl + ]
```

---

## 🎯 Các Trường Hợp Thường Gặp

### Case 1: Muốn Thay Đổi Chip (VD: từ ESP32-S3 → ESP32-C3)

```bash
# Xoá cấu hình cũ
idf.py fullclean

# Đặt chip mới
idf.py set-target esp32c3

# Build
idf.py build

# Flash
idf.py flash monitor
```

### Case 2: Build Thất Bại

```bash
# Dọn dẹp toàn bộ
idf.py fullclean

# Build lại
idf.py build

# Nếu vẫn lỗi, xem chi tiết:
idf.py build -v
```

### Case 3: Muốn Thay Đổi Cài Đặt (Wi-Fi, Audio, v.v.)

```bash
# Mở menu cấu hình
idf.py menuconfig

# Chỉnh sửa → Save → Exit

# Build lại
idf.py build

# Flash
idf.py flash monitor
```

### Case 4: Flash Không Thành Công

```bash
# Kiểm tra cổng
ls /dev/cu.* 2>/dev/null

# Flash với tốc độ thấp hơn
idf.py -b 115200 flash

# Hoặc chỉ định cổng cụ thể
idf.py -p /dev/cu.usbserial-14110 -b 115200 flash monitor
```

---

## 🚨 Khắc Phục Sự Cố

### Lỗi: "idf.py: command not found"

**Nguyên nhân**: Không kích hoạt SDK

**Giải pháp**:

```bash
source ~/esp-idf-5.4/export.sh
```

---

### Lỗi: "ESP-IDF Python virtual environment not found"

**Nguyên nhân**: SDK chưa cài đặt đúng

**Giải pháp**:

```bash
cd ~/esp-idf-5.4
./install.sh all
source ~/esp-idf-5.4/export.sh
```

---

### Lỗi: "Failed to connect to ESP32"

**Nguyên nhân**: Board không được kết nối hoặc driver USB bị lỗi

**Giải pháp**:

```bash
# 1. Kiểm tra kết nối
ls /dev/cu.* 2>/dev/null

# 2. Cắm lại cable USB

# 3. Restart board (nhấn nút reset)

# 4. Chỉ định cổng tường minh
idf.py -p /dev/cu.usbserial-14110 flash

# 5. Dùng tốc độ thấp hơn
idf.py -b 115200 -p /dev/cu.usbserial-14110 flash
```

---

### Lỗi: "target already set" hoặc "CMakeError"

**Nguyên nhân**: Cấu hình cũ conflict

**Giải pháp**:

```bash
# Dọn sạch
idf.py fullclean

# Đặt lại target
idf.py set-target esp32s3

# Build
idf.py build
```

---

### Lỗi: Build chạy quá lâu hoặc bị treo

**Nguyên nhân**: RAM không đủ hoặc lỗi thư viện

**Giải pháp**:

```bash
# Build với 1 luồng
idf.py -j 1 build

# Hoặc xoá cache
idf.py fullclean
idf.py -j 4 build
```

---

## 📊 Thông Tin Build

### Xem Chi Tiết Build

Sau khi build xong, kiểm tra kích thước:

```bash
idf.py size
```

**Thông tin xem được**:

- Kích thước firmware (.bin)
- Kích thước memory usage
- Flash allocation

---

## 📝 Ghi Chú Quan Trọng

1. **Lần đầu build lâu**: Build lần đầu sẽ chậm hơn vì cần biên dịch tất cả. Lần sau sẽ nhanh hơn.

2. **Giữ nguyên SDK**: Không xoá thư mục `~/esp-idf-5.4` vì nó sẽ được dùng cho các project khác.

3. **Dependencies**: Một số thay đổi code sẽ yêu cầu rebuild toàn bộ (không phải chỉ rebuild).

4. **Backup firmware**: Lưu firmware sau khi flash thành công để backup:

   ```bash
   cp build/xiaozhi.bin ~/backups/xiaozhi_v$(date +%Y%m%d_%H%M%S).bin
   ```

5. **Monitor output**: Khi xem serial monitor, nếu thấy lỗi, hãy note lại để debug sau.

---

## 🎓 Tài Liệu Tham Khảo

- [ESP-IDF Documentation (Tiếng Anh)](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/)
- [XiaoZhi Project GitHub](https://github.com/78/xiaozhi-esp32)
- [ESP-IDF GitHub](https://github.com/espressif/esp-idf)

---

## 💬 Câu Hỏi Thường Gặp (FAQ)

### Q: Làm sao để build nhanh hơn?

A:

```bash
# Dùng nhiều luồng (mặc định là tất cả)
idf.py -j 8 build

# Hoặc build từng phần
idf.py build app  # Chỉ build app, không build SDK
```

### Q: Làm sao để tiết kiệm dung lượng?

A:

```bash
# Build tối ưu kích thước
idf.py menuconfig
# Tìm: Compiler options → Optimization level → "Size (-Os)"

# Hoặc dọn cache
rm -rf ~/.espressif/dist/  # Xoá cache downloaded tools
```

### Q: Có cách nào để debug không?

A:

```bash
# Dùng JTAG debugger (cần hardware)
idf.py openocd
# Trong terminal khác:
idf.py gdb

# Hoặc xem log qua serial monitor
idf.py monitor -v
```

### Q: Làm sao để backup cài đặt?

A:

```bash
# Backup sdkconfig
cp sdkconfig sdkconfig.backup

# Restore
cp sdkconfig.backup sdkconfig
idf.py reconfigure
```

---

**Viết lần cuối**: 28 Tháng 10, 2025
**Phiên bản**: v2.0.4
**ESP-IDF**: v5.4
**Cập nhật bởi**: GitHub Copilot

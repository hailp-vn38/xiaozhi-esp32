# 📦 Hướng Dẫn Nạp Assets.bin Vào Device

**Assets.bin** là file chứa âm thanh, ngôn ngữ, mô hình, hình ảnh của device.

---

## 📋 MỤC LỤC

1. [Assets là gì](#assets-là-gì)
2. [Cấu trúc Partition](#cấu-trúc-partition)
3. [Cách nạp assets.bin](#cách-nạp-assetsbinvào-device)
4. [Xác minh nạp thành công](#xác-minh-nạp-thành-công)
5. [Xử lý sự cố](#xử-lý-sự-cố)

---

## 📱 ASSETS LÀ GÌ

### **Nội Dung**

```
Assets Partition (8MB)
├─ Âm thanh (Audio)
│  ├─ 0.ogg, 1.ogg, 2.ogg (số)
│  ├─ activation.ogg
│  ├─ upgrade.ogg
│  └─ ... (30+ file âm thanh)
│
├─ Ngôn Ngữ (Locales)
│  ├─ en.json (English)
│  ├─ vi.json (Tiếng Việt)
│  ├─ zh.json (中文)
│  └─ ... (nhiều ngôn ngữ)
│
├─ Mô Hình (Models)
│  ├─ Wakenet model (phát hiện từ khóa)
│  ├─ Multinet model (nhận diện lệnh)
│  └─ ... (các model ML)
│
└─ Giao Diện (UI)
   ├─ Font files
   ├─ Hình ảnh (PNG)
   ├─ Icon
   └─ Theme configuration
```

### **Kích Thước**

| Flash Size | Assets Partition | Ví Dụ |
|-----------|-----------------|-------|
| 8MB | 2MB | ESP32-C3 |
| 16MB | 8MB | ESP32-S3 (Standard) |
| 16MB | 4MB | ESP32-C3 Optimized |
| 32MB | 16MB | Máy chủ giàu tài nguyên |

---

## 🗂️ CẤU TRÚC PARTITION

### **Partition Table (16MB Device)**

```
Địa chỉ    | Kích thước | Tên       | Loại  | Nội Dung
-----------|-----------|-----------|-------|------------------
0x9000     | 16KB      | nvs       | data  | Cấu hình NVS
0xd000     | 8KB       | otadata   | ota   | OTA metadata
0xf000     | 4KB       | phy_init  | data  | PHY init data
0x20000    | 4MB       | ota_0     | app   | Firmware v0
           | 4MB       | ota_1     | app   | Firmware v1
0x800000   | 8MB       | assets    | data  | ← ASSETS TẠI ĐÂY
```

### **Offset Cho Các Kích Thước**

**8MB Device:**
```
assets offset: 0x280000 (2.5MB)
size: 0x180000 (1.5MB)
```

**16MB Device (Standard):**
```
assets offset: 0x800000 (8MB)
size: 0x800000 (8MB)
```

**32MB Device:**
```
assets offset: 0xA00000
size: 0x1000000 (16MB)
```

---

## 🔧 CÁCH NẠP ASSETS.BIN VÀO DEVICE

### **Phương Pháp 1: Dùng esptool.py (Nhanh Nhất)**

**Cài đặt esptool:**
```bash
pip install esptool
```

**Nạp assets.bin:**

**Với 16MB device (offset 0x800000):**
```bash
esptool.py -p /dev/ttyUSB0 -b 460800 write_flash 0x800000 assets.bin
```

**Với 8MB device (offset 0x280000):**
```bash
esptool.py -p /dev/ttyUSB0 -b 460800 write_flash 0x280000 assets.bin
```

**Tham số giải thích:**
- `-p /dev/ttyUSB0` = Port COM (tìm với `esptool.py chip_id`)
- `-b 460800` = Tốc độ baud rate (450-930000)
- `write_flash` = Lệnh ghi
- `0x800000` = Offset assets partition
- `assets.bin` = File cần nạp

**Windows:**
```bash
esptool.py -p COM3 -b 460800 write_flash 0x800000 assets.bin
```

**macOS:**
```bash
esptool.py -p /dev/cu.usbserial-14 -b 460800 write_flash 0x800000 assets.bin
```

### **Phương Pháp 2: Dùng IDF Flash Tool**

```bash
# Tìm port
idf.py -p /dev/ttyUSB0 monitor

# Nạp assets.bin
idf.py -p /dev/ttyUSB0 -b 460800 write_flash 0x800000 path/to/assets.bin
```

### **Phương Pháp 3: Dùng VSCode + ESP-IDF Extension**

**Bước 1:** Mở VSCode với project
**Bước 2:** Chuột phải → "ESP-IDF: Flash Device"
**Bước 3:** Chọn port và tốc độ
**Bước 4:** Chọn file assets.bin
**Bước 5:** Chọn offset 0x800000

### **Phương Pháp 4: Nạp Cùng Lúc (Build + Assets)**

**Trong build process, ESP-IDF tự động nạp:**

```bash
idf.py build
idf.py flash  # Tự động nạp tất cả including assets
```

**File nạp sẽ bao gồm:**
```
0x1000: bootloader
0xf000: phy_init
0x20000: firmware (ota_0)
0x800000: assets.bin ← TỰ ĐỘNG NẠPNHẬ
```

---

## ✅ XÁC MINH NẠP THÀNH CÔNG

### **Cách 1: Dùng esptool Read**

**Kiểm tra partition:**
```bash
esptool.py -p /dev/ttyUSB0 read_flash 0x800000 0x100 read_assets.bin
hexdump -C read_assets.bin
```

**Kiểm tra magic byte:**
```bash
# Đầu file assets nên là "ZZ" (0x5A 0x5A)
hexdump -C assets.bin | head -1
# Kết quả: 00000000  5a 5a ... (ZZ magic)
```

### **Cách 2: Kiểm Tra Từ Device**

**Kết nối serial monitor:**
```bash
idf.py -p /dev/ttyUSB0 monitor
```

**Log sẽ hiển thị:**
```
I (120) Assets: Assets partition found
I (121) Assets: Assets initialized successfully
I (122) Assets: Total files: 45
I (123) Assets: Checksum valid
```

### **Cách 3: Kiểm Tra Chức Năng**

- ✓ Device phát âm các chữ số khi kích hoạt (âm thanh nạp OK)
- ✓ Ngôn ngữ hiển thị đúng (locales nạp OK)
- ✓ Phát hiện từ thức tỉnh hoạt động (models nạp OK)

---

## 🔍 LỆNH ESPTOOL NÂNG CAO

### **Xem Danh Sách Partition**

```bash
esptool.py -p /dev/ttyUSB0 read_flash 0x8000 0x800 partition_table.bin
hexdump -C partition_table.bin
```

### **Nạp Nhiều File Cùng Lúc**

```bash
esptool.py -p /dev/ttyUSB0 -b 460800 write_flash \
  0x1000 bootloader.bin \
  0xf000 phy_init.bin \
  0x20000 firmware.bin \
  0x800000 assets.bin
```

### **Xóa Assets Partition**

```bash
esptool.py -p /dev/ttyUSB0 erase_region 0x800000 0x800000
```

### **Sao Lưu Assets**

```bash
esptool.py -p /dev/ttyUSB0 read_flash 0x800000 0x800000 assets_backup.bin
```

### **Verify (Kiểm Tra CRC)**

```bash
esptool.py -p /dev/ttyUSB0 verify_flash 0x800000 assets.bin
```

---

## 🚨 XỬ LÝ SỰ CỐ

### **Lỗi: "Failed to write"**

**Nguyên nhân:** Port không khả dụng hoặc chip không nhận
**Giải pháp:**
1. Kiểm tra kết nối USB
2. Bấm nút Reset trên device
3. Kiểm tra driver CH340 / CP2102
4. Thử port khác

```bash
# Tìm port đúng
esptool.py chip_id
# Sẽ hiển thị: "Detecting chip type..."
```

### **Lỗi: "Device not found"**

```bash
# Liệt kê tất cả port
esptool.py list_ports

# Kết quả:
# /dev/ttyUSB0 (CH340, S/N: ...)

# Nếu không thấy → Driver cần cài
```

### **Nạp Chậm**

```bash
# Tăng tốc độ baud rate
esptool.py -p /dev/ttyUSB0 -b 921600 write_flash 0x800000 assets.bin
# Tốc độ max: 921600
```

### **File Assets Corrupt Sau Nạp**

**Triệu chứng:** Device không phát âm, UI lỗi

**Giải pháp:**
1. Xóa partition assets
```bash
esptool.py -p /dev/ttyUSB0 erase_region 0x800000 0x800000
```

2. Nạp lại
```bash
esptool.py -p /dev/ttyUSB0 -b 460800 write_flash 0x800000 assets.bin
```

3. Kiểm tra checksum
```bash
# Log sẽ hiển thị checksum
idf.py -p /dev/ttyUSB0 monitor
```

### **Device Không Nhận Assets Sau Nạp**

**Kiểm tra:**
1. Offset đúng chưa? (0x800000 cho 16MB)
2. File assets.bin có valid magic? (0x5A 0x5A)
3. File size phù hợp partition? (max 8MB)

```bash
# Kiểm tra size
ls -lh assets.bin
# Nên < 8000000 bytes

# Kiểm tra magic
od -x assets.bin | head -1
# Nên có "5a5a" ở đầu
```

---

## 📊 BẢNG THAM CHIẾU OFFSET

**Lựa chọn offset theo flash size:**

| Flash Size | Device | Assets Offset | Assets Size | Cmd |
|-----------|--------|---------------|-------------|-----|
| **4MB** | C3 | 0x1C0000 | 384KB | `write_flash 0x1C0000` |
| **8MB** | C6 | 0x280000 | 1.5MB | `write_flash 0x280000` |
| **16MB** | S3 | 0x800000 | 8MB | `write_flash 0x800000` |
| **16MB** | C3 | 0x800000 | 4MB | `write_flash 0x800000` |
| **32MB** | S3 Pro | 0xA00000 | 16MB | `write_flash 0xA00000` |

**Tìm offset từ partition table:**
```bash
# Mở file partition table (ví dụ 16m.csv)
cat partitions/v2/16m.csv | grep assets
# Kết quả:
# assets,   data, spiffs,  0x800000,  8M
```

---

## 🔐 BUILD + NẠP TƯỞNGVÔI

### **Cách Dễ Nhất: Dùng idf.py**

```bash
# Build project
idf.py build

# Nạp tất cả (bootloader + firmware + assets)
idf.py -p /dev/ttyUSB0 -b 460800 flash

# Monitor log
idf.py -p /dev/ttyUSB0 monitor
```

### **Chỉ Nạp Assets (Sau Build)**

```bash
# Build lần đầu (để tạo assets)
idf.py build

# Nạp chỉ assets
esptool.py -p /dev/ttyUSB0 -b 460800 write_flash 0x800000 build/generated_assets.bin
```

### **Trong CMakeLists.txt**

Xiaozhi tự động nạp assets khi build:
```cmake
# main/CMakeLists.txt dòng 861-878
partition_table_get_partition_info(offset "--partition-name assets" "offset")
if ("${offset}")
    esptool_py_flash_to_partition(flash "assets" "${GENERATED_ASSETS_LOCAL_FILE}")
    message(STATUS "Assets flash configured: ... -> assets partition")
endif()
```

---

## ⚡ QUICK START

**5 bước nạp assets nhanh nhất:**

```bash
# 1. Tìm port
esptool.py chip_id

# 2. Xác định offset (16MB → 0x800000)
cat partitions/v2/16m.csv | grep assets

# 3. Nạp
esptool.py -p /dev/ttyUSB0 -b 460800 write_flash 0x800000 assets.bin

# 4. Kiểm tra magic
hexdump -C assets.bin | head -1
# Kết quả: 00000000  5a 5a ...

# 5. Xác minh
idf.py -p /dev/ttyUSB0 monitor
# Tìm "Assets partition found"
```

---

## 📚 TÀI LIỆU THAM KHẢO

- `partitions/v2/README.md` - Chi tiết partition layout
- `main/CMakeLists.txt:861-878` - Build script assets
- `main/assets.cc:44-100` - Assets initialization code
- `partitions/v2/16m.csv` - Partition table 16MB

**Câu lệnh kiểm tra nhanh:**
```bash
# Tất cả dalam 1 dòng
esptool.py chip_id && \
cat partitions/v2/16m.csv | grep assets && \
esptool.py -p /dev/ttyUSB0 -b 460800 write_flash 0x800000 build/generated_assets.bin && \
echo "✓ Nạp xong"
```


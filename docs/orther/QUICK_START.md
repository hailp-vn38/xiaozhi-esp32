# 🚀 Quick Start - XiaoZhi ESP32 (Bắt Đầu Nhanh)

## Các Bước Nhanh Nhất

### 1️⃣ Kích Hoạt SDK (Mỗi Lần Mở Terminal)

```bash
source ~/esp-idf-5.4/export.sh
```

### 2️⃣ Di Chuyển Đến Project

```bash
cd /Users/lamphuchai/Downloads/xiaozhi-esp32-main
```

### 3️⃣ Chỉnh Sửa Code (Tuỳ Chọn)

Chỉnh sửa các file trong thư mục `main/` và `components/`

### 4️⃣ Build Project

```bash
idf.py build
```

⏱️ **Thời gian lần đầu**: 10-15 phút | **Lần sau**: 2-5 phút

### 5️⃣ Kết Nối Board

- Cắm USB cable vào board
- Cắm vào máy tính
- Chờ board được nhận dạng

### 6️⃣ Flash + Monitor

```bash
idf.py flash monitor
```

⏱️ **Thời gian**: 2-5 phút

### 7️⃣ Xem Kết Quả

Serial monitor sẽ hiển thị:

```
I (XYZ) [TAG]: Message...
```

**Thoát monitor**: `Ctrl + ]`

---

## 📋 Script Toàn Bộ (Copy & Paste)

```bash
#!/bin/bash

# Kích hoạt SDK
source ~/esp-idf-5.4/export.sh

# Di chuyển đến project
cd /Users/lamphuchai/Downloads/xiaozhi-esp32-main

# Build
echo "=== Building... ==="
idf.py build

# Flash + Monitor
echo "=== Flashing & Starting Monitor... ==="
idf.py flash monitor
```

Lưu thành file `build.sh` và chạy:

```bash
chmod +x build.sh
./build.sh
```

---

## 🔄 Workflow Phát Triển

```
1. Sửa code trong main/ hoặc components/
   ↓
2. Chạy: idf.py build
   ↓
3. Kết nối board
   ↓
4. Chạy: idf.py flash monitor
   ↓
5. Xem output, debug
   ↓
6. Lặp lại bước 1
```

---

## ⚡ Lệnh Tắt

| Mục Đích                | Lệnh                   |
| ----------------------- | ---------------------- |
| Build                   | `idf.py build`         |
| Flash                   | `idf.py flash`         |
| Monitor                 | `idf.py monitor`       |
| Build + Flash + Monitor | `idf.py flash monitor` |
| Dọn sạch                | `idf.py fullclean`     |
| Menu Config             | `idf.py menuconfig`    |
| Xem kích thước          | `idf.py size`          |

---

## 🆘 Giải Quyết Nhanh

| Vấn Đề                 | Lệnh                                        |
| ---------------------- | ------------------------------------------- |
| Quên kích hoạt SDK     | `source ~/esp-idf-5.4/export.sh`            |
| idf.py không tìm thấy  | `source ~/esp-idf-5.4/export.sh`            |
| Build bị lỗi           | `idf.py fullclean && idf.py build`          |
| Flash không thành công | `idf.py -b 115200 flash`                    |
| Chip lỗi               | `idf.py set-target esp32s3 && idf.py build` |

---

## 📁 Cấu Trúc Project

```
xiaozhi-esp32-main/
├── main/                    # Source code chính
│   ├── main.cc            # Điểm vào
│   ├── application.cc      # Logic ứng dụng
│   └── ...
├── components/            # Các components tùy chỉnh
├── build/                 # Output build (tự động tạo)
│   └── xiaozhi.bin       # Firmware (sau khi build)
├── sdkconfig              # Cấu hình project
├── CMakeLists.txt         # Build config
└── idf_component.yml      # Dependencies
```

---

**Ready? Let's Build! 🔨**

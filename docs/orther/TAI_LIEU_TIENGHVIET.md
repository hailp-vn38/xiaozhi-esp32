# 📚 README - Tài Liệu Tiếng Việt

Dự án XiaoZhi ESP32 đã được cài đặt thành công. Dưới đây là hướng dẫn nhanh gọn.

## 🚀 Bắt Đầu Nhanh (2 Phút)

```bash
# 1. Kích hoạt SDK (mỗi terminal)
source ~/esp-idf-5.4/export.sh

# 2. Di chuyển đến project
cd /Users/lamphuchai/Downloads/xiaozhi-esp32-main

# 3. Cắm board vào USB

# 4. Build + Flash + Monitor
idf.py flash monitor
```

**Kết quả**: Firmware sẽ được flash lên board, serial monitor sẽ hiển thị output

## 📖 Tài Liệu (Chọn 1)

### Nếu Đã Setup Xong, Chỉ Muốn Build Nhanh

👉 Đọc: **[QUICK_START.md](./QUICK_START.md)** (2 phút)

### Nếu Muốn Hiểu Chi Tiết Mọi Thứ

👉 Đọc: **[HUONG_DAN_TIENGHVIET.md](./HUONG_DAN_TIENGHVIET.md)** (20 phút)

### Nếu Muốn Chỉnh Sửa Cấu Hình menuconfig

👉 Đọc: **[CAU_HINH_CHI_TIET.md](./CAU_HINH_CHI_TIET.md)** (15 phút)

### Nếu Muốn Tra Cứu Lệnh & Script

👉 Đọc: **[LENH_VA_QYTRINH.md](./LENH_VA_QYTRINH.md)** (10 phút)

### Tóm Tắt Kết Quả Cài Đặt

👉 Đọc: **[TONG_HOP_CAI_DAT.md](./TONG_HOP_CAI_DAT.md)** (5 phút)

---

## ✅ Đã Cài Đặt

| Thành Phần         | Trạng Thái  | Vị Trí              |
| ------------------ | ----------- | ------------------- |
| **ESP-IDF v5.4**   | ✅          | `~/esp-idf-5.4`     |
| **Target Board**   | ✅ ESP32-S3 | Cấu hình            |
| **Firmware Build** | ✅          | `build/xiaozhi.bin` |
| **Kích Thước**     | 2.4 MB      | 39% dung lượng      |

---

## 🎯 Lệnh Quan Trọng Nhất

```bash
# Build project
idf.py build

# Flash firmware lên board
idf.py flash

# Xem serial monitor
idf.py monitor

# Build + Flash + Monitor (all-in-one)
idf.py flash monitor

# Cấu hình
idf.py menuconfig

# Dọn sạch build
idf.py fullclean
```

---

## 📋 Quy Trình Hàng Ngày

1. **Mở terminal mới**

   ```bash
   source ~/esp-idf-5.4/export.sh
   cd /Users/lamphuchai/Downloads/xiaozhi-esp32-main
   ```

2. **Chỉnh sửa code** (tuỳ chọn)

   - Sửa file trong `main/` hoặc `components/`

3. **Build & Flash**

   ```bash
   idf.py flash monitor
   ```

4. **Xem kết quả**
   - Serial monitor sẽ hiển thị output
   - Nhấn `Ctrl + ]` để thoát

---

## 🆘 Lỗi Phổ Biến

### "idf.py: command not found"

```bash
source ~/esp-idf-5.4/export.sh
```

### Build bị lỗi

```bash
idf.py fullclean && idf.py build
```

### Flash không thành công

```bash
idf.py -b 115200 flash
```

---

## 📚 Tài Liệu Chi Tiết

| File                        | Nội Dung            | Thời Gian |
| --------------------------- | ------------------- | --------- |
| **QUICK_START.md**          | Bắt đầu nhanh       | 2 phút    |
| **HUONG_DAN_TIENGHVIET.md** | Hướng dẫn đầy đủ    | 20 phút   |
| **CAU_HINH_CHI_TIET.md**    | Cấu hình menuconfig | 15 phút   |
| **LENH_VA_QYTRINH.md**      | Danh sách lệnh      | 10 phút   |
| **TONG_HOP_CAI_DAT.md**     | Kết quả cài đặt     | 5 phút    |

---

## 🌐 Tài Liệu Tham Khảo

- [ESP-IDF Official Docs](https://docs.espressif.com/)
- [XiaoZhi GitHub](https://github.com/78/xiaozhi-esp32)
- [Custom Board Guide](./docs/custom-board.md)
- [MCP Protocol](./docs/mcp-protocol.md)

---

**Chuẩn bị sẵn sàng? Chạy lệnh này:**

```bash
source ~/esp-idf-5.4/export.sh
cd /Users/lamphuchai/Downloads/xiaozhi-esp32-main
idf.py flash monitor
```

🎉 **Chúc bạn may mắn!**

# XiaoZhi ESP32-S3 - Build & Development Guide

## ✅ Cài đặt Hoàn Thành

- **ESP-IDF Version**: 5.4
- **Target Board**: ESP32-S3
- **Installation Path**: `/Users/lamphuchai/esp/esp-idf-5.4`
- **Build Status**: ✅ Thành công

## 🚀 Quick Start

### 1. Setup Environment

```bash
# Load ESP-IDF environment
source /Users/lamphuchai/esp/esp-idf-5.4/export.sh

# Hoặc sử dụng script đã chuẩn bị
source esp_env.sh
```

### 2. Build Project

```bash
# Method 1: Using idf.py
idf.py build

idf.py menuconfig


# Method 2: Using VS Code (Ctrl+Shift+B)
# Chọn task "idf_build"
```

### 3. Flash to ESP32-S3

```bash
# Tìm port của board
ls /dev/tty.usb*

# Flash firmware
idf.py -p /dev/tty.usbserial-0 flash

# Hoặc sử dụng esptool trực tiếp
python -m esptool --chip esp32s3 -b 460800 --before default_reset --after hard_reset write_flash --flash_mode dio --flash_size 16MB --flash_freq 80m 0x0 build/bootloader/bootloader.bin 0x8000 build/partition_table/partition-table.bin 0xd000 build/ota_data_initial.bin 0x20000 build/xiaozhi.bin 0x800000 build/generated_assets.bin
```

### 4. Monitor Serial Output

```bash
idf.py -p /dev/tty.usbserial-0 monitor
```

## 📂 Build Output

- `build/xiaozhi.bin` - Main firmware (2.4 MB)
- `build/bootloader/bootloader.bin` - Bootloader
- `build/partition_table/partition-table.bin` - Partition table
- `build/generated_assets.bin` - Assets

## 🔧 Configuration

### VS Code Settings

```json
{
  "idf.espIdfPath": "/Users/lamphuchai/esp/esp-idf-5.4",
  "idf.pythonBinPath": "/Users/lamphuchai/.espressif/python_env/idf5.4_py3.13_env/bin/python",
  "idf.toolsPath": "/Users/lamphuchai/.espressif"
}
```

### SDKConfig

- File: `sdkconfig`
- Defaults: `sdkconfig.defaults.esp32s3`

## 🐛 Troubleshooting

### Error: FileNotFound - esptool.py

**Solution**: Make sure environment is sourced correctly:

```bash
source /Users/lamphuchai/esp/esp-idf-5.4/export.sh
```

### CMake Error - Toolchain not set

**Solution**: Ensure target is set:

```bash
idf.py set-target esp32s3
```

### Build Errors

**Solution**: Clean build:

```bash
idf.py fullclean
idf.py build
```

## 📊 Build Statistics

| Item             | Value       |
| ---------------- | ----------- |
| Firmware Size    | 2.4 MB      |
| Partition Usage  | 61%         |
| Free Space       | 39%         |
| Compilation Time | ~30 seconds |
| Components       | 100+        |

## 📝 Project Structure

```
xiaozhi-esp32-main/
├── main/                    # Main source code
│   ├── application.cc      # Main application
│   ├── boards/             # Board configurations
│   ├── audio/              # Audio processing
│   ├── display/            # Display drivers
│   └── protocols/          # Protocol implementations
├── managed_components/     # IDF component manager
├── build/                  # Build output
├── .vscode/                # VS Code settings
│   ├── settings.json      # Editor settings
│   ├── tasks.json         # Build tasks
│   ├── launch.json        # Debugging config
│   └── c_cpp_properties.json  # C++ IntelliSense
└── CMakeLists.txt         # CMake configuration
```

## 🔗 Useful Links

- [ESP-IDF Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/)
- [ESP32-S3 Technical Reference](https://www.espressif.com/sites/default/files/documentation/esp32-s3_datasheet_en.pdf)
- [VS Code ESP-IDF Extension](https://marketplace.visualstudio.com/items?itemName=espressif.esp-idf-extension)

## ✨ Fixed Issues

1. ✅ Format string error in `esp32_camera.cc` (line 477)

   - Changed `%08x` to `%08lx` for `v4l2_pix_fmt_t`

2. ✅ VS Code configuration paths
   - Updated ESP-IDF path to correct location
   - Configured Python executable path
   - Added toolchain paths

---

**Last Updated**: November 6, 2025
**Status**: ✅ Ready for Development

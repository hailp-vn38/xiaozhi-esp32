#!/bin/bash
# ESP-IDF Setup Script for xiaozhi-esp32

export ESP_IDF_PATH="/Users/lamphuchai/esp/esp-idf-5.4"
export ESP_TOOLS_PATH="/Users/lamphuchai/.espressif"
export IDF_TARGET="esp32s3"
export IDF_PATH="${ESP_IDF_PATH}"
export PYTHON="${ESP_TOOLS_PATH}/python_env/idf5.4_py3.13_env/bin/python"

# Add to PATH
export PATH="${ESP_IDF_PATH}/tools:${PATH}"
export PATH="${ESP_TOOLS_PATH}/tools/xtensa-esp-elf/esp-14.2.0_20241119/xtensa-esp-elf/bin:${PATH}"
export PATH="${ESP_TOOLS_PATH}/tools/riscv32-esp-elf/esp-14.2.0_20241119/riscv32-esp-elf/bin:${PATH}"
export PATH="${ESP_TOOLS_PATH}/tools/esp32ulp-elf/2.38_20240113/esp32ulp-elf/bin:${PATH}"
export PATH="${ESP_TOOLS_PATH}/tools/openocd-esp32/v0.12.0-esp32-20241016/openocd-esp32/bin:${PATH}"
export PATH="${PYTHON%/*}:${PATH}"

echo "ESP-IDF 5.4 Environment Loaded"
echo "IDF_PATH: $IDF_PATH"
echo "IDF_TARGET: $IDF_TARGET"
echo "Python: $PYTHON"

- ESP32-S3 - ILI9341 240×320 Non-IPS 2.4 inch

```
GPIO 3	CS
GPIO 9	RESET
GPIO 10	DC
GPIO 11	SDA
GPIO 12	SCL
GPIO 13	LED
```

- MAX98357A: bộ khuếch đại mono, cũng sử dụng giao tiếp I2S

```
GPIO7	DIN
GPIO15	BCLK
GPIO16	LRCLK
```

- Microphone

```
GPIO4	WS
GPIO5	SCK
GPIO6	SD
```

- Nút nhấn

```
GPIO37	Nút nhấn 1	Tăng âm lượng
GPIO36	Nút nhấn 2	Giảm âm lượng
GPIO0	Nút nhấn 3	Đánh thức
GPIO18	LED	Đèn

```

Ghi chú
Màn hình ILI9341 240×320 Non-IPS 2.4 inch: TFT 240×320, giao tiếp SPI
MIC INMP441: micro kỹ thuật số, sử dụng giao tiếp I2S
MAX98357A: bộ khuếch đại mono, cũng sử dụng giao tiếp I2S
Nút bấm: Kéo xuống GND
ESP32-S3: sử dụng GPIO từ 0 đến 46 (chọn GPIO hỗ trợ I2S/I2C/SPI)

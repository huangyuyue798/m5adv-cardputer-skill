# 编译、合并、烧录与发布（Cardputer 通用）

## 标准迭代流程

```
改源码 → pio run 编译 → merge_bin 生成合并镜像 → write_flash 烧录 → 实机验证
```

按需再更新文档、打包发布（发布方式随项目而定，见末尾）。

## 编译

```bash
cd <project>
<workspace>/.pio-venv/bin/pio run
```

- 看输出末尾 RAM / Flash 占用。无 PSRAM 设备上 RAM 接近上限（>40%）要警惕栈溢出。
- 编译报错优先排查：函数前置声明（定义顺序）、颜色必须是 16 位、中文字符常量别赋给 `char`、缺 `<math.h>` 等。

## 生成合并镜像

bootloader/partitions 通常在 `.pio/build/<env>/`，`boot_app0.bin` 在 framework 包里：

```bash
VENV=<workspace>/.pio-venv/bin
ESP=$(find ~/.platformio/packages/tool-esptoolpy -name esptool.py | head -1)
BUILD=.pio/build/<env>                       ;# env 名见 platformio.ini，如 m5stack-cardputer
BOOTAPP0=$(find ~/.platformio/packages/framework-arduinoespressif32 -name boot_app0.bin | head -1)

$VENV/python "$ESP" --chip esp32s3 merge_bin -o firmware/merged_firmware.bin \
  0x0 "$BUILD/bootloader.bin" \
  0x8000 "$BUILD/partitions.bin" \
  0xe000 "$BOOTAPP0" \
  0x10000 "$BUILD/firmware.bin"
```

- **烧录用合并镜像 `firmware/merged_firmware.bin`（写 0x0）**，不是单独的 `firmware.bin`（那只含 app，需配 0x10000 和对应 bootloader/分区表）。
- 每次重新编译后都要重新 merge_bin；建议把最新 `firmware.bin` 也 `cp` 到 `firmware/` 保持一致，避免新旧混淆。

## 烧录

```bash
PORT=$(ls /dev/cu.usbmodem* 2>/dev/null | head -1)     ;# macOS；Linux 多为 /dev/ttyUSB*
$VENV/python "$ESP" --chip esp32s3 --port "$PORT" --baud 921600 \
  write_flash 0x0 firmware/merged_firmware.bin
```

- 成功标志：`Hash of data verified.` + `Hard resetting via RTS pin...`。
- 串口号用 `ls /dev/cu.usbmodem*` 确认；设备重插可能变号。
- 有些环境 `esptool.py` 走代理会报 502，多为网络/代理问题，重试或检查代理设置。

## 版本号

- 在源码里维护一个固件版本常量（如 `FW_VERSION`），每次迭代 +1，并在设置页/关于页显示。
- 烧录后让用户在该页确认版本号，确保烧的是最新固件——排查"改了没生效"时这步能省很多时间。

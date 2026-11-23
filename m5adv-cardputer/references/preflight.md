# 依赖完整性预检（动手写代码之前必做）

新手用 AI coding 做 M5ADV 固件时最常见的事故：在**没有确认工具链和依赖已就绪**的情况下就开始写功能，结果编译出来的固件中文全是方块、数字都显示不出来、二维码空白、页面错位——却误以为是代码逻辑错了，浪费大量 token 反复试错。

**铁律：任何功能实现之前，先跑预检脚本；预检不过，先解决环境，不要写一行 UI 代码。**

## 一键预检

```bash
bash scripts/preflight.sh /path/to/your-cardputer-project
```

脚本检查以下每一项，缺哪项就先补哪项（补完重跑直到全绿）。

## 检查项与修复

### 1. Python 虚拟环境 + PlatformIO

- 检查：项目旁的 `.pio-venv/bin/pio` 是否存在、能否 `pio --version`。
- 缺失修复：
  ```bash
  python3 -m venv <workspace>/.pio-venv
  <workspace>/.pio-venv/bin/pip install platformio
  ```
- **不要**用系统 `pio`（可能没有或版本不符）。

### 2. platformio.ini 依赖版本

- 必须锁定以下版本（版本漂移会导致编译/运行异常）：
  ```ini
  platform = espressif32@6.7.0
  board = esp32-s3-devkitc-1      ; Cardputer ADV 无独立 board ID，用同规格板型
  framework = arduino
  board_upload.flash_size = 8MB
  lib_deps =
      m5stack/M5Unified@^0.2.8
      m5stack/M5GFX@^0.2.8
      m5stack/M5Cardputer@^1.1.0
      bblanchon/ArduinoJson@^6.21.4
  ```
- Cardputer ADV 是 ESP32-S3、8MB Flash、**无 PSRAM**。`board` 用 `esp32-s3-devkitc-1`，M5Unified 运行时自动探测 Cardputer 硬件配置键盘/屏幕引脚。

### 3. 依赖库是否真正下载完整

- 检查 `.pio/libdeps/m5stack-cardputer/` 下是否有 `M5Unified`、`M5GFX`、`M5Cardputer`、`ArduinoJson` 四个目录。
- 首次编译会下载依赖。若下载中途失败（网络/代理），可能出现"目录存在但内容不全"——必须删除该库目录后重新 `pio run` 让它完整重下。
- 框架包若解包失败，需手动用完整 temp 包替换 `~/.platformio/packages/framework-arduinoespressif32` 并补 `.piopm`。

### 4. 中文字体支持（导致"方块字"的头号原因）

- 必须显式使用中文字体，不能用默认字体：
  ```cpp
  M5.Display.setFont(&fonts::efontCN_12);   // 或 efontCN_14 / efontCN_16
  ```
- `efontCN_*` 由 M5GFX 内置，无需外部字体文件；但**必须调用 setFont**，否则中文显示为空心方块。
- 已知渲染缺陷：`efontCN` 对「大」(U+5927)、「小」(U+5C0F) 会画成形近错字。规避：这两字用自定义点阵 `drawPixel` 直画，或从标题里去掉、改用 detail 面板显示。

### 5. 先编译一个最小 hello-world 验证环境

- 在写任何业务 UI 前，先写一个只做 `M5.begin()` + `M5.Display.print("测试中 123")` 的最小程序，编译烧录。
- 若中文和数字都能正常显示，说明环境 OK；若显示方块/空白，**停在这里修环境**，不要继续写功能。

## 环境就绪判定

只有以下全部为真，才允许开始功能开发：

- [ ] `pio --version` 正常
- [ ] 四个 lib_deps 目录都存在且 `pio run` 能完整编译通过
- [ ] hello-world 实测中文+数字正常显示
- [ ] 设备串口存在（macOS 通常 `/dev/cu.usbmodem*`，见 build-flash.md）

## 阅读顺序建议

为节省 token，不要一上来读全部源码。按需加载：

- 开始环境准备 → 本文档 + `preflight.sh`
- 写 UI / 页面 → `hardware-and-ui.md`
- 配网 / 二维码 → `hardware-and-ui.md` 的配网章节
- 接 AI / 语音 → `ai-and-config.md`
- 编译烧录发布 → `build-and-flash.md`

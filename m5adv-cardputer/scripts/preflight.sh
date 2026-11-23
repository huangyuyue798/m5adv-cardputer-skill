#!/usr/bin/env bash
# M5ADV / Cardputer ADV 固件开发依赖预检
# 用法: bash preflight.sh <项目目录>
# 用途: 在写任何功能代码之前，确认工具链与依赖完整，避免"干跑出半成品"。

set -u
PROJ="${1:-.}"
if [ ! -d "$PROJ" ]; then
  echo "[FAIL] 项目目录不存在: $PROJ"; exit 1
fi
cd "$PROJ" || exit 1

PASS=0; FAIL=0
ok(){ echo "  [OK]   $1"; PASS=$((PASS+1)); }
no(){ echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
info(){ echo "  [INFO] $1"; }

echo "=== M5ADV 依赖预检: $(pwd) ==="

# 1. PlatformIO 虚拟环境
VENV=""
for cand in ../.pio-venv ../../.pio-venv .pio-venv "$HOME/WorkBuddy"/*/.pio-venv; do
  if [ -x "$cand/bin/pio" ]; then VENV="$cand/bin"; break; fi
done
if [ -n "$VENV" ]; then
  if "$VENV/pio" --version >/dev/null 2>&1; then
    ok "PlatformIO: $($VENV/pio --version 2>&1 | head -1)"
  else
    no "PlatformIO 存在但无法运行 ($VENV/pio)"
  fi
else
  no "未找到 .pio-venv/bin/pio（先在 workspace 建 venv 并 pip install platformio）"
fi

# 2. platformio.ini 关键配置
if [ -f platformio.ini ]; then
  ok "platformio.ini 存在"
  grep -q "espressif32@6.7.0" platformio.ini && ok "platform 锁定 espressif32@6.7.0" || no "platform 未锁定 6.7.0"
  grep -q "esp32-s3-devkitc-1" platformio.ini && ok "board=esp32-s3-devkitc-1 (Cardputer ADV)" || no "board 不是 esp32-s3-devkitc-1"
  grep -q "M5Unified" platformio.ini && ok "lib_deps 含 M5Unified" || no "lib_deps 缺 M5Unified"
  grep -q "M5GFX" platformio.ini && ok "lib_deps 含 M5GFX" || no "lib_deps 缺 M5GFX"
  grep -q "M5Cardputer" platformio.ini && ok "lib_deps 含 M5Cardputer" || no "lib_deps 缺 M5Cardputer"
  grep -q "ArduinoJson" platformio.ini && ok "lib_deps 含 ArduinoJson" || no "lib_deps 缺 ArduinoJson"
else
  no "platformio.ini 缺失"
fi

# 3. 依赖库是否实际下载
LIBDIR=".pio/libdeps/m5stack-cardputer"
if [ -d "$LIBDIR" ]; then
  for lib in M5Unified M5GFX M5Cardputer ArduinoJson; do
    if [ -d "$LIBDIR/$lib" ] && [ -n "$(ls -A "$LIBDIR/$lib" 2>/dev/null)" ]; then
      ok "库已下载: $lib"
    else
      no "库缺失或内容不全: $lib（删该目录后重新 pio run 完整下载）"
    fi
  done
else
  no "未找到 $LIBDIR（先运行一次 pio run 触发依赖下载）"
fi

# 4. 中文字体调用（源码层面）
if grep -Rqs "fonts::efontCN" src/ 2>/dev/null; then
  ok "源码使用 efontCN 中文字体"
  info "确认每个 setCursor/print 前都 setFont(&fonts::efontCN_12/14/16)"
else
  no "源码未发现 efontCN 调用——中文会显示成方块！"
fi

# 5. 大缓冲是否误用栈（静态检查常见模式，仅提示）
if grep -Rqs "uint8_t g_.*\[" src/ 2>/dev/null; then
  info "检测到全局缓冲，确认 QR/音频/JSON 大对象均为 static/全局（无 PSRAM，栈仅 8KB）"
fi

# 6. 设备串口
PORT=$(ls /dev/cu.usbmodem* 2>/dev/null | head -1)
if [ -n "$PORT" ]; then ok "设备串口: $PORT"; else info "未检测到设备串口（烧录时确认设备已连接）"; fi

echo ""
echo "=== 结果: $PASS 通过, $FAIL 失败 ==="
if [ "$FAIL" -gt 0 ]; then
  echo "[STOP] 预检未通过。先修复所有 FAIL 项，再开始写功能代码。"
  exit 1
else
  echo "[GO] 环境就绪。建议先编译烧录一个 hello-world（中文+数字）实测显示，再做业务 UI。"
  exit 0
fi

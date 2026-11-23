---
name: m5adv-cardputer
version: 1.4.0
display_name: M5ADV Cardputer 中文固件开发护栏
display_name_en: M5ADV Cardputer Chinese Firmware Guardrails
description: "M5Stack Cardputer ADV / Cardputer（ESP32-S3，8MB Flash，无 PSRAM）通用固件开发护栏。当在该硬件上用 PlatformIO/Arduino 做固件（任何 UI、仪表盘、配网、AI 接入、中文显示、二维码、按键交互、传感器等）时使用，尤其适合刚接触该硬件、用 AI coding 从零搭项目的新手。提供依赖完整性预检、中文/颜色/栈/UI/配网/AI 的通用踩坑规范与编译烧录流程，避免做出中文显示不了、无图形化、二维码空白、页面错位的半成品，并节省试错 token。与具体业务无关，适用于所有 Cardputer 项目。固件已经通过人工审查。"
description_zh: "面向 M5Stack Cardputer ADV / Cardputer（ESP32-S3，无 PSRAM）所有固件的通用开发护栏，尤其适合刚接触该硬件、用 AI coding 从零搭项目的新手。做项目前先跑依赖完整性预检，再按规范实现中文显示、图形化界面、配网二维码与 AI 接入，规避中文方块、绿屏、二维码空白、页面错位、按键失灵、栈溢出等硬件层面常见失误，减少试错与 token 消耗。不绑定任何具体业务项目。固件已经通过人工审查。"
description_en: "General development guardrails for any M5Stack Cardputer ADV / Cardputer (ESP32-S3, no PSRAM) firmware, designed for beginners new to the hardware who build projects with AI coding. Runs a dependency preflight check before coding, then applies proven hardware-level conventions for Chinese fonts, graphical UI, WiFi provisioning QR codes, and AI integration, avoiding common failures such as tofu characters, green screens, blank QR codes, misaligned layouts, unresponsive keys, and stack overflows while saving trial-and-error tokens. Business-agnostic, applies to all Cardputer projects. The firmware has passed manual review."
agent_created: true
---

# M5ADV Cardputer 中文固件开发护栏

## 用途

把在 Cardputer ADV 上从零做固件时踩过的**硬件层面通用坑**固化成护栏：**先确认依赖完整，再写代码**；**按规范处理中文、颜色、内存、UI、配网、AI**，避免反复试错浪费 token。

**本 skill 与具体业务无关**——无论做工具、仪表盘、游戏、AI 终端还是其他任何应用，只要跑在 Cardputer ADV / Cardputer（ESP32-S3、8MB Flash、无 PSRAM）上都适用。业务算法、数据、页面内容由项目自己决定。

## 何时使用

- 用户要在 M5Stack Cardputer ADV / Cardputer 上开发或修复 PlatformIO/Arduino 固件。
- 出现中文方块/数字不显示、界面简陋、二维码空白、页面错位、AI 请求失败、按键失灵、黑屏重启等症状。
- 用户要新增图形化页面、配网、AI 接入、设置项，或要从零搭一个 Cardputer 项目。

## 核心原则（先看这里，能避免绝大多数事故）

1. **依赖预检优先**：写任何功能代码前，先跑 `bash scripts/preflight.sh <项目目录>`。预检不过就先修环境，绝不"干跑"。没有确认工具链就写功能，是做出"中文数字都显示不出来"半成品的头号原因。
2. **颜色一律 16 位 RGB565**：写 24 位 `0xRRGGBB` 会被静默截断（曾导致整屏变绿）。
3. **中文必须显式 setFont(&fonts::efontCN_12/14/16)**：默认字体显示中文是方块。
4. **大对象一律 static/全局或堆分配**：无 PSRAM、主循环栈仅 8KB。QR 编码缓冲、音频缓冲、JSON 文档放栈上必溢出（二维码空白、黑屏重启多因于此）。
5. **用图形化界面，不做纯文字列表**：圆角卡片 + 自绘几何图标 + 底部按键提示条，善用配色与留白。
6. **接 AI 要处理三个通用坑**：chunked 分块解码、thinking 模式正文分离、JSON 解析缓冲。详见 `ai-and-config.md`。
7. **按键用按下沿+等松键**，不用有状态的 `isChange()`；自定义等待循环返回前也要等松键，否则一次按键连跳两页；返回操作逐级回退，不直接跳顶层。
8. **UI 无闪烁靠"持久框架 + 局部重绘 + 单次事务提交"**：背景和上下块画一次常驻，绘制只擦变化区，一个批次只 `endWrite()` 一次。详见 `hardware-and-ui.md` 的 UI 无闪烁节。
9. **先定主题再写 UI**：新项目/大改版先出主题方案，用 Python 生成 240×135 HTML 模拟页让用户确认风格，不满意就改、直到点头；确认后把配色/字号/布局锁成固件常量，后续所有页面照此实现，不再随意改风格。详见 `hardware-and-ui.md` 的"UI 开发第一步"节。
10. **电池设备做省电四件套**：对时后关 WiFi + 联网入口按需重连（收益最大）、空闲 1 分钟降到 3%（1% 不显示）、CPU 降频做成可开关供实测、电池图标用主题色统一。充电无需写驱动（硬件充电 IC），充不进电先查侧面开关是否 ON。详见 `hardware-and-ui.md` 的"省电"节。

## 工作流程

### 第 0 步：依赖预检（强制）
```bash
bash scripts/preflight.sh <项目目录>
```
逐项修复所有 FAIL。确认 `pio --version` 正常、lib_deps 完整下载、源码用了 efontCN。
完整检查项与修复方法见 `references/preflight.md`。预检通过后，先编译烧录一个最小 hello-world（`M5.begin()` + 中文数字打印）实测显示正常，再进入功能开发。

### 第 1 步：按规范实现功能
按需加载参考文档（不要一次读全部，节省 token）：

- **UI / 页面 / 按键 / 中文 / 颜色 / 二维码 / 配网 / 内存** → 读 `references/hardware-and-ui.md`
- **AI 接入 / HTTP 请求 / JSON 解析 / 语音识别 / 配置持久化** → 读 `references/ai-and-config.md`
- **编译 / 合并镜像 / 烧录 / M5Burner 发布** → 读 `references/build-and-flash.md`

关键踩坑速查：

| 症状 | 根因 | 修复 |
|---|---|---|
| 中文方块、数字不显示 | 未 setFont / 依赖不全 | efontCN + 预检依赖 |
| 整屏变绿 | 用了 24 位颜色 | 改 16 位 RGB565 |
| 二维码空白 | 大对象放栈上溢出 | QR 相关对象改 static |
| 按键按一次后失灵 | 用了 isChange 有状态 API | 按下沿+等松键 |
| 一次 OK 连跳两页 | 自定义等待循环返回前没等松键 | 返回前等 isPressed()==false |
| 页面闪烁/切页闪空框 | 每页 fillScreen 整屏重绘 / 一批次多次 endWrite | 持久框架+局部重绘+单次提交 |
| 文本逐行冒出 | clearAndTitle 已 endWrite 后又 print 正文 | 正文并进同一事务 |
| 列表往下选高亮出屏 | 一屏行数写死超过像素可容 | 按像素算行数+滚动窗口 |
| 断电后时间重置/回编译日期 | 无 RTC 电池且 NVS 没存时间 | NVS 存 epoch + 开机恢复 + 周期保存 |
| 待机耗电快 | 对时后 WiFi 一直挂着 | 对时后关射频 + 联网入口按需重连 |
| 空闲降亮度像黑屏 | 目标亮度设到 1% 不显示 | 改成 3%（约 8/255）|
| 充不进电 | 侧面电源开关 OFF / 快充头不兼容 | 开关拨 ON + 换 5V 普通充电器数据线；无需写电源驱动 |
| 页面错位/信息被遮挡 | 行距超可用区 | 压缩行距、实机拍照核对 |
| AI 报非JSON `391\r\n` | chunked 未解码 | 加 decodeChunked |
| AI 报仅思考/正文空 | thinking 模式 + filter 吞正文 | 关 thinking + 完整解析不用 filter |
| AI 报 401 | Key 与服务商不匹配 | 换对应服务商 Key |
| 黑屏重启 | 栈溢出 / 递归调用 | 大缓冲静态化 / 避免递归 |

### 第 2 步：编译烧录验证
按 `references/build-and-flash.md`：
```
pio run → merge_bin → write_flash 0x0 firmware/merged_firmware.bin
```
成功标志 `Hash of data verified.`。建议维护一个固件版本号并在界面显示，便于确认烧的是哪一版。

## 参考文档索引
- `references/preflight.md` — 依赖完整性检查、中文支持、环境就绪判定
- `references/hardware-and-ui.md` — 硬件特性、颜色、按键、**先定主题（Python 模拟页确认风格）**、**UI 无闪烁（持久框架/局部重绘/事务）**、**省电四件套（关 WiFi/熄屏/降频/电池图标与充电）**、时间持久化、图形化 UI、配网二维码、内存规则
- `references/ai-and-config.md` — HTTP 通用坑、JSON 解析、语音识别、配置持久化、错误对照
- `references/build-and-flash.md` — 编译合并烧录、M5Burner 发布、危险操作提醒
- `scripts/preflight.sh` — 一键依赖预检脚本

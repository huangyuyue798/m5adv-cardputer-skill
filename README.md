# M5ADV Cardputer 中文固件开发护栏 Skill

> 固件已通过人工审查。与具体业务无关，适用于所有基于 M5Stack Cardputer ADV / Cardputer（ESP32-S3）的固件开发项目。

**一句话**：这是一套给 AI 编码助手用的「踩坑护栏」——把在 Cardputer ADV 上从零做固件时反复踩过的硬件层面坑固化成规则，让 AI 第一次就写对，避免做出「中文显示成方块、界面简陋、二维码空白、页面闪烁」的半成品。

尤其适合**刚接触这块板子、用 AI coding 从零搭项目的新手**：你不用事先知道「M5GFX 颜色必须 16 位」「无 PSRAM 大缓冲必须 static」这些坑，skill 会替你盯住。

---

## 一、它解决什么问题

用 AI 做 Cardputer 固件时，最常见的失败不是算法写错，而是**硬件层面的坑**——这些坑 AI 不知道，会反复犯：

- 中文显示成方块、数字不显示（没设中文字体 / 依赖没装全）
- 整屏变绿或颜色错乱（写了 24 位颜色，M5GFX 要 16 位 RGB565）
- 二维码空白、黑屏重启（无 PSRAM，大缓冲放栈上溢出）
- 切页闪烁、文字逐行冒出（整屏重绘 / 一个批次多次提交）
- 按键失灵、一次 OK 连跳两页（用了有状态 API / 没等松键）
- AI 请求失败（chunked 没解码、thinking 模式正文被吞、JSON 缓冲不够）
- 断电后时间回编译日期（无 RTC 电池却没存 NVS）

这套 skill 把这些坑全部写成**强制规则 + 速查表 + 预检脚本**，让 AI 在写代码前先躲开它们。

---

## 二、核心护栏（10 条）

1. **依赖预检优先**——写任何功能代码前先跑 `bash scripts/preflight.sh <项目目录>`，预检不过先修环境，绝不「干跑」。这是做出「中文数字都显示不出来」半成品的头号原因。
2. **颜色一律 16 位 RGB565**——写 24 位 `0xRRGGBB` 会被静默截断（曾导致整屏变绿）。
3. **中文必须显式 setFont**——用 `fonts::efontCN_12/14/16`，默认字体显示中文是方块。
4. **大对象一律 static/全局或堆分配**——无 PSRAM、主循环栈仅 8KB，QR 缓冲 / 音频缓冲 / JSON 文档放栈上必溢出。
5. **用图形化界面，不做纯文字列表**——圆角卡片 + 自绘几何图标 + 底部按键提示条，善用配色与留白。
6. **接 AI 要处理三个通用坑**——chunked 分块解码、thinking 模式正文分离、JSON 解析缓冲。
7. **按键用按下沿 + 等松键**——不用有状态的 `isChange()`；等待循环返回前也等松键，否则一次按键连跳两页；返回逐级回退不跳顶层。
8. **UI 无闪烁靠「持久框架 + 局部重绘 + 单次事务提交」**——背景和上下块画一次常驻，只擦变化区，一个批次只 `endWrite()` 一次。
9. **先定主题再写 UI**——用 Python 生成 240×135 HTML 模拟页让用户确认风格，满意后把配色/字号/布局锁成固件常量，后续不再随意改风格。
10. **电池设备做省电四件套**——对时后关 WiFi + 按需重连、空闲 1 分钟降到 3%（1% 不显示）、CPU 降频做成可开关、电池图标主题色统一。充电由硬件 IC 完成无需写驱动，充不进电先查侧边开关是否 ON。

---

## 三、工作流程

### 第 0 步：依赖预检（强制）
```bash
bash scripts/preflight.sh <项目目录>
```
逐项修复所有 FAIL，确认 `pio --version` 正常、lib_deps 完整下载、源码用了 efontCN。预检通过后先编译烧录一个最小 hello-world（中文 + 数字打印）实测显示正常，再进入功能开发。

### 第 1 步：按规范实现功能
按需加载参考文档（不一次读全部，节省 token）：

| 要做的事 | 读哪份文档 |
|---|---|
| UI / 页面 / 按键 / 中文 / 颜色 / 二维码 / 配网 / 内存 | `references/hardware-and-ui.md` |
| AI 接入 / HTTP / JSON / 配置持久化 | `references/ai-and-config.md` |
| 编译 / 合并镜像 / 烧录 / M5Burner 发布 | `references/build-and-flash.md` |

### 第 2 步：编译烧录验证
```
pio run → merge_bin → write_flash 0x0 firmware/merged_firmware.bin
```
成功标志是 `Hash of data verified.`。建议维护固件版本号并在界面显示，方便确认烧的是哪一版。

---

## 四、症状 → 根因 → 修复速查表

skill 内置一份高频故障对照，AI 遇到问题时直接查表：

| 症状 | 根因 | 修复 |
|---|---|---|
| 中文方块、数字不显示 | 未 setFont / 依赖不全 | efontCN + 预检依赖 |
| 整屏变绿 | 用了 24 位颜色 | 改 16 位 RGB565 |
| 二维码空白 | 大对象放栈上溢出 | QR 相关对象改 static |
| 按键按一次后失灵 | 用了 isChange 有状态 API | 按下沿 + 等松键 |
| 一次 OK 连跳两页 | 等待循环返回前没等松键 | 返回前等松键 |
| 页面闪烁 / 切页闪空框 | 整屏重绘 / 多次 endWrite | 持久框架 + 局部重绘 + 单次提交 |
| 文本逐行冒出 | 正文在 endWrite 之后 print | 正文并进同一事务 |
| 断电后时间重置 | NVS 没存时间 | NVS 存 epoch + 开机恢复 |
| 待机耗电快 | 对时后 WiFi 一直挂着 | 关射频 + 按需重连 |
| 充不进电 | 侧面开关 OFF / 快充头不兼容 | 开关拨 ON + 换 5V 普通充电器 |
| AI 报 `391\r\n` | chunked 未解码 | 加 decodeChunked |
| AI 报仅思考 / 正文空 | thinking 模式 + filter 吞正文 | 关 thinking + 完整解析不用 filter |
| 黑屏重启 | 栈溢出 / 递归调用 | 大缓冲静态化 / 避免递归 |

---

## 五、目录结构

```
m5adv-cardputer/
├── SKILL.md                       # 入口：核心原则、工作流、故障速查
├── references/
│   ├── hardware-and-ui.md         # 硬件特性、颜色、按键、先定主题、UI 无闪烁、省电、时间持久化、配网二维码、内存规则
│   ├── ai-and-config.md           # HTTP 通用坑、JSON 解析、AI 三模式、配置持久化
│   ├── build-and-flash.md         # PlatformIO 编译、合并镜像、烧录、M5Burner 发布
│   └── preflight.md               # 依赖完整性预检清单
└── scripts/
    └── preflight.sh               # 一键预检脚本
```

---

## 六、安装

下载 `m5adv-cardputer.zip`，解压到 WorkBuddy 的 skills 目录：

```
~/.workbuddy/skills/m5adv-cardputer/
```

之后在 WorkBuddy 里提到 Cardputer / ESP32-S3 相关开发时，skill 会自动加载生效。也可把 `m5adv-cardputer/` 整个目录复制到项目的 `.workbuddy/skills/` 做项目级共享。

---

## 七、配套固件项目

这套护栏沉淀自「玄机OS」固件项目（M5ADV 玄机固件）——7 种离线占卜玩法、三层解读、AI 三模式、省电续航，历经 56 个版本迭代与人工审查。

固件二进制发布在：https://github.com/huangyuyue798/m5adv-fortune

---

## 许可与声明

仅供学习与个人项目参考。skill 内容是通用开发经验总结，不绑定任何具体业务。固件功能涉及的传统玄学内容属文化娱乐，不构成现实决策依据。

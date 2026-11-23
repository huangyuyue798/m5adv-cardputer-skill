# M5ADV Cardputer 中文固件开发护栏 Skill

> 固件已通过人工审查。与具体业务无关，适用于所有基于 M5Stack Cardputer ADV / Cardputer（ESP32-S3）的固件开发项目，尤其适合用 AI coding 从零搭项目的新手。

一套给 AI 编码助手用的开发护栏（Skill），把 Cardputer 固件开发中反复踩过的坑固化成规则：依赖完整性预检、中文字体、颜色格式、无 PSRAM 内存约束、UI 无闪烁、省电方案、配网二维码等。

## 安装

下载 `m5adv-cardputer.zip`，解压到 WorkBuddy 的 skills 目录：

```
~/.workbuddy/skills/m5adv-cardputer/
```

目录结构：

```
m5adv-cardputer/
├── SKILL.md                       # 入口：核心原则、工作流、故障速查
├── references/
│   ├── hardware-and-ui.md         # 硬件特性、颜色、按键、UI 无闪烁、时间持久化、省电、配网二维码、内存规则
│   ├── ai-and-config.md           # AI 三模式、NVS 配置、云端 API、离线 WebLLM
│   ├── build-and-flash.md         # PlatformIO 编译、合并镜像、烧录
│   └── preflight.md               # 依赖完整性预检清单
└── scripts/
    └── preflight.sh               # 一键预检脚本
```

## 核心护栏（摘要）

1. **编译前先做依赖预检**：库版本、字体、分区表，缺一个就编译失败。
2. **先定主题再写 UI**：用 Python 生成 240×135 HTML 模拟页让用户确认风格，锁成配色/字号常量。
3. **UI 无闪烁**：持久框架 + 局部重绘，背景和上下块只画一次，只刷新变化区，切页一次上屏。
4. **颜色用 RGB565**：M5GFX 是 16 位色，写 24 位 0xRRGGBB 会静默截断变错色。
5. **无 PSRAM 的内存纪律**：主循环栈仅 8KB，大缓冲必须 static/全局。
6. **省电四件套**：对时后关 WiFi + 按需重连、空闲 1 分钟熄屏至 3%、CPU 降频可开关、电池图标。
7. **时间持久化**：无 RTC 电池要 NVS 存 epoch + 开机恢复，避免断电回编译日期。
8. **充电误区**：充电由硬件 IC 完成无需写驱动，侧边开关拨到 ON；固件读不到充电状态。

完整规则见 `SKILL.md` 与 `references/`。

## 配套固件项目

本护栏沉淀自「玄机OS」固件项目（M5ADV 玄机固件），固件二进制发布在：
https://github.com/huangyuyue798/m5adv-fortune

## 许可与声明

仅供学习与个人项目参考。固件功能涉及的传统玄学内容属文化娱乐，不构成现实决策依据。

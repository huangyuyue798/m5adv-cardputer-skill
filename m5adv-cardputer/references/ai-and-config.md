# AI 接入与配置规范

主流大模型服务大多提供 OpenAI 兼容的 Chat Completions 接口，在 Cardputer 上接入的坑是通用的。本节把踩过的坑一次讲清，避免重复排查。具体服务商/模型按项目需要选择即可。

## 配置结构（config.h/.cpp）

- NVS `Preferences` 持久化：WiFi SSID/密码、API Base URL、API Key、模型名、AI 开关、设备名、亮度、音量、ASR URL/模型。
- 配置版本迁移：用 `cfgVer` 字段。旧配置缺新字段时用 `prefs.isKey()` 判断并补默认值；服务商/模型变更在迁移分支里 `configApplyPreset()`。每次加字段记得 bump `cfgVer`。
- 服务商预设表 `LLM_PRESETS[]`，每项含：name / baseUrl / defaultModel / asrUrl / asrModel。切换预设时这些字段一起填好。

## 服务商与模型（示例，按项目选择）

- 只要符合 OpenAI Chat Completions 协议的服务都可用。常见示例：混元 `https://api.hunyuan.cloud.tencent.com/v1`、DeepSeek `https://api.deepseek.com/v1`、OpenAI `https://api.openai.com/v1`、通义/Kimi/智谱等兼容端点。
- 模型名会随服务商更新，接入前核对官方文档当前名称（如 DeepSeek 现行为 `deepseek-flash`，旧的 `deepseek-chat` 已归档但兼容）。
- **Key 不能混用**：换成另一家服务商必须换对应平台的 API Key，否则 HTTP 401。
- 401/403/429/404 要给中文短提示（240px 屏放不下长串英文 JSON）：401「API Key 错误」、429「请求过多/余额不足」、404「端点或模型名错误」。

## AI HTTP 请求：必须处理的三个坑

### 坑 1：响应是 chunked 分块编码

- 症状：屏幕报 `非JSON r=9251:391`，原始响应开头是 `391\r\n{"id":...`——`391` 是十六进制块长度。
- 根因：`getStreamPtr()` 裸流读到的是未解码分块流，直接 JSON 解析必失败。
- 修复：实现 `decodeChunked()`，把 `长度\r\n数据\r\n...0\r\n\r\n` 还原成完整 JSON 到第二个静态缓冲；仅当解码结果更短且以 `{` 开头时替换。
- 注：`getString()` 内部会解码 chunked，但在此设备上偶发读空 body（见坑 3），所以最终方案是流式读取 + 手动解码。

### 坑 2：DeepSeek thinking 模式把正文塞进 reasoning_content

- 症状：JSON 解析成功但 `content` 为空，报「响应无正文(仅思考)」，思考响应时间过长。
- 根因：DeepSeek V4 默认开 thinking（effort=high），文字写进 `reasoning_content`。
- 修复：请求时对 DeepSeek 端点加官方字段 `thinking:{"type":"disabled"}`，让 `content` 正常填正文。

### 坑 3：JSON filter 在 ESP32 上吞掉正文

- 症状：原始截图里 `content` 明明有正文，却判成空。
- 根因：`DeserializationOption::Filter` 在此环境把 content 也滤掉了；小容量 filter（96B）在 32 位上也存不下嵌套路径。
- 修复：**移除 filter，改完整解析**（`DynamicJsonDocument(16384)` 全局/堆分配），直接取 `choices[0].message.content`。不要再引入 filter。

## 推荐解析骨架（已验证可用）

```cpp
// 请求
doc["stream"] = false;
if (strstr(g_cfg.baseUrl, "deepseek")) {
    JsonObject th = doc.createNestedObject("thinking");
    th["type"] = "disabled";
}
// 响应：流式读到 16KB 全局静态缓冲 g_respBuf（25s 超时）→ decodeChunked → 完整解析
DynamicJsonDocument rdoc(16384);              // 堆分配，勿放栈
deserializeJson(rdoc, decodedBuf);
const char* content = rdoc["choices"][0]["message"]["content"];
```

- 错误信息带诊断：如 `非JSON len=N`、`空响应 c=%d p=%d r=%d`（HTTP 码/请求长度/实读字节），便于一次定位。

## 语音识别（麦克风输入）：默认不建议做，优先考虑内存容量

- **先说结论**：M5ADV 无 PSRAM、RAM 很小，设备端语音识别体验差（录音缓冲吃内存、压缩 HTTPS/TLS 后余量紧张，云端 ASR 依赖网络、本地模型又放不下）。**新项目默认不要做设备端语音**，优先用文字输入。
- 若项目确有必要做，开始前必须先如实告诉用户局限（内存小导致体验不好、可能识别慢/不准），并给出几套不同的语音方案让其选择确认，别直接埋头做。
- 以下是确实要做时的实现细节，供参考：
- 录音：16kHz 单声道 16-bit PCM，最长 4 秒；`M5.Mic` 与 `M5.Speaker` 共用 I2S，录音前 `Speaker.end()`、结束 `begin()`。
- 实时音量柱反馈；`OK`/`Tab`/`ESC` 结束录音。
- WAV 拼 multipart POST 到 ASR 端点：
  - **DeepSeek ASR**：`POST https://api.deepseek.com/v1/tools/asr`，只传 `file` 字段、**不要 model 字段**，支持 16k/16-bit WAV。
  - OpenAI/通义/Kimi/智谱：标准 `/audio/transcriptions`，模型 `whisper-1`，需传 model 字段。
- ASR URL 若是完整端点（含 `/tools/asr`、`/audio/transcriptions`）直接用，否则按 Base URL 拼接。
- multipart 的收尾 boundary 必须用同一个边界串拼，不要手写不同横线数导致解析失败。

## 调试手段（串口不可用时的替代）

- 此板 `Serial` 走硬件 UART0（GPIO43/44），**不走 USB CDC**，电脑 USB 口读不到 `Serial.printf`。
- 需要看服务端原始响应时，用**屏幕诊断页**显示配置值 + 响应摘要；诊断页必须"任意键返回、绝不递归调用 interpretAI"（曾因递归栈溢出黑屏重启）。

## 常见错误信息对照

| 屏幕提示          | 含义          | 处理                         |
| ------------- | ----------- | -------------------------- |
| `HTTP 401`    | Key 与服务商不匹配 | 换对应服务商的 Key                |
| `响应过长: 内存不足`  | JSON 文档容量不够 | 加大文档/修复 chunked 解码         |
| `非JSON len=N` | 拿到数据但格式不对   | 看 len 与前缀，多半是 chunked 未解码  |
| `空响应 r=0`     | 一个字节都没读到    | 服务端/网络问题，或 getString 读空    |
| `响应无正文(仅思考)`  | content 空   | 关 thinking / 完整解析不要 filter |

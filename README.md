# 识图 / Vision / OCR

看图：读取图片信息、用系统 OCR 提取文字；如果配了视觉模型（GGUF + mmproj）就直接描述画面。

Image understanding: read image info, extract text with system OCR, or describe the picture when a vision GGUF + mmproj is configured.

> Local-Harness（Godot 版）的独立插件。不随主程序发布，由主程序
> 「设置 → 插件管理」从 GitHub 下载并自动部署到 `user://plugins/vision/`。

## 安装

1. 打开 Local-Harness → 设置 → 插件管理 → 刷新列表
2. 找到「识图」点「安装」
3. 装好后在侧栏底部点同名按钮，里面是这个插件自己的设置页

手动安装：把本仓库下载解压到 `%LOCALAPPDATA%\Godot\app_userdata\Local-Harness\plugins\vision\`

## 工具

- `vision_info` —— 读取图片的尺寸、格式、文件大小。（只读）
  - `image`: string，图片路径
- `vision_ocr` —— 用 Windows 自带 OCR 识别图片里的文字（离线，支持中英文，取决于系统装了哪些语言包）。（只读）
  - `image`: string，图片路径
  - `lang`: string，可选，例如 zh-Hans / en-US；不填用系统默认
- `vision_describe` —— 描述画面内容：需要视觉模型（设置里填 vision_model 和 vision_mmproj），没配就退回 OCR。（只读）
  - `image`: string，图片路径
  - `question`: string，可选，想重点关注什么

## 命令

（没有命令）

## 设置项

- **OCR 语言**（`ocr_lang`，默认 `zh-Hans`）简体中文 zh-Hans，英文 en-US

## 权限

每个工具都能在插件设置页里单独开关。关掉之后它不会出现在模型的工具清单里，
就算模型硬要调用也会被主程序拒绝。协议里用 `level` 标了风险等级：

- `read` 只读：不会改动任何东西
- `act` 会产生操作：会读写文件、联网或占用设备
- `danger` 高危：会操作你的系统

## 怎么用

装好后直接在对话里提需求，例如：“读取图片的尺寸、格式、文件大小。”

模型会输出一行 ```tool 协议块，宿主解析后执行，再把结果喂回模型。
也可以直接用斜杠命令，不经过模型。

## 许可

GPL-3.0（与主程序一致）。完整协议文本见仓库根目录的 [LICENSE](LICENSE)。

---

# Vision / OCR

Image understanding: read image info, extract text with system OCR, or describe the picture when a vision GGUF + mmproj is configured.

> An independent plugin for **Local-Harness (Godot edition)**. It is not bundled with the
> app; the app downloads it from this repository into `user://plugins/vision/` and hot-loads it.

## Install

1. Local-Harness → Settings → Plugins → Refresh
2. Find "Vision / OCR" and click Install
3. Open it from the button at the bottom of the sidebar for its own settings page

Manual: unzip this repo into `%LOCALAPPDATA%\Godot\app_userdata\Local-Harness\plugins\vision\`

## Tools

- `vision_info` — 读取图片的尺寸、格式、文件大小。 (read-only)
  - `image`: string，图片路径
- `vision_ocr` — 用 Windows 自带 OCR 识别图片里的文字（离线，支持中英文，取决于系统装了哪些语言包）。 (read-only)
  - `image`: string，图片路径
  - `lang`: string，可选，例如 zh-Hans / en-US；不填用系统默认
- `vision_describe` — 描述画面内容：需要视觉模型（设置里填 vision_model 和 vision_mmproj），没配就退回 OCR。 (read-only)
  - `image`: string，图片路径
  - `question`: string，可选，想重点关注什么

## Commands

(no commands)

## Settings

- **OCR 语言** (`ocr_lang`, default `zh-Hans`) 简体中文 zh-Hans，英文 en-US

## Permissions

Every tool can be toggled individually on the plugin settings page. A disabled tool is
removed from the model's tool list and rejected by the host even if the model still calls it.
`level` in the manifest marks the risk:

- `read` — no side effects
- `act` — reads/writes, network or devices
- `danger` — controls your system

## Usage

Just ask in the chat, e.g. “读取图片的尺寸、格式、文件大小。”

The model emits a ```tool block, the host executes it and feeds the result back.
You can also use the slash commands above, which skip the model entirely.

## License

GPL-3.0 (same as the host app). Full text: [LICENSE](LICENSE).

# 识图 / Vision / OCR

看图：读取图片信息、用系统 OCR 提取文字；如果配了视觉模型（GGUF + mmproj）就直接描述画面。

Image understanding: read image info, extract text with system OCR, or describe the picture when a vision GGUF + mmproj is configured.

Local-Harness（Godot 版）的独立插件。**不随主程序发布**，由主程序「设置 → 插件管理」从 GitHub 下载并自动部署到 `user://plugins/vision/`。

## 工具

- `vision_info` —— 读取图片的尺寸、格式、文件大小。
  - `image`: string，图片路径
- `vision_ocr` —— 用 Windows 自带 OCR 识别图片里的文字（离线，支持中英文，取决于系统装了哪些语言包）。
  - `image`: string，图片路径
  - `lang`: string，可选，例如 zh-Hans / en-US；不填用系统默认
- `vision_describe` —— 描述画面内容：需要视觉模型（设置里填 vision_model 和 vision_mmproj），没配就退回 OCR。
  - `image`: string，图片路径
  - `question`: string，可选，想重点关注什么

## 安装

1. Local-Harness → 设置 → 插件管理 → 刷新列表
2. 找到「识图」点安装
3. 装完直接在对话里让模型调用（插件会出现在系统提示的工具清单里）

手动安装：把仓库解压到 `%LOCALAPPDATA%\Godot\app_userdata\Local-Harness\plugins\vision\`。

## 结构

```
manifest.json   清单：id / 版本 / 工具定义
main.gd         extends Node，实现 run(tool, args) -> {ok, output}
```

## 许可

GPL-3.0（与主程序一致）。

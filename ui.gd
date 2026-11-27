extends VBoxContainer
## 本插件的设置界面 —— 由插件自己提供，主程序只负责挂载。
## 想改这个插件在这里长什么样、有哪些开关，改这个文件即可。

func build(plugin_id: String) -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(PluginUI.title("识图"))
	add_child(PluginUI.hint("读图片：能识别图里的文字（离线 OCR），配了视觉模型还能描述画面。"))
	add_child(PluginUI.section("行为"))
	add_child(PluginUI.str_field(plugin_id, "ocr_lang", "OCR 语言", "zh-Hans",
		"简体中文 zh-Hans，英文 en-US"))
	add_child(PluginUI.section("能力开关"))
	add_child(PluginUI.hint("每一项都能单独关掉；关掉后模型看不到这个能力，也调用不了。"))
	for t in Plugins.tools_of(plugin_id):
		var tname := str(t.get("name", ""))
		var human := tname
		var desc := str(t.get("description", ""))
		if tname == "vision_info":
			human = "读取图片信息"
			desc = "只看尺寸/格式，不碰内容"
		if tname == "vision_ocr":
			human = "识别图中文字"
			desc = "把图片里的文字提取出来"
		if tname == "vision_describe":
			human = "描述画面"
			desc = "需要配视觉模型；没配会自动退回 OCR"
		add_child(PluginUI.perm_row(tname, human, desc, bool(t.get("dangerous", false))))
	add_child(PluginUI.readme_box(plugin_id))

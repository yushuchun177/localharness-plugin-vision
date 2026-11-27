extends VBoxContainer
## 识图 —— 这个页面是插件自己提供的界面。
## 界面全部由插件自己拼，主程序只提供积木。

func build(plugin_id: String) -> void:
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	add_child(PluginUI.section("认字设置"))
	add_child(PluginUI.choice_row(plugin_id, "ocr_lang", "识别哪种文字",
		[{"value": "zh-Hans", "label": "简体中文"},
		 {"value": "en-US", "label": "English"},
		 {"value": "zh-Hant", "label": "繁體中文"}],
		"zh-Hans", "系统没装对应语言包时会失败，换成中文一般都能用"))

	add_child(PluginUI.section("试一下"))
	var picked: Array = [""]
	add_child(PluginUI.file_pick_row("选一张图片读文字", "支持 png / jpg / bmp",
		PackedStringArray(["*.png,*.jpg,*.jpeg,*.bmp,*.webp ; 图片"]),
		func(p: String):
			picked[0] = p
			PluginPrefs.set_value(plugin_id, "last_image", p)))
	add_child(PluginUI.action_row("识别刚才选的图里的文字", "用的是系统自带 OCR，离线",
		"开始识别", func():
			var p: String = str(PluginPrefs.get_value(plugin_id, "last_image", ""))
			if p == "":
				return {"ok": false, "output": "先在上面选一张图片"}
			return Plugins.invoke("vision_ocr", {"image": p})))
	add_child(PluginUI.overview(plugin_id))
	add_child(PluginUI.permissions_section(plugin_id))
	add_child(PluginUI.doc_section(plugin_id))

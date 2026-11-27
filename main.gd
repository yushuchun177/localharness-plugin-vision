extends Node
## 识图插件 · local-harness
## 工具：vision_info / vision_ocr / vision_describe
##
## 三种能力，按"手上有什么"逐级降级：
##   1. vision_describe —— 配了视觉模型（GGUF + mmproj）就临时起个 llama-server 看图
##   2. vision_ocr      —— 没视觉模型也能用：Windows 自带 OCR，离线识别中英文
##   3. vision_info     —— 纯 Godot，读尺寸/格式/大小
##
## OCR 走 PowerShell + WinRT（Windows.Media.Ocr），结果写进临时文件再用 UTF-8 读回来，
## 避免 PowerShell 的控制台编码把中文弄坏。

const VISION_PORT := 18767
const VISION_START_TIMEOUT := 150.0


func _app() -> Node:
	var ml := Engine.get_main_loop()
	return ml.root.get_node_or_null("/root/App") if ml != null else null



func _pref(key: String, def_value):
	# 直接读设置文件：在后台线程里也能用（不能碰场景树）
	var f := FileAccess.open("user://plugin_settings.json", FileAccess.READ)
	if f == null:
		return def_value
	var obj = JSON.parse_string(f.get_as_text())
	if not (obj is Dictionary):
		return def_value
	var vals: Dictionary = obj.get("values", {})
	var mine: Dictionary = vals.get("vision", {})
	return mine.get(key, def_value)

func run(tool: String, args: Dictionary) -> Dictionary:
	match tool:
		"vision_info":
			return _info(args)
		"vision_ocr":
			return _ocr(args)
		"vision_describe":
			return _describe(args)
	return {"ok": false, "output": "未知工具：%s" % tool}


func _resolve(path: String) -> String:
	var p := path.strip_edges().trim_prefix("\"").trim_suffix("\"")
	if p.begins_with("user://") or p.begins_with("res://"):
		return ProjectSettings.globalize_path(p)
	return p


func _info(args: Dictionary) -> Dictionary:
	var path := _resolve(str(args.get("image", "")))
	if not FileAccess.file_exists(path):
		return {"ok": false, "output": "找不到图片：%s" % path}
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		return {"ok": false, "output": "不是能识别的图片格式：%s" % path}
	var f := FileAccess.open(path, FileAccess.READ)
	var size := f.get_length() if f else 0
	return {"ok": true, "output": "%s\n尺寸 %d×%d，格式 %s，%.0f KB" % [
		path, img.get_width(), img.get_height(), _fmt_name(img.get_format()), size / 1024.0]}


func _fmt_name(fmt: int) -> String:
	var names := {
		Image.FORMAT_RGBA8: "RGBA8", Image.FORMAT_RGB8: "RGB8",
		Image.FORMAT_L8: "L8", Image.FORMAT_RG8: "RG8",
	}
	return str(names.get(fmt, "format_%d" % fmt))


# ---------------------------------------------------------------- OCR
func _ocr(args: Dictionary) -> Dictionary:
	var path := _resolve(str(args.get("image", "")))
	if not FileAccess.file_exists(path):
		return {"ok": false, "output": "找不到图片：%s" % path}
	var lang := str(args.get("lang", "")).strip_edges()

	var out_file := OS.get_temp_dir().path_join("lh_ocr_%d.txt" % randi())
	var ps_file := OS.get_temp_dir().path_join("lh_ocr_%d.ps1" % randi())
	# Windows OCR 对小字识别很差，图太小就先放大两倍再识别
	var ocr_src := path
	var img := Image.new()
	if img.load(path) == OK and img.get_width() < 900:
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_BILINEAR)
		ocr_src = OS.get_temp_dir().path_join("lh_ocr_up_%d.png" % randi())
		img.save_png(ocr_src)
	var lang2: String = lang if lang != "" else str(_pref("ocr_lang", "zh-Hans"))
	var win_path := ocr_src.replace("/", "\\")
	var script := _ocr_script(win_path, lang2, out_file)
	var f := FileAccess.open(ps_file, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "output": "写临时脚本失败"}
	# PowerShell 5.1 会把无 BOM 的 .ps1 当 ANSI 读，反引号和引号会被弄坏；
	# 所以写成 UTF-16LE + BOM（和记事本"Unicode"一致），WinRT 桥接才能跑。
	f.store_buffer(PackedByteArray([0xFF, 0xFE]))
	f.store_buffer(script.to_utf16_buffer())
	f.close()

	var out: Array = []
	var code := OS.execute("powershell.exe", PackedStringArray([
		"-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", ps_file]), out, true)
	if code == 0:
		DirAccess.remove_absolute(ps_file)

	var text := ""
	if FileAccess.file_exists(out_file):
		var rf := FileAccess.open(out_file, FileAccess.READ)
		if rf:
			text = rf.get_as_text()
		DirAccess.remove_absolute(out_file)
	# 保留脚本路径方便排查（失败时提示里会带上）
	if code != 0 and text.strip_edges() == "":
		var msg := "OCR 失败（PowerShell 退出码 %d，脚本 %s）" % [code, ps_file]
		if out.size() > 0 and str(out[0]).strip_edges() != "":
			msg += "：" + str(out[0]).strip_edges().substr(0, 300)
		return {"ok": false, "output": msg}
	if text.strip_edges() == "":
		return {"ok": true, "output": "（这张图里没识别出文字）"}
	if text.begins_with("ERR:"):
		return {"ok": false, "output": "OCR 失败：" + text.substr(4).strip_edges()}
	return {"ok": true, "output": "OCR 结果：\n" + text.strip_edges()}


func _ocr_script(image: String, lang: String, out_file: String) -> String:
	# 注意：PowerShell 5.1 里 WinRT 的 await 桥接要逐个显式指定类型，
	# 包成泛型函数传 Type 容易在 MakeGenericMethod 处炸，这里全部内联。
	var lang_line := ""
	if lang != "":
		lang_line = """
[Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime] | Out-Null
$langObj = [Windows.Globalization.Language]::new('%s')
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($langObj)
if (-not $engine) { $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages() }
""" % lang.replace("'", "''")
	else:
		lang_line = "$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()\n"

	return """
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null

$op1 = [Windows.Storage.StorageFile]::GetFileFromPathAsync('IMAGE_PATH')
$t1 = $asTaskGeneric.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @($op1))
$t1.Wait(-1) | Out-Null
$file = $t1.Result

$op2 = $file.OpenAsync([Windows.Storage.FileAccessMode]::Read)
$t2 = $asTaskGeneric.MakeGenericMethod([Windows.Storage.Streams.IRandomAccessStream]).Invoke($null, @($op2))
$t2.Wait(-1) | Out-Null
$stream = $t2.Result

$op3 = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)
$t3 = $asTaskGeneric.MakeGenericMethod([Windows.Graphics.Imaging.BitmapDecoder]).Invoke($null, @($op3))
$t3.Wait(-1) | Out-Null
$decoder = $t3.Result

$op4 = $decoder.GetSoftwareBitmapAsync()
$t4 = $asTaskGeneric.MakeGenericMethod([Windows.Graphics.Imaging.SoftwareBitmap]).Invoke($null, @($op4))
$t4.Wait(-1) | Out-Null
$bitmap = $t4.Result

LANG_LINE
if (-not $engine) { throw 'no OCR engine (no language pack installed)' }
$op5 = $engine.RecognizeAsync($bitmap)
$t5 = $asTaskGeneric.MakeGenericMethod([Windows.Media.Ocr.OcrResult]).Invoke($null, @($op5))
$t5.Wait(-1) | Out-Null
$result = $t5.Result

$sb = New-Object System.Text.StringBuilder
foreach ($line in $result.Lines) { [void]$sb.AppendLine($line.Text) }
[System.IO.File]::WriteAllText('OUT_FILE', $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Output 'ok'
} catch {
    $e2 = $_.Exception
    while ($e2.InnerException) { $e2 = $e2.InnerException }
    [System.IO.File]::WriteAllText('OUT_FILE', 'ERR: ' + $e2.Message, [System.Text.Encoding]::UTF8)
    Write-Output ('ERR: ' + $e2.Message)
    exit 1
}
""".replace("IMAGE_PATH", image.replace("'", "''")).replace("LANG_LINE", lang_line).replace("OUT_FILE", out_file.replace("'", "''"))


# ---------------------------------------------------------------- 视觉模型
func _describe(args: Dictionary) -> Dictionary:
	var path := _resolve(str(args.get("image", "")))
	if not FileAccess.file_exists(path):
		return {"ok": false, "output": "找不到图片：%s" % path}
	var a := _app()
	if a == null:
		return {"ok": false, "output": "取不到主程序状态"}
	var model := str(a.cfg.get("vision_model", "")).strip_edges()
	var mmproj := str(a.cfg.get("vision_mmproj", "")).strip_edges()
	if model == "" or mmproj == "":
		var ocr := _ocr({"image": path})
		var hint := "没有配置视觉模型（设置里 vision_model / vision_mmproj 为空），先用 OCR 顶上：\n"
		return {"ok": true, "output": hint + str(ocr.get("output", ""))}
	if not FileAccess.file_exists(model):
		return {"ok": false, "output": "视觉模型文件不存在：%s" % model}
	if not FileAccess.file_exists(mmproj):
		return {"ok": false, "output": "mmproj 文件不存在：%s" % mmproj}

	var backends: Dictionary = a.backends
	var exe := str(backends.get(str(a.effective_backend()), ""))
	if exe == "":
		exe = str(backends.get("cpu", ""))
	if exe == "":
		return {"ok": false, "output": "没有可用的 llama-server"}

	var pid := OS.create_process(exe, PackedStringArray([
		"-m", model, "--mmproj", mmproj,
		"-c", "2048", "-ngl", "999",
		"--host", "127.0.0.1", "--port", str(VISION_PORT), "--no-warmup"]), false)
	if pid <= 0:
		return {"ok": false, "output": "视觉服务启动失败"}

	if not _wait_health():
		OS.kill(pid)
		var o := _ocr({"image": path})
		return {"ok": true, "output": "视觉模型 %.0f 秒内没起来（显存/内存不够？），退回 OCR：\n%s" % [
			VISION_START_TIMEOUT, str(o.get("output", ""))]}

	var question := str(args.get("question", "")).strip_edges()
	if question == "":
		question = "请描述这张图里的内容。"
	var data_url := _data_url(path)
	var body := JSON.stringify({
		"messages": [{
			"role": "user",
			"content": [
				{"type": "text", "text": question},
				{"type": "image_url", "image_url": {"url": data_url}},
			],
		}],
		"stream": false,
		"temperature": 0.2,
		"max_tokens": 512,
	})
	var reply := _post_chat(body)
	OS.kill(pid)
	if reply == "":
		return {"ok": false, "output": "视觉模型没有返回内容"}
	return {"ok": true, "output": reply}


func _data_url(path: String) -> String:
	var img := Image.new()
	if img.load(path) != OK:
		return ""
	# 太大先缩到 1024 长边，避免请求体爆炸
	var w := img.get_width()
	var h := img.get_height()
	if max(w, h) > 1024:
		var scale := 1024.0 / float(max(w, h))
		img.resize(int(w * scale), int(h * scale), Image.INTERPOLATE_BILINEAR)
	var png := img.save_png_to_buffer()
	return "data:image/png;base64," + Marshalls.raw_to_base64(png)


func _wait_health() -> bool:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < VISION_START_TIMEOUT:
		var out: Array = []
		var code := OS.execute("curl.exe", PackedStringArray([
			"-s", "-o", "NUL", "-w", "%{http_code}", "-m", "2",
			"http://127.0.0.1:%d/health" % VISION_PORT]), out, true)
		if code == 0 and out.size() > 0 and str(out[0]).strip_edges() == "200":
			return true
		OS.delay_msec(500)
	return false


func _post_chat(body: String) -> String:
	var req_path := OS.get_temp_dir().path_join("lh_vision_req_%d.json" % randi())
	var out_path := OS.get_temp_dir().path_join("lh_vision_out_%d.json" % randi())
	var f := FileAccess.open(req_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(body)
	f.close()
	var out: Array = []
	var code := OS.execute("curl.exe", PackedStringArray([
		"-s", "-m", "240", "-H", "Content-Type: application/json",
		"--data-binary", "@" + req_path, "-o", out_path,
		"http://127.0.0.1:%d/v1/chat/completions" % VISION_PORT]), out, true)
	var text := ""
	if FileAccess.file_exists(out_path):
		var of := FileAccess.open(out_path, FileAccess.READ)
		if of:
			text = of.get_as_text()
		DirAccess.remove_absolute(out_path)
	DirAccess.remove_absolute(req_path)
	if code != 0 or text.strip_edges() == "":
		return ""
	var obj = JSON.parse_string(text)
	if obj is Dictionary and obj.has("choices"):
		var ch: Array = obj["choices"]
		if ch.size() > 0 and ch[0] is Dictionary:
			var content = ch[0].get("message", {}).get("content", "")
			if typeof(content) == TYPE_STRING:
				return str(content).strip_edges()
	return ""






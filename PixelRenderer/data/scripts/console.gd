extends RichTextLabel
class_name Console

enum {OK, INFO, WARN, ERROR}

func _ready():
	bbcode_enabled = true
	scroll_active = true
	scroll_following = true
	meta_clicked.connect(_on_meta_clicked)

func log(message: String, prefix = INFO):
	var names = {
		OK: {"tag": "✅ OK", "color": "green"},
		INFO: {"tag": "ℹ️ INFO", "color": "lightblue"},
		WARN: {"tag": "⚠️ WARN", "color": "yellow"},
		ERROR: {"tag": "❗ ERROR", "color": "red"}
	}

	var entry = names.get(prefix, {"tag": "ℹ️ INFO", "color": "white"})
	var tag = entry["tag"]
	var color = entry["color"]

	var url_regex = RegEx.new()
	url_regex.compile("https?://\\S+")
	var matches = url_regex.search_all(message)

	for match in matches:
		var url = match.get_string()
		message = message.replace(url, "[url=%s]%s[/url]" % [url, url])

	var line: String = "[color=%s][b][font_size=16][%s][/font_size][/b][/color]  %s" % [color, tag, message]

	append_text(line + "\n")
	scroll_to_line(get_line_count())

func _on_meta_clicked(meta):
	OS.shell_open(str(meta))

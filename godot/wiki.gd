extends "res://hud_window.gd"
## Centred wiki window, toggled with F1. It shows wiki/wiki.html, the same page a
## browser opens, converted to the BBCode a RichTextLabel draws.

const PAGE := "res://wiki/wiki.html"
const HEADING_FONT := "res://assets/fonts/CormorantUnicase-Bold.ttf"
const GOLD_HEX := "#d9b56e"

var text := RichTextLabel.new()

func _init() -> void:
	super("Wiki", "F1", 720, 540)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var bold := TimeHud.serif_font()
	bold.font_weight = 700
	var italic := TimeHud.serif_font()
	italic.font_italic = true
	text.bbcode_enabled = true
	text.fit_content = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", _serif)
	text.add_theme_font_override("bold_font", bold)
	text.add_theme_font_override("italics_font", italic)
	for kind in ["normal", "bold", "italics"]:
		text.add_theme_font_size_override(kind + "_font_size", 15)
	text.add_theme_color_override("default_color", TimeHud.PARCHMENT)
	text.add_theme_color_override("table_odd_row_bg", Color(TimeHud.GOLD, 0.08))
	text.add_theme_constant_override("table_h_separation", 14)
	text.add_theme_constant_override("table_v_separation", 4)
	var page := FileAccess.get_file_as_string(PAGE)
	# An export only carries the page when its filters include wiki/*.html.
	text.text = to_bbcode(page) if page else "The wiki page is missing from this build: export it with wiki/*.html included."
	body.add_child(text)
	_scroll.custom_minimum_size.y = _max_height

## The wiki's HTML as BBCode. Handles the tags the page keeps to (see its header
## comment); other tags are dropped and their text kept.
static func to_bbcode(html: String) -> String:
	var bb := _sub(html, "(?s)<head>.*?</head>|<!--.*?-->", "")
	bb = _sub(bb, "\\s+", " ")
	# Square brackets in the page's text would otherwise read as BBCode tags.
	bb = bb.replace("[", "\u0001").replace("]", "[rb]").replace("\u0001", "[lb]")
	bb = _tables(bb)
	bb = _sub(bb, "<h1>(.*?)</h1>", "[font=%s][font_size=30][color=%s]$1[/color][/font_size][/font]\n" % [HEADING_FONT, GOLD_HEX])
	bb = _sub(bb, "<h2>(.*?)</h2>", "\n[font=%s][font_size=22][color=%s]$1[/color][/font_size][/font]\n" % [HEADING_FONT, GOLD_HEX])
	bb = _sub(bb, "<h3>(.*?)</h3>", "[b][color=%s]$1[/color][/b]\n" % GOLD_HEX)
	bb = _sub(bb, "</li>\\s*<li>", "\n")
	bb = _sub(bb, "<ul>\\s*<li>", "[ul]")
	bb = _sub(bb, "<ol>\\s*<li>", "[ol type=1]")
	bb = _sub(bb, "</li>\\s*</ul>", "[/ul]\n")
	bb = _sub(bb, "</li>\\s*</ol>", "[/ol]\n")
	bb = _sub(bb, "</p>", "\n\n")
	bb = _sub(bb, "<br ?/?>", "\n")
	bb = _sub(bb, "<(b|strong)>", "[b]")
	bb = _sub(bb, "</(b|strong)>", "[/b]")
	bb = _sub(bb, "<(i|em)>", "[i]")
	bb = _sub(bb, "</(i|em)>", "[/i]")
	bb = _sub(bb, "<kbd>", "[b][color=%s]" % GOLD_HEX)
	bb = _sub(bb, "</kbd>", "[/color][/b]")
	bb = _sub(bb, "<[^>]*>", "")
	bb = bb.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&nbsp;", " ").replace("&amp;", "&")
	bb = _sub(bb, " *\n *", "\n")
	return _sub(bb, "\n{3,}", "\n\n").strip_edges()

## Each <table> as a BBCode table, header cells in gold.
static func _tables(bb: String) -> String:
	var table := RegEx.create_from_string("(?s)<table>(.*?)</table>")
	var row := RegEx.create_from_string("(?s)<tr>(.*?)</tr>")
	var cell := RegEx.create_from_string("(?s)<t([hd])>(.*?)</t[hd]>")
	var found := table.search(bb)
	while found:
		var rows := row.search_all(found.get_string(1))
		var out := "[table=%d]" % (cell.search_all(rows[0].get_string(1)).size() if rows else 1)
		for each in rows:
			for item in cell.search_all(each.get_string(1)):
				var content := item.get_string(2).strip_edges()
				out += "[cell]%s[/cell]" % ("[color=%s]%s[/color]" % [GOLD_HEX, content] if item.get_string(1) == "h" else content)
		out += "[/table]\n"
		bb = bb.substr(0, found.get_start()) + out + bb.substr(found.get_end())
		found = table.search(bb, found.get_start() + out.length())
	return bb

static func _sub(subject: String, pattern: String, replacement: String) -> String:
	return RegEx.create_from_string(pattern).sub(subject, replacement, true)

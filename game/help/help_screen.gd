class_name HelpScreen
extends Control
## THE HELP SCREEN — the paged reference the main menu's **Help** button
## opens, sitting directly above Exit.
##
## WHY IT EXISTS. The 1997 game shipped two things we do not: a printed
## manual, and a context-sensitive **Dueling Help** you reached by
## right-clicking any part of the table (manual p.14/112 —
## `docs/glossary-1997.md` §1 lists it under "we have none"). A player who
## has never seen Magic before has, in our build, nowhere to learn what a
## tapped land is or what the spiral over a creature means. This screen is
## the first half of that gap: a linear, readable primer plus a complete
## ICON REFERENCE, turned page by page.
##
## WHAT IS ON A PAGE is not decided here — [HelpPages] owns every word and
## every icon, as pure data, so the content can be tested without a scene
## and so this file stays a renderer. Every claim on those pages is
## sourced; see that file's header for the citation rules.
##
## THE CHROME is the menu's own ([UiChrome]): the original sandstone panel,
## its stone buttons, and the white-with-a-drop-shadow text treatment the
## owner asked for on menu grounds. Nothing new is invented here. The
## ground is `Menubak.pic`, the original's own menu backdrop — imported
## since the first skin pass and, until now, never used.
##
## TURNING PAGES: the ◀ / ▶ buttons, Left/Right, PageUp/PageDown, and
## Home/End. Paging is clamped at both ends (the buttons grey out there);
## Escape returns to the menu. The keys are read in [method _input] and
## marked handled, so a focused button's own arrow-key focus navigation
## can never eat a page turn.

## THE PAGE IS SAND, SO THE WORDS ARE DARK. Every emphasised word here —
## section headings, an icon's name, the letter standing in for a missing
## symbol — used to be warm gold, which is the voice for text on a DARK
## ground. This page is the original's parchment, and the 2026-09-03
## playtest of the first exported build could not read any of it (the same
## report that moved [UiChrome] to dark ink). One accent now, and it is
## the shared [constant UiChrome.ACCENT] — the owner's own pick, dark
## purple — so every emphasised word in the game is one colour.
const ACCENT := UiChrome.ACCENT
## A citation, which is quieter than the sentence it credits.
const FAINT := Color8(92, 82, 68)

## THE TYPE SCALE. Every size on the page in one place, a step up from
## what it was: MPlantin is a thin 1997 serif and the page is a mottled
## stone ground, so what reads at 16pt in a browser does not read here —
## the 2026-09-03 playtest asked for "a bit bigger to be more readable".
## The steps stay in proportion, because a heading that no longer leads
## its paragraph is a different bug from a small one.
const BODY_SIZE := 18
const HEADING_SIZE := 22
const NAME_SIZE := 18
const CITE_SIZE := 15


## Displayed size of an icon that carries no size hint of its own.
const ICON_SIZE := 34.0

## Room the icon column takes on an icon row, whatever the icon's size —
## so every name in a list starts at the same x.
const ICON_COLUMN := 76.0

## THE READING WIDTH. The panel fills the window so the page furniture
## does not jump about between pages, but a line of prose set across
## 1160px is a line nobody finishes: the eye loses the return sweep. The
## body is therefore centred inside the panel and capped here, which is
## the single measurement that made the first screenshot pass readable.
const MAX_TEXT_WIDTH := 980.0

var _page := 0
var _pages: Array = []

var _title_label: Label = null
var _counter_label: Label = null
var _body: VBoxContainer = null
var _gutter: MarginContainer = null
var _scroll: ScrollContainer = null
var _prev_button: Button = null
var _next_button: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_pages = HelpPages.pages()

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# `Menubak.pic` — the shell's own backdrop, dimmed so white body text
	# reads over it (the Options screen dims the title art the same way).
	var art_texture := GameSkin.texture("menu_background")
	if art_texture == null:
		art_texture = GameSkin.texture("title_background")
	if art_texture != null:
		var art := TextureRect.new()
		art.texture = art_texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.modulate = Color(0.42, 0.42, 0.42)
		add_child(art)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)

	# ------------------------------------------------------------ header --
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_title_label = UiChrome.body_label("", 26)
	var title_font := GameSkin.font("font_title")
	if title_font != null:
		_title_label.add_theme_font_override("font", title_font)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	_counter_label = UiChrome.body_label("", 15)
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_counter_label)
	column.add_child(header)

	# -------------------------------------------------------------- body --
	# Horizontal scrolling is DISABLED so the inner column is handed the
	# viewport's width — which is what lets every body label word-wrap.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The gutters that hold the body to MAX_TEXT_WIDTH are recomputed from
	# the live width, so the cap survives a resize instead of being baked
	# in at one window size.
	_gutter = MarginContainer.new()
	_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gutter.add_child(_body)
	_scroll.add_child(_gutter)
	_scroll.resized.connect(_apply_gutters)
	column.add_child(_scroll)

	# ------------------------------------------------------------ footer --
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_prev_button = UiChrome.menu_button("◀  Back", Vector2(180, 40))
	_prev_button.tooltip_text = "Previous page (Left arrow, Page Up)"
	_prev_button.pressed.connect(func() -> void: go_to(_page - 1))
	footer.add_child(_prev_button)
	var close := UiChrome.menu_button("Close", Vector2(150, 40))
	close.tooltip_text = "Back to the main menu (Esc)"
	close.pressed.connect(_close)
	footer.add_child(close)
	_next_button = UiChrome.menu_button("Next  ▶", Vector2(180, 40))
	_next_button.tooltip_text = "Next page (Right arrow, Page Down)"
	_next_button.pressed.connect(func() -> void: go_to(_page + 1))
	footer.add_child(_next_button)
	column.add_child(footer)

	# The panel FOLLOWS THE WINDOW rather than sitting at one size: the
	# margins are what change when the window does, so the screen is whole
	# at 1280x720 as well as 1280x800.
	var panel := UiChrome.panel_around(column, 18.0)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 24
	panel.offset_bottom = -24
	add_child(panel)

	_apply_gutters()
	go_to(0)


## Centre the body inside the panel and hold it to [constant
## MAX_TEXT_WIDTH]. Called on every resize of the scrolling viewport.
func _apply_gutters() -> void:
	if _gutter == null or _scroll == null:
		return
	var slack: float = maxf(0.0, _scroll.size.x - MAX_TEXT_WIDTH)
	var side := int(slack * 0.5)
	_gutter.add_theme_constant_override("margin_left", side)
	_gutter.add_theme_constant_override("margin_right", side)


# --------------------------------------------------------------- paging --

## How many pages the reference has.
func page_count() -> int:
	return _pages.size()


## Which page is showing.
func current_page() -> int:
	return _page


## Show page [param index], CLAMPED — paging can never run off either end,
## by button, by key, or by a caller's arithmetic.
func go_to(index: int) -> void:
	if _pages.is_empty():
		return
	_page = clampi(index, 0, _pages.size() - 1)
	_rebuild()


func _close() -> void:
	get_tree().change_scene_to_file("res://game/main.tscn")


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_LEFT, KEY_PAGEUP:
			go_to(_page - 1)
		KEY_RIGHT, KEY_PAGEDOWN:
			go_to(_page + 1)
		KEY_HOME:
			go_to(0)
		KEY_END:
			go_to(_pages.size() - 1)
		KEY_ESCAPE:
			_close()
		_:
			return
	get_viewport().set_input_as_handled()


# -------------------------------------------------------------- drawing --

func _rebuild() -> void:
	var page: Dictionary = _pages[_page]
	_title_label.text = String(page.get("title", ""))
	_counter_label.text = "Page %d of %d" % [_page + 1, _pages.size()]
	_prev_button.disabled = _page == 0
	_next_button.disabled = _page == _pages.size() - 1
	# remove_child BEFORE queue_free: a queued node is still a child until
	# the end of the frame, so freeing without detaching left the VBox
	# holding the old page AND the new one, laid out at double height —
	# and the `scroll_vertical = 0` below was applied against that. Same
	# idiom as every other rebuild in the duel (MiniCard._rebuild_badges,
	# CardPile.populate, GraveyardView).
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	for block in page.get("blocks", []):
		_add_block(block)
	if _scroll != null:
		_scroll.scroll_vertical = 0


func _add_block(block: Dictionary) -> void:
	match String(block.get("kind", "")):
		HelpPages.HEADING:
			# The era's display face, in the same warm gold an icon's name
			# wears, so a section title and a named thing read as the same
			# rank of heading rather than two competing ones.
			var heading := UiChrome.body_label(String(block.get("text", "")), HEADING_SIZE)
			var font := GameSkin.font("font_title")
			if font != null:
				heading.add_theme_font_override("font", font)
			heading.add_theme_color_override("font_color", ACCENT)
			_body.add_child(heading)
		HelpPages.TEXT:
			_body.add_child(_paragraph(String(block.get("text", "")), BODY_SIZE))
		HelpPages.QUOTE:
			_body.add_child(_quote(block))
		HelpPages.ICONS:
			for entry in block.get("entries", []):
				_body.add_child(_icon_row(entry))


## A wrapping body paragraph. `custom_minimum_size.x = 0` plus EXPAND_FILL
## is what makes a Label inside a scrolling column wrap to the column.
func _paragraph(text: String, size: int) -> Label:
	var label := UiChrome.body_label(text, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## A SOURCED QUOTATION — the 1997 manual's or `Duel.hlp`'s own sentence,
## set in italick-less quotation marks with its citation under it. Every
## page that states a rule shows the sentence it came from, so a reader can
## tell our prose from the original's.
func _quote(block: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := _paragraph("“%s”" % String(block.get("text", "")), BODY_SIZE)
	body.add_theme_color_override("font_color", UiChrome.INK)
	box.add_child(body)
	var cite := UiChrome.body_label("— %s" % String(block.get("cite", "")), CITE_SIZE)
	cite.add_theme_color_override("font_color", FAINT)
	box.add_child(cite)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return margin


## ONE ICON AND ITS EXPLANATION: the real texture on the left at a
## readable size, the original's name for it and what it means on the
## right. Without the 1997 skin the texture is absent and the entry's own
## short ALT string stands in, so the reference still reads.
func _icon_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(ICON_COLUMN, 0)
	var texture := HelpPages.icon_texture(entry.get("icon", {}))
	if texture != null:
		var icon := TextureRect.new()
		icon.texture = texture
		var wide: float = float(entry.get("size", ICON_SIZE))
		var aspect := float(texture.get_width()) / maxf(1.0, float(texture.get_height()))
		icon.custom_minimum_size = Vector2(wide, wide / maxf(0.05, aspect))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# The 1997 art is small pixel art shown BIGGER here; nearest keeps
		# a 17px stripe or a 22px badge crisp instead of smearing it.
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.add_child(icon)
	else:
		var alt := UiChrome.body_label(String(entry.get("alt", "?")), NAME_SIZE + 2)
		alt.add_theme_color_override("font_color", ACCENT)
		slot.add_child(alt)
	row.add_child(slot)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 0)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := UiChrome.body_label(String(entry.get("name", "")), NAME_SIZE)
	name_label.add_theme_color_override("font_color", ACCENT)
	text_box.add_child(name_label)
	text_box.add_child(_paragraph(String(entry.get("text", "")), BODY_SIZE - 1))
	row.add_child(text_box)
	return row

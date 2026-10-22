class_name EmbarkScreen
extends Control
## EMBARK TO THE WORLD OF SHANDALAR — the new adventure's one screen
## (owner design, 2026-10-22): the hero's face, their name, the figure
## that walks the map, the colour of their magic, their playmat, the card
## packs that join and the difficulty, then `Adventure` or `Leave`.
##
## THE 1997 GAME ASKED ON THREE SCREENS and 1.3 on five (difficulty,
## colour, the face designer, the name; `RunAdventureSession`); here it is
## one, so every choice is in view while the others are made, and a
## second adventure opens on the first one's hero ([AdventureSetup],
## which holds every choice and turns them into the world's record).
##
## THE GROUND IS THE 1997 PORTRAIT SCREEN'S: `Menu4.pic`, the dark
## scratched field with its dark red veins the faces stood on (imported as
## `adventure_hero_background`), so the panels are dark and the lettering
## light, and the face is chosen with red arrows ([RedArrow]). Without the
## picture the field is the same dark red-brown, flat.
##
## WHAT `Adventure` DOES TODAY: it checks the hero, remembers every choice
## and makes the record the world will be built from — and says so,
## because the world itself is the next piece of M5
## (`docs/adventure-implementation-notes.md`).

signal embarked(record: Dictionary)

const TITLE := "Embark to the world of Shandalar…"
const BACKGROUND_KEY := "adventure_hero_background"
const FLAT := Color8(34, 20, 18)

const PARCHMENT := Color8(236, 222, 196)
const DIM := Color8(176, 160, 136)
const GOLD := Color8(232, 190, 110)
const GARNET := Color8(112, 34, 26)

## The face at twice its 1997 size (137 × 169), the size 1.3 showed the
## finished face on its pedestal (`RunFacemakerFlow`).
const PORTRAIT_SIZE := Vector2(250, 308)
const SYMBOL_CELL := 48
const SYMBOL_SIZE := Vector2(60, 60)
## The board half's own proportions (914 × 400), as the battle-setup
## screen's preview keeps them, so a picture is cropped here as there.
const PLAYMAT_PREVIEW := Vector2(320, 140)
## The narrowest the three windows go; on the 1280-wide layout each is a
## third of the row.
const PANEL_WIDTH := 370.0

## Each level's plain word in its own ink, from green for a training game
## to red for a hard one ([constant AdventureSetup.DIFFICULTY_WORDS]).
const DIFFICULTY_INKS: Array[Color] = [Color8(150, 214, 126), Color8(222, 208, 118),
	Color8(238, 164, 78), Color8(238, 92, 62)]

## A colour's name in letters that read on the dark field — black's own
## would not, so it is the pale violet of its mana.
const COLOR_INKS := {
	"white": Color8(244, 238, 222), "blue": Color8(120, 168, 238),
	"black": Color8(184, 160, 204), "red": Color8(238, 96, 64),
	"green": Color8(120, 204, 112),
}

var setup := AdventureSetup.new()
## The faces in the order the chooser walks them ([method faces]).
var _faces: Array[Dictionary] = []
## Whether the name follows the face: true while the field holds the
## face's own suggestion or nothing, false once the player types a name.
var _name_follows := true
var _leaving := false
## The thread making the world behind the veil ([method _make_world_aside]).
var _worker: Thread
var _popup: Control = null

var _portrait: TextureRect
var _portrait_caption: Label
var _arrows: Array[RedArrow] = []
var _name_edit: LineEdit
var _walker_buttons: Array[Button] = []
var _color_buttons: Array[Button] = []
var _color_name: Label
var _color_flavor: Label
var _color_gifts: Label
var _playmat_color: OptionButton
var _playmat_type: OptionButton
var _playmat_preview: Control
var _playmat_note: Label
var _difficulty_buttons: Array[Button] = []
var _difficulty_word: Label
var _difficulty_note: Label
var _pack_checks: Dictionary = {}
var _seed_edit: LineEdit
var _seed_row: Control
## The bottom strip: `Leave`, the seed and `Adventure`.
var _bar: HBoxContainer
## While the world is made: the strip's hourglass and words, the stars, and
## how long they have shown ([method show_generating]).
var _wait: HBoxContainer
var _wait_stars: Label
var _wait_time := 0.0
var _note: Label
var adventure_button: Button
var leave_button: Button
var randomize_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	setup = AdventureSetup.restore(_installed_packs())
	_faces = faces()
	if PortraitLibrary.texture(setup.portrait) == null:
		setup.portrait = String(_faces[0]["id"]) if not _faces.is_empty() else ""
	if setup.player_name == "":
		setup.player_name = AdventureSetup.suggested_name(setup.portrait)
	_name_follows = setup.player_name == AdventureSetup.suggested_name(setup.portrait)
	# A NEW WORLD'S SEED FROM THE CLOCK, as the 1997 game seeded its dice,
	# written as the time of day (the owner, 2026-10-22): filled in each time
	# the screen opens, never remembered.
	if setup.seed_text == "":
		setup.seed_text = AdventureSetup.time_seed_text()
	_build()
	_show_all()
	var music := get_node_or_null(^"/root/ShellMusic")
	if music != null:
		music.call(&"play")
	if _arrows.size() == 2 and not _arrows[1].disabled:
		_arrows[1].grab_focus()
	else:
		adventure_button.grab_focus()


## THE FACES IN CHOOSER ORDER: the fourteen 1997 heroes first, in the
## order the original stood them on their pedestals, then every other
## face the game has — the rogues, a face made in 1.3's designer, the
## player's own, ours — as the battle-setup screen lists them.
static func faces() -> Array[Dictionary]:
	var all := PortraitLibrary.all()
	var out: Array[Dictionary] = []
	for row in AdventureSetup.HEROES:
		for face in all:
			if face["id"] == row["id"]:
				out.append(face)
	for face in all:
		if AdventureSetup.hero(String(face["id"])).is_empty():
			out.append(face)
	return out


func _card_packs() -> Node:
	return get_node_or_null(^"/root/CardPacks")


func _installed_packs() -> Array[String]:
	var packs := _card_packs()
	return packs.available_ids() if packs != null else ([] as Array[String])


# ---------------------------------------------------------------- build --

func _build() -> void:
	var art := GameSkin.texture(BACKGROUND_KEY)
	if art != null:
		var ground := TextureRect.new()
		ground.name = "Ground"
		ground.texture = art
		ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ground.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(ground)
	else:
		var flat := ColorRect.new()
		flat.name = "Ground"
		flat.color = FLAT
		flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(flat)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var title := _heading(TITLE, 40)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)

	# THE COLUMNS SCROLL, THE BUTTONS DO NOT — the battle-setup screen's
	# rule: a short window loses neither `Leave` nor `Adventure`.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	page.add_child(scroll)
	# THREE WINDOWS OF ONE SIZE, LINED UP (the owner, 2026-10-22: *"these
	# sub windows should be the same size! And aligned."*): each takes an
	# equal share of the width and the whole height down to the buttons,
	# so their headings sit on one line and their edges meet the edges of
	# `Leave` and `Adventure`. In a window too small for them they keep
	# one width each and the row scrolls.
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	scroll.add_child(columns)
	var panels: Array[Control] = [_panel(_build_hero(), "HeroPanel"),
		_panel(_build_magic(), "MagicPanel"), _panel(_build_journey(), "JourneyPanel")]
	# One floor for all three: the widest one's own, so a window whose
	# contents want more than a third never ends up wider than the others.
	# Measured once they are in the tree, in the fonts they wear there (an
	# Export MPN button measured outside it came out 4 px short on CI).
	for panel in panels:
		columns.add_child(panel)
	var widest := PANEL_WIDTH
	for panel in panels:
		widest = maxf(widest, panel.get_combined_minimum_size().x)
	for panel in panels:
		panel.custom_minimum_size.x = widest

	page.add_child(_build_buttons())


func _build_hero() -> Control:
	var box := _column("Your hero")
	var frame := PanelContainer.new()
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0, 0, 0, 0.45)
	well.border_color = GOLD.darkened(0.35)
	well.set_border_width_all(2)
	well.set_corner_radius_all(4)
	well.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", well)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = PORTRAIT_SIZE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.tooltip_text = "Your face in every adventure duel. Your own pictures go in %s" \
		% PortraitLibrary.ensure_folder()
	frame.add_child(_portrait)
	box.add_child(frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var back := RedArrow.new(-1)
	back.name = "PreviousFace"
	back.tooltip_text = "The face before."
	back.pressed.connect(step_face.bind(-1))
	row.add_child(back)
	_portrait_caption = _text("", 15)
	_portrait_caption.name = "FaceName"
	_portrait_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_caption.clip_text = true
	row.add_child(_portrait_caption)
	var forward := RedArrow.new(1)
	forward.name = "NextFace"
	forward.tooltip_text = "The face after."
	forward.pressed.connect(step_face.bind(1))
	row.add_child(forward)
	_arrows = [back, forward]
	box.add_child(row)

	box.add_child(_label("Name"))
	_name_edit = LineEdit.new()
	_name_edit.name = "HeroName"
	_name_edit.max_length = AdventureSetup.NAME_MAX
	_name_edit.placeholder_text = "Your hero's name"
	_name_edit.tooltip_text = "Up to %d characters. A 1997 hero comes with their own name; type yours over it." \
		% AdventureSetup.NAME_MAX
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: embark())
	box.add_child(_name_edit)
	_note = _text("", 14)
	_note.name = "Note"
	_note.add_theme_color_override("font_color", Color8(240, 120, 96))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.visible = false
	box.add_child(_note)

	box.add_child(_label("On the map"))
	var walkers := HBoxContainer.new()
	walkers.alignment = BoxContainer.ALIGNMENT_CENTER
	walkers.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in AdventureSetup.WALKERS.size():
		var button := _toggle(AdventureSetup.WALKER_LABELS[i], Vector2(96, 34), 16, group)
		button.name = "Walker" + AdventureSetup.WALKER_LABELS[i]
		button.tooltip_text = [
			"The man who walks the world map.",
			"The woman who walks the world map.",
			"One of the two, drawn when the world is made."][i]
		button.pressed.connect(choose_walker.bind(AdventureSetup.WALKERS[i]))
		walkers.add_child(button)
		_walker_buttons.append(button)
	box.add_child(walkers)
	return box


func _build_magic() -> Control:
	var box := _column("Your magic")
	var symbols := HBoxContainer.new()
	symbols.alignment = BoxContainer.ALIGNMENT_CENTER
	symbols.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for row in AdventureSetup.COLORS:
		var button := _symbol_button(row, group)
		symbols.add_child(button)
		_color_buttons.append(button)
	box.add_child(symbols)
	_color_name = _heading("", 34)
	_color_name.name = "ColorName"
	_color_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_color_name)
	_color_flavor = _text("", 16)
	_color_flavor.name = "ColorFlavor"
	_color_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_color_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_color_flavor.custom_minimum_size.y = 46
	box.add_child(_color_flavor)
	_color_gifts = _text("", 14)
	_color_gifts.name = "ColorGifts"
	_color_gifts.add_theme_color_override("font_color", GOLD)
	_color_gifts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_color_gifts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_color_gifts)

	box.add_child(HSeparator.new())
	box.add_child(_heading("Your playmat", 22))
	var pickers := HBoxContainer.new()
	pickers.add_theme_constant_override("separation", 8)
	_playmat_color = OptionButton.new()
	_playmat_color.name = "PlaymatColor"
	_playmat_color.add_item("Your color")
	_playmat_color.set_item_metadata(0, "")
	for row in AdventureSetup.COLORS:
		_playmat_color.add_item(String(row["name"]))
		_playmat_color.set_item_metadata(_playmat_color.item_count - 1, String(row["key"]))
	_playmat_color.tooltip_text = "The color of your half of the table in adventure duels."
	_playmat_color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_playmat_color.item_selected.connect(func(index: int) -> void:
		setup.playmat_color = String(_playmat_color.get_item_metadata(index))
		_show_playmat())
	pickers.add_child(_playmat_color)
	_playmat_type = OptionButton.new()
	_playmat_type.name = "PlaymatStyle"
	_playmat_type.add_item(AdventureSetup.RANDOM_TYPE)
	for entry in DuelOptions.TERRITORY_TYPES:
		_playmat_type.add_item(String(entry["label"]))
	_playmat_type.tooltip_text = "Which of the color's three grounds. Random: one of them, drawn when the world is made, as in 1997."
	_playmat_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_playmat_type.item_selected.connect(func(index: int) -> void:
		setup.playmat_type = _playmat_type.get_item_text(index)
		_show_playmat())
	pickers.add_child(_playmat_type)
	box.add_child(pickers)
	var well := PanelContainer.new()
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(0, 0, 0, 0.5)
	edge.border_color = GOLD.darkened(0.35)
	edge.set_border_width_all(2)
	edge.set_content_margin_all(2)
	well.add_theme_stylebox_override("panel", edge)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_playmat_preview = Control.new()
	_playmat_preview.name = "PlaymatPreview"
	_playmat_preview.custom_minimum_size = PLAYMAT_PREVIEW
	_playmat_preview.clip_contents = true
	well.add_child(_playmat_preview)
	box.add_child(well)
	_playmat_note = _text("", 13)
	_playmat_note.add_theme_color_override("font_color", DIM)
	_playmat_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_playmat_note)
	return box


func _build_journey() -> Control:
	var box := _column("Difficulty")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var group := ButtonGroup.new()
	for i in AdventureSetup.DIFFICULTIES.size():
		var button := _toggle(AdventureSetup.DIFFICULTIES[i], Vector2(170, 36), 17, group)
		button.name = "Difficulty" + AdventureSetup.DIFFICULTIES[i]
		button.tooltip_text = "%s: %s." % [AdventureSetup.DIFFICULTIES[i],
			AdventureSetup.difficulty_phrase(i)]
		button.pressed.connect(choose_difficulty.bind(i))
		grid.add_child(button)
		_difficulty_buttons.append(button)
	box.add_child(grid)
	_difficulty_word = _heading("", 22)
	_difficulty_word.name = "DifficultyWord"
	box.add_child(_difficulty_word)
	_difficulty_note = _text("", 14)
	_difficulty_note.name = "DifficultyNote"
	_difficulty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_difficulty_note)

	box.add_child(HSeparator.new())
	box.add_child(_heading("Card packs", 22))
	# The owner's words, 2026-10-22, first and in gold.
	var challenge := _text("These are additional challenges. The base cards are always present.", 14)
	challenge.name = "PacksChallenge"
	challenge.add_theme_color_override("font_color", GOLD)
	challenge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(challenge)
	var about := _text("Each pack opens its own world on the map, ruled by a World Lord. Defeat the lord and the pack's cards appear everywhere. Your first deck is always base cards.", 13)
	about.add_theme_color_override("font_color", DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(about)
	var installed := AdventureSetup.offered_packs(_installed_packs())
	if installed.is_empty():
		var none := _text("No card packs are installed. Options › Card Packs... adds them.", 14)
		none.name = "NoPacks"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(none)
	else:
		var list := VBoxContainer.new()
		list.name = "Packs"
		list.add_theme_constant_override("separation", 0)
		var packs := _card_packs()
		for id in installed:
			var info: Dictionary = packs.info(id)
			var check := CheckBox.new()
			check.name = "Pack_" + id
			check.text = "%s · %s" % [packs.label_for(id), String(info.get("name", id))]
			check.tooltip_text = "%s\nVersion %s" % [String(info.get("description", "")),
				String(info.get("version", "?"))]
			check.add_theme_color_override("font_color", PARCHMENT)
			check.add_theme_color_override("font_hover_color", GOLD)
			check.add_theme_color_override("font_pressed_color", PARCHMENT)
			check.add_theme_color_override("font_hover_pressed_color", GOLD)
			check.add_theme_font_size_override("font_size", 15)
			check.add_theme_icon_override("checked", UiChrome.check_icon(true))
			check.add_theme_icon_override("unchecked", UiChrome.check_icon(false))
			check.button_pressed = id in setup.packs
			check.toggled.connect(choose_pack.bind(id))
			list.add_child(check)
			_pack_checks[id] = check
		box.add_child(list)
		var both := HBoxContainer.new()
		both.add_theme_constant_override("separation", 6)
		for label in ["All", "None"]:
			var button := UiChrome.menu_button(label, Vector2(80, 28), 14)
			button.name = "Packs" + label
			button.pressed.connect(choose_all_packs.bind(label == "All"))
			both.add_child(button)
		box.add_child(both)
	return box


func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	_bar = row
	row.add_theme_constant_override("separation", 16)
	leave_button = UiChrome.menu_button("Leave", Vector2(180, 46))
	leave_button.name = "Leave"
	leave_button.tooltip_text = "Back to the main menu. Your choices are kept for next time only when you embark."
	leave_button.pressed.connect(leave)
	row.add_child(leave_button)
	# THE WORLD'S SEED, beside the button that makes the world. The 1997
	# game seeded its dice from the clock as it started
	# (`srand(GetTickCount())`) and made every world from them; the field
	# comes filled in from the clock the same way, and showing the seed and
	# taking one is ours [QoL]: a number makes the same world again.
	var seed_row := HBoxContainer.new()
	_seed_row = seed_row
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_theme_constant_override("separation", 8)
	var seed_label := _label("World seed")
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_row.add_child(seed_label)
	_seed_edit = LineEdit.new()
	_seed_edit.name = "WorldSeed"
	_seed_edit.placeholder_text = "a new world"
	_seed_edit.max_length = AdventureSetup.SEED_LENGTH
	_seed_edit.custom_minimum_size = Vector2(300, 0)
	_seed_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_seed_edit.tooltip_text = "Every world is made at random from a seed, as in 1997, and the seed comes from the clock as the screen opens: the time of day, 14:35:07 making 143507. Keep it for a new world; type a number or a word to make that world again: the seed of a world you liked, or a friend's."
	_seed_edit.text_changed.connect(_on_seed_changed)
	seed_row.add_child(_seed_edit)
	row.add_child(seed_row)
	randomize_button = UiChrome.menu_button("Randomize", Vector2(180, 46))
	randomize_button.name = "Randomize"
	randomize_button.tooltip_text = "Draw every choice on this screen at random, then change any of them before you set out."
	randomize_button.pressed.connect(randomize_all)
	row.add_child(randomize_button)
	adventure_button = UiChrome.menu_button("Adventure", Vector2(220, 46), 24, 0.6)
	adventure_button.name = "Adventure"
	adventure_button.tooltip_text = "Make the world and set out."
	adventure_button.pressed.connect(embark)
	row.add_child(adventure_button)
	return row


# ------------------------------------------------------------- choices --

## One face along, wrapping; the name comes along while it is the face's.
func step_face(step: int) -> void:
	if _faces.is_empty():
		return
	var index := 0
	for i in _faces.size():
		if _faces[i]["id"] == setup.portrait:
			index = i
			break
	setup.portrait = String(_faces[wrapi(index + step, 0, _faces.size())]["id"])
	if _name_follows:
		setup.player_name = AdventureSetup.suggested_name(setup.portrait)
		_name_edit.text = setup.player_name
	_show_face()
	_show_walker()


func choose_walker(figure: String) -> void:
	setup.walker = figure
	_show_walker()


func choose_color(key: String) -> void:
	setup.color = key
	_show_color()
	_show_playmat()


func choose_difficulty(level: int) -> void:
	setup.difficulty = level
	_show_difficulty()


func choose_pack(on: bool, id: String) -> void:
	if on and not id in setup.packs:
		setup.packs.append(id)
	elif not on:
		setup.packs.erase(id)


func choose_all_packs(on: bool) -> void:
	for id in _pack_checks:
		(_pack_checks[id] as CheckBox).button_pressed = on


func _on_name_changed(text: String) -> void:
	setup.player_name = text
	_name_follows = text.strip_edges() == "" \
		or text == AdventureSetup.suggested_name(setup.portrait)
	_say("")


## RANDOMIZE (the owner, 2026-10-22): every choice on the screen drawn at
## random — the face, a name ([method AdventureSetup.random_name]: a first
## name and a surname of our own, magical and sometimes funny), the figure
## on the map, the colour,
## the playmat's colour and style, the card packs, the difficulty and a new
## seed (a time of day, as the clock gives) — for the player to enjoy and
## change before setting out. [param rng] is for tests.
func randomize_all(rng: RandomNumberGenerator = null) -> void:
	if _leaving:
		return
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if not _faces.is_empty():
		setup.portrait = String(_faces[rng.randi_range(0, _faces.size() - 1)]["id"])
	setup.player_name = AdventureSetup.random_name(rng)
	_name_follows = false
	setup.walker = AdventureSetup.WALKERS[rng.randi_range(0, AdventureSetup.WALKERS.size() - 1)]
	setup.color = String(AdventureSetup.COLORS[rng.randi_range(0, AdventureSetup.COLORS.size() - 1)]["key"])
	setup.playmat_color = String(_playmat_color.get_item_metadata(
		rng.randi_range(0, _playmat_color.item_count - 1)))
	setup.playmat_type = _playmat_type.get_item_text(rng.randi_range(0, _playmat_type.item_count - 1))
	setup.difficulty = rng.randi_range(0, AdventureSetup.DIFFICULTIES.size() - 1)
	var time := "%02d%02d%02d" % [rng.randi_range(0, 23), rng.randi_range(0, 59), rng.randi_range(0, 59)]
	setup.seed_text = "240000" if time == "000000" else time
	for id in _pack_checks:
		(_pack_checks[id] as CheckBox).button_pressed = rng.randi_range(0, 1) == 1
	_show_all()
	_say("")


## Any number or word is a seed ([method AdventureSetup.parse_seed]).
func _on_seed_changed(text: String) -> void:
	setup.seed_text = text


# ---------------------------------------------------------------- show --

func _show_all() -> void:
	_name_edit.text = setup.player_name
	_seed_edit.text = setup.seed_text
	for i in _playmat_color.item_count:
		if String(_playmat_color.get_item_metadata(i)) == setup.playmat_color:
			_playmat_color.select(i)
	for i in _playmat_type.item_count:
		if _playmat_type.get_item_text(i) == setup.playmat_type:
			_playmat_type.select(i)
	_show_face()
	_show_walker()
	_show_color()
	_show_playmat()
	_show_difficulty()


func _show_face() -> void:
	var live := not _faces.is_empty()
	for arrow in _arrows:
		arrow.disabled = not live
	if not live:
		_portrait.texture = null
		_portrait_caption.text = "(no faces yet)"
		return
	_portrait.texture = PortraitLibrary.texture(setup.portrait)
	var row := AdventureSetup.hero(setup.portrait)
	_portrait_caption.text = String(row["name"]) if not row.is_empty() \
		else PortraitLibrary.title_of(setup.portrait)
	_portrait_caption.tooltip_text = _portrait_caption.text


func _show_walker() -> void:
	var shown := setup.walker_shown()
	for i in _walker_buttons.size():
		_walker_buttons[i].set_pressed_no_signal(AdventureSetup.WALKERS[i] == shown)


func _show_color() -> void:
	var row := AdventureSetup.color_row(setup.color)
	for i in _color_buttons.size():
		var chosen: bool = AdventureSetup.COLORS[i]["key"] == setup.color
		_color_buttons[i].set_pressed_no_signal(chosen)
		_color_buttons[i].modulate = Color.WHITE if chosen else Color(0.62, 0.58, 0.56)
	_color_name.text = String(row["name"])
	_color_name.add_theme_color_override("font_color", COLOR_INKS[setup.color])
	_color_flavor.text = String(row["flavor"])
	_color_gifts.text = "You begin with an amulet of %s and the world magic %s." % [
		String(row["name"]).to_lower(), String(row["world_magic"])]
	if _playmat_color != null and _playmat_color.item_count > 0:
		_playmat_color.set_item_text(0, "Your color (%s)" % String(row["name"]).to_lower())


func _show_playmat() -> void:
	for child in _playmat_preview.get_children():
		_playmat_preview.remove_child(child)
		child.queue_free()
	var style := setup.playmat_type
	if style == AdventureSetup.RANDOM_TYPE:
		style = String(DuelOptions.TERRITORY_TYPES[1]["label"])
		_playmat_note.text = "Random: one of the color's three, drawn when the world is made."
	else:
		_playmat_note.text = ""
	var ground := TerritoryGround.node(setup.playmat_color_shown(), style)
	_playmat_preview.add_child(ground)


func _show_difficulty() -> void:
	for i in _difficulty_buttons.size():
		_difficulty_buttons[i].set_pressed_no_signal(i == setup.difficulty)
	_difficulty_word.text = AdventureSetup.DIFFICULTY_WORDS[setup.difficulty]
	_difficulty_word.add_theme_color_override("font_color", DIFFICULTY_INKS[setup.difficulty])
	var start := AdventureSetup.starting_resources(setup.difficulty)
	var colors: int = start["deck_colors"]
	_difficulty_note.text = "%d gold · %d food · %d %s\nA %d-card first deck in %s." % [
		start["gold"], start["food"], start["amulets"],
		"amulet" if int(start["amulets"]) == 1 else "amulets",
		start["deck_cards"],
		"your color" if colors == 1 else ("all five colors" if colors == 5
			else "your color and %d more" % (colors - 1))]


# ------------------------------------------------------------ leaving --

## CHECK, REMEMBER, RECORD. A refusal stays on the screen, under the
## buttons and in a window; a hero who passes is remembered and their
## world's record made ([method AdventureSetup.resolve]).
func embark() -> void:
	if _leaving:
		return
	setup.player_name = _name_edit.text
	var refusal := setup.name_refusal()
	if refusal != "":
		_say(refusal)
		_name_edit.grab_focus()
		return
	_say("")
	var versions := {}
	var packs := _card_packs()
	if packs != null:
		for id in setup.packs:
			var info: Dictionary = packs.info(id)
			if not info.is_empty():
				versions[id] = String(info.get("version", ""))
	setup.remember()
	var record := setup.resolve(versions)
	print("Adventure record: %s" % JSON.stringify(record))
	embarked.emit(record)
	if DisplayServer.get_name() == "headless":
		return
	_materialize(record)


## The world is made while the hourglass runs ([method show_generating]),
## then the world screen takes over. (The original said "Shandalar
## Materializing..." over the whole screen, `@STARTUP`.)
func _materialize(record: Dictionary) -> void:
	_leaving = true
	show_generating()
	await get_tree().process_frame
	var world := await _make_world_aside(record)
	if not is_inside_tree():
		return
	var screen := open_world(record, world)
	var tree := get_tree()
	tree.root.add_child(screen)
	tree.current_scene = screen
	queue_free()


## CONJURATION OF SHANDALAR WORLD (the owner, 2026-10-22): the bottom
## strip gives `Leave`, the seed and `Adventure` up to an [Hourglass] left of
## its middle and, right of it, the words with a row of one to five stars
## and back ([method stars]), so the player sees the work going on. The
## strip keeps its height; the choices are held still until the world
## screen takes over.
func show_generating() -> void:
	if _wait != null:
		return
	var hold := Control.new()
	hold.name = "HoldStill"
	hold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hold.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(hold)
	var strip_height := maxf(_bar.size.y, 46.0)
	for item in [leave_button, _seed_row, randomize_button, adventure_button]:
		(item as Control).visible = false
	leave_button.disabled = true
	randomize_button.disabled = true
	adventure_button.disabled = true
	_wait = HBoxContainer.new()
	_wait.name = "Conjuration"
	_wait.alignment = BoxContainer.ALIGNMENT_CENTER
	_wait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wait.custom_minimum_size.y = strip_height
	_wait.add_theme_constant_override("separation", 18)
	# The glass stands a little taller than the strip, into the space above
	# and below it, so its gems and sand can be seen.
	var glass := Hourglass.new()
	glass.name = "Hourglass"
	glass.custom_minimum_size = Vector2(strip_height, strip_height)
	glass.reach = 1.4
	glass.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wait.add_child(glass)
	var words := _heading(CONJURATION, 26)
	words.name = "Words"
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wait.add_child(words)
	_wait_stars = _heading(stars(0), 26)
	_wait_stars.name = "Stars"
	_wait_stars.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# As wide as five stars, so the words never move as the stars count.
	var font := _wait_stars.get_theme_font("font")
	_wait_stars.custom_minimum_size.x = font.get_string_size(stars(4),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 6.0
	_wait.add_child(_wait_stars)
	_bar.add_child(_wait)
	_wait_time = 0.0
	get_viewport().gui_release_focus()


## How long each row of stars shows.
const STAR_STEP := 0.28
## The words beside the hourglass (the owner's, 2026-10-22).
const CONJURATION := "Conjuration of Shandalar World"


## The stars for [param step]: one to five and back to one, over and over.
static func stars(step: int) -> String:
	var turn := posmod(step, 8)
	return "*".repeat(turn + 1 if turn < 5 else 9 - turn)


func _process(delta: float) -> void:
	if _wait == null:
		return
	_wait_time += delta
	_wait_stars.text = stars(int(_wait_time / STAR_STEP))


## Makes [param record]'s world on a thread of its own, so the window stays
## alive while the original's generator retries: most worlds take under a
## second, about one in a hundred several (`world-builder-adventure-notes.md`,
## "Never stuck").
func _make_world_aside(record: Dictionary) -> ShandalarWorld:
	_worker = Thread.new()
	if _worker.start(func() -> ShandalarWorld: return AdventureSetup.make_world(record)) != OK:
		_worker = null
		return AdventureSetup.make_world(record)
	while _worker != null and _worker.is_alive() and is_inside_tree():
		await get_tree().process_frame
	if _worker == null:
		return null
	var made: ShandalarWorld = _worker.wait_to_finish()
	_worker = null
	return made


## A world still being made is waited for when the screen goes: the thread
## must not outlive it, nor run on while the game quits.
func _exit_tree() -> void:
	if _worker != null and _worker.is_started():
		_worker.wait_to_finish()
	_worker = null


## The world screen for [param record], its arrival note set — not yet in
## the tree. Its world is [param world], or made here when none is given.
func open_world(record: Dictionary, world: ShandalarWorld = null) -> WorldScreen:
	var screen: WorldScreen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = record
	screen.world = world if world != null else AdventureSetup.make_world(record)
	screen.arrival = summary(record)
	return screen


## The record in a few sentences, for the window `Adventure` opens.
func summary(record: Dictionary) -> String:
	var hero: Dictionary = record["hero"]
	var start: Dictionary = record["start"]
	var color := AdventureSetup.color_row(String(record["color"]))
	var lines: Array[String] = []
	lines.append("%s sets out as a %s mage, at %s level: %s." % [String(hero["name"]),
		String(color["name"]).to_lower(),
		AdventureSetup.DIFFICULTIES[int(record["difficulty"])],
		AdventureSetup.difficulty_phrase(int(record["difficulty"]))])
	lines.append("%d gold, %d food, %d %s and the world magic %s." % [
		start["gold"], start["food"], start["amulets"],
		"amulet" if int(start["amulets"]) == 1 else "amulets",
		String(start["world_magic"])])
	var packs: Array = record["packs"]
	if not packs.is_empty():
		var names: Array[String] = []
		var catalogue := _card_packs()
		for pack in packs:
			var id := String(pack["id"])
			var info: Dictionary = catalogue.info(id) if catalogue != null else {}
			names.append(String(info.get("name", id)))
		lines.append("Pack worlds: %s." % ", ".join(names))
	lines.append("World seed %s." % String(record.get("seed_text", str(record["seed"]))))
	return "\n".join(lines)


## The note under the name: shown while it has something to say.
func _say(text: String) -> void:
	_note.text = text
	_note.visible = text != ""


func leave() -> void:
	if _leaving:
		return
	_leaving = true
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://game/main.tscn")


## ESCAPE IS `Leave`, as `Back` is on the battle-setup screen — after a
## window that is up, which it closes first.
func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if is_instance_valid(_popup) and not _popup.is_queued_for_deletion():
		UiChrome.dismiss_popup(_popup)
		_popup = null
		return
	leave()


# ------------------------------------------------------------- pieces --

func _panel(inner: Control, panel_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.09, 0.045, 0.04, 0.82)
	face.border_color = GARNET
	face.set_border_width_all(2)
	face.set_corner_radius_all(6)
	face.set_content_margin_all(12)
	face.shadow_color = Color(0, 0, 0, 0.5)
	face.shadow_size = 6
	panel.add_theme_stylebox_override("panel", face)
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.size_flags_vertical = Control.SIZE_FILL
	panel.add_child(inner)
	return panel


func _column(heading: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_heading(heading, 24))
	return box


## Lettering in the title face, gold on the dark field.
func _heading(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	var face := GameSkin.font("font_title")
	if face != null:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", Color8(40, 8, 6))
	label.add_theme_constant_override("outline_size", 4 if size >= 30 else 2)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


## Body lettering, light on the dark field (the menus elsewhere are dark
## on sandstone; this screen is the 1997 portrait screen's dark).
func _text(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	var face := GameSkin.font("font_body")
	if face != null:
		label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", PARCHMENT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _label(text: String) -> Label:
	var label := _text(text, 15)
	label.add_theme_color_override("font_color", DIM)
	return label


func _toggle(text: String, size: Vector2, font_size: int, group: ButtonGroup) -> Button:
	var button := UiChrome.menu_button(text, size, font_size)
	button.toggle_mode = true
	button.button_group = group
	UiChrome.gold_when_chosen(button)
	return button


## One colour's button: its 1997 symbol from `stat_buttons`, or without
## the skin a disc of the colour with its initial, in a gold ring when
## chosen.
func _symbol_button(row: Dictionary, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.name = "Color" + String(row["name"])
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = SYMBOL_SIZE + Vector2(10, 10)
	button.tooltip_text = "%s: %s" % [String(row["name"]), String(row["flavor"])]
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "disabled"]:
		button.add_theme_stylebox_override(state, none)
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(1, 0.85, 0.5, 0.12)
	ring.border_color = GOLD
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(40)
	button.add_theme_stylebox_override("pressed", ring)
	button.add_theme_stylebox_override("hover_pressed", ring)
	button.add_theme_stylebox_override("focus", OriginalDialog.focus_ring())
	var sheet := GameSkin.texture("stat_buttons")
	var picture: Control
	if sheet != null:
		var symbol := TextureRect.new()
		symbol.texture = ImageTexture.create_from_image(GameSkin.cut(sheet,
			Rect2i(int(row["symbol"]) * SYMBOL_CELL, 0, SYMBOL_CELL, SYMBOL_CELL)))
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture = symbol
	else:
		var disc := Panel.new()
		var fill := StyleBoxFlat.new()
		fill.bg_color = COLOR_INKS[String(row["key"])].darkened(0.25)
		fill.set_corner_radius_all(32)
		disc.add_theme_stylebox_override("panel", fill)
		var letter := Label.new()
		letter.text = String(row["name"]).left(1) if row["key"] != "blue" else "U"
		letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_font_size_override("font_size", 28)
		letter.add_theme_color_override("font_color", Color8(20, 14, 12))
		disc.add_child(letter)
		picture = disc
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	button.add_child(picture)
	button.pressed.connect(choose_color.bind(String(row["key"])))
	return button

class_name AutoDeckWindow
extends RefCounted
## [QoL] AUTODECK'S WINDOW — the mini-menu's `AutoDeck`
## entry (2026-09-18). A card pool at the top, the wishes under it, one
## button at the foot, and the deck it builds lands on the surface with
## the pool under the pool medallion so the player can go on from there
## ([method DeckBuilderScreen._take_auto_deck]). The building itself is
## [AutoDeck]'s; this class only asks the questions.
##
## THE POOL is one of three: the cards of some sets (the Extras window's
## two switches honoured, as the Inventory honours them), the cards dealt
## by the Sealed Deck window or the Booster Draft when one is in force,
## or a list of cards from a file or the clipboard — the same lines a
## `.deck` file holds, main and sideboard both counted, so a decklist, a
## draft pool file or a plain collection list all read.
##
## THE WISHES: which colours (none = the builder's choice) and how many
## at most, up to five; a gold deck, multicoloured cards preferred; 40
## or 60 cards; more creatures or more spells; fast, medium or slow; a
## rarity — commons only, no rares, uncommons and up, rares and legends
## only; classic lands (the basics) or non-classic (the pool's duals and
## lands with abilities preferred); the tournament rules on or off; the
## Power Nine on or off — off by default, the builder avoids them, on it
## puts the Lotus and the Moxen in every deck and the blue three in a
## blue deck, when the pool has them; whether to build around the cards
## already on the surface; a variety — best (the best card wins every
## slot), a little, some or wild, how far the seed's taste moves a card's
## worth, so that two seeds build two decks rather than one (2026-09-26,
## [member AutoDeck.variety]); and a seed
## — blank for a fresh roll every build, a number for the same deck
## again, since the builder is seeded and its notes give the roll back
## (`Seed 565933: …`). All of it is remembered between visits under one
## settings key, the way the Sealed Deck window's numbers are — the seed
## too, so the summary line says out loud when the next build will be
## the same deck.

const TITLE := "AutoDeck"
const WINDOW_SIZE := Vector2(680, 800)
## The `[Settings]` key the wishes are kept under.
const OPTIONS_SETTING := "auto_deck_options"
## The three pools.
const SOURCE_SETS := "sets"
const SOURCE_DEALT := "dealt"
const SOURCE_LIST := "list"
## The wishes as saved, and their defaults.
const DEFAULTS := {
	"source": SOURCE_SETS, "sets": ["4ed"], "colors": 0, "max_colors": 2, "gold": false,
	"size": 60, "lean": AutoDeck.LEAN_BALANCED, "speed": AutoDeck.SPEED_MEDIUM,
	"rarity": AutoDeck.RARITY_ANY, "lands": AutoDeck.LANDS_CLASSIC,
	"tournament": true, "power_nine": false, "variety": 0, "keep": false, "seed": 0,
	"last_seed": 0,
}
## The seed field's word for a blank, and the most a seed may be — what
## [method AutoDeck.build] rolls.
const SEED_BLANK := "random"
const SEED_MOST := 999_999
const SEED_TIP := "A number: the same pool, wishes and seed build the same deck again. Blank for a fresh roll every build — the deck notes say which seed was rolled."
## The rarity wishes as the window words them, in the row's order.
const RARITY_LABELS := {AutoDeck.RARITY_ANY: "Any", AutoDeck.RARITY_PAUPER: "Common-pauper",
	AutoDeck.RARITY_NO_RARES: "No rares", AutoDeck.RARITY_UNCOMMON_UP: "Uncommon up",
	AutoDeck.RARITY_RARES: "Only rares"}
const GOLD_TEXT := "Gold deck — multicoloured cards preferred"
const POWER_TEXT := "Use the Power Nine — Lotus, Moxen, and the blue three in a blue deck"
const POWER_TIP := "Black Lotus and the five Moxen go into every deck for first-turn mana; Ancestral Recall, Time Walk and Timetwister into a blue deck. Only when the pool holds them — Unlimited does, Fourth Edition does not — and one copy each under the tournament rules. Off, the builder avoids all nine."

const BRIEF := "Pick a card pool, say what you like, and the builder lays out a deck. Basic lands are always free."
const NO_LIST := "No list yet — a file or a paste of card lines, `4 Lightning Bolt` a line."
const PASTE_TITLE := "Paste a card list"
const PASTE_ERROR := "That is not a card list"
const BUILD_LABEL := "Build me a deck"

var screen: DeckBuilderScreen
var dialog: OriginalDialog
## The wishes, live; see [constant DEFAULTS].
var options: Dictionary = {}
## The list pool, once one is read, and where it came from.
var list_pool: Dictionary = {}
var list_label := ""

var _source_lines: Dictionary = {}
var _set_lines: Dictionary = {}
var _groups: Dictionary = {}
var _color_buttons: Dictionary = {}
var _tournament_line: Button
var _gold_line: Button
var _power_line: Button
var _keep_line: Button
var _seed_edit: LineEdit
var _last_seed_button: Button
var _list_line: Label
var _summary: Label
var _build_button: Button
var _sets_cache_key := ""
var _sets_cache: Dictionary = {}


## Open the window over [param on]. Null when a dialog is already up.
static func open_on(on: DeckBuilderScreen) -> AutoDeckWindow:
	if on._dialog_busy():
		return null
	var window := AutoDeckWindow.new()
	window.screen = on
	window._build()
	return window


# ------------------------------------------------------------- the build --

func _build() -> void:
	options = DEFAULTS.duplicate(true)
	var saved: Variant = Settings.get_value(OPTIONS_SETTING, {})
	if saved is Dictionary:
		for key in DEFAULTS:
			if saved.has(key) and typeof(saved[key]) == typeof(DEFAULTS[key]):
				options[key] = saved[key]
	# A dealt pool remembered from last time that is not in force now.
	if options["source"] == SOURCE_DEALT and screen.sealed == null:
		options["source"] = SOURCE_SETS
	if options["source"] == SOURCE_LIST:
		options["source"] = SOURCE_SETS
	dialog = OriginalDialog.create(TITLE, WINDOW_SIZE)
	dialog.name = "AutoDeckWindow"
	# The dialog carries its window, so a test can reach the wishes.
	dialog.set_meta("auto_deck_window", self)
	var body := dialog.body()
	body.add_theme_constant_override("separation", 4)
	var brief := OriginalDialog.label(BRIEF, 13)
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(brief)

	# --- the pool ---
	body.add_child(_head("Card pool"))
	_source_lines[SOURCE_SETS] = _tick_line("Cards from these sets", "SourceSets",
		func() -> void: _pick_source(SOURCE_SETS))
	body.add_child(_source_lines[SOURCE_SETS])
	var grid := GridContainer.new()
	grid.name = "SetGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 0)
	for code in CardRegistry.active_set_order():
		var set_code := String(code)
		var line := _tick_line(String(DeckFilter.SET_LABELS.get(set_code, set_code.to_upper())),
			"Set_" + set_code, func() -> void: _toggle_set(set_code))
		line.custom_minimum_size = Vector2(150, 22)
		line.add_theme_font_size_override("font_size", 13)
		_set_lines[set_code] = line
		grid.add_child(line)
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 22)
	indent.add_child(grid)
	body.add_child(indent)
	if screen.sealed != null:
		_source_lines[SOURCE_DEALT] = _tick_line("", "SourceDealt",
			func() -> void: _pick_source(SOURCE_DEALT))
		body.add_child(_source_lines[SOURCE_DEALT])
	_source_lines[SOURCE_LIST] = _tick_line("A list of cards", "SourceList",
		func() -> void: _pick_source(SOURCE_LIST))
	body.add_child(_source_lines[SOURCE_LIST])
	var list_row := HBoxContainer.new()
	list_row.add_theme_constant_override("separation", 8)
	var list_indent := Control.new()
	list_indent.custom_minimum_size.x = 14
	list_row.add_child(list_indent)
	var file_button := OriginalDialog.button("File…", Vector2(72, 24))
	file_button.name = "FileButton"
	file_button.disabled = OS.has_feature("web")
	file_button.pressed.connect(_open_file)
	list_row.add_child(file_button)
	var paste_button := OriginalDialog.button("Paste…", Vector2(72, 24))
	paste_button.name = "PasteButton"
	paste_button.pressed.connect(_open_paste)
	list_row.add_child(paste_button)
	_list_line = OriginalDialog.label(NO_LIST, 12)
	_list_line.name = "ListLine"
	_list_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_list_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_row.add_child(_list_line)
	body.add_child(list_row)

	# --- the colours ---
	body.add_child(_head("Colours"))
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 6)
	for color in Mtg.WUBRG:
		var button := OriginalDialog.button(String(Mtg.COLOR_NAMES[color]), Vector2(92, 30))
		button.name = "Color_" + _color_letter(color)
		button.toggle_mode = true
		button.tooltip_text = "Build in %s. None ticked: the builder picks the strongest colours in the pool." % String(Mtg.COLOR_NAMES[color]).to_lower()
		var art := ManaIcons.symbol(_color_letter(color))
		if art != null:
			button.icon = art
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 18)
		UiChrome.gold_when_chosen(button)
		button.set_pressed_no_signal((int(options["colors"]) & color) != 0)
		button.pressed.connect(func() -> void:
			options["colors"] = int(options["colors"]) ^ color
			_refresh())
		_color_buttons[color] = button
		color_row.add_child(button)
	body.add_child(color_row)
	_choice_row(body, "At most", "max_colors", [[1, "1 colour", "Mono-coloured."],
		[2, "2 colours", "Two colours — the norm."], [3, "3 colours", "Three colours; the lands will be thin."],
		[4, "4 colours", "Up to four colours; tick the four to make sure of them."],
		[5, "5 colours", "Up to five colours — tick all five to make sure of a five-colour deck."]])
	_gold_line = _tick_line(GOLD_TEXT, "GoldLine", func() -> void:
		options["gold"] = not bool(options["gold"])
		_refresh())
	_gold_line.tooltip_text = "Cards of two colours or more come first; two colours at least."
	body.add_child(_gold_line)

	# --- the deck ---
	body.add_child(_head("Deck"))
	_choice_row(body, "Cards", "size", [[40, "40", "A 40-card deck — the 1997 floor; up to three copies of a card."],
		[60, "60", "A 60-card deck — the tournament norm; up to four copies of a card."]])
	_choice_row(body, "Lean", "lean", [
		[AutoDeck.LEAN_CREATURES, "More creatures", "About seven spells in ten are creatures."],
		[AutoDeck.LEAN_BALANCED, "Balanced", "A little over half creatures."],
		[AutoDeck.LEAN_SPELLS, "More spells", "Under four in ten are creatures; the rest do things."]])
	_choice_row(body, "Speed", "speed", [
		[AutoDeck.SPEED_FAST, "Fast", "Three spells in ten cast on the first turn, few above three mana; around %d lands in 60, settled to the curve." % int(AutoDeck.LANDS[60][AutoDeck.SPEED_FAST])],
		[AutoDeck.SPEED_MEDIUM, "Medium", "A curve that peaks at two and three; around %d lands in 60, settled to the curve." % int(AutoDeck.LANDS[60][AutoDeck.SPEED_MEDIUM])],
		[AutoDeck.SPEED_SLOW, "Slow", "Hardly a one-drop; big spells and the lands to cast them, around %d in 60, settled to the curve." % int(AutoDeck.LANDS[60][AutoDeck.SPEED_SLOW])]])
	_choice_row(body, "Rarity", "rarity", [
		[AutoDeck.RARITY_ANY, RARITY_LABELS[AutoDeck.RARITY_ANY], "Every card in the pool."],
		[AutoDeck.RARITY_PAUPER, RARITY_LABELS[AutoDeck.RARITY_PAUPER], "Commons only — a pauper deck."],
		[AutoDeck.RARITY_NO_RARES, RARITY_LABELS[AutoDeck.RARITY_NO_RARES], "Commons and uncommons — no rares, no legends."],
		[AutoDeck.RARITY_UNCOMMON_UP, RARITY_LABELS[AutoDeck.RARITY_UNCOMMON_UP], "Uncommons, rares and legends — no commons."],
		[AutoDeck.RARITY_RARES, RARITY_LABELS[AutoDeck.RARITY_RARES], "Rares and legends only."]])
	_choice_row(body, "Lands", "lands", [
		[AutoDeck.LANDS_CLASSIC, "Classic", "Basic lands only — Plains, Island, Swamp, Mountain and Forest in the proportion of the pips."],
		[AutoDeck.LANDS_NONCLASSIC, "Non-classic", "Dual lands, City of Brass and lands with abilities from the pool first, up to half the lands; the basics fill the rest."]])
	_tournament_line = _tick_line("Tournament rules — no banned cards, restricted cards once", "TournamentLine",
		func() -> void:
			options["tournament"] = not bool(options["tournament"])
			_refresh())
	body.add_child(_tournament_line)
	_power_line = _tick_line(POWER_TEXT, "PowerNineLine", func() -> void:
		options["power_nine"] = not bool(options["power_nine"])
		_refresh())
	_power_line.tooltip_text = POWER_TIP
	body.add_child(_power_line)
	_keep_line = _tick_line("", "KeepLine", func() -> void:
		options["keep"] = not bool(options["keep"])
		_refresh())
	body.add_child(_keep_line)
	_choice_row(body, "Variety", "variety", [
		[AutoDeck.VARIETY_LEVELS[0], "Best", "The best card wins every slot; the seed decides only among cards worth the same."],
		[AutoDeck.VARIETY_LEVELS[1], "A little", "The seed's taste moves a card's worth by up to %.3f points — a card or two changes hands between seeds." % (AutoDeck.TASTE_SPAN * AutoDeck.VARIETY_LEVELS[1] / 100.0)],
		[AutoDeck.VARIETY_LEVELS[2], "Some", "Up to %.2f points — two seeds build decks about half alike." % (AutoDeck.TASTE_SPAN * AutoDeck.VARIETY_LEVELS[2] / 100.0)],
		[AutoDeck.VARIETY_LEVELS[3], "Wild", "Up to %.1f points, a whole mana step — two seeds share a third of their cards." % (AutoDeck.TASTE_SPAN * AutoDeck.VARIETY_LEVELS[3] / 100.0)]])
	_seed_row(body)

	# --- the summary and the foot ---
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	_summary = OriginalDialog.label("", 13, true)
	_summary.name = "SummaryLine"
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_summary)
	_build_button = dialog.add_button(BUILD_LABEL)
	_build_button.name = "BuildButton"
	_build_button.custom_minimum_size.x = 160
	_build_button.pressed.connect(_build_deck)
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	screen._show_dialog(dialog)
	_refresh()
	_build_button.grab_focus()


func _head(text: String) -> Label:
	var head := OriginalDialog.label(text, 14, true)
	head.add_theme_color_override("font_color", UiChrome.CHOSEN)
	head.add_theme_color_override("font_outline_color", UiChrome.CHOSEN)
	return head


## A `[x] text` line, the Sealed Deck window's own switch idiom.
func _tick_line(text: String, node_name: String, on_press: Callable) -> Button:
	var line := OriginalDialog.choice_line(text)
	line.name = node_name
	line.custom_minimum_size = Vector2(0, 24)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.pressed.connect(on_press)
	return line


static func _tick_text(on: bool, text: String) -> String:
	return ("[x] " if on else "[  ] ") + text


## The seed row: a field for a number, blank for a fresh roll, and a
## button that puts the last build's seed back in it.
func _seed_row(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "Row_seed"
	row.add_theme_constant_override("separation", 6)
	var label := OriginalDialog.label("Seed", 14)
	label.custom_minimum_size.x = 64
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.tooltip_text = SEED_TIP
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(label)
	_seed_edit = LineEdit.new()
	_seed_edit.name = "SeedEdit"
	_seed_edit.custom_minimum_size = Vector2(120, 26)
	_seed_edit.placeholder_text = SEED_BLANK
	_seed_edit.tooltip_text = SEED_TIP
	_seed_edit.max_length = 6
	if int(options["seed"]) > 0:
		_seed_edit.text = str(int(options["seed"]))
	_seed_edit.text_changed.connect(_seed_typed)
	row.add_child(_seed_edit)
	_last_seed_button = OriginalDialog.button("", Vector2(0, 26))
	_last_seed_button.name = "LastSeedButton"
	_last_seed_button.tooltip_text = "The seed of the last deck built — press to build it again."
	_last_seed_button.pressed.connect(func() -> void:
		set_seed(int(options["last_seed"])))
	row.add_child(_last_seed_button)
	body.add_child(row)


## The field keeps to digits; what it says is the seed, 0 for blank.
func _seed_typed(text: String) -> void:
	var digits := ""
	for c in text:
		if c >= "0" and c <= "9":
			digits += c
	if digits != text:
		_seed_edit.text = digits
		_seed_edit.caret_column = digits.length()
	options["seed"] = mini(int(digits) if digits != "" else 0, SEED_MOST)
	_refresh()


## Put [param value] in the seed field — 0 blanks it.
func set_seed(value: int) -> void:
	value = clampi(value, 0, SEED_MOST)
	_seed_edit.text = "" if value == 0 else str(value)
	options["seed"] = value
	_refresh()


## A titled row of toggles, one of which is lit ([method
## UiChrome.gold_when_chosen]) — the wish [param key] takes the value of
## the lit one.
func _choice_row(body: VBoxContainer, title: String, key: String, choices: Array) -> void:
	var row := HBoxContainer.new()
	row.name = "Row_" + key
	row.add_theme_constant_override("separation", 6)
	var label := OriginalDialog.label(title, 14)
	label.custom_minimum_size.x = 64
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	_groups[key] = {}
	for choice in choices:
		var value: Variant = choice[0]
		var button := OriginalDialog.button(String(choice[1]), Vector2(0, 26))
		button.name = "%s_%s" % [key.capitalize().replace(" ", ""), str(value)]
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = String(choice[2])
		UiChrome.gold_when_chosen(button)
		button.set_pressed_no_signal(options[key] == value)
		button.pressed.connect(func() -> void:
			options[key] = value
			_refresh())
		_groups[key][value] = button
		row.add_child(button)
	body.add_child(row)


static func _color_letter(color: int) -> String:
	match color:
		Mtg.ManaColor.W: return "W"
		Mtg.ManaColor.U: return "U"
		Mtg.ManaColor.B: return "B"
		Mtg.ManaColor.R: return "R"
		Mtg.ManaColor.G: return "G"
	return "C"


# ------------------------------------------------------------ the wishes --

func _pick_source(source: String) -> void:
	if source == SOURCE_LIST and list_pool.is_empty():
		# Nothing to build from yet; the two buttons under the line are
		# how a list arrives, and reading one ticks the line.
		if OS.has_feature("web"):
			_open_paste()
		else:
			_open_file()
		return
	options["source"] = source
	_refresh()


func _toggle_set(code: String) -> void:
	var sets: Array = options["sets"].duplicate()
	if sets.has(code):
		sets.erase(code)
	else:
		sets.append(code)
	options["sets"] = sets
	options["source"] = SOURCE_SETS
	_refresh()


## The pool the wishes point at now, and its name for the report.
func current_pool() -> Dictionary:
	match String(options["source"]):
		SOURCE_DEALT:
			if screen.sealed != null:
				return AutoDeck.pool_from_counts(screen.sealed.counts)
			return {}
		SOURCE_LIST:
			return list_pool
	var codes: Array = []
	for code in CardRegistry.active_set_order():
		if options["sets"].has(code):
			codes.append(code)
	var key := "%s|%s|%s" % [",".join(PackedStringArray(codes)),
		screen.filter.completion_pack_on, screen.filter.original_cards_on]
	if key != _sets_cache_key:
		_sets_cache_key = key
		_sets_cache = AutoDeck.pool_from_sets(codes, screen.filter.completion_pack_on,
			screen.filter.original_cards_on)
	return _sets_cache


func pool_label() -> String:
	match String(options["source"]):
		SOURCE_DEALT:
			return "the pool in force" if screen.sealed == screen._auto_pool else "the dealt cards"
		SOURCE_LIST:
			return list_label
	var names: PackedStringArray = []
	for code in CardRegistry.active_set_order():
		if options["sets"].has(code):
			names.append(String(DeckFilter.SET_LABELS.get(code, String(code).to_upper())))
	if names.is_empty():
		return "no set"
	if names.size() > 3:
		return "%d sets" % names.size()
	return ", ".join(names)


## What is on the surface that a build could keep: the non-land cards.
func _keepable() -> int:
	var n := 0
	for name in screen.deck.names():
		var data := DeckModel._card(String(name))
		if data != null and not data.is_land():
			n += int(screen.deck.counts[name])
	return n


func _refresh() -> void:
	var source := String(options["source"])
	_source_lines[SOURCE_SETS].text = _tick_text(source == SOURCE_SETS, "Cards from these sets")
	for code in _set_lines:
		_set_lines[code].text = _tick_text(options["sets"].has(code),
			String(DeckFilter.SET_LABELS.get(code, String(code).to_upper())))
	if _source_lines.has(SOURCE_DEALT):
		var dealt := AutoDeck.pool_from_counts(screen.sealed.counts) if screen.sealed != null else {}
		var dealt_words := "The pool in force" if screen.sealed == screen._auto_pool else "The dealt cards"
		_source_lines[SOURCE_DEALT].text = _tick_text(source == SOURCE_DEALT,
			"%s (%d cards)" % [dealt_words, AutoDeck.pool_total(dealt)])
	_source_lines[SOURCE_LIST].text = _tick_text(source == SOURCE_LIST, "A list of cards")
	_list_line.text = NO_LIST if list_pool.is_empty() else "%d cards (%d names) from %s" % [
		AutoDeck.pool_total(list_pool), list_pool.size(), list_label]
	_tournament_line.text = _tick_text(bool(options["tournament"]),
		"Tournament rules — no banned cards, restricted cards once")
	_gold_line.text = _tick_text(bool(options["gold"]), GOLD_TEXT)
	_power_line.text = _tick_text(bool(options["power_nine"]), POWER_TEXT)
	var keepable := _keepable()
	_keep_line.text = _tick_text(bool(options["keep"]) and keepable > 0,
		"Build around the %d non-land card%s already on the surface" % [keepable, "" if keepable == 1 else "s"]
		if keepable > 0 else "Build around the cards already on the surface (none yet)")
	_keep_line.disabled = keepable == 0
	var last_seed := int(options["last_seed"])
	_last_seed_button.visible = last_seed > 0
	_last_seed_button.text = "Last build: %d" % last_seed
	var pool := current_pool()
	var total := AutoDeck.pool_total(pool)
	var colors := int(options["colors"])
	var color_words := "the builder's choice of colours" if colors == 0 else AutoDeck.color_phrase(colors).to_lower()
	var most := maxi(int(options["max_colors"]), AutoDeck._count_colors(colors))
	if bool(options["gold"]):
		most = maxi(most, 2)
	_summary.text = "%d cards from %s — %d on offer, %d names; %s, up to %d; %s, %s." % [
		int(options["size"]), pool_label(), total, pool.size(), color_words, most,
		String(options["lean"]), String(options["speed"])]
	# The wishes beyond the defaults, in a sentence of their own.
	var extras: PackedStringArray = []
	if bool(options["gold"]):
		extras.append("a gold deck")
	if String(options["rarity"]) != AutoDeck.RARITY_ANY:
		extras.append(String(RARITY_LABELS.get(options["rarity"], "")).to_lower())
	if String(options["lands"]) == AutoDeck.LANDS_NONCLASSIC:
		extras.append("non-classic lands")
	if bool(options["power_nine"]):
		extras.append("the Power Nine")
	if int(options["variety"]) > 0:
		extras.append("variety %d" % int(options["variety"]))
	if not extras.is_empty():
		var sentence := ", ".join(extras)
		_summary.text += " %s%s." % [sentence.left(1).to_upper(), sentence.substr(1)]
	if int(options["seed"]) > 0:
		_summary.text += " Seed %d — the same deck again." % int(options["seed"])
	_build_button.disabled = total == 0
	if total == 0:
		_summary.text += " Nothing to build from yet."


# -------------------------------------------------------------- the list --

func _open_file() -> void:
	screen._open_deck_file_browser("Card pool", func(path: String) -> void:
		var text := FileAccess.get_file_as_string(path)
		if text == "":
			screen._say(DeckStore.LOAD_ERROR % path.get_file(), true)
			return
		_take_list(text, path.get_file()))


## The paste half — a text box over the window, the notes dialog's own
## shape, one layer up so the window under it stays intact.
func _open_paste() -> void:
	var paste := OriginalDialog.create(PASTE_TITLE, Vector2(520, 380))
	paste.name = "AutoDeckPaste"
	paste.z_index = 210
	paste.body().add_child(OriginalDialog.label(
		"One card a line, a count in front: `4 Lightning Bolt`. Sideboard lines count too.", 13))
	var edit := TextEdit.new()
	edit.name = "PasteEdit"
	edit.custom_minimum_size = Vector2(480, 240)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.add_theme_stylebox_override("normal", OriginalDialog.panel_style("panel_dark_stone", 6.0))
	edit.add_theme_stylebox_override("focus", OriginalDialog.panel_style("panel_dark_stone", 6.0))
	edit.add_theme_color_override("font_color", OriginalDialog.CHOICE_LIT)
	paste.body().add_child(edit)
	var take := paste.add_button("Read the list")
	take.name = "ReadButton"
	take.pressed.connect(func() -> void:
		if _take_list(edit.text, "a pasted list"):
			paste.dismiss())
	paste.add_button("Cancel").pressed.connect(paste.dismiss)
	screen._show_dialog(paste, 209)
	edit.grab_focus()


## Read [param text] as the list pool. False, with the reason said on the
## screen's line, when it is not a list at all.
func _take_list(text: String, label: String) -> bool:
	var report: Array = []
	var pool := AutoDeck.pool_from_text(text, report)
	if pool.is_empty():
		screen._say("%s — %s" % [PASTE_ERROR, String(report[0])] if not report.is_empty()
			else "%s — no card the game has" % PASTE_ERROR, true)
		return false
	list_pool = pool
	list_label = label
	options["source"] = SOURCE_LIST
	if report.is_empty():
		screen._say("%d cards read from %s" % [AutoDeck.pool_total(pool), label])
	else:
		screen._say("%d cards read from %s — %s" % [AutoDeck.pool_total(pool), label, String(report[0])], true)
	_refresh()
	return true


# ------------------------------------------------------------- the deck --

## The builder the wishes describe, ready to [method AutoDeck.build].
func builder() -> AutoDeck:
	var auto := AutoDeck.new()
	auto.pool = current_pool()
	auto.pool_label = pool_label()
	auto.size = int(options["size"])
	auto.colors = int(options["colors"])
	auto.max_colors = int(options["max_colors"])
	auto.gold = bool(options["gold"])
	auto.lean = String(options["lean"])
	auto.speed = String(options["speed"])
	auto.rarity = String(options["rarity"])
	auto.land_kind = String(options["lands"])
	auto.tournament = bool(options["tournament"])
	auto.power_nine = bool(options["power_nine"])
	auto.variety = int(options["variety"])
	auto.seed = int(options["seed"])
	if bool(options["keep"]) and _keepable() > 0:
		auto.keep = screen.deck.duplicate_model()
	return auto


## The window rolls a blank seed itself, so it can remember the roll
## for the `Last build` button; the builder would roll the same range.
func _build_deck() -> void:
	var auto := builder()
	if AutoDeck.pool_total(auto.pool) == 0:
		return
	if auto.seed == 0:
		auto.seed = randi_range(1, SEED_MOST)
	options["last_seed"] = auto.seed
	Settings.set_value(OPTIONS_SETTING, options.duplicate(true))
	dialog.dismiss()
	screen._take_auto_deck(auto)

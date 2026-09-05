class_name DuelOptions
extends RefCounted
## THE DUEL OPTIONS PANEL — `@DIALOG_DUELOPTIONS`
## (`shandalar-src/Program/UIStrings.txt:598`), the nineteen strings of the
## 1997 duel's own preferences window, and the persistence behind them.
##
## `Duel.hlp`, topic **Dueling Options**: *"The dueling options are a
## convenient way to customize the Dueling Table. **These settings are
## retained for future duels.**"* — which is why every one of them is a
## [Settings] key rather than screen state.
##
## THE TABLE, verbatim and in the string table's own order (its ampersands
## are the Windows accelerators; we drop them, as `@MENU_PHASEBAR`'s
## accelerators were dropped in §6.1, because we do not honour them):
##
##     Duel Options
##     &Layout / Standard / Advanced
##     Show coin &flip animations
##     Show &cue cards
##     Show &abilities on small cards
##     Show &power/toughness on small cards
##     See next &draws at end of duel
##     Your &territory background
##     White / Blue / Black / Red / Green / Deck color
##     Line drawing / Pattern / Mana symbols
##
## THE KEYS ARE THE ORIGINAL'S OWN, spelled exactly as they appear under
## `Software\MicroProse\Magic: The Gathering\DuelOptions` in
## `Program/Magic.exe`. Keeping `ShowCueCards` rather than inventing
## `show_cue_cards` is the same rule §9 applies to user-facing text: the
## original's word for a thing beats ours, and here it also makes a
## 1997 registry export readable straight into `user://settings.cfg`.
##
## WHAT EACH ONE DOES, from the help file's own descriptions:
##  - **Layout** — *"**Standard Layout** returns the dueling display to its
##    original form. This layout includes a permanent Showcase, but the
##    territories are slightly smaller to compensate. **Advanced Layout**
##    streamlines the dueling area. The Showcase is removed (though it
##    appears when necessary), and the other parts of the interface are
##    rearranged to allow the largest possible territories."*
##  - **Show Cue Cards** — *"controls the appearance of the tiny hints that
##    pop up when you position the mouse cursor over an active location."*
##  - **Show Abilities** — *"determines whether each creature's abilities
##    (flying and such) are marked on the card by ability icons."*
##  - **Show Power/Toughness** — *"determines whether or not the current
##    power and toughness of each creature is displayed on the card in
##    play. (The Showcase always shows the original power and toughness.)"*
##  - **See Next Draws** — *"has no effect during the duel. Rather, this
##    controls whether, at the end of a duel, you get to see the next cards
##    you and your opponent would have drawn."*
##  - **territory background** — *"The box in the lower portion of the
##    window is relevant to the appearance of the background in your
##    territory. (You cannot do anything to change the background in your
##    opponent's territory; it matches the predominant color in her deck.)
##    The list on the left simply allows you to pick the predominant color
##    of your background. The list on the right includes the different
##    types of background art available for each color."*
##
## The two lists are the original's own file naming: `Terr_<Colour><Type>`
## in `Program/DuelArt/`, where the three types are `Pict` (Line drawing),
## `Patt` (Pattern) and `Mana` (Mana symbols). All fifteen files are
## imported (`tools/import_original.py`) and [TerritoryGround] draws them;
## without the 1997 art it paints all fifteen itself, so the two lists
## work on a machine that has never seen the original.
##
## THE SAME CONTRACT COVERS THE COIN TOSS, one section further down: the
## checkbox above is the 1997 boolean view of a three-way `[QoL]` value
## that also has a home on the Options screen. See [method
## coin_flip_style].
##
## ONE SETTING, TWO PLACES TO SET IT. The 1997 home is this panel, reached
## from `Duel Options...` on the Territory menu. `[QoL]` — the battle-setup
## screen offers the same two lists beside the duelist portraits, which
## the original's own pre-duel screen did not. They are two views of ONE
## value: both go through [method set_territory_color] /
## [method set_territory_type] into the same two [Settings] keys, so they
## cannot disagree.

## The window's own title line — entry 1.
const TITLE := "Duel Options"

## Entry 2 and its two choices (entries 3-4).
const LAYOUT_LABEL := "Layout"
const LAYOUT_STANDARD := "Standard"
const LAYOUT_ADVANCED := "Advanced"

## Entries 10-15: the colour list, `Deck color` last as the table has it.
const TERRITORY_COLORS: Array[String] = [
	"White", "Blue", "Black", "Red", "Green", "Deck color",
]

## Entries 16-18: the art-style list — `Duel.hlp`'s *"different types of
## background art available for each color"*, in the string table's order.
##
## Each row carries three things beside its label, so the mapping from a
## 1997 word to a file to a way of drawing it is stated exactly once:
##  - `suffix` — the original's own filename suffix
##    (`Program/DuelArt/Terr_<Colour><Type>.pic`). `Magic.exe`'s string
##    table holds `pict patt mana` as a table of three, right after
##    `TERR_BLACK TERR_WHITE TERR_GREEN TERR_BLUE TERR_RED` and the format
##    `%s\%s.pic`, which is how the game builds the name.
##  - `key` — our skin key stem, so `Pattern` on green is
##    `duel_pattern_green` (see [method ground_key]). Spelled out rather
##    than reusing `suffix`, because `duel_pattern_*` was imported under
##    that name long before the other two joined it and a key is a
##    filename on a player's disk.
##  - `wallpaper` — TRUE for the two that REPEAT and false for the one
##    that does not. This is the distinction `game/duel/opening_window.gd`
##    draws for `Winbk_Startduel`: a picture's middle stretches rather
##    than repeats, and it must keep its own aspect or the art is visibly
##    squashed. [TerritoryGround] is where it is acted on.
const TERRITORY_TYPES: Array[Dictionary] = [
	{"label": "Line drawing", "suffix": "pict", "key": "picture",
		"wallpaper": false},
	{"label": "Pattern", "suffix": "patt", "key": "pattern",
		"wallpaper": true},
	{"label": "Mana symbols", "suffix": "mana", "key": "mana",
		"wallpaper": true},
]

## The five toggles (entries 5-9), each with the registry value it writes
## and its 1997 default. `live` is false for one we list but cannot yet
## honour — the original greys what it cannot offer rather than shortening
## its menu (`Duel.hlp`, **Territory**), and [TerritoryMenu] already
## follows that rule.
const TOGGLES: Array[Dictionary] = [
	# `ShowCoinFlips` is the one entry in this table whose stored value is
	# NOT a plain bool any more — see [method coin_flip_style]. The
	# checkbox is still the checkbox; it is a two-position view of a
	# three-position value, and [method toggle] hides that from callers.
	{"label": "Show coin flip animations", "key": "ShowCoinFlips",
		"default": true, "live": true},
	{"label": "Show cue cards", "key": "ShowCueCards",
		"default": true, "live": true},
	{"label": "Show abilities on small cards", "key": "ShowAbilitiesOnCards",
		"default": true, "live": true},
	{"label": "Show power/toughness on small cards",
		"key": "ShowPowerToughnessOnCards", "default": true, "live": true},
	{"label": "See next draws at end of duel",
		"key": "SeeNextDrawsAtEndOfDuel", "default": true, "live": true},
]

## THE THREE DISPLAY TOGGLES THE MINI-MENUS CARRY, which are NOT in
## `@DIALOG_DUELOPTIONS` — they live on `@MENU_TERRITORY` (entries 18-20)
## and again on `@MENU_SMALLCARD` (entries 5-7), with their Windows
## accelerators written into the strings. They are settings all the same,
## so they are persisted here beside the panel's, under the same
## `Software\MicroProse\Magic: The Gathering` key names the 1997
## executable uses — `ShowIDTagsOnCards`, `ShowInvisibleEffectCards` and
## `ShowAllCardsSummonSickness` are all in `Program/Magic.exe`'s own
## string table.
##
## `Duel.hlp`, topic **Territory**, on each:
##  - **Show ID Tags** — *"toggles the display of each card's unique ID
##    code. This can be useful when you need to determine exactly which of
##    several otherwise identical cards is the target of a specific spell
##    or effect."*
##  - **Show Invisible Effects** — *"toggles the appearance of those effect
##    cards (the temporary yellow cards that pop up all the time) that are
##    not normally displayed."*
##  - **Show all cards' summoning sickness** — no help entry of its own,
##    and the KEY is what explains it: `ShowAllCardsSummonSickness`. It is
##    not an on/off switch for the spiral (which is how `docs/duel-todo.md`
##    §6.3 read it) — it is *all cards*, i.e. whether the mark appears on
##    permanents that are not creatures. Summoning sickness reaches every
##    permanent in this engine (CR 302.6 and the pre-Sixth artifact rule
##    the original played under), so the data was always there and only
##    the drawing was filtered.
##
## All three default OFF, which is the view the duel has today.
const MENU_TOGGLES: Array[Dictionary] = [
	{"label": "Show ID tags", "accel": "Ctrl+T", "key": "ShowIDTagsOnCards",
		"default": false, "live": true},
	{"label": "Show invisible effects", "accel": "Ctrl+I",
		"key": "ShowInvisibleEffectCards", "default": false, "live": false},
	{"label": "Show all cards' summoning sickness", "accel": "Ctrl+U",
		"key": "ShowAllCardsSummonSickness", "default": false, "live": true},
]


## Label above the two lists — entry 9 in the table.
##
## THE STRING CARRIES NO COLON, checked twice (2026-09-02): `UIStrings.txt`
## line 609 is `Your &territory background` and nothing else — the hex is
## `59 6f 75 72 20 26 … 64 0a`, straight from `d` to the newline — and
## `Magic.exe`'s own UTF-16 dialog resource holds the same 26 characters.
## An earlier comment here said it was *"printed with a colon in the
## original's dialog resource"*; it is not. The colon the panel draws is
## OURS, added by the caller the same way `Layout:` is, and it is a
## rendering habit rather than a quotation — which is why it lives at the
## draw site and not in this constant.
const TERRITORY_LABEL := "Your territory background"

## `Deck color` — the behaviour we had before this panel existed, and the
## default, because [DuelConfig.apply_deck_colors] is what has always
## dressed the table.
const DECK_COLOR := "Deck color"


## Read one toggle — the panel's five or the mini-menus' three. Unknown
## keys answer with `true`, which is every 1997 default in
## `@DIALOG_DUELOPTIONS`: the original ships with all five switches ON.
## The three mini-menu toggles carry their own defaults (all off) and are
## found here, so a caller never has to know which table a key came from.
static func toggle(key: String) -> bool:
	if key == COIN_FLIP_KEY:
		# The 1997 checkbox is the two-position VIEW of a three-position
		# value: ticked means the toss is acted out, by either of the two
		# animated modes. See [method coin_flip_style].
		return coin_flip_style() != COIN_INSTANT
	for row in TOGGLES + MENU_TOGGLES:
		if row["key"] == key:
			return bool(Settings.get_value(key, row["default"]))
	return true


## Is this toggle one we can actually honour? The original *"greys what it
## cannot offer"* (`Duel.hlp`, **Territory**), so a menu asks this rather
## than dropping the entry.
static func menu_toggle_live(key: String) -> bool:
	for row in MENU_TOGGLES:
		if row["key"] == key:
			return bool(row["live"])
	return false


## The accelerator a toggle's menu entry shows — `Ctrl+T` / `Ctrl+I` /
## `Ctrl+U`, the `accel` the 1997 strings write after their tab
## (`UIStrings.txt:927-929`), now that [DuelScreen] honours them (§6.3a).
## A DARK command keeps none: its key does nothing, and a menu that
## advertises a shortcut it does not honour is worse than one that stays
## quiet. `KEY_NONE` for a dark or unknown key.
static func menu_toggle_accelerator(key: String) -> Key:
	for row in MENU_TOGGLES:
		if row["key"] == key and bool(row["live"]):
			var letter := String(row["accel"]).get_slice("+", 1)
			return (KEY_MASK_CTRL | OS.find_keycode_from_string(letter)) as Key
	return KEY_NONE


static func set_toggle(key: String, on: bool) -> void:
	if key == COIN_FLIP_KEY:
		# Unticking parks the value on `instant`; reticking returns it to
		# the DEFAULT presentation rather than to whatever animated mode
		# was last picked. There is deliberately nowhere to remember that
		# — a second key would be the parallel copy this panel's contract
		# forbids — and 1997 had no memory here either: its `ShowCoinFlips`
		# was a bare 0/1. A player who wants the original's movie back
		# re-picks it on the Options screen.
		set_coin_flip_style(COIN_FLIP_DEFAULT if on else COIN_INSTANT)
		return
	Settings.set_value(key, on)


# ----------------------------------------- how the coin toss is presented --
#
# `[QoL]`, and a SUPERSET of the 1997 switch rather than a replacement for
# it. The original's `Show coin flip animations` gated ONE thing: whether
# the pre-rendered movie played. It is a bool in the registry and a
# checkbox in this panel, and both stay exactly that.
#
# What we add is a choice between two ways of acting the toss out, because
# only one of them is available to most players: the original's footage is
# `COINTOSS_Heads.AVI` / `COINTOSS_Tails.AVI`, which ship with the 1997
# game and with nothing else (no reference tree carries them), so the
# recreation has to be the default and the movie has to be an upgrade.
# [CoinToss] carries the whole provenance and does the presenting.
#
# ONE STORED VALUE, TWO VIEWS — the contract this file already states for
# the territory background. The key is the ORIGINAL's own
# (`ShowCoinFlips`, under `Software\MicroProse\Magic: The Gathering\
# DuelOptions`), it holds one of the three style names, and a 1997
# registry export still reads correctly into it because [method
# coin_flip_style] accepts the bool (or the 0/1) the original wrote there.
# The checkbox above is the boolean view; the Options screen is the full
# one; neither keeps a copy.

## The 1997 registry value the three-way lives in.
const COIN_FLIP_KEY := "ShowCoinFlips"

## Mode 1 — the original's two pre-rendered AVIs, transcoded at import
## time (`tools/import_original.py`) and played in the middle of the
## screen, which is where `MCIWndCreateA` put them.
const COIN_VIDEO := "video"

## Mode 2 — our own coin, rising and turning end over end onto the
## winner's colour. A reconstruction, not a port: the 1997 game had no
## coin ART at all, only the movie.
const COIN_RECREATION := "recreation"

## Mode 3 — no animation, just the result. This is also what 1997 did with
## the switch OFF: `coin_flip()`'s third parameter is literally
## `show_dialog_if_animation_is_off` (`shandalar-src/src/manalink.h:266`),
## so the dialog appeared either way.
const COIN_INSTANT := "instant"

## The default — the ORIGINAL'S OWN MOVIE, because a machine that has
## never seen the original does not get it anyway:
## [method CoinToss.effective_style] downgrades `video` to the recreation
## whenever the two sheets are missing, which is every install without an
## imported skin. Defaulting to the recreation instead meant that a player
## who HAD imported the movies still had to go and ask for them.
##
## (It could not be this until 2026-09-03, when the movies became
## importable at all: the coin AVIs are CRAM, not the Indeo the importer
## had assumed, and `decodebin` reads them — see the codec block in
## `tools/import_original.py`.)
const COIN_FLIP_DEFAULT := COIN_VIDEO

## The three, in the order they are offered — most faithful first, so the
## list reads as a ladder down from the original.
const COIN_FLIP_STYLES: Array[Dictionary] = [
	{"key": COIN_VIDEO, "label": "The original's video",
		"blurb": "The two pre-rendered movies the 1997 game played, "
			+ "COINTOSS_Heads.AVI and COINTOSS_Tails.AVI. Needs the "
			+ "original game imported."},
	{"key": COIN_RECREATION, "label": "Our coin animation",
		"blurb": "The coin rises, turns end over end and lands on the "
			+ "winning seat's colour. Our reconstruction — the 1997 game "
			+ "shipped no coin art, only the movie."},
	{"key": COIN_INSTANT, "label": "Instant — the result only",
		"blurb": "No animation: the coin is already down, and a pointer "
			+ "says whose half of the table won."},
]


## How the opening toss is presented — one of [constant COIN_VIDEO],
## [constant COIN_RECREATION], [constant COIN_INSTANT].
##
## READS THE 1997 VALUE TOO. `ShowCoinFlips` was a bare 0/1 in the
## original's registry, and the whole reason this project keeps the
## original's key spellings is that such an export should drop straight
## into `user://settings.cfg`. So a stored bool or int is accepted and
## mapped: on → the default animated mode, off → instant. Anything
## unrecognised answers with the default rather than erroring, exactly as
## [method territory_type_row] does.
static func coin_flip_style() -> String:
	var raw: Variant = Settings.get_value(COIN_FLIP_KEY, COIN_FLIP_DEFAULT)
	if typeof(raw) == TYPE_BOOL:
		return COIN_FLIP_DEFAULT if bool(raw) else COIN_INSTANT
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		return COIN_FLIP_DEFAULT if float(raw) != 0.0 else COIN_INSTANT
	return _coin_flip_style_or_default(String(raw))


## Set the presentation. An unknown name is refused into the default, so
## nothing can write a style the game cannot show.
static func set_coin_flip_style(style: String) -> void:
	Settings.set_value(COIN_FLIP_KEY, _coin_flip_style_or_default(style))


## One row of [constant COIN_FLIP_STYLES] by its key, or `{}`.
static func coin_flip_style_row(style: String) -> Dictionary:
	for row in COIN_FLIP_STYLES:
		if row["key"] == style:
			return row
	return {}


static func _coin_flip_style_or_default(style: String) -> String:
	return style if not coin_flip_style_row(style).is_empty() \
		else COIN_FLIP_DEFAULT


## The layout: `Standard` or `Advanced`.
##
## SIMPLIFIED: only Standard is built. Advanced removes the permanent
## Showcase and re-flows the whole table around the space, which is a
## screen-layout milestone rather than a switch; the entry is therefore
## listed and DISABLED. Ledgered in `docs/ROADMAP.md`.
static func layout() -> String:
	return String(Settings.get_value("Layout", LAYOUT_STANDARD))


## Which colour the player's own territory is painted in, or `Deck color`
## for the original's default of following the deck.
static func territory_color() -> String:
	return String(Settings.get_value("PlayerTerritoryColor", DECK_COLOR))


static func set_territory_color(name: String) -> void:
	Settings.set_value("PlayerTerritoryColor", name)


## Which of the three art styles the territory wears.
static func territory_type() -> String:
	return String(Settings.get_value("PlayerTerritoryType", "Pattern"))


static func set_territory_type(name: String) -> void:
	Settings.set_value("PlayerTerritoryType", name)


## One row of [constant TERRITORY_TYPES] by its 1997 label. An unknown
## label answers with `Pattern`, which is what an unreadable
## `PlayerTerritoryType` should fall back to: the middle of the three, and
## the style the table wore before this list was offered.
static func territory_type_row(type_label: String) -> Dictionary:
	for row in TERRITORY_TYPES:
		if row["label"] == type_label:
			return row
	return TERRITORY_TYPES[1]


## The skin key for one of the nine choices: `duel_<style>_<colour>`, e.g.
## `duel_pattern_green`, `duel_picture_red`, `duel_mana_black`. All
## fifteen are in `tools/import_original.py`'s MANIFEST (its territory
## block records what each of the three files actually is).
##
## PURE — no skin lookup, so it answers the same in a headless test as on
## a machine with the 1997 art. Whether that art is PRESENT is
## [TerritoryGround]'s question, and its answer is a derived ground rather
## than a substitute style: falling back from `Line drawing` to `Pattern`
## would silently show the player a style they did not choose.
static func ground_key(color_name: String, type_label := "") -> String:
	return "duel_%s_%s" % [
		String(territory_type_row(type_label)["key"]), color_name]


## Which colour a seat's territory should be painted, given the seat's deck
## colour. The player's own answers to `PlayerTerritoryColor`; the
## opponent's never does — *"You cannot do anything to change the
## background in your opponent's territory; it matches the predominant
## color in her deck."*
static func ground_color_for(pid: int, human_seat: int, deck_color: String) -> String:
	if pid != human_seat:
		return deck_color
	var chosen := territory_color()
	if chosen == DECK_COLOR:
		return deck_color
	return chosen.to_lower()


## BUILD THE WINDOW. Returns an [OriginalDialog] carrying the whole table,
## already wired: every control writes its [Settings] key the moment it is
## touched (*"These settings are retained for future duels"* — there is no
## Apply in the original either), and [signal OriginalDialog.closed] tells
## the caller to redress the table.
##
## `Duel Options...` is entry 17 of `@MENU_TERRITORY`, so this opens from
## a right-click on either territory, which is where the 1997 player found
## it.
##
## The layout follows the original's own dialog: the five checkboxes in a
## column under the Layout radio pair, then the territory box "in the
## lower portion of the window" with its two lists side by side.
static func window() -> OriginalDialog:
	var dialog := OriginalDialog.create(TITLE, Vector2(430, 470),
		"panel_dark_stone")
	var box := dialog.body()

	# &Layout: two mutually exclusive choices, which is a radio pair.
	box.add_child(OriginalDialog.label(LAYOUT_LABEL + ":", 14, true))
	var layout_row := HBoxContainer.new()
	layout_row.add_theme_constant_override("separation", 12)
	var group := ButtonGroup.new()
	for name in [LAYOUT_STANDARD, LAYOUT_ADVANCED]:
		var pick := CheckBox.new()
		pick.text = name
		pick.button_group = group
		pick.button_pressed = layout() == name
		pick.add_theme_color_override("font_color", OriginalDialog.CHOICE)
		# Advanced is listed and dark — see [method layout].
		pick.disabled = name == LAYOUT_ADVANCED
		pick.toggled.connect(func(on: bool) -> void:
			if on:
				Settings.set_value("Layout", name))
		layout_row.add_child(pick)
	box.add_child(layout_row)

	for row in TOGGLES:
		var check := CheckBox.new()
		check.text = String(row["label"])
		check.button_pressed = toggle(String(row["key"]))
		check.add_theme_color_override("font_color", OriginalDialog.CHOICE)
		check.disabled = not bool(row["live"])
		var key := String(row["key"])
		check.toggled.connect(func(on: bool) -> void: set_toggle(key, on))
		box.add_child(check)

	box.add_child(OriginalDialog.label(TERRITORY_LABEL + ":", 14, true))
	var lists := HBoxContainer.new()
	lists.add_theme_constant_override("separation", 16)
	var colors := OptionButton.new()
	for i in TERRITORY_COLORS.size():
		colors.add_item(TERRITORY_COLORS[i], i)
	colors.selected = maxi(0, TERRITORY_COLORS.find(territory_color()))
	colors.item_selected.connect(func(index: int) -> void:
		set_territory_color(TERRITORY_COLORS[index]))
	lists.add_child(colors)
	var types := OptionButton.new()
	for i in TERRITORY_TYPES.size():
		types.add_item(String(TERRITORY_TYPES[i]["label"]), i)
	types.selected = maxi(0, _type_index(territory_type()))
	types.item_selected.connect(func(index: int) -> void:
		set_territory_type(String(TERRITORY_TYPES[index]["label"])))
	lists.add_child(types)
	box.add_child(lists)

	# `@DIALOGBUTTONS` names exactly three buttons in the whole 1997 game,
	# and a settings window that applies as you go needs only the one.
	dialog.add_button("OK").pressed.connect(dialog.dismiss)
	return dialog


static func _type_index(label: String) -> int:
	for i in TERRITORY_TYPES.size():
		if TERRITORY_TYPES[i]["label"] == label:
			return i
	return 1   # Pattern — see [method territory_type_row]

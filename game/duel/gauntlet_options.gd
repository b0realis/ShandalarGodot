class_name GauntletOptions
extends RefCounted
## THE GAUNTLET'S PARAMETERS — `@DIALOG_GAUNTLETOPTIONS`
## (`Program/UIStrings.txt:620-632` = `s30/assets/text/Uistrings.txt:620-632`,
## the two copies are aligned to line 1183), eleven strings and every one
## of them below:
##
##     Gauntlet Options
##     Difficulty
##     Match Size / Best of &Three / Best of &One
##     A&nte
##     Enemy Level / &Apprentice / &Magician / &Sorcerer / &Wizard
##
## WHICH GAUNTLET THIS IS. The sources describe TWO configuration screens
## and they disagree (`docs/gauntlet-design.md` §5.1): the shell's page
## (`@SHELLPAGE_GAUNTLET`, with `&Num opponents:`, a `&Best of:` SPINNER
## and a five-band computed difficulty) and the duel program's own
## (`@DIALOG_GAUNTLETSTARTUP` + this dialog, with two Match Sizes, four
## Enemy Levels and a hard cap of twenty opponents). **This is the second
## one**, which is the design's recommendation and the owner's decision to
## reverse if he wants the other: it is the one the Tier 2 decompilation
## implements, so every behaviour behind it can be CHECKED rather than
## reconstructed, and its Match Size pair is the one the manual describes
## in prose (p.156).
##
## PLUS TWO CONTROLS FROM THE SHELL PAGE, `[QoL]` and deliberate
## (`docs/gauntlet-design.md` §5.4). `&Num opponents:`
## (`Program/UIStrings.txt:69`) and `Side&board between duels` (`:72`)
## belong to the page we are NOT building; splitting one run's parameters
## across a modal and a screen we do not have would be fidelity to
## nothing. `&Num opponents:` in particular is the one parameter whose
## absence would hurt — a run whose length is "however many files are in
## the folder" is not a design, it is an accident of the filesystem.
##
## WHAT THIS CLASS IS. A run's parameters plus the window that sets them —
## the shape [DuelOptions] has, one level up. It is a [RefCounted] with no
## Node in it so the table, the defaults and the difficulty arithmetic are
## all testable headless; only [method window] touches the scene tree.
## Unlike [DuelOptions] these are NOT [Settings] keys: `Duel.hlp` says the
## duel options *"are retained for future duels"* and nothing says that
## about a gauntlet's, and the mode deliberately keeps nothing between
## runs (`docs/gauntlet-design.md` §1.6).

## Entry 1 — the window's own line.
const TITLE := "Gauntlet Options"
## Entry 2. A READOUT, not a setting — see [method difficulty].
const DIFFICULTY := "Difficulty"
## Entries 3-5.
const MATCH_SIZE := "Match Size"
const BEST_OF_THREE := "Best of Three"
const BEST_OF_ONE := "Best of One"
## Entry 6. Also a difficulty input — manual p.138: *"ANTE is a checkbox
## that determines whether you play each duel for an ante card. Playing
## for ante adds 1 to the Difficulty."*
const ANTE := "Ante"
## Entries 7-11. [AiProfile] already ships all four under these names.
const ENEMY_LEVEL := "Enemy Level"
const ENEMY_LEVELS: Array[String] = ["Apprentice", "Magician", "Sorcerer",
	"Wizard"]

# The two borrowed from `@SHELLPAGE_GAUNTLET` (`Program/UIStrings.txt:58-75`
# = `s30/assets/text/Uistrings.txt:58-75`), verbatim.
const NUM_OPPONENTS := "Num opponents:"
const SIDEBOARD := "Sideboard between duels"
const YOUR_DECK := "Your deck:"
## Entry 3 of the same page, and the same string the battle-setup screen's
## deck list already opens with.
const RANDOM_DECK := "<random deck>"
## Entry 15 — the button that starts the run.
const RUN := "Run the gauntlet"
## `&Create Deck...`, `@DIALOG_GAUNTLETSTARTUP` entry 13
## (`Program/UIStrings.txt:648` = `s30/assets/text/Uistrings.txt:648`) —
## the startup screen's own door into the Deck Builder, and the reason
## `&Num opponents:` has anything to count. It sits before `E&xit`, which
## is where the original lists it.
const CREATE_DECK := "Create Deck..."
## `E&xit`, `@DIALOG_GAUNTLETSTARTUP` entry 15 — the way back out.
const EXIT := "Exit"

## `Gauntlet difficulty: %3d (%s)` — entry 4 of the shell page, a number
## with a band name beside it.
const READOUT := "Gauntlet difficulty: %3d (%s)"
## Entries 5-9, the five bands, in the original's order. (Its fifth is
## written `very hard ` with a trailing space; trimmed here.)
const BANDS: Array[String] = ["very easy", "easy", "normal", "hard",
	"very hard"]

## `Best of &Three` / `Best of &One` -> [member MatchState.best_of], which
## turns them into the 2 and the 1 the decompiled `DUEL.EXE` sets
## wins-needed to (dialog `0xe8`, controls `0x456`/`0x457`), because
## [method MatchState.wins_needed] is already `best_of / 2 + 1`.
const MATCH_SIZES: Array[int] = [3, 1]

## `Match Size`. Three is listed first in the original and is the manual's
## *"two out of three contest"*.
var best_of := 3
## `A&nte`. On, as the battle-setup screen's own checkbox is: Shandalar
## plays for keeps (manual p.165).
var ante := true
## `Enemy Level`, an index into [constant ENEMY_LEVELS]. Wizard, which is
## what the battle-setup screen defaults its AI seat to.
var enemy_level := 3
## `&Num opponents:`. 0 = every deck there is, which is the original's own
## length (`min(decks on disk, 20)`); anything else shortens the run.
## [GauntletState.shuffle] holds the cap.
var num_opponents := 0
## `Side&board between duels`.
var sideboard_between_duels := false
## The path of YOUR deck, or "" for `<random deck>`.
var your_deck := ""


## A deck file's own name — what `Your next duel is against %s.`
## (`@GAUNTLET` entry 5) prints, and what the deck picker lists. Falls
## back to the file's stem, which is all a 1997 `.dck` could show.
static func deck_title(path: String) -> String:
	var list := DeckList.load_file(path, false)
	if list.deck_name.strip_edges() != "":
		return list.deck_name
	return path.get_file().get_basename()


## WIDEN A DIALOG BUTTON TO ITS OWN LABEL. [method OriginalDialog.button]
## floors a button at 96px — the width `OK` and `Cancel` want — and the
## 1997 art it wears is a DOUBLE rule 8px deep on each side. A label as
## long as `Run the gauntlet` overran both: the screenshot pass caught its
## last letter sitting ON the inner rule, with every test green and
## `visible == true`. Measured off the button's own font rather than
## guessed at, so a skin with a different face cannot break it again.
static func fit(button: Button) -> Button:
	var font := button.get_theme_font("font")
	if font == null:
		return button
	var wide := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, button.get_theme_font_size("font_size")).x \
		+ 2.0 * OriginalDialog.BUTTON_MARGIN + 8.0
	button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, wide)
	return button


## The [AiProfile] for an [constant ENEMY_LEVELS] index — the four the
## original names, which this project has shipped under those names since
## the AI landed (`engine/ai/ai_profile.gd`).
static func profile(level: int) -> AiProfile:
	match clampi(level, 0, 3):
		0:
			return AiProfile.apprentice()
		1:
			return AiProfile.magician()
		2:
			return AiProfile.sorcerer()
		_:
			return AiProfile.wizard()


## `Gauntlet difficulty: %3d (%s)` — THE NUMBER IS OURS. `[QoL]`.
##
## The original computed one and we have the format string, the five band
## names and exactly one input rule for it (manual p.138, *"Playing for
## ante adds 1 to the Difficulty"*); the shell binary that computes the
## rest is not in the decompilation, so the formula, its range and its
## band boundaries are not recoverable. `docs/gauntlet-design.md` §5.2
## weighs omitting the readout against inventing one and takes the second,
## because the readout is the only thing that tells a player their choices
## have a cost — and the words at least are MicroProse's.
##
## Everything but the ante term is mine:
##
##     enemy level (0..3) x 3      Apprentice 0 … Wizard 9
##   + ante ? 1 : 0                manual p.138, verbatim
##   + best of one ? 2 : 0         one duel is swingier than two of three
##   + opponents / 4               a longer run is a harder run
static func difficulty(level: int, playing_for_ante: bool, size: int,
		opponents: int) -> int:
	return clampi(level, 0, 3) * 3 \
		+ (1 if playing_for_ante else 0) \
		+ (2 if size == 1 else 0) \
		+ int(maxi(opponents, 0) / 4)


## The band a difficulty falls in — 0-2 `very easy`, 3-5 `easy`, 6-8
## `normal`, 9-11 `hard`, 12+ `very hard`. Ours, with the original's words.
static func band(value: int) -> String:
	return BANDS[clampi(int(value / 3), 0, BANDS.size() - 1)]


## The whole readout line, as the shell page writes it.
func readout(opponents: int) -> String:
	var value := difficulty(enemy_level, ante, best_of, opponents)
	return READOUT % [value, band(value)]


# ------------------------------------------------------------ the window --

## The Gauntlet Options window, in the original's own order: the deck, the
## Match Size pair, the two checkboxes, the four Enemy Levels, the run
## length, and the difficulty readout under all of them — a readout goes
## below the things it reads.
##
## [param decks] is the deck files to offer, [param on_run] is called with
## nothing when `Run the gauntlet` is pressed, [param on_exit] when `Exit`
## is, and [param on_create] — if it was given one — when `Create Deck...`
## is. The window writes straight into this object as the player clicks,
## exactly as [method DuelOptions.window] writes into [Settings], so there
## is no "apply" step to get wrong.
##
## [param on_create] is OPTIONAL because this window is also raised by
## tests and by anything that has no scene tree to change: an unset
## [Callable] means the button is simply not offered, which is the same
## answer §6.1 gives every command we cannot honour, one step further
## along — a button that leads nowhere is worse than no button.
func window(decks: Array[String], on_run: Callable, on_exit: Callable,
		on_create := Callable()) -> OriginalDialog:
	# Measured against the content, not guessed: nine rows and a foot,
	# which the screenshot pass fitted to 450 with the stone still
	# reading as a window rather than a wall.
	var dialog := OriginalDialog.create(TITLE, Vector2(470, 450),
		"panel_dark_stone")
	var box := dialog.body()
	var readout_label := OriginalDialog.label("", 15, true)
	readout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The era's own numeric field — a bevel run BACKWARDS, cut into the
	# stone ([method OriginalDialog.field]), which is what the 1997
	# dialogs that ask for an amount wear.
	var opponents := OriginalDialog.field(90.0)

	var refresh := func() -> void:
		readout_label.text = readout(_run_length(decks.size(),
			int(opponents.value)))

	# `&Your deck:` and its `<random deck>` — the shell page's first two
	# entries, and the one choice the gauntlet leaves the player. The
	# OPPONENT's picker is deliberately absent: the decompiled startup
	# screen DISABLES its opponent combo and `Pick a deck` whenever
	# `&Gauntlet` is chosen (controls `0x463`/`0x468`), because in a
	# gauntlet you do not choose who you meet.
	box.add_child(OriginalDialog.label(YOUR_DECK, 14, true))
	var deck_list := OptionButton.new()
	# CLIPPED, not free to grow. An OptionButton sizes itself to its
	# widest entry, and a deck title long enough to outgrow the panel
	# would push the whole column past the window's edge — a layout bug a
	# passing test cannot see.
	deck_list.clip_text = true
	deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_list.add_item(RANDOM_DECK)
	deck_list.set_item_metadata(0, "")
	# GROUPED BY PROVENANCE, a labelled separator per heading, exactly as
	# the battle setup screen's picker is ([DeckGroups]) — the list grew
	# from five decks to near two hundred on 2026-09-02 and its headings
	# are what tells a Kevin Bane deck from a 1997 enemy's. `<random
	# deck>` stays above every heading: it is the choice not to choose.
	var by_group := DeckGroups.grouped(decks)
	for group in by_group:
		deck_list.add_separator(group)
		for path in by_group[group]:
			deck_list.add_item(deck_title(path))
			deck_list.set_item_metadata(deck_list.item_count - 1, path)
	deck_list.select(0)
	deck_list.item_selected.connect(func(index: int) -> void:
		your_deck = String(deck_list.get_item_metadata(index)))
	box.add_child(deck_list)

	# `Match Size`: two mutually exclusive choices, so a radio pair.
	box.add_child(OriginalDialog.label(MATCH_SIZE, 14, true))
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 12)
	var size_group := ButtonGroup.new()
	for i in MATCH_SIZES.size():
		var pick := CheckBox.new()
		pick.text = BEST_OF_THREE if MATCH_SIZES[i] == 3 else BEST_OF_ONE
		pick.button_group = size_group
		pick.button_pressed = best_of == MATCH_SIZES[i]
		pick.add_theme_color_override("font_color", OriginalDialog.CHOICE)
		var length: int = MATCH_SIZES[i]
		pick.toggled.connect(func(on: bool) -> void:
			if on:
				best_of = length
				refresh.call())
		sizes.add_child(pick)
	box.add_child(sizes)

	var ante_check := CheckBox.new()
	ante_check.text = ANTE
	ante_check.button_pressed = ante
	ante_check.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	ante_check.toggled.connect(func(on: bool) -> void:
		ante = on
		refresh.call())
	box.add_child(ante_check)

	var sideboard_check := CheckBox.new()
	sideboard_check.text = SIDEBOARD
	sideboard_check.button_pressed = sideboard_between_duels
	sideboard_check.add_theme_color_override("font_color",
		OriginalDialog.CHOICE)
	sideboard_check.toggled.connect(func(on: bool) -> void:
		sideboard_between_duels = on)
	box.add_child(sideboard_check)

	# `Enemy Level`, four radios in one group.
	box.add_child(OriginalDialog.label(ENEMY_LEVEL, 14, true))
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 10)
	var level_group := ButtonGroup.new()
	for i in ENEMY_LEVELS.size():
		var pick := CheckBox.new()
		pick.text = ENEMY_LEVELS[i]
		pick.button_group = level_group
		pick.button_pressed = enemy_level == i
		pick.add_theme_color_override("font_color", OriginalDialog.CHOICE)
		var index := i
		pick.toggled.connect(func(on: bool) -> void:
			if on:
				enemy_level = index
				refresh.call())
		levels.add_child(pick)
	box.add_child(levels)

	# `&Num opponents:` — a spinner on the original's page too. 0 is our
	# spelling of "all of them", which is the length the original always
	# ran at.
	var length_row := HBoxContainer.new()
	length_row.add_theme_constant_override("separation", 8)
	length_row.add_child(OriginalDialog.label(NUM_OPPONENTS, 14, true))
	opponents.min_value = 0
	opponents.max_value = mini(decks.size(), GauntletState.MAX_OPPONENTS)
	opponents.value = num_opponents
	opponents.value_changed.connect(func(_v: float) -> void:
		num_opponents = int(opponents.value)
		refresh.call())
	length_row.add_child(opponents)
	length_row.add_child(OriginalDialog.label(
		"0 = every deck (max %d)" % GauntletState.MAX_OPPONENTS, 13))
	box.add_child(length_row)

	box.add_child(readout_label)
	refresh.call()

	fit(dialog.add_button(RUN)).pressed.connect(func() -> void:
		dialog.dismiss()
		on_run.call())
	if on_create.is_valid():
		fit(dialog.add_button(CREATE_DECK)).pressed.connect(func() -> void:
			dialog.dismiss()
			on_create.call())
	fit(dialog.add_button(EXIT)).pressed.connect(func() -> void:
		dialog.dismiss()
		on_exit.call())
	return dialog


## How long the run will actually be: [member num_opponents] if it was
## set, else every deck available, and never more than the twenty the
## original's own buffer holds.
func _run_length(available: int, chosen: int) -> int:
	var want := available if chosen <= 0 else chosen
	return mini(mini(want, available), GauntletState.MAX_OPPONENTS)


## [method _run_length] for a caller that has only the deck count — the
## screen asks this to size its run.
func run_length(available: int) -> int:
	return _run_length(available, num_opponents)

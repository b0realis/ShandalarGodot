class_name SetupScreen
extends Control
## The battle-setup screen: everything about the duel is decided HERE,
## then "Go" starts it (or "Back" returns to the title) — the flow the
## original's start-duel dialog served, dressed in its own backdrop
## (Winbk_Startduel) and stone panels.
##
## Choices: battle mode (hotseat / vs AI / AI-vs-AI demo), per-seat deck
## (every deck in decks/ that loads strictly, or `<random deck>`), name,
## starting life, AI difficulty for AI seats, and the demo's watchable
## pace. Everything lands in one DuelConfig handed to the duel screen.
##
## DETERMINISM. "Go" resolves the duel's RNG seed FIRST and puts it in the
## config, then makes every random choice this screen owns off an RNG
## seeded from it. So a seed does not merely replay the shuffles — it
## replays which decks `<random deck>` chose as well, and a duel is
## reproducible from its logged seed alone.
##
## THIS SCREEN IS A DOOR INTO A DUEL, which means it is one of the places
## the [ProxyCard] boundary is held. A deck holding proxies is LISTED here
## (marked, and with the names on its tooltip) but refused twice over:
## once live, on the note under the picker, and again on `Go!` before any
## config is handed over. `<random deck>` never draws one. See
## [method _scan_decks] for the two lists that make that true.

enum BattleMode { HOTSEAT, VS_AI, DEMO }

var _mode := BattleMode.VS_AI
var _mode_buttons: Array[Button] = []
## What an unnamed AI seat is called. The owner's pick, and it does the
## job the old "AI <skill>" label did badly: a name that cannot lie about
## which pilot the duel will actually get, because it does not claim a
## skill at all. Two of them, because AI Demo seats both sides — and the
## second is the sequel, not the same machine twice.
const AI_NAMES := ["HAL 9000", "HAL 9001"]

## The settings panel's MINIMUM width — the content usually asks for more
## and gets it ([method _fit_panel]) — and the breathing room around it.
## The margin is the Options screen's number: the two screens are the same
## shape of thing and a player moves between them.
const PANEL_WIDTH := 760.0
const PANEL_MARGIN := 12.0

var _panel: Control
var _panel_content: Control

var _deck_options: Array[OptionButton] = []
var _name_edits: Array[LineEdit] = []
var _life_spins: Array[SpinBox] = []
var _difficulty_options: Array[OptionButton] = []
## Their labels, kept so they can be hidden with them.
var _difficulty_labels: Array[Label] = []
## The chosen-portrait row under each duelist face.
var _portrait_rects: Array[TextureRect] = []
var _portrait_captions: Array[Label] = []
var _portrait_arrows: Array = []
## `Back` / `Go!`, pinned under the scroller rather than in it.
var _action_row: Control
var _pace_slider: HSlider
var _pace_row: HBoxContainer
## `&Ante` — the original's match parameter, ticked by default.
var _ante_check: CheckBox
## `&Free play` / `&Best of:` — the radio pair that decides whether this
## is one duel or a match, and the length when it is one ([MatchState]).
var _free_play: CheckBox
var _best_of_check: CheckBox
var _best_of_option: OptionButton
## `Side&board between duels` — the other match parameter.
var _sideboard_check: CheckBox
## `Opponent:` — the five formats, the radio group at the top of the
## original's screen ([DeckFormat]).
var _format_option: OptionButton
## [QoL] The duel's SEED, typed. Ours — the original had no such field.
var _seed_edit: LineEdit
## The line under the picker: what this format allows, and whether the
## chosen decks pass it.
var _format_note: Label
## Every deck the pickers list, playable or not (see [method _scan_decks]).
var _deck_paths: Array[String] = []
## The subset `<random deck>` may draw from: the decks that load STRICTLY,
## i.e. the ones this screen would not refuse. A seed that could hand a
## seat a deck holding [ProxyCard]s would be a seed that cannot start a
## duel, which is not a choice worth offering.
var _playable_paths: Array[String] = []
## Deck path -> the proxy names it holds, for every listed deck that holds
## any. Worked out once in [method _scan_decks]; the picker's row text and
## its tooltip both read it, and so does the note.
var _proxy_paths: Dictionary = {}
## Deck path -> the `name:` its file declares, for the picker's row text.
## A file name is all the 1997 list could show (an eight-character DOS
## name); ours carry a title, and `Kzzy'n - The Dragon Lord` reads better
## than `Kzzy N The Dragon Lord`. A file with no title is labelled by its
## file name, as before.
var _deck_titles: Dictionary = {}
## `Go!` has been pressed and the duel built. `queue_free()` defers, so a
## second press in the same frame (a double-click, a held Return) used to
## build a second duel under `root` and orphan the first, still running
## (2026-09-02). Once this is set the screen is on its way out and
## presses do nothing.
var _leaving := false
## THE DUELIST'S FACE, per seat — the same 1997 portrait the duel's life
## register flips over to (see [DuelistFace]), shown here because the deck
## you pick IS the duelist you will be.
var _face_rects: Array[TextureRect] = []
var _face_captions: Array[Label] = []
## Deck path -> its dominant colour key, worked out once. Re-deriving it
## on every click of the picker would re-read and re-validate the file.
var _deck_colors: Dictionary = {}

## [QoL] `Your territory background` — the original's own two lists, in a
## place the original never put them. See [method _build_territory_row].
var _territory_color: OptionButton
var _territory_type: OptionButton
var _territory_preview: Control

const DIFFICULTIES := ["Apprentice", "Magician", "Sorcerer", "Wizard"]

## What the four levels mean, for the picker's tooltip — the same
## [AiProfile] presets the Deck Lab's `--profile-a/--profile-b` name, so a
## player and a tester read one description. Kept next to DIFFICULTIES
## because the order is the order.
const DIFFICULTY_TOOLTIP := \
	"How well the AI plays this seat (the same four levels as the Deck " \
	+ "Lab's --profile-a/--profile-b). Every level knows the same plays; " \
	+ "the lower ones fumble more of them.\n" \
	+ "Apprentice: fumbles a third of its plays, never holds instants " \
	+ "open (sorcery-speed Magic), never sideboards.\n" \
	+ "Magician: holds instants and mana for them; counters only the " \
	+ "biggest threats; may sideboard 2 cards.\n" \
	+ "Sorcerer: few mistakes; may sideboard 3 cards.\n" \
	+ "Wizard: no mistakes; may sideboard 4 cards."

## `<random deck>` — the original's own entry, verbatim, and its own place:
## first in the deck list, above the decks themselves
## (`Program/Text.res:2866`, `@SHELLPAGE_MULTIDUEL`, whose `&Your deck:`
## label is the list this sits in). Picking it hands the choice to the
## duel's seed instead of to the player.
const RANDOM_DECK := "<random deck>"

## `<random from …>` — the same choice, POOLED. The 2026-09-05 playtest
## asked for it in one sentence: *"I want to play against AI random decks
## but only from the 1997 original game, nothing else."*
##
## THE POOL IS THE GROUP, and it needed no new control because the list is
## already partitioned by provenance ([method DeckGroups.grouped]): the row
## goes under the heading it draws from, so the pool is named where the
## player is already looking when they want it. Every group gets one, so
## "only Coyote Tex" and "only my own" are the same feature rather than
## eleven decisions.
##
## It rides in the row's METADATA, which is why no index moves: `""` is
## "any deck", a path is "that deck", and this prefix plus a group name is
## "any deck filed there". [method _row_of_deck] skips all three kinds of
## non-deck row.
const GROUP_RANDOM := "group:"

## The duelist portrait's own size — the 120x88 the original drew
## `Life_<colour>pict.pic` at, and the size of the life register it is the
## other side of. Shown at 1:1, never stretched.
const FACE_SIZE := Vector2(120, 88)
## The chosen portrait under it. THE SAME WIDTH as the duelist frame, so
## the seat row — which is what sets this screen's width
## ([method _fit_panel]) — does not grow when a player installs art; the
## height is that width at the original sheet's own 137x169 aspect, so a
## 1997 face fills the box exactly and anything else is fitted into it.
const PORTRAIT_SIZE := Vector2(120, 148)
## Where a seat's chosen portrait is remembered, by ID.
const PORTRAIT_KEY := "Portrait%d"
## What the caption says when the player has no portrait art at all.
const NO_PORTRAITS := "(no portraits)"

## The territory preview beside the two lists: 160 wide at the BOARD
## HALF's own aspect (914x400 = 2.285, measured on the live duel screen at
## 1280x800), so 160 / 2.285 = 70 tall. Anything else would frame a `Line
## drawing` differently here than in the duel.
const TERRITORY_PREVIEW := Vector2(160, 70)


## The shell's bed, carried into this screen — see `_start_music`.
var _music: MusicPlayer

func _ready() -> void:
	_scan_decks()
	_build_ui()
	for pid in 2:
		_update_face(pid)
	_refresh_format_note()
	_apply_mode(BattleMode.VS_AI)
	_start_music()

## THE SHELL'S BED CARRIES INTO THE SETUP SCREEN. Magic Battle is the
## title screen's own next room — you reach it by pressing a button on the
## shell and you go back with `Back` — so falling silent on the way in
## made the menu music read as a title-screen jingle rather than as the
## front of the game (2026-09-05 playtest: *"the magic battle GUI menu
## should have also the same music as main menu"*).
##
## The SAME bed, from [constant MainScreen.MENU_BEDS] via the same
## [method MusicLibrary.single_for], so the two screens cannot drift onto
## different tracks; and [method MusicPlayer.play_one] keys on the track
## id, so this is a fresh start of the same tune rather than a second
## voice over the first. The global `music_enabled` switch is the whole
## rule here, exactly as it is on the shell — the Deck Builder's own
## screen-scoped switch is that screen's and must not reach this one.
func _start_music() -> void:
	GameAudio.apply_settings()
	_music = MusicPlayer.new()
	add_child(_music)
	_apply_music_switch()


func _apply_music_switch() -> void:
	if _music == null:
		return
	if not Settings.music_enabled():
		_music.stop_music()
		return
	_music.play_one(MusicLibrary.single_for(MainScreen.MENU_BEDS))


## Stops on the way out, so the duel starts against silence and the PCM
## is dropped rather than carried — [MainScreen] does the same.
func _exit_tree() -> void:
	if is_instance_valid(_music):
		_music.stop_music()



## Every deck this screen LISTS, from both deck directories — the ones the
## project ships and the ones the Deck Builder saves. DeckStore.all_deck_paths
## is the single list, so a deck saved in the builder is a deck that turns
## up here.
##
## TWO KINDS OF DECK GO IN, and [member _playable_paths] is the difference:
##
##  * a deck that loads STRICTLY is playable, and only those may be drawn
##    by `<random deck>` — the seed must never hand a seat a deck the
##    screen is then going to refuse;
##  * a deck that loads only LENIENTLY, i.e. one holding [ProxyCard]s, is
##    listed anyway, marked, and refused with its reasons the moment it is
##    selected ([method _refresh_format_note]) and again on `Go!`. It is
##    listed rather than hidden because a deck the player built and saved
##    that silently vanished from this list would be a mystery, and the
##    thing they need is the NAMES of the cards to replace.
##
## A file that will not parse at all is in neither list, as before.
func _scan_decks() -> void:
	for path in DeckStore.all_deck_paths():
		var deck := DeckList.load_file(path, true)
		if deck.errors.is_empty() and deck.cards.size() >= 20:
			_deck_paths.append(path)
			_playable_paths.append(path)
			_deck_titles[path] = deck.deck_name
			continue
		var lenient := DeckList.load_file(path, false)
		if lenient.errors.is_empty() and not lenient.proxies.is_empty() \
				and lenient.cards.size() >= 20:
			_deck_paths.append(path)
			_proxy_paths[path] = lenient.proxies
			_deck_titles[path] = lenient.deck_name
	_deck_paths.sort()
	_playable_paths.sort()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := GameSkin.texture("versus_background")
	if backdrop != null:
		var bg := TextureRect.new()
		bg.texture = backdrop
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
	else:
		var flat := ColorRect.new()
		flat.color = Color(0.09, 0.08, 0.07)
		flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(flat)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	# THE PANEL SCROLLS, and it is ANCHORED rather than centred on its own
	# size — the same fix the Options screen already carries, for the same
	# reason. A panel sized by its content and centred cannot be smaller
	# than that content, so a window shorter or narrower than the settings
	# loses BOTH ends of them: the 2026-09-03 playtest saw exactly that
	# ("the gui window of the magic battle settings clips out of the
	# screen"). Anchored to a fixed width and the window's full height
	# minus a margin, the panel is as big as it can be and never bigger,
	# and anything that does not fit scrolls instead of being cut off.
	var scroll := ScrollContainer.new()
	# AUTO, not DISABLED: a window too narrow for the seat boxes must
	# scroll sideways rather than cut them off, which is the whole point.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# GO! IS NOT PART OF THE SCROLL. The settings are a list that grows;
	# the two buttons that leave this screen are not, and when they rode
	# at the bottom of the list they were the first thing a short window
	# cut off — the 2026-09-03 playtest photographed `Back` and `Go!` with
	# their bottom bevel sliced away, and one more row of settings would
	# have hidden them entirely. They sit under the scroller now, inside
	# the panel, always whole and always reachable.
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 10)
	inside.add_child(scroll)
	inside.add_child(_build_action_row())
	var panel := UiChrome.panel_around(inside, 16.0)
	# CENTRED, and capped by the window. Anchored to the middle of the
	# screen on both axes; [method _fit_panel] then gives it the height its
	# settings actually need, or the height there is room for, whichever is
	# smaller — so it is a centred window on a big screen (the owner's ask,
	# 2026-09-03) and a full-height scroller on a small one, and it can
	# never hang off an edge again.
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	# GROW BOTH WAYS. Should anything still ask for more room than
	# [method _fit_panel] gave it, the extra has to come off both sides or
	# the panel walks off centre — which is exactly what happened when the
	# width was a constant.
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -PANEL_WIDTH * 0.5
	panel.offset_right = PANEL_WIDTH * 0.5
	add_child(panel)
	_panel = panel
	_panel_content = content
	# Both the window and the settings themselves can change height (Best
	# of, the format note), so re-fit on either.
	resized.connect(_fit_panel)
	content.minimum_size_changed.connect(_fit_panel)
	_fit_panel()

	var title := UiChrome.body_label("Magic Battle", 26)
	var title_font := GameSkin.font("font_title")
	if title_font != null:
		title.add_theme_font_override("font", title_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	# --- battle mode ---
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair in [["Hotseat", BattleMode.HOTSEAT], ["Duel the AI", BattleMode.VS_AI],
			["AI Demo", BattleMode.DEMO]]:
		var button := Button.new()
		button.text = pair[0]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(150, 36)
		button.pressed.connect(_apply_mode.bind(pair[1]))
		mode_row.add_child(button)
		_mode_buttons.append(button)
	content.add_child(mode_row)

	# --- per-seat configuration ---
	var seats := HBoxContainer.new()
	seats.add_theme_constant_override("separation", 14)
	for pid in 2:
		var seat_row := HBoxContainer.new()
		seat_row.add_theme_constant_override("separation", 10)
		seat_row.add_child(_build_face(pid))
		var seat_box := VBoxContainer.new()
		seat_box.add_theme_constant_override("separation", 6)
		seat_box.custom_minimum_size.x = 300
		seat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seat_row.add_child(seat_box)
		seat_box.add_child(UiChrome.body_label("— Seat %d —" % (pid + 1), 16))

		# `&Your deck:` (`Program/Text.res:2865`) — worded "Deck:" here
		# because this screen sets BOTH seats and "your" would be a lie on
		# one of them.
		seat_box.add_child(UiChrome.body_label("Deck:"))
		var deck_option := OptionButton.new()
		# A LIST IS NOT A LABEL. Godot sizes an OptionButton to its widest
		# ROW (`fit_to_longest_item`, on by default), which was harmless
		# while this picker held five starter decks and became a layout
		# bug the moment the 2026-09-02 port put 318 in it: the longest
		# name is 71 characters, and that one row pushed the seat column,
		# the panel and the whole screen past both edges of the window
		# (2026-09-03 playtest — the left-hand labels were cut off). The
		# full name still reads in the POPUP, which is where a list of 318
		# is read anyway.
		deck_option.fit_to_longest_item = false
		deck_option.clip_text = true
		deck_option.custom_minimum_size.x = 300
		_fill_deck_options(deck_option)
		# Seat 1 defaults to the first deck, seat 2 to the second — the
		# selection this screen has always opened on. Counted in DECKS,
		# not in rows, so neither `<random deck>` nor a group heading can
		# shift it.
		deck_option.select(_row_of_deck(deck_option, pid))
		deck_option.item_selected.connect(func(_i: int) -> void:
			_update_face(pid)
			# `Deck color` follows seat 1's deck, so the preview beside
			# the lists has to follow the picker too.
			_update_territory_preview()
			_refresh_format_note())
		seat_box.add_child(deck_option)
		_deck_options.append(deck_option)

		seat_box.add_child(UiChrome.body_label("Name:"))
		var name_edit := LineEdit.new()
		name_edit.text = "Player %d" % (pid + 1)
		seat_box.add_child(name_edit)
		_name_edits.append(name_edit)

		seat_box.add_child(UiChrome.body_label("Starting life:"))
		var life_spin := SpinBox.new()
		life_spin.min_value = 1
		life_spin.max_value = 400
		life_spin.value = 20
		seat_box.add_child(life_spin)
		_life_spins.append(life_spin)

		# The LABEL is kept, not just added: it has to disappear with the
		# picker it names. A human seat hid the picker and left "AI
		# difficulty:" standing over the gap where it had been (visible in
		# the 2026-09-03 playtest shots of Seat 1).
		var difficulty_label := UiChrome.body_label("AI difficulty:")
		seat_box.add_child(difficulty_label)
		_difficulty_labels.append(difficulty_label)
		var difficulty := OptionButton.new()
		for name in DIFFICULTIES:
			difficulty.add_item(name)
		difficulty.tooltip_text = DIFFICULTY_TOOLTIP
		difficulty.select(3)   # Wizard
		# THE SEAT NAME FOLLOWS THE DIFFICULTY. Nothing was connected here,
		# so the name froze at whatever skill was current when the mode was
		# applied — and `_start_battle` copies that text straight into
		# `DuelConfig.player_names`, while the field is `editable = false`
		# for an AI seat. Choosing Apprentice therefore gave an Apprentice
		# pilot labelled "AI Wizard" for the whole duel, uncorrectably.
		difficulty.item_selected.connect(_on_difficulty_changed)
		seat_box.add_child(difficulty)
		_difficulty_options.append(difficulty)

		seats.add_child(UiChrome.panel_around(seat_row, 10.0))
	content.add_child(seats)
	content.add_child(_build_territory_row())

	# `Opponent:` (`Program/Text.res:2854`) — the original's own label over
	# the five FORMAT radio buttons, which are the first thing its screen
	# asks. It reads oddly out of the multiplayer context it was written
	# for (there it meant "what your opponent may bring"), so the row is
	# labelled with what it actually sets and the 1997 word is kept in
	# this comment rather than put on a control it would confuse.
	var format_row := HBoxContainer.new()
	format_row.add_theme_constant_override("separation", 8)
	format_row.add_child(UiChrome.body_label("Deck format:"))
	_format_option = OptionButton.new()
	for i in DeckFormat.ORDER.size():
		var format: String = DeckFormat.ORDER[i]
		_format_option.add_item(format)
		# The Options screen's own habit: the one-line answer rides as a
		# tooltip so it is available without leaving the screen, and the
		# `?` beside it opens the full explanation.
		_format_option.set_item_tooltip(i, DeckFormat.SUMMARY[format])
	# Unrestricted first, as the original lists it, and it is also the only
	# choice that can never refuse a deck — so the default refuses nothing.
	_format_option.select(0)
	_format_option.item_selected.connect(func(_i: int) -> void: _refresh_format_note())
	format_row.add_child(_format_option)
	var explain := UiChrome.menu_button("?", Vector2(34, 30))
	explain.pressed.connect(_explain_formats)
	format_row.add_child(explain)
	content.add_child(format_row)
	_format_note = UiChrome.body_label("", 13)
	_format_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_format_note.custom_minimum_size.x = 660
	content.add_child(_format_note)

	# `Match parameters` (`Program/Text.res:2860`) — the original's own
	# heading for this group, and the group is its own three: `&Ante`,
	# `&Best of:` and `Side&board between duels`. (Its fourth entry,
	# `Duel &Options...`, is our Options screen and lives on the main menu.)
	content.add_child(UiChrome.body_label("Match parameters", 16))

	# --- the match parameters: `&Ante` (Program/Text.res:2861,
	# @SHELLPAGE_SINGLEDUEL) — the original's own checkbox, and the manual's
	# (p.138): *"ANTE is a checkbox that determines whether you play each
	# duel for an ante card."* ON by default, because Shandalar itself
	# always plays for keeps (p.165) and §6.19 wants the stake visible from
	# the opening window onward.
	_ante_check = CheckBox.new()
	_ante_check.text = "Ante"
	_ante_check.tooltip_text = \
		"Each player stakes one card from their deck; the winner keeps both."
	_ante_check.button_pressed = true
	UiChrome.shadowed_button(_ante_check)
	content.add_child(_ante_check)

	# `&Free play` (`Text.res:2869`) or `&Best of:` (`:2862`) — one radio
	# group in the original (`MULTIDUELPAGE` in `Program/Magic.exe`:
	# `Free Play` carries WS_GROUP and `Best of:` continues it), so one
	# ButtonGroup here. Free play is the default, which is what keeps
	# "Go!" the single duel it has always been.
	var match_row := HBoxContainer.new()
	match_row.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	_free_play = CheckBox.new()
	_free_play.text = "Free play"
	_free_play.tooltip_text = "One duel. No match record is kept."
	_free_play.button_group = group
	_free_play.button_pressed = true
	UiChrome.shadowed_button(_free_play)
	match_row.add_child(_free_play)
	_best_of_check = CheckBox.new()
	_best_of_check.text = "Best of:"
	_best_of_check.tooltip_text = \
		"Play duels until one side has won more than half of them."
	_best_of_check.button_group = group
	UiChrome.shadowed_button(_best_of_check)
	match_row.add_child(_best_of_check)
	_best_of_option = OptionButton.new()
	for length in MatchState.LENGTHS:
		_best_of_option.add_item(str(length))
	# THREE, not the first entry. [constant MatchState.LENGTHS] gained a
	# 1 when `Best of &One` landed (docs/duel-todo.md §6.21), and a list
	# that opens on it would make `&Best of:` mean "one duel with a
	# record" by default — where the length this screen has always meant,
	# and the one the original's record sentence narrates first, is three.
	_best_of_option.select(maxi(MatchState.LENGTHS.find(3), 0))
	match_row.add_child(_best_of_option)
	content.add_child(match_row)

	# `Side&board between duels` (`Text.res:2863`). Meaningless in free
	# play — there is no "between duels" — so it follows the radio.
	_sideboard_check = CheckBox.new()
	_sideboard_check.text = "Sideboard between duels"
	_sideboard_check.tooltip_text = \
		"Between the duels of a match, swap cards with your sideboard. " \
		+ "AI seats sideboard too, on what they saw you play — as many " \
		+ "cards as their difficulty allows (the Apprentice never does). " \
		+ "Off: nobody swaps. The Deck Lab's --sideboard on|off is the " \
		+ "same switch."
	UiChrome.shadowed_button(_sideboard_check)
	content.add_child(_sideboard_check)
	for button in [_free_play, _best_of_check]:
		button.toggled.connect(func(_on: bool) -> void: _apply_match_mode())
	_apply_match_mode()

	# --- [QoL] THE SEED ---------------------------------------------------
	# NOT a 1997 control: the original had nothing like it, and this is
	# marked as ours rather than dressed up as theirs. It exists because
	# every duel already runs on a seed and already LOGS it
	# (`DuelScreen._new_game`), so the one thing missing between a bug
	# report and a reproduction was a box to type the number back into.
	# Blank means "roll a fresh one", which is what it has always done.
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	seed_row.add_child(UiChrome.body_label("Seed:"))
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "random"
	_seed_edit.custom_minimum_size.x = 180
	_seed_edit.tooltip_text = "Leave blank for a fresh duel. Type the " \
		+ "seed from a duel's log to replay it exactly — the same " \
		+ "shuffles, the same coin toss, and the same <random deck>."
	seed_row.add_child(_seed_edit)
	content.add_child(seed_row)

	# --- demo pace ---
	_pace_row = HBoxContainer.new()
	_pace_row.add_child(UiChrome.body_label("Demo pace (seconds/action):"))
	_pace_slider = HSlider.new()
	_pace_slider.min_value = 0.2
	_pace_slider.max_value = 2.0
	_pace_slider.step = 0.1
	_pace_slider.value = 0.8
	_pace_slider.custom_minimum_size.x = 220
	_pace_row.add_child(_pace_slider)
	content.add_child(_pace_row)

	# (`Back` and `Go!` are built by _build_action_row and live OUTSIDE
	#  the scroller — see the panel above.)


## [QoL] `Your territory background` ON THE PRE-DUEL SCREEN.
##
## NOT a 1997 control in this place. The setting itself is entirely the
## original's — `@DIALOG_DUELOPTIONS`'s own two lists, its own labels, its
## own two registry values — but the original put it in the Duel Options
## panel and NOWHERE ELSE; its start-duel screen has no such box. Offering
## it here is ours, and it is marked rather than dressed up, because the
## table you will be looking at for the next twenty minutes is chosen in
## the same breath as the deck and the face, and having to start the duel
## to reach it is a modern annoyance the 90s did not know it had.
##
## ONE SETTING, NOT TWO. Both lists write [DuelOptions]'s own accessors,
## which write the same two [Settings] keys the Duel Options panel writes
## (`PlayerTerritoryColor` and `PlayerTerritoryType`), so this control and
## that one are two views of one value and cannot disagree. Change it
## here, open the panel mid-duel, and the panel opens on what was chosen.
##
## ONE CONTROL, NOT ONE PER SEAT. `Your territory background` is
## possessive and singular, and `Duel.hlp`, **Dueling Options**, is
## explicit about the other half: *"You cannot do anything to change the
## background in your opponent's territory; it matches the predominant
## color in her deck."* A picker per seat would be a second value that
## could contradict the first.
func _build_territory_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiChrome.body_label(
		"[QoL] " + DuelOptions.TERRITORY_LABEL + ":"))
	_territory_color = OptionButton.new()
	for name in DuelOptions.TERRITORY_COLORS:
		_territory_color.add_item(name)
	_territory_color.select(maxi(0,
		DuelOptions.TERRITORY_COLORS.find(DuelOptions.territory_color())))
	_territory_color.tooltip_text = "The predominant colour of YOUR half " \
		+ "of the table. Your opponent's always follows her own deck."
	_territory_color.item_selected.connect(func(index: int) -> void:
		DuelOptions.set_territory_color(DuelOptions.TERRITORY_COLORS[index])
		_update_territory_preview())
	row.add_child(_territory_color)
	_territory_type = OptionButton.new()
	for entry in DuelOptions.TERRITORY_TYPES:
		_territory_type.add_item(String(entry["label"]))
	_territory_type.select(maxi(0, _type_index()))
	_territory_type.tooltip_text = \
		"Which of the three background arts that colour wears."
	_territory_type.item_selected.connect(func(index: int) -> void:
		DuelOptions.set_territory_type(
			String(DuelOptions.TERRITORY_TYPES[index]["label"]))
		_update_territory_preview())
	row.add_child(_territory_type)
	# THE PREVIEW, at the board half's own proportions (914x400 at
	# 1280x800, i.e. 2.285) so a `Line drawing` is cropped here exactly as
	# it will be cropped there — a preview that lied about the framing
	# would be worse than none.
	_territory_preview = Control.new()
	_territory_preview.custom_minimum_size = TERRITORY_PREVIEW
	_territory_preview.clip_contents = true
	row.add_child(UiChrome.panel_around(_territory_preview, 3.0))
	_update_territory_preview()
	return row


## Which style is selected, by index into [constant
## DuelOptions.TERRITORY_TYPES].
func _type_index() -> int:
	var chosen := DuelOptions.territory_type()
	for i in DuelOptions.TERRITORY_TYPES.size():
		if DuelOptions.TERRITORY_TYPES[i]["label"] == chosen:
			return i
	return 1


## Repaint the preview from the two pickers. `Deck color` resolves against
## SEAT 1's deck, because seat 1 is the seat a human takes in every mode
## but the demo (`DuelScreen._human_seat` picks the first human seat, and
## seat 2 is the AI's) — so the preview shows the half the player will
## actually be sitting behind.
func _update_territory_preview() -> void:
	if _territory_preview == null:
		return
	for child in _territory_preview.get_children():
		_territory_preview.remove_child(child)
		child.queue_free()
	var meta: Variant = _deck_options[0].get_selected_metadata()
	var deck_color := "white"
	if meta != null and str(meta) != "":
		deck_color = _color_of(str(meta))
	_territory_preview.add_child(TerritoryGround.node(
		DuelOptions.ground_color_for(0, 0, deck_color),
		DuelOptions.territory_type()))
	_name_the_deck_color(deck_color)


## SAY WHAT `Deck color` RESOLVES TO. It is the shipped default and it
## already does the thing — your half of the table takes your deck's
## dominant colour, the same rule that picks the duelist portrait above it
## — but the entry read `Deck color` whatever deck was chosen, so a player
## could not see that it was already answered (asked 2026-09-03: "can the
## territory background be pre-filled by a dominant colour?"). It now
## reads `Deck color (red)` and follows the picker.
##
## ONLY THE TEXT CHANGES. The value behind the row is still `Deck color`
## ([constant DuelOptions.DECK_COLOR]) — the handler maps by INDEX — so
## what lands in the settings file is unchanged and a saved preference
## still means "follow my deck", not "red, that once".
func _name_the_deck_color(deck_color: String) -> void:
	if _territory_color == null:
		return
	var row := DuelOptions.TERRITORY_COLORS.find(DuelOptions.DECK_COLOR)
	if row < 0 or row >= _territory_color.item_count:
		return
	_territory_color.set_item_text(row, "%s (%s)" % [
		DuelOptions.DECK_COLOR, deck_color])


## THE DUELIST'S FACE for one seat: the 1997 portrait
## (`Life_<colour>pict.pic`, imported as `duelist_face_<colour>`) at its
## own 120x88 — the size the original drew it, and the size the duel's
## life register flips over to. Never scaled: this is the same picture in
## both places or it is not the same picture.
##
## The face follows the DECK, because the deck is what decides which
## duelist you are — [method DuelConfig.dominant_color] is the same rule
## that colours the seat's half of the table, its life register and its
## graveyard plate, so the portrait here is a promise the duel keeps.
func _build_face(pid: int) -> Control:
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 4)
	var face := TextureRect.new()
	face.custom_minimum_size = FACE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	frame.add_child(UiChrome.panel_around(face, 4.0))
	_face_rects.resize(2)
	_face_rects[pid] = face
	var caption := UiChrome.body_label("", 13)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.custom_minimum_size.x = FACE_SIZE.x
	frame.add_child(caption)
	_face_captions.resize(2)
	_face_captions[pid] = caption
	frame.add_child(_build_portrait_chooser(pid))
	return frame


## THE SEAT'S OWN FACE, under the duelist's. The duelist above is DERIVED
## — the original picks it from the deck's dominant colour and so do we —
## and this one is CHOSEN. Nothing reads it in a duel yet; it is the
## avatar the adventure will want (M5), and it exists now so the choice
## can be made and remembered.
##
## Two arrows and a name, in the width the duelist frame already occupies
## — the seat boxes set this screen's width (see [method _fit_panel]) and
## a chooser that widened them would push the whole panel around again.
## The two buttons that leave this screen, pinned under the scroller.
func _build_action_row() -> Control:
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	var back := UiChrome.menu_button("Back", Vector2(180, 42))
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://game/main.tscn"))
	buttons.add_child(back)
	var go := UiChrome.menu_button("Go!", Vector2(180, 42))
	go.pressed.connect(_start_battle)
	buttons.add_child(go)
	_action_row = buttons
	return buttons


func _build_portrait_chooser(pid: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var art := TextureRect.new()
	art.custom_minimum_size = PORTRAIT_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# IGNORE_SIZE or the TextureRect takes its minimum from whatever
	# picture it is holding, and the seat column — and with it the whole
	# panel — changes width depending on what art the player installed.
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.tooltip_text = "Your own portrait. Drop image files into %s" \
		% PortraitLibrary.ensure_folder()
	box.add_child(UiChrome.panel_around(art, 4.0))
	_portrait_rects.resize(2)
	_portrait_rects[pid] = art

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var back := UiChrome.menu_button("◀", Vector2(22, 22), 13)
	back.pressed.connect(_cycle_portrait.bind(pid, -1))
	row.add_child(back)
	var caption := UiChrome.body_label("", 12)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.clip_text = true
	row.add_child(caption)
	var forward := UiChrome.menu_button("▶", Vector2(22, 22), 13)
	forward.pressed.connect(_cycle_portrait.bind(pid, 1))
	row.add_child(forward)
	box.add_child(row)
	_portrait_captions.resize(2)
	_portrait_captions[pid] = caption
	_portrait_arrows.resize(2)
	_portrait_arrows[pid] = [back, forward]
	_update_portrait(pid)
	return box


## Step to the next portrait, wrapping. The CHOICE IS STORED BY ID, never
## by index, so a portrait dropped into the folder later cannot silently
## change which face a seat wears.
func _cycle_portrait(pid: int, step: int) -> void:
	var faces := PortraitLibrary.all()
	if faces.is_empty():
		return
	var index := 0
	var current := String(Settings.get_value(PORTRAIT_KEY % pid, ""))
	for i in faces.size():
		if faces[i]["id"] == current:
			index = i
			break
	index = wrapi(index + step, 0, faces.size())
	Settings.set_value(PORTRAIT_KEY % pid, String(faces[index]["id"]))
	_update_portrait(pid)


## Show whatever the seat is set to — and, when there is nothing to show,
## say where portraits go instead of leaving an empty frame to puzzle over.
func _update_portrait(pid: int) -> void:
	if _portrait_rects.size() != 2 or _portrait_rects[pid] == null:
		return
	var faces := PortraitLibrary.all()
	var live := not faces.is_empty()
	for arrow in _portrait_arrows[pid]:
		(arrow as Button).disabled = not live
	if not live:
		_portrait_rects[pid].texture = null
		_portrait_captions[pid].text = NO_PORTRAITS
		return
	var current := String(Settings.get_value(PORTRAIT_KEY % pid, ""))
	var chosen: Dictionary = faces[mini(pid, faces.size() - 1)]
	for face in faces:
		if face["id"] == current:
			chosen = face
			break
	_portrait_rects[pid].texture = PortraitLibrary.texture(String(chosen["id"]))
	_portrait_captions[pid].text = String(chosen["name"])
	_portrait_captions[pid].tooltip_text = String(chosen["name"])


## Repoint one seat's portrait at whatever its picker now names. On
## `<random deck>` the frame goes EMPTY and says so: the seed has not been
## rolled yet, so there is no honest face to show — inventing one would
## promise a duelist the duel need not produce.
func _update_face(pid: int) -> void:
	if _face_rects.size() != 2 or _face_rects[pid] == null:
		return
	var meta: Variant = _deck_options[pid].get_selected_metadata()
	var path := str(meta) if meta != null else ""
	if path == "":
		_face_rects[pid].texture = null
		_face_captions[pid].text = RANDOM_DECK
		return
	var color := _color_of(path)
	_face_rects[pid].texture = DuelistFace.portrait(color)
	_face_captions[pid].text = "%s duelist" % color.capitalize()


## A deck's dominant colour, cached — the picker can be clicked freely
## without re-reading and re-validating a file each time.
func _color_of(path: String) -> String:
	if not _deck_colors.has(path):
		_deck_colors[path] = DuelConfig.dominant_color(
			DeckList.load_file(path, true).cards)
	return _deck_colors[path]


## Fill one seat's deck picker: `<random deck>` first, then every deck
## found. Each row carries its deck PATH as item metadata (empty string
## for the random row), so choosing a deck never depends on a list index —
## which is what lets rows be added above and between the decks.
## Give the settings panel the size it needs, or the size the window has,
## whichever is smaller — on BOTH axes, and centred on both. See the panel
## in [method _ready].
##
## WIDTH IS NOT A CONSTANT, and assuming it was is what put the panel off
## centre. [constant PANEL_WIDTH] was set as the panel's width, but a
## Control can never be narrower than its own content: the two seat boxes,
## their duelist faces and the margins between them ask for about a
## thousand pixels, so Godot grew the panel past 760 — and it grew it to
## the RIGHT, because that is what a control does when it has room on one
## side only. The screen looked shoved against the right edge with the
## backdrop showing on the left (the 2026-09-03 playtest saw it straight
## away). PANEL_WIDTH is a FLOOR now, the content sets the real width, and
## the window caps it.
func _fit_panel() -> void:
	if _panel == null or _panel_content == null:
		return
	# The panel's own content margin (16) on each side, plus whatever the
	# settings ask for.
	var wanted := _panel_content.get_combined_minimum_size() + Vector2(32.0, 32.0)
	# The action row is inside the panel but outside the scroller, so its
	# height is the panel's too — forgetting it is what cut `Go!` in half.
	if _action_row != null:
		wanted.y += _action_row.get_combined_minimum_size().y + 10.0
	var room := size - Vector2(2.0 * PANEL_MARGIN, 2.0 * PANEL_MARGIN)
	var width: float = clampf(wanted.x, minf(PANEL_WIDTH, room.x), room.x)
	var height: float = minf(wanted.y, room.y)
	_panel.offset_left = -width * 0.5
	_panel.offset_right = width * 0.5
	_panel.offset_top = -height * 0.5
	_panel.offset_bottom = height * 0.5


func _fill_deck_options(option: OptionButton) -> void:
	option.add_item(RANDOM_DECK)
	option.set_item_metadata(option.item_count - 1, "")
	option.set_item_tooltip(option.item_count - 1,
		"Let the duel's seed choose this seat's deck.")
	# GROUPED BY PROVENANCE ([DeckGroups]): a labelled separator per
	# heading, and headings with no decks are simply absent. `<random
	# deck>` stays ABOVE every heading, because it is not a deck and
	# belongs to no group — it is the choice not to choose.
	var by_group := DeckGroups.grouped(_deck_paths)
	for group in by_group:
		option.add_separator(group)
		# ONE POOLED RANDOM PER HEADING — but only where it is a real
		# choice. A group holding a single PLAYABLE deck would offer a
		# draw with one ball in the bag; a group holding none could not
		# draw at all, and `_deck_path_for` would fall back to the whole
		# pool, quietly handing the player the opposite of what the row
		# promised. Two is the smallest number that makes the row honest.
		var drawable := paths_in_group(_playable_paths, String(group))
		if drawable.size() >= 2:
			option.add_item("<random from %s>" % group)
			option.set_item_metadata(option.item_count - 1,
				GROUP_RANDOM + String(group))
			option.set_item_tooltip(option.item_count - 1,
				"Let the duel's seed choose one of the %d playable decks "
				% drawable.size() + "under %s, and nothing else." % group)
		for path in by_group[group]:
			var label: String = str(_deck_titles.get(path, "")).strip_edges()
			# An untitled file loads under its bare file stem
			# ([method DeckList.load_file]); show that the way it was
			# always shown.
			if label == "" or label == path.get_file().get_basename():
				label = path.get_file().get_basename().capitalize()
			# A DECK THAT CANNOT BE PLAYED SAYS SO ON ITS OWN ROW, in its
			# own group rather than exiled to a heading of its own: it is
			# still the player's deck and still belongs where they filed
			# it. The refusal itself, with the names, is one selection
			# away on the note under the picker.
			var proxies: Array = _proxy_paths.get(path, [])
			if not proxies.is_empty():
				label += "  (%d proxy)" % proxies.size()
			option.add_item(label)
			option.set_item_metadata(option.item_count - 1, path)
			if not proxies.is_empty():
				option.set_item_tooltip(option.item_count - 1,
					ProxyCard.refusal(proxies))


## The row index of the [param nth] deck in a picker (0-based), skipping
## `<random deck>` and every group heading. Falls back to the last deck,
## and to `<random deck>` when there are no decks at all.
static func _row_of_deck(option: OptionButton, nth: int) -> int:
	var seen := -1
	var last := 0
	for i in option.item_count:
		var meta := str(option.get_item_metadata(i))
		if option.is_item_separator(i) or meta == "" \
				or meta.begins_with(GROUP_RANDOM):
			continue
		last = i
		seen += 1
		if seen == nth:
			return i
	return last


## The deck file a seat will play. `<random deck>` resolves HERE, off
## [param picker], so the choice is part of the seeded duel rather than a
## coin flip outside it.
func _deck_path_for(pid: int, picker: RandomNumberGenerator) -> String:
	var meta: Variant = _deck_options[pid].get_selected_metadata()
	var chosen := str(meta) if meta != null else ""
	if chosen.begins_with(GROUP_RANDOM):
		# POOLED RANDOM. Drawn from the same RNG as the unpooled one and
		# in the same place, so a seed still reproduces the whole duel —
		# only the bag it draws from is narrower.
		var pool := paths_in_group(_playable_paths,
			chosen.substr(GROUP_RANDOM.length()))
		if not pool.is_empty():
			return random_deck_path(pool, picker)
		# A pool that has emptied since the list was built (a deck deleted
		# under us) draws from everything rather than handing the seat no
		# deck at all — the same fallback `<random deck>` already makes.
		return random_deck_path(_playable_paths, picker)
	if chosen != "":
		return chosen
	# `<random deck>` draws from the PLAYABLE decks only — see
	# [member _playable_paths].
	return random_deck_path(_playable_paths, picker)


## One deck path out of [param paths], drawn from [param rng]. Static and
## RNG-injected on purpose: the pick is then a pure function of the seed,
## which is the only way `<random deck>` and "replay this duel from its
## logged seed" can both be true (pinned by tests/ui/test_setup_screen.gd).
## Those of [param paths] filed under [param group]. Static and pure for
## the same reason [method random_deck_path] is: the pooled draw has to be
## a function of the seed and nothing else, so the two halves of it are
## both testable without a screen.
static func paths_in_group(paths: Array[String], group: String) -> Array[String]:
	var out: Array[String] = []
	for path in paths:
		if DeckGroups.of(path) == group:
			out.append(path)
	return out


static func random_deck_path(paths: Array[String], rng: RandomNumberGenerator) -> String:
	if paths.is_empty():
		return ""
	return paths[rng.randi() % paths.size()]


## The seed this duel will run on — one number that fixes the deck picks,
## the shuffles, the coin toss and every random choice in the duel.
## Whatever the player typed, or a fresh roll when they typed nothing (or
## typed something that is not a number, which is the same request).
##
## Never 0, and never negative: `DuelConfig.rng_seed` reads 0 as "roll
## one", and a negative seed would round-trip through the duel's own log
## line as a number the field then refuses. A typed 0 therefore becomes 1
## — the nearest seed that means what the player asked for.
func _resolve_seed() -> int:
	if _seed_edit != null:
		var typed := _seed_edit.text.strip_edges()
		if typed.is_valid_int():
			var value := absi(typed.to_int())
			return value if value != 0 else 1
	return randi() | 1


## The chosen format.
func deck_format() -> String:
	return DeckFormat.ORDER[_format_option.selected]


## The note under the picker: the format's one line, plus — if a chosen
## deck does not meet it — the refusal, HERE rather than on "Go!", so a
## player finds out while they can still change the deck.
##
## PROXIES ARE CHECKED FIRST AND INSTEAD (proxy pass, 2026-09-01). A deck
## holding a [ProxyCard] cannot be played at all, so saying anything about
## which FORMAT it fits would be answering a question that no longer
## arises; the note names the cards to replace and stops there.
##
## The load is LENIENT here, which it has to be: a strict load of a proxy
## deck reports errors and hands back only the names it recognised, so the
## format check would be vetting a deck with holes in it and the proxies
## themselves would be invisible.
func _refresh_format_note() -> void:
	if _format_note == null:
		return
	var format := deck_format()
	var text: String = DeckFormat.SUMMARY[format]
	for pid in 2:
		var meta: Variant = _deck_options[pid].get_selected_metadata()
		var path := str(meta) if meta != null else ""
		if path == "":
			continue     # `<random deck>`: nothing to check until "Go!"
		var listed := DeckList.load_file(path, false)
		var proxied := ProxyCard.refusal_for(listed.cards, listed.sideboard)
		if proxied != "":
			text += "\n Seat %d — %s" % [pid + 1, proxied]
			continue
		# The SIDEBOARD is checked with the maindeck: those cards come
		# into the deck between the duels of a match, so a format that
		# ignored them would be vetting a deck nobody plays
		# (docs/ROADMAP.md, third audit pass).
		var refusal := DeckFormat.legal(listed.cards, format, listed.sideboard)
		if refusal != "":
			text += "\n Seat %d — %s" % [pid + 1, refusal]
	_format_note.text = text


## The full explanation, on the era's stone panel — the same `?` the
## Options screen puts beside each rules fork.
func _explain_formats() -> void:
	var lines := PackedStringArray()
	for format in DeckFormat.ORDER:
		lines.append("%s\n%s" % [format, DeckFormat.SUMMARY[format]])
	lines.append("These five are the original's own (Program/Text.res:2854"
		+ "-2859). The restricted and banned lists are the game's own data"
		+ " (deckdll.cpp), not MicroProse's 1997 list, which does not"
		+ " survive in any file we have. Help has the full page.")
	UiChrome.explain_popup(self, "Deck format", "\n\n".join(lines), 560.0)


## Grey what free play cannot use: the length, and the sideboard step
## that only exists between two duels. Greyed rather than hidden, on the
## same precedent every 1997 menu in this project follows.
func _apply_match_mode() -> void:
	var matched: bool = _best_of_check.button_pressed
	_best_of_option.disabled = not matched
	_sideboard_check.disabled = not matched


## The chosen `&Best of:` length, or [constant MatchState.FREE_PLAY].
func best_of() -> int:
	if not _best_of_check.button_pressed:
		return MatchState.FREE_PLAY
	return MatchState.LENGTHS[_best_of_option.selected]


## A new AI skill re-applies the current mode, which is what re-fits the
## seat's controls (see the connection in `_ready`). It no longer touches
## the NAME — see [constant AI_NAMES].
func _on_difficulty_changed(_index: int) -> void:
	_apply_mode(_mode)


## The name a seat opens with: its HAL when the AI has it, `Player N`
## when a person does. AI seats take the HALs IN SEAT ORDER, so a demo
## reads 9000 against 9001 and a single AI opponent is always 9000.
func _default_name(pid: int, mode: int) -> String:
	if not _seat_is_ai(pid, mode):
		return "Player %d" % (pid + 1)
	var nth := 0
	for other in pid:
		if _seat_is_ai(other, mode):
			nth += 1
	return AI_NAMES[mini(nth, AI_NAMES.size() - 1)]


## Who holds a seat in [param mode]: the AI in every seat of a demo, and
## in the second seat against the AI.
static func _seat_is_ai(pid: int, mode: int) -> bool:
	return mode == BattleMode.DEMO \
		or (mode == BattleMode.VS_AI and pid == 1)


## Is [param text] a name this screen wrote, rather than one the player
## typed? Only an auto-name may be replaced when the seat changes hands;
## anything else is the player's and is left exactly as it is.
static func _is_auto_name(text: String) -> bool:
	if text in AI_NAMES:
		return true
	for pid in 2:
		if text == "Player %d" % (pid + 1):
			return true
	# The names this screen used to write, so an old habit does not
	# strand a seat called "AI Wizard" that nobody can explain.
	for skill in DIFFICULTIES:
		if text == "AI %s" % skill:
			return true
	return false


func _apply_mode(mode: int) -> void:
	_mode = mode
	for i in _mode_buttons.size():
		_mode_buttons[i].button_pressed = i == mode
	# Which seats are AI decides which controls matter.
	for pid in 2:
		var seat_is_ai := _seat_is_ai(pid, mode)
		_difficulty_options[pid].visible = seat_is_ai
		_difficulty_labels[pid].visible = seat_is_ai
		# AN AI SEAT IS NAMED BY THE PLAYER TOO (the owner's ask,
		# 2026-09-03). The field used to be locked for an AI and written
		# over with its skill; both are gone. What replaces the skill
		# label is a DEFAULT, and only a default gets overwritten — type
		# your own and the screen leaves it alone through every mode
		# change.
		_name_edits[pid].editable = true
		if _is_auto_name(_name_edits[pid].text):
			_name_edits[pid].text = _default_name(pid, mode)
	_pace_row.visible = mode == BattleMode.DEMO


func _start_battle() -> void:
	if _leaving:
		return
	var config := DuelConfig.new()
	# The seed is settled BEFORE anything random happens, and travels with
	# the duel — see the class doc. `<random deck>` reads from `picker`,
	# a stream of its own seeded from the same number, so it never
	# perturbs the duel's shuffles while still replaying with them.
	config.rng_seed = _resolve_seed()
	var picker := RandomNumberGenerator.new()
	picker.seed = config.rng_seed
	# THE PATHS ARE RESOLVED FIRST, in seat order, so `<random deck>` draws
	# from `picker` in exactly the order it always did — the seed still
	# replays which decks were chosen — and so that the proxy gate below
	# has both decks to look at before anything else happens.
	var paths: Array[String] = []
	for pid in 2:
		paths.append(_deck_path_for(pid, picker))
	# A DECK HOLDING PROXIES STOPS HERE, NAMING THEM. This is the door the
	# whole [ProxyCard] boundary exists to hold: a proxy has no rules
	# behind it, so one that reached [MtgGame] would be a card that cannot
	# resolve — `MtgGame._build_library` would push_error and skip it, and
	# the seat would be dealt a library quietly short of cards.
	#
	# LENIENT on purpose, and BEFORE the format check: a strict load hides
	# the very names this refusal has to print.
	for pid in 2:
		var listed := DeckList.load_file(paths[pid], false)
		var proxied := ProxyCard.refusal_for(listed.cards, listed.sideboard)
		if proxied != "":
			UiChrome.explain_popup(self,
				"Seat %d cannot play this deck" % (pid + 1), proxied)
			return
	for pid in 2:
		var deck := DeckList.load_file(paths[pid], true)
		# A FILE THE PARSER COULD NOT READ STOPS HERE TOO. `deck.errors`
		# was collected and then never looked at, so a deck deleted
		# between `_scan_decks()` and this button — or `<random deck>`
		# with an empty playable pool, which resolves to the path "" —
		# handed the seat `cards == []` and started the duel anyway. The
		# proxy gate above cannot catch that one (there are no names to
		# call proxies) and neither can the format check below (no format
		# has a minimum deck size), so an empty library reached MtgGame.
		if not deck.errors.is_empty():
			UiChrome.explain_popup(self,
				"Seat %d cannot play this deck" % (pid + 1),
				"\n".join(PackedStringArray(deck.errors)))
			return
		config.decks[pid] = deck.cards
		# The `SB:` cards the file has always carried. Nothing read them
		# until `Side&board between duels` existed (docs/ROADMAP.md).
		config.sideboards[pid] = deck.sideboard
		config.player_names[pid] = _name_edits[pid].text
		# What the pre-duel splash says under each portrait.
		config.deck_names[pid] = _deck_options[pid].get_item_text(
			_deck_options[pid].selected).strip_edges()
		config.portraits[pid] = String(
			Settings.get_value(PORTRAIT_KEY % pid, ""))
		config.lives[pid] = int(_life_spins[pid].value)
		config.panel_colors[pid] = DuelConfig.dominant_color(deck.cards)
		var seat_is_ai: bool = (_mode == BattleMode.DEMO) \
			or (_mode == BattleMode.VS_AI and pid == 1)
		if seat_is_ai:
			config.pilots[pid] = [AiProfile.apprentice(), AiProfile.magician(),
				AiProfile.sorcerer(), AiProfile.wizard()][_difficulty_options[pid].selected]
	config.pace = _pace_slider.value if _mode == BattleMode.DEMO else Settings.ai_pace()
	config.ante = 1 if _ante_check.button_pressed else 0
	config.deck_format = deck_format()
	# A DECK THAT DOES NOT MEET THE FORMAT STOPS HERE, naming the card.
	# Checked after the decks are resolved, because `<random deck>` has no
	# deck to check until now.
	for pid in 2:
		var refusal := DeckFormat.legal(config.decks[pid], config.deck_format,
			config.sideboards[pid])
		if refusal != "":
			UiChrome.explain_popup(self, "Seat %d cannot play this deck" % (pid + 1),
				refusal)
			return
	config.best_of = best_of()
	config.sideboard_between_duels = _sideboard_check.button_pressed \
		and config.best_of != MatchState.FREE_PLAY
	var tree := get_tree()
	# FREE PLAY GOES STRAIGHT TO THE DUEL, exactly as it always has — one
	# screen, one duel, nothing between this and it. A match needs
	# something to own the sequence and the record, so it gets
	# [MatchScreen], which builds the same duel screen once per duel.
	var screen: Control
	if config.best_of == MatchState.FREE_PLAY:
		var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
		duel.config = config
		screen = duel
	else:
		var run: MatchScreen = load("res://game/match_screen.tscn").instantiate()
		run.config = config
		screen = run
	_leaving = true
	tree.root.add_child(screen)
	tree.current_scene = screen
	queue_free()

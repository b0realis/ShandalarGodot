class_name MatchScreen
extends Control
## THE MATCH — the thing that runs when the battle-setup screen's
## `&Best of:` is chosen instead of `&Free play`
## (`Program/Text.res:2862`, `:2869`).
##
## A match is a sequence of duels with a record kept between them, so this
## screen owns the sequence and nothing else: it builds one [DuelScreen]
## per duel, listens for that duel's [signal DuelScreen.duel_finished],
## hands the result to [MatchState], and puts the between-duels window up.
## The duel screen still knows nothing about matches — it plays a duel and
## says who won, which is all it did before.
##
## THE BETWEEN-DUELS WINDOW is the original's own, entry for entry:
## `@DIALOG_ENDEXP1DUEL_MATCHPROGRESS` (`Program/UIStrings.txt:553`) for
## the record line and the three verdicts, `@DIALOG_ENDEXP1DUEL_BUTTONS`
## (`:564`) for `Side&board...` and `&Edit deck...`, and
## `@DIALOG_ENDEXP1DUEL` (`:571`) for `&Continue match` / `&Quit match`.
## `&Edit deck...` is listed and DISABLED — the Deck Builder is a whole
## screen away and a match cannot leave for it and come back — which is
## the same treatment §6.1 gives every 1997 entry we have no command for.
##
## DETERMINISM. The match carries ONE seed (`DuelConfig.rng_seed`, settled
## on the setup screen). Each duel's own seed is drawn from it in order,
## so duel 3 of a match is reproducible only as duel 3 of that match —
## which is what a bug report from the middle of a match needs.
##
## WHAT THE AI DOES BETWEEN DUELS. It sideboards too, and it does so
## WITHOUT a window: the `Side&board...` button is a human affordance and
## an AI seat has no use for one. [AiSideboard] makes the swap the moment
## the duel is recorded, on nothing but what that seat SAW
## ([AiMatchMemory]) — never on the opponent's decklist, which would be
## cheating.
##
## This screen owns the memories because it owns the sequence: one per AI
## seat, alive for the whole match, watching each duel's [MtgGame] from the
## moment it is built. Until this landed, `Sideboard between duels` against
## an AI was a match in which only one side adapted, which is worse than
## not offering the step at all.

## THE MATCH IS OVER — the seat that took it, or -1 for a tie, which is
## exactly what [method MatchState.winner] returns and the same shape
## [signal DuelScreen.duel_finished] already has one layer down.
##
## Always emitted, exactly once, the moment the match is decided — what
## an owner DOES about it is [member reports_to_owner]'s business and not
## this signal's. (Deciding it by counting connections would have been
## neat and wrong: a test that merely WATCHES the signal is a connection.)
signal match_finished(winner_id: int)

## `&Continue match` / `&Quit match` — `@DIALOG_ENDEXP1DUEL`,
## `Program/UIStrings.txt:578-579`.
const CONTINUE := "Continue match"
const QUIT := "Quit match"
## `Side&board...` / `&Edit deck...` — `@DIALOG_ENDEXP1DUEL_BUTTONS`, `:566`.
const SIDEBOARD := "Sideboard..."
const EDIT_DECK := "Edit deck..."
## `Match parameters` — the original's own heading for this group of
## settings (`Program/Text.res:2860`), reused as the window's title.
const TITLE := "Match parameters"
## Above the duel screen's own coin panel (250) and dialogs (200).
const WINDOW_Z := 400

## The match's parameters and its decks. Mutated between duels by the
## sideboard step, which is the whole point of `Side&board between duels`.
var config: DuelConfig
var state: MatchState

## THIS MATCH IS SOMEBODY ELSE'S ROUND, and that is the whole of what the
## gauntlet needed from this file.
##
## A match started from the battle-setup screen is the entire session: it
## ends with its own window and that window's OK goes back to the title,
## which is what this screen has always done. A match started by a
## [GauntletScreen] is one ROUND of a longer run, so its last word belongs
## to the gauntlet's round window and not to a second window underneath
## it: the owner sets this, takes [signal match_finished], and this screen
## simply stops at the end of the last duel. Nothing else in here knows a
## gauntlet exists.
var reports_to_owner := false

var _duel: DuelScreen = null
var _window: Control = null
## Draws each duel's seed from the match's, so a match replays whole.
var _seeder := RandomNumberGenerator.new()
## One [AiMatchMemory] per seat (null for a human seat) — what that seat
## has seen its opponent do so far, and the only thing [AiSideboard] is
## allowed to read.
var _memories: Array = [null, null]

# The Sideboard... window's own state, while it is open.
var _sb_dialog: OriginalDialog = null
var _sb_columns: HBoxContainer = null
var _sb_note: Label = null
var _sb_done: Button = null
var _sb_pid := -1
## The size the deck must go back into the next duel at.
var _sb_size := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if config == null:
		config = DuelConfig.hotseat_default()
	state = MatchState.new()
	state.best_of = config.best_of
	state.sideboard_between_duels = config.sideboard_between_duels
	state.human_seat = _human_seat()
	_seeder.seed = config.rng_seed if config.rng_seed != 0 else randi() | 1
	for pid in 2:
		if config.is_ai(pid):
			_memories[pid] = AiMatchMemory.new(pid)
	_start_duel()


## Whose record the match keeps: the first human seat, or seat 0 when both
## are AI (a demo has no "you", and [MatchState] says why the words stay
## the same anyway).
func _human_seat() -> int:
	for pid in 2:
		if not config.is_ai(pid):
			return pid
	return 0


# ------------------------------------------------------------ the duels --

func _start_duel() -> void:
	_duel = load("res://game/duel/duel_screen.tscn").instantiate()
	_duel.config = _config_for_this_duel()
	_duel.duel_finished.connect(_on_duel_finished)
	# `add_child` runs the duel screen's `_ready`, which builds its
	# [MtgGame] — so the memories can start watching on the very next
	# line, before a single card is played.
	add_child(_duel)
	for pid in 2:
		if _memories[pid] != null:
			(_memories[pid] as AiMatchMemory).watch(_duel.game)


## A duel's own config: the match's, with the decks as they stand right
## now (the sideboard step edits them) and a seed of its own.
func _config_for_this_duel() -> DuelConfig:
	var out := DuelConfig.new()
	out.decks = [config.decks[0].duplicate(), config.decks[1].duplicate()]
	out.sideboards = [config.sideboards[0].duplicate(),
		config.sideboards[1].duplicate()]
	out.player_names = config.player_names.duplicate()
	out.deck_names = config.deck_names.duplicate()
	out.portraits = config.portraits.duplicate()
	out.lives = config.lives.duplicate()
	out.pilots = config.pilots.duplicate()
	out.panel_colors = config.panel_colors.duplicate()
	out.pace = config.pace
	out.ante = config.ante
	# The match's parameters do NOT travel into the duel: a duel inside a
	# match is still one duel, and telling it otherwise would give it a
	# match of its own.
	out.rng_seed = _seeder.randi() | 1
	return out


func _on_duel_finished(winner_id: int) -> void:
	state.record(winner_id)
	_ai_sideboards()
	if DisplayServer.get_name() == "headless":
		# Tests/CI: no windows and nothing to dismiss — the match simply
		# plays on, exactly as the duel screen starts without a coin toss.
		_advance()
		return
	# The duel's own End of Duel window has the duel's last word; the
	# match's window is the next one, not a second one on top of it.
	while is_instance_valid(_duel) and _duel.result_dialog_open():
		await get_tree().process_frame
	_advance()


## The duel is over and recorded. Either the match is too — one window
## with its verdict — or there is another duel, and the between-duels
## window goes up first.
func _advance() -> void:
	# THE FINISHED DUEL IS A PICTURE NOW, not a table: whichever window
	# goes up over it — ours below, or the gauntlet's round window when
	# [member reports_to_owner] — the duel underneath must take no mouse
	# (a permanent still answered a click there until 2026-09-02).
	# `_show_window` silencing its keys was not enough, and did not run
	# at all for an owner's match.
	if is_instance_valid(_duel):
		_duel.process_mode = Node.PROCESS_MODE_DISABLED
	if state.is_over():
		match_finished.emit(state.winner())
		# AN OWNER THAT ASKED FOR THE RESULT gets the last word: no window
		# of ours, and no scene change. See [member reports_to_owner].
		if reports_to_owner:
			return
	if DisplayServer.get_name() == "headless":
		if state.is_over():
			return
		_drop_duel()
		_start_duel()
		return
	_show_window()


func _drop_duel() -> void:
	if is_instance_valid(_duel):
		_duel.queue_free()
	_duel = null


# ------------------------------------------- the between-duels window --

func _show_window() -> void:
	if _window != null:
		_window.queue_free()
	var over := state.is_over()
	var dialog := OriginalDialog.create(TITLE, Vector2(430, 200),
		"panel_end_duel" if over else "panel_dark_stone")
	# ABOVE EVERYTHING THE DUEL LEAVES ON SCREEN. The duel's own coin
	# panel sits at 250 (`duel_screen.gd:453`) and its dialogs at 200; the
	# match's window is a window over the whole duel screen, not another
	# of the duel's own, so it must outrank all of them.
	dialog.z_index = WINDOW_Z
	_window = dialog
	# The duel screen is still in the tree under this window, and its
	# keys — Space, Return, the Ctrl accelerators (§6.3a) — must not
	# leak into a finished duel while the player reads the match's word.
	if is_instance_valid(_duel):
		_duel.set_process_unhandled_key_input(false)
	dialog.body().add_child(_centred(state.progress_line(), 14))
	if over:
		dialog.body().add_child(_centred(state.verdict(), 16, true))
		dialog.add_button("OK").pressed.connect(_leave)
	else:
		dialog.body().add_child(_centred(state.duel_heading(), 14))
		if state.sideboard_between_duels:
			for pid in 2:
				# AN AI SEAT GETS NO BUTTON — it has already sideboarded,
				# in [method _ai_sideboards]. The button is the human's
				# way into the same step.
				if config.is_ai(pid):
					continue
				var button := dialog.add_button(SIDEBOARD)
				button.tooltip_text = "%s: swap cards with the sideboard" \
					% config.player_names[pid]
				button.pressed.connect(_open_sideboard.bind(pid))
		# Listed and greyed: there is no route from a match into the Deck
		# Builder and back.
		dialog.add_button(EDIT_DECK).disabled = true
		dialog.add_button(CONTINUE).pressed.connect(_next_duel)
		dialog.add_button(QUIT).pressed.connect(_leave)
	add_child(dialog)


## THE AI'S HALF OF `Side&board between duels`, taken here rather than in
## a window because an AI seat has no window. Runs as the duel is
## recorded, so the human's own Sideboard window (which opens a moment
## later) is already looking at an opponent that has adapted.
##
## Randomness comes from the finished duel's own [MtgGame.rng] — CONTRIBUTING.md
## rule 7, and what makes a seeded match replay line for line. Nothing
## happens on the last duel of a match: there is no next duel to board for.
func _ai_sideboards() -> void:
	for pid in 2:
		if _memories[pid] != null:
			(_memories[pid] as AiMatchMemory).end_duel()
	if not state.sideboard_between_duels or state.is_over():
		return
	if not is_instance_valid(_duel) or _duel.game == null:
		return
	for pid in 2:
		if _memories[pid] == null:
			continue
		var plan := AiSideboard.sideboard(_memories[pid], config.decks[pid],
			config.sideboards[pid], config.pilots[pid] as AiProfile,
			_duel.game.rng, config.deck_format)
		var line := AiSideboard.summary(plan)
		if line != "":
			print("%s %s" % [config.player_names[pid], line])


## A dialog line, centred — the between-duels window is two short
## sentences and a row of buttons, and left-ragged text under a centred
## title reads as a mistake.
static func _centred(text: String, size := 14, bold := false) -> Label:
	var line := OriginalDialog.label(text, size, bold)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return line


func _next_duel() -> void:
	if _window != null:
		_window.queue_free()
		_window = null
	_drop_duel()
	_start_duel()


func _leave() -> void:
	get_tree().change_scene_to_file("res://game/main.tscn")


# ----------------------------------------------------------- Sideboard... --

## `Side&board between duels` (`Program/Text.res:2863`) — the only thing
## the original lets a player do to their deck inside a match.
##
## WHAT THE RULE IS, AND WHOSE IT IS. No source available to this project
## states one: the printed manual's only "sideboard" is advice about your
## Shandalar COLLECTION (p.140), `Duel.hlp` mentions the word once in
## passing, and the string tables give the BUTTON and nothing behind it.
## So the rule enforced here is OURS and is marked as such: **the deck
## must go back into the next duel at the size it came out of this one.**
## Cards move freely in both directions while the window is open and
## `Done` stays disabled until the sizes match, which is the smallest rule
## that cannot make a deck illegal and needs no invented number to do it.
func _open_sideboard(pid: int) -> void:
	_sb_pid = pid
	_sb_size = (config.decks[pid] as Array).size()
	var dialog := OriginalDialog.create(
		"%s — %s" % [config.player_names[pid], SIDEBOARD], Vector2(600, 470))
	dialog.z_index = WINDOW_Z + 1     # over the between-duels window
	_sb_dialog = dialog
	_sb_columns = HBoxContainer.new()
	_sb_columns.add_theme_constant_override("separation", 16)
	_sb_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.body().add_child(_sb_columns)
	_sb_note = OriginalDialog.label("", 13)
	_sb_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.body().add_child(_sb_note)
	# `Done` is one of the three buttons the 1997 game owns
	# (`@DIALOGBUTTONS` — "OK", "Cancel", "Done").
	_sb_done = dialog.add_button("Done")
	_sb_done.pressed.connect(_close_sideboard)
	_refresh_sideboard()
	add_child(dialog)


func _close_sideboard() -> void:
	if _sb_dialog != null:
		_sb_dialog.dismiss()
		_sb_dialog = null
	_sb_pid = -1


func _refresh_sideboard() -> void:
	if _sb_columns == null or _sb_pid < 0:
		return
	for child in _sb_columns.get_children():
		_sb_columns.remove_child(child)
		child.queue_free()
	_sb_columns.add_child(_pile_column("Your deck", true))
	_sb_columns.add_child(_pile_column(SIDEBOARD.trim_suffix("..."), false))
	var now := (config.decks[_sb_pid] as Array).size()
	_sb_note.text = "%d cards" % now if now == _sb_size \
		else "%d cards — the deck must go back in at %d" % [now, _sb_size]
	_sb_done.disabled = now != _sb_size


## One side of the swap: a heading and a clickable line per card name,
## `3  Lightning Bolt`, in name order. A click moves ONE copy across, so
## a four-of comes apart one card at a time rather than all at once.
func _pile_column(heading: String, from_main: bool) -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	var head := OriginalDialog.label(heading, 14, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 0)
	scroll.add_child(rows)
	column.add_child(scroll)
	var pile: Array = config.decks[_sb_pid] if from_main \
		else config.sideboards[_sb_pid]
	for card_name in counted(pile):
		var line := OriginalDialog.choice_line("%d  %s" % [
			counted(pile)[card_name], card_name])
		line.pressed.connect(_move_one.bind(String(card_name), from_main))
		rows.add_child(line)
	if rows.get_child_count() == 0:
		var empty := OriginalDialog.label("(empty)", 13)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(empty)
	return column


## card name -> how many, in name order. Static so a test can check the
## counting without a window.
static func counted(pile: Array) -> Dictionary:
	var names: Array[String] = []
	var counts := {}
	for card_name in pile:
		if not counts.has(card_name):
			counts[card_name] = 0
			names.append(String(card_name))
		counts[card_name] += 1
	names.sort()
	var ordered := {}
	for card_name in names:
		ordered[card_name] = counts[card_name]
	return ordered


## Move one copy of [param card_name] between the seat's deck and its
## sideboard. Returns "" or a refusal, on this project's action-method
## convention, so a test can assert the refusal rather than a crash.
func move_one(pid: int, card_name: String, from_main: bool) -> String:
	var from: Array = config.decks[pid] if from_main else config.sideboards[pid]
	var into: Array = config.sideboards[pid] if from_main else config.decks[pid]
	var at := from.find(card_name)
	if at == -1:
		return "%s is not there to move" % card_name
	from.remove_at(at)
	into.append(card_name)
	return ""


func _move_one(card_name: String, from_main: bool) -> void:
	if _sb_pid < 0:
		return
	move_one(_sb_pid, card_name, from_main)
	_refresh_sideboard()

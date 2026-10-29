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
##
## SAVED BETWEEN DUELS (the polish pass c18; the owner, 2026-10-28:
## *"Saving: between duels (Gauntlet runs and matches save after each duel
## and resume); no mid-duel save"*). A match from Magic Battle
## ([member keeps_save]) writes itself whole after every duel — the record,
## the decks as they stand, the stream, what the computer saw — and again
## when a Sideboard window closes; a decided one drops its file; a
## Gauntlet's match hands the same snapshot to its run ([member
## save_with]), and a decided one tells its run at once ([signal
## match_decided]) — every save point comes before the duel's End of Duel
## window, never after it (the bug campaign of 0.50.65, k4-1), and the
## doors out of that window say what was kept ([method _retell_doors],
## k4-4). [member resume_from] takes one up again AT THE
## BETWEEN-DUELS WINDOW it was saved behind, its next duel dealt afresh
## ([MatchSaves], the resume count). 1997's `&Save match` was a button on
## that window (`@DIALOG_ENDEXP1DUEL_BUTTONS`, `Program/UIStrings.txt:564-
## 571`); ours saves without one [ours] and says so on the window.

## THE MATCH IS OVER — the seat that took it, or -1 for a tie, which is
## exactly what [method MatchState.winner] returns and the same shape
## [signal DuelScreen.duel_finished] already has one layer down.
##
## Always emitted, exactly once, when the deciding duel's End of Duel
## window has closed (at once headless) — what an owner DOES about it is
## [member reports_to_owner]'s business and not this signal's. (Deciding
## it by counting connections would have been neat and wrong: a test that
## merely WATCHES the signal is a connection.) What the owner must KEEP
## of the match is [signal match_decided]'s, which comes first.
signal match_finished(winner_id: int)

## THE MATCH IS DECIDED — emitted once, the moment its deciding duel is
## recorded, BEFORE that duel's End of Duel window has closed (the bug
## campaign of 0.50.65, k4-1). An owner records the match and saves or
## drops what it keeps here, not at [signal match_finished]: a player can
## quit at that window — Pause → `Return to main menu`, `Quit`, closing
## the game — and its OK never comes. The Gauntlet's run waited for it,
## so a run lost at that window came back from its file, and a won one
## came back a duel short. Same arguments as [signal match_finished].
signal match_decided(winner_id: int)

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

# --- review 2026-10-21 ui-1: leaving from inside one of this match's duels ---
## EVERY DUEL OF A MATCH IS HELD ([member DuelScreen.leave_question]): its
## splash's left button and Pause → `Exit duel` ask first, and only a yes
## leaves. Until this they went straight to the battle-setup screen and the
## record went with them, without a word — and inside a Gauntlet the whole
## run did. A match from the battle-setup screen goes back THERE on a yes:
## where the player came from, and the ROADMAP's own reading of Exit duel,
## *"exit duel (return to duel config)"*. An owner's match
## ([member reports_to_owner]) goes nowhere itself: it passes the yes up as
## [signal leave_confirmed], and the owner sets the words below before the
## match enters the tree, as it sets [member reports_to_owner].
const LEAVE_QUESTION := "Quit this match? Its record so far is lost, and you go back to Magic Battle."
## Where a yes goes for a match nobody owns.
const SETUP_SCREEN := "res://game/setup_screen.tscn"
## What Pause → `Return to main menu` asks in one of its duels (the owner,
## 2026-10-21: it asks too), and where a yes goes for a match nobody owns.
const MENU_QUESTION := "Quit this match? Its record so far is lost, and you go back to the main menu."
const MAIN_MENU := "res://game/main.tscn"
var leave_title := TITLE
var leave_question := LEAVE_QUESTION
var menu_question := MENU_QUESTION
## The splash's left button; "" keeps `Reconfigure duel`, which is exactly
## what a yes does for a match from the battle-setup screen.
var leave_label := ""
## A yes, for an owner's match.
signal leave_confirmed
## A yes to [member menu_question], for an owner's match.
signal menu_confirmed
# --- end review 2026-10-21 ui-1 ---

# --- the polish pass c18, P4: saved between duels ---
## What the two doors out of a duel ask once the match is saved: the duel
## in play is not kept (no mid-duel save), the match is.
const SAVED_LEAVE_QUESTION := "Leave this match? It is saved as it stood before this duel, and you go back to Magic Battle, where Resume match takes it up again."
const SAVED_MENU_QUESTION := "Leave this match? It is saved as it stood before this duel, and you go back to the main menu. Resume match on Magic Battle takes it up again."
## What the same two doors ask over a finished duel's End of Duel window
## (the bug campaign of 0.50.65, k4-4): the match is saved with that
## duel's result — or, decided, there is nothing left to keep.
const RESULT_SAVED_LEAVE_QUESTION := "Leave this match? It is saved with this duel's result, and you go back to Magic Battle, where Resume match takes it up again."
const RESULT_SAVED_MENU_QUESTION := "Leave this match? It is saved with this duel's result, and you go back to the main menu. Resume match on Magic Battle takes it up again."
const OVER_LEAVE_QUESTION := "Leave this match? It is over, and you go back to Magic Battle."
const OVER_MENU_QUESTION := "Leave this match? It is over, and you go back to the main menu."
## The between-duels window's line under the record, saved or not.
const SAVED_NOTE := "Saved. Resume match on Magic Battle takes it up again."
const NOT_SAVED_NOTE := "This match could not be saved."
## A MATCH THAT KEEPS ITS OWN SAVE ([MatchSaves.match_file]) — set by Magic
## Battle's `Go!` and `Resume match` before the match enters the tree. Off
## for everything else that builds a match (the tests, the tools), so none
## of them can write over the player's saved match.
var keeps_save := false
## AN OWNER'S SAVE: called with [method snapshot] at every save point
## instead of writing a file of this match's own, answering whether it was
## written — the Gauntlet's, which saves the match inside its run.
var save_with := Callable()
## A saved match to take up ([method MatchSaves.match_from_json]'s), set
## before the match enters the tree; `{}` starts a new one.
var resume_from: Dictionary = {}
## Does a save hold this match as it stands — what the doors out of its
## duels say ([member saved_leave_question]). An owner sets it for a match
## whose run is already saved.
var saved := false
## The last save point could not be written (the window says so).
var _save_failed := false
## The owner's words for the same moments ([member saved]); "" keeps the
## unsaved ones.
var saved_note := SAVED_NOTE
var saved_leave_question := SAVED_LEAVE_QUESTION
var saved_menu_question := SAVED_MENU_QUESTION
## ...and over a finished duel whose result is saved (k4-4). A decided
## owner's match says nothing of its own there: what the decision means
## is the owner's to tell ([method tell_doors], from [signal match_decided]).
var result_saved_leave_question := RESULT_SAVED_LEAVE_QUESTION
var result_saved_menu_question := RESULT_SAVED_MENU_QUESTION
## How often the save point this match was taken up from has been taken up:
## that many seeds are passed over before the next duel's is drawn, so a
## resumed duel is never the deal that was quit ([MatchSaves]). Spent by
## the next duel.
var _resumes := 0
## The window's saved line, so a later save point can correct it.
var _saved_line: Label = null
# --- end P4 ---

var _duel: DuelScreen = null
var _window: Control = null
## DOES A FINISHED DUEL'S END OF DUEL WINDOW HOLD THE MATCH — true wherever
## the window opens; false headless (tests/CI), where none does and the
## match plays straight on. A test sets it to hold a match at that window,
## where a player meets the deciding duel and may quit before its OK (the
## bug campaign of 0.50.65, k4-1).
var waits_for_result_window := DisplayServer.get_name() != "headless"
## Has the duel that is up been advanced past? Two ears hear the End of
## Duel window close — [signal DuelScreen.result_closed] and the frame
## loop in [method _on_duel_finished] — and only the first may act.
var _duel_advanced := false
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
## Each seat's `Sideboard...` button on the between-duels window (null for
## an AI seat), so the keyboard goes back to the one that opened the
## window when it closes (the bug campaign c12, h4-5).
var _sb_buttons: Array = [null, null]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not resume_from.is_empty():
		_take_up(resume_from)
		return
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


# --- the polish pass c18, P4: saved between duels ---

## TAKE UP A SAVED MATCH ([member resume_from]): its config, record, stream
## and memories, the resume counted in the file at once (so taking the same
## point up again deals afresh again), then the between-duels window it was
## saved behind — `Continue match`, the Sideboard step, `Quit match` — over
## the pre-duel ground. Headless plays straight on, as after any duel.
func _take_up(taken: Dictionary) -> void:
	config = taken["config"]
	state = taken["state"]
	_memories = (taken["memories"] as Array).duplicate()
	_seeder.state = int(taken["seeder_state"])
	_resumes = int(taken["resumes"]) + 1
	# The computer's pace is today's Options', as `Go!` reads it; only a
	# demo (two computer seats) keeps the pace it was set up with.
	if not (config.is_ai(0) and config.is_ai(1)):
		config.pace = Settings.ai_pace()
	_save_point()
	# The file holds this point whether or not the count could be added.
	saved = true
	print("Match resumed: duel %d of %d, seed %d" % [state.duels_played() + 1,
		state.best_of, config.rng_seed])
	if DisplayServer.get_name() == "headless":
		_start_duel()
		return
	_backdrop()
	_show_window()


## THE MATCH AS IT STANDS, for a save ([method MatchSaves.match_json]).
func snapshot() -> Dictionary:
	return MatchSaves.match_json(config, state, _seeder.state, _resumes, _memories)


## A SAVE POINT — between duels only: a match decided drops its own file
## (an owner's run sees to its own, at [signal match_decided] — k4-1), any
## other writes itself whole, to its
## owner ([member save_with]) or its own file ([member keeps_save]).
## Free play and a match nobody asked to save write nothing.
func _save_point() -> void:
	if state.best_of == MatchState.FREE_PLAY or not (keeps_save or save_with.is_valid()):
		return
	if state.is_over():
		if not save_with.is_valid():
			MatchSaves.clear_match(config.record_match)
		saved = false
		return
	var ok: bool = bool(save_with.call(snapshot())) if save_with.is_valid() \
		else MatchSaves.write_match(snapshot())
	saved = ok
	_save_failed = not ok
	if is_instance_valid(_saved_line):
		_saved_line.text = saved_note if ok else NOT_SAVED_NOTE


## The ground a match taken up shows its window on before a duel is dealt
## — the pre-duel `Winbk_Startduel` the Magic Battle screen and the
## Gauntlet wear ([method GauntletScreen._backdrop]), or the flat dark one.
func _backdrop() -> void:
	var art := GameSkin.texture("versus_background")
	if art == null:
		var flat := ColorRect.new()
		flat.color = Color(0.09, 0.08, 0.07)
		flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(flat)
		return
	var ground := TextureRect.new()
	ground.texture = art
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
# --- end P4 ---


# ------------------------------------------------------------ the duels --

func _start_duel() -> void:
	_duel = load("res://game/duel/duel_screen.tscn").instantiate()
	_duel.config = _config_for_this_duel()
	_duel_advanced = false
	_duel.duel_finished.connect(_on_duel_finished)
	_duel.result_closed.connect(_on_result_closed.bind(_duel))
	_duel.leave_title = leave_title          # review 2026-10-21 ui-1
	# Saved, the doors say so (P4): the match is kept, the duel is not.
	var kept := saved and saved_leave_question != ""
	_duel.leave_question = saved_leave_question if kept else leave_question
	_duel.leave_label = leave_label
	_duel.leave_confirmed.connect(_on_leave_confirmed)
	_duel.menu_question = saved_menu_question if kept and saved_menu_question != "" \
		else menu_question
	_duel.menu_confirmed.connect(_on_menu_confirmed)
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
	if config.record_match == "": config.record_match = MpnArchive.new_id()
	if config.record_started == "": config.record_started = MpnArchive.utc_now()
	out.record_match = config.record_match
	out.record_started = config.record_started
	out.record_game = state.duels_played() + 1
	out.decks = [config.decks[0].duplicate(), config.decks[1].duplicate()]
	out.printings = config.printings.duplicate(true)
	out.sideboards = [config.sideboards[0].duplicate(),
		config.sideboards[1].duplicate()]
	out.player_names = config.player_names.duplicate()
	out.deck_names = config.deck_names.duplicate()
	out.portraits = config.portraits.duplicate()
	out.lives = config.lives.duplicate()
	out.pilots = config.pilots.duplicate()
	out.hotseat_privacy = config.hotseat_privacy
	out.unfair = config.unfair.duplicate()
	out.panel_colors = config.panel_colors.duplicate()
	out.pace = config.pace
	out.ante = config.ante
	# THE FORMAT TRAVELS (the bug campaign c12, h5-4): the duel writes its
	# record's `Format` header from its own config, and every duel of a
	# match or a gauntlet round was filed as Unrestricted whatever the
	# battle-setup screen had chosen — Past Games → Info said so.
	out.deck_format = config.deck_format
	# The match's parameters do NOT travel into the duel: a duel inside a
	# match is still one duel, and telling it otherwise would give it a
	# match of its own.
	# A MATCH TAKEN UP passes over one seed per time its save point was
	# (P4, [member _resumes]): the duel that was quit is never dealt again.
	for _passed in _resumes:
		_seeder.randi()
	_resumes = 0
	out.rng_seed = _seeder.randi() | 1
	return out


func _on_duel_finished(winner_id: int) -> void:
	state.record(winner_id)
	_ai_sideboards()
	# SAVED THE MOMENT THE DUEL IS RECORDED (P4) — before any window, so a
	# game closed over the End of Duel window keeps this duel's result.
	_save_point()
	# ...and the doors out of the finished duel say so (k4-4).
	_retell_doors()
	# A DECIDED MATCH IS ITS OWNER'S NOW, before the window too (the bug
	# campaign of 0.50.65, k4-1): a Gauntlet records the match and saves
	# or drops its run here, and may tell the doors what that means.
	if state.is_over():
		match_decided.emit(state.winner())
	if not waits_for_result_window:
		# Tests/CI: no windows and nothing to dismiss — the match simply
		# plays on, exactly as the duel screen starts without a coin toss.
		_advance_once(_duel)
		return
	# The duel's own End of Duel window has the duel's last word; the
	# match's window is the next one, not a second one on top of it.
	# TWO EARS ON ONE MOMENT. The duel announces the window's closing
	# ([signal DuelScreen.result_closed], [method _on_result_closed]) and
	# this loop watches for it as well; whichever hears first advances,
	# and [member _duel_advanced] keeps the other quiet. One ear was the
	# 2026-09-07 playtest's *"stuck on playfield"* — see
	# [method DuelScreen._show_result_window].
	var duel := _duel
	while is_instance_valid(duel) and duel.result_dialog_open():
		await get_tree().process_frame
	_advance_once(duel)


func _on_result_closed(duel: DuelScreen) -> void:
	_advance_once(duel)


## THE DOORS OUT OF A FINISHED DUEL SAY WHAT IS TRUE NOW (the bug campaign
## of 0.50.65, k4-4). Pause → `Exit duel` and `Return to main menu` still
## open over the End of Duel window, and their words were set when the duel
## was dealt: after duel 1 of a match they said its record was lost when it
## had just been saved, and after the deciding duel that Resume match would
## take it up when its file had just been dropped. Saved with this duel's
## result, they say so; decided, a match nobody owns says it is over (an
## owner's says what the owner tells it, [signal match_decided]); otherwise
## the words the duel was dealt with stand — they are still true.
func _retell_doors() -> void:
	if state.is_over():
		if not reports_to_owner:
			tell_doors(OVER_LEAVE_QUESTION, OVER_MENU_QUESTION)
	elif saved:
		tell_doors(result_saved_leave_question, result_saved_menu_question)


## The two doors of the duel on the table — its splash's left button and
## Pause → `Exit duel` ([param leave]), Pause → `Return to main menu`
## ([param menu]) — ask these from now on. For an owner, which tells a
## decided match's doors what its decision means (k4-4).
func tell_doors(leave: String, menu: String) -> void:
	if not is_instance_valid(_duel):
		return
	_duel.leave_question = leave
	_duel.menu_question = menu


## Advance past [param duel] — once, and only while it is still the duel
## on the table.
func _advance_once(duel: DuelScreen) -> void:
	if _duel_advanced or duel != _duel:
		return
	_duel_advanced = true
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
		_duel.set_process_unhandled_input(false)   # and the pad's buttons
	dialog.body().add_child(_centred(state.progress_line(), 14))
	_sb_buttons = [null, null]
	var go_on: Button
	if over:
		dialog.body().add_child(_centred(state.verdict(), 16, true))
		go_on = dialog.add_button("OK")
		go_on.pressed.connect(_leave)
	else:
		dialog.body().add_child(_centred(state.duel_heading(), 14))
		# SAVED, OR NOT (P4): one small line, so `Quit match` is read as
		# the way out it now is — the match waits on Magic Battle.
		_saved_line = null
		if keeps_save or save_with.is_valid():
			_saved_line = _centred(saved_note if saved
				else (NOT_SAVED_NOTE if _save_failed else ""), 13)
			dialog.body().add_child(_saved_line)
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
				_sb_buttons[pid] = button
		# Listed and greyed: there is no route from a match into the Deck
		# Builder and back.
		dialog.add_button(EDIT_DECK).disabled = true
		go_on = dialog.add_button(CONTINUE)
		go_on.pressed.connect(_next_duel)
		var quit := dialog.add_button(QUIT)
		quit.pressed.connect(_leave)
		if saved:
			quit.tooltip_text = saved_note      # P4: leaving keeps the match
	add_child(dialog)
	# THE WINDOW HOLDS ITS ROW AND TAKES THE KEYBOARD (the bug campaign
	# c12, h4-5). Made 430 wide for two buttons, it held four or five:
	# `Quit match` ran past its right edge against the computer with
	# sideboarding, and in hotseat the last two sat wholly outside it. And
	# nothing on it had the focus, so after End of Duel's OK the keyboard
	# and a pad's D-pad had nothing to press — Enter did nothing. The
	# window now grows to its row, and `Continue match` (or the last
	# window's OK) holds the keyboard, as the duel's own windows do.
	fit_to_buttons(dialog)
	go_on.grab_focus()


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


## GROW A WINDOW TO ITS BUTTON ROW (the bug campaign c12, h4-5) — this
## screen's window and the gauntlet's two ([GauntletScreen]). Each foot
## button first widens to its own label, by the measure
## [method GauntletOptions.fit] uses (the 1997 button art is a double rule
## 8px deep a side, and `Continue match` sat on the inner one); then the
## window widens to the row, never narrows, stays centred, grows to its
## lines ([method OriginalDialog.fit_height]) and stays on the screen.
## Measured off the buttons' own font, so the 1997 lettering and the
## fallback face both fit. Call it once the window is in the tree.
static func fit_to_buttons(dialog: OriginalDialog) -> void:
	if not dialog.is_inside_tree():
		return
	var row: HBoxContainer = dialog._buttons
	for child in row.get_children():
		var button := child as Button
		if button == null:
			continue
		var font := button.get_theme_font("font")
		if font != null:
			var wide := font.get_string_size(button.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1,
				button.get_theme_font_size("font_size")).x \
				+ 2.0 * OriginalDialog.BUTTON_MARGIN + 8.0
			button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, wide)
	var wanted := row.get_combined_minimum_size().x + 2.0 * OriginalDialog.MARGIN
	if wanted > dialog.size.x:
		dialog.size.x = wanted
	dialog.fit_height()
	# Even sides, so the centred window lands on whole pixels (a grown
	# window can come out an odd number wide or tall).
	dialog.size = (dialog.size * 0.5).ceil() * 2.0
	dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER,
		Control.PRESET_MODE_KEEP_SIZE)
	dialog.keep_on_screen()


## A dialog line, centred — the between-duels window is two short
## sentences and a row of buttons, and left-ragged text under a centred
## title reads as a mistake.
static func _centred(text: String, size := 14, bold := false) -> Label:
	var line := OriginalDialog.label(text, size, bold)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return line


func _next_duel() -> void:
	# NOT UNDER THE SIDEBOARD WINDOW (bug pass 2026-10-03). The
	# between-duels window draws no blocker, so its `Continue match` kept
	# the keyboard while `Sideboard...` was open: Tab from `Done` reached
	# it and Enter dealt duel 2 with the deck still short — the size rule
	# `Done` is greyed to enforce — and the Sideboard window left open
	# over the new table. [method _open_sideboard] also takes the focus
	# off these buttons; this is the gate for any other way in.
	if _sideboard_open():
		return
	if _window != null:
		_window.queue_free()
		_window = null
	_drop_duel()
	_start_duel()


func _leave() -> void:
	get_tree().change_scene_to_file("res://game/main.tscn")


## The player said yes to leaving from inside a duel (review 2026-10-21,
## ui-1; [member leave_question]). Only while this match is the scene — the
## guard [method DuelScreen._on_game_over_dismissed] keeps for the same
## reason: a match a test holds is not the tree's to swap.
func _on_leave_confirmed() -> void:
	if reports_to_owner:
		leave_confirmed.emit()
		return
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file(SETUP_SCREEN)


## The player said yes to [member menu_question]: the title, or the owner's
## to act on, under the same guard.
func _on_menu_confirmed() -> void:
	if reports_to_owner:
		menu_confirmed.emit()
		return
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file(MAIN_MENU)


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
	# ONE AT A TIME. The between-duels window draws no blocker, so the
	# `Side&board...` button under this one keeps the KEYBOARD: Enter again
	# built a second window over the first, and only the newest is
	# remembered — `Done` closed that one and left the older sitting over
	# `Continue match` with nothing on screen able to close it.
	if _sideboard_open():
		return
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
	# ...and the keyboard comes with it, so Enter answers THIS window
	# rather than the button that opened it — and STAYS with it: the
	# between-duels buttons under it leave the focus ring until it closes
	# (bug pass 2026-10-03; see [method _next_duel]).
	_set_window_focusable(false)
	_sb_done.grab_focus()


func _close_sideboard() -> void:
	var pid := _sb_pid
	if is_instance_valid(_sb_dialog):
		_sb_dialog.dismiss()
	_sb_dialog = null
	_sb_pid = -1
	_set_window_focusable(true)
	# The deck as it now stands is the match's (P4): a save point.
	_save_point()
	# ...and the keyboard back to the button that opened it (the bug
	# campaign c12, h4-5): `Done` goes with its window, and the focus went
	# with it — Enter and the D-pad had nothing to press until a click.
	if pid >= 0 and pid < _sb_buttons.size() and is_instance_valid(_sb_buttons[pid]) \
			and (_sb_buttons[pid] as Control).is_inside_tree():
		(_sb_buttons[pid] as Control).grab_focus()


## Is the Sideboard window up (and not on its way out)?
func _sideboard_open() -> bool:
	return is_instance_valid(_sb_dialog) and not _sb_dialog.is_queued_for_deletion()


## Take the between-duels window's buttons out of the keyboard's ring
## while the Sideboard window is over them, and put them back after.
func _set_window_focusable(on: bool) -> void:
	if not is_instance_valid(_window):
		return
	for button: Control in _window.find_children("*", "BaseButton", true, false):
		if not on:
			if not button.has_meta(&"sb_focus_mode"):
				button.set_meta(&"sb_focus_mode", button.focus_mode)
			button.focus_mode = Control.FOCUS_NONE
		elif button.has_meta(&"sb_focus_mode"):
			button.focus_mode = button.get_meta(&"sb_focus_mode")
			button.remove_meta(&"sb_focus_mode")


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

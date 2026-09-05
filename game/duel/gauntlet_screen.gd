class_name GauntletScreen
extends Control
## THE GAUNTLET, RUNNING — the fourth 1997 duel mode, and the only one
## this project had never built: `2&Gauntlet:Defeat as many opponents in a
## row as possible.` (`@SHELLSCREEN_DUEL`, `Program/UIStrings.txt:5-11`).
##
## THE NESTING IS THE DESIGN. A gauntlet is a sequence of MATCHES, a match
## is a sequence of DUELS, and each layer knows only the one below it:
## this screen owns [MatchScreen]s exactly as [MatchScreen] owns
## [DuelScreen]s, listens for [signal MatchScreen.match_finished] exactly
## as that screen listens for [signal DuelScreen.duel_finished], and hands
## each result to [GauntletState] exactly as that screen hands each duel's
## to [MatchState]. Nothing below this file knows a gauntlet exists.
##
## THE THREE WINDOWS.
##
##  1. **Gauntlet Options** ([GauntletOptions]) — the run's parameters,
##     shown before it starts. `@DIALOG_GAUNTLETOPTIONS` entry for entry,
##     plus the shell page's `&Num opponents:` and `Side&board between
##     duels` (that file's doc comment carries the choice and the `[QoL]`
##     label on it), and the startup screen's `&Create Deck...`
##     ([method _create_deck]).
##  2. **The next-opponent window** — `@DIALOG_STARTEXP1MATCH_GAUNTLET`
##     (`Program/UIStrings.txt:149-153`), shown before each MATCH: one of
##     three sentences over the opponent's name. See
##     [method _show_announcement].
##  3. **The round window** — `@DIALOG_GAUNTLETENDDUEL`
##     (`Program/UIStrings.txt:520-525`), shown between MATCHES: the
##     `@GAUNTLET` message, `That was round %d`, `Your record is %d/%d/%d`
##     and the two buttons `&Next round` / `&Quit Gauntlet`. See
##     [method _show_round_window] for the two rules in it that are easy
##     to get wrong.
##
## BETWEEN THE DUELS OF ONE MATCH, NOTHING NEW HAPPENS, and that is the
## design's own reading (`docs/gauntlet-design.md` §1.5): it is the
## ordinary between-duels window [MatchScreen] already builds, with the
## sideboard step on it. The original showed one window after EVERY duel
## and our mid-match one is [MatchScreen]'s — so `The match continues...`
## ([constant GauntletState.CONTINUES]) is composed and tested in
## [method GauntletState.end_of_duel_lines] and is the one branch of the
## four this screen never renders. Recorded rather than quietly dropped.
##
## DETERMINISM: ONE SEED FOR THE WHOLE RUN, split the way [MatchScreen]
## splits a match's. `DuelConfig.rng_seed` seeds one stream, and that
## stream draws — in this order and no other — your `<random deck>`, the
## opponent shuffle, the start offset, and then one seed per match. So a
## gauntlet replays whole from its logged number, and round 4 of a run is
## reproducible only as round 4 of THAT run. This matters more here than
## anywhere: MicroProse's own patch notes list *"The random selection of
## opponents in the Gauntlet is now fixed"* (FAQ 1.2,
## `s30/shandalar-faq.txt:458-465`).
##
## WHAT IS NOT HERE, deliberately: `&Save gauntlet` / `&Load gauntlet...`.
## We have no save/load anywhere — not for a duel, not for a match — and
## it should land as one design when M5 needs it
## (`docs/gauntlet-design.md` §5.5). The run logs its seed instead.

## Over [MatchScreen]'s own between-duels window (400), which is over the
## duel screen's coin panel (250) and dialogs (200). The round window is a
## window over the whole stack, so it must outrank all of them.
const WINDOW_Z := MatchScreen.WINDOW_Z + 1

## Where `&Create Deck...` goes ([method _create_deck]). A scene path is a
## string and a typo in one fails at RUN time, so it is a constant with a
## test on it rather than a literal at the call site.
const DECK_BUILDER := "res://game/deck_builder/deck_builder_screen.tscn"

## The run's template: seat 0 is YOU (deck, name, life), seat 1 is the
## opponent of the round. [member GauntletOptions.enemy_level] fills seat
## 1's pilot on `Run the gauntlet` — the gauntlet is single-seat by
## definition (`docs/gauntlet-design.md` §5.7), so it never offers the
## hotseat choice the battle-setup screen does.
var config: DuelConfig = null
## The run's parameters and the window that sets them.
var options := GauntletOptions.new()
## The deck files the opponents are drawn from. Empty means "every deck
## this project can see" ([method default_roster]), which is the
## original's own rule: it counts the `.dck` files in its deck directory
## and runs against them (`DUEL.EXE` 0x49c2d0). Your own deck is NOT
## removed from that list — the original does not remove it either, and a
## mirror match is a real 1997 gauntlet round.
var opponent_paths: Array[String] = []
var state := GauntletState.new()

var _match: MatchScreen = null
var _window: Control = null
## The run's one stream — see the class doc on determinism.
var _rng := RandomNumberGenerator.new()
## Set once `Run the gauntlet` has been pressed (or, headless, at once).
var _running := false
## The last `@GAUNTLETERRORS` line said about YOUR deck, "" if none —
## what the window shows, kept so a headless run can be asked.
var last_refusal := ""


## Every deck this project can see THAT A GAUNTLET COULD DEAL — the
## original's rule (every `.dck` in its directory), less the decks a round
## would refuse the moment it drew them ([method
## GauntletState.opponent_deck_problem]: unreadable, under forty, over
## the caps). [QoL] The 1997 directory held only decks the 1997 engine
## could play; ours also ships `decks/tournament/`, `decks/community/` and
## `decks/extended_community/`, period decks whose cards this pool does
## not all hold yet (`docs/decks-1997.md`), and a strict load turns those
## into refusals. Dealt blind, a hundred such decks in a pool of three
## hundred ended most twenty-round runs on a deck nobody chose. The
## proxy-free ones among them ARE dealt. A roster the player hands in is
## taken as given.
static func default_roster() -> Array[String]:
	var out: Array[String] = []
	for path in DeckStore.all_deck_paths():
		if GauntletState.opponent_deck_problem(path,
				DeckList.load_file(path, true)) == "":
			out.append(path)
	return out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop()
	if config == null:
		config = DuelConfig.hotseat_default()
	if opponent_paths.is_empty():
		opponent_paths = default_roster()
	var run_seed := config.rng_seed
	if run_seed == 0:
		run_seed = randi() | 1      # never 0: that means "roll one"
		config.rng_seed = run_seed
	_rng.seed = run_seed
	# LOGGED, on the same reasoning the duel logs its own: a run is
	# reproducible from a bug report without a save file.
	print("Gauntlet seed: %d" % run_seed)
	if DisplayServer.get_name() == "headless":
		# Tests/CI: no windows and nothing to dismiss. The run simply
		# begins on the parameters it was handed, exactly as the match
		# screen starts its first duel without a coin toss.
		begin_run()
		return
	_show_options()
	_start_music()

## THE GAUNTLET'S OWN BED, and the longest the library has: a gauntlet is
## a RUN of duels, so its screen is looked at repeatedly across a session
## and a short loop wears through fastest of anything in the game.
##
## `music_location_13` measured 2026-09-05 across all 27 beds: **38.9 s,
## the longest**, with **zero** frames below the silence floor (the trap
## that ruled out `Ucastle`, which is 30.6% silence) and 932
## zero-crossings/s — darker than its length-neighbours (`location_14` is
## 1577), which is what a screen you return to between duels wants.
## `location_11` (38.6 s) and `location_19` (36.2 s) sit behind it in
## measured order. Deliberately NOT the shell's `music_location_15`: the
## two screens are one button apart and sharing a bed would restart the
## same track on every crossing.
##
## `[QoL]`: the 1997 shell played no music at all (`Provenance.md`, "The
## shell screen's audio"), so every bed on a menu screen here is ours.
const GAUNTLET_BEDS: Array[String] = [
	"music_location_13",
	"music_location_11",
	"music_location_19",
]

## The screen's voice on the Music bus. Freed with the screen.
var _music: MusicPlayer


func _start_music() -> void:
	GameAudio.apply_settings()
	_music = MusicPlayer.new()
	add_child(_music)
	_apply_music_switch()


## The GLOBAL `music_enabled` switch is the whole rule, as it is on the
## shell — the Deck Builder's screen-scoped switch is that screen's.
func _apply_music_switch() -> void:
	if _music == null:
		return
	if not Settings.music_enabled():
		_music.stop_music()
		return
	_music.play_one(MusicLibrary.single_for(GAUNTLET_BEDS))


## Stops on the way out, so the duel starts against silence and the PCM
## is dropped rather than carried.
func _exit_tree() -> void:
	if is_instance_valid(_music):
		_music.stop_music()



## THE GROUND THE OPTIONS WINDOW SITS ON. `Winbk_Startduel` — the
## classical line-art mourners, the original's own pre-duel ground, and
## the same one the battle-setup screen wears. A gauntlet is a screen
## BEFORE a duel and reaches its first duel through nothing else, so
## without this its window would float on a black void, which is what the
## screenshot pass showed. Same fallback as that screen's: the flat dark
## ground, so the layout is identical with or without the 1997 art.
func _backdrop() -> void:
	var art := GameSkin.texture("versus_background")
	if art == null:
		var flat := ColorRect.new()
		flat.color = Color(0.09, 0.08, 0.07)
		flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(flat)
		return
	var bg := TextureRect.new()
	bg.texture = art
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


# --------------------------------------------------------- the front door --

func _show_options() -> void:
	var dialog := options.window(opponent_paths, begin_run, _leave,
		_create_deck)
	dialog.z_index = WINDOW_Z
	_window = dialog
	add_child(dialog)


## `&Create Deck...` — `@DIALOG_GAUNTLETSTARTUP` entry 13
## (`s30/assets/text/Uistrings.txt:648` = `Program/UIStrings.txt:648`), the
## startup screen's own route into the Deck Builder. The original wires it
## to control `0x44e`, calls `DeckBuilderMain(hwnd, 0x18, 1)` and, when
## that returns, **re-enumerates the decks and re-shuffles the gauntlet**
## (`docs/gauntlet-design.md` §1.5).
##
## OURS IS A SCENE CHANGE, and the re-enumeration rule comes free rather
## than being implemented: our Deck Builder is a whole screen, it goes back
## to the title when it exits, and the gauntlet is re-entered from there —
## so the next run reads the deck folder afresh in [method _ready] and
## shuffles it afresh in [method begin_run]. There is no path on which a
## stale list or a stale order survives a visit to the builder, which is
## exactly what the 1997 rule guarantees.
##
## WHAT DIVERGES, marked because it is a real difference: the original came
## BACK to its startup screen with the parameters still set, and we come
## back to the title. Honouring that would need the Deck Builder to know
## who sent it (`MatchScreen` disables its own `&Edit deck...` for the same
## missing piece), and inventing a return path for one button is a bigger
## change to a shared 115 KB screen than slice 4 is worth. The run has not
## started when this button is available, so nothing is lost but the
## clicks.
func _create_deck() -> void:
	_window = null
	get_tree().change_scene_to_file(DECK_BUILDER)


## `&Run the gauntlet`. Resolves your deck, shuffles the opponents, and
## starts round 1. Public so a test — and a standalone scene run — can
## start a run without a window.
func begin_run() -> void:
	if _running:
		return
	_window = null
	if not _apply_options():
		return                        # your deck was refused, and said so
	_running = true
	var pool: Array[String] = opponent_paths.duplicate()
	state.begin(pool, _rng, options.run_length(pool.size()))
	for path in state.order:
		state.names[path] = GauntletOptions.deck_title(path)
	_start_match()


## The options window writes into [member options] as the player clicks;
## this is where those parameters become the run's [DuelConfig]. False
## when YOUR deck cannot be played, in which case the refusal is already
## on screen and the run has not begun.
##
## YOUR DECK IS CHECKED THE WAY THE OPPONENTS' ARE, in `@GAUNTLETERRORS`'
## own `Player's deck %s is invalid.` words ([method
## GauntletState.your_deck_problem]), and a refusal puts the options
## window BACK, because the original's message box returns to its startup
## screen with the parameters still set (`docs/gauntlet-design.md` §1.7)
## and `Please select a new deck` is what it asks for. Before 2026-09-02
## an unreadable deck fell through to "keep the default" — the config's
## own deck, which in a gauntlet reached from the title is the hotseat
## White Knights — so the player picked a deck and played another with no
## word said. A deck that holds a proxy is exactly such a deck: the
## strict load reports it as an error, and the setup screen refuses it by
## name for the same reason ([method ProxyCard.refusal]).
##
## `<random deck>` DRAWS ONLY FROM DECKS THAT PASS, so the seed can never
## hand you one the next line would refuse — the setup screen's
## `_playable_paths` rule. The draw still comes from the run's own
## stream, so the seed replays which deck you were given.
func _apply_options() -> bool:
	config.best_of = options.best_of
	config.ante = 1 if options.ante else 0
	config.sideboard_between_duels = options.sideboard_between_duels
	config.pilots[0] = null          # seat 0 is you, always (§5.7)
	config.pilots[1] = GauntletOptions.profile(options.enemy_level)
	config.pace = Settings.ai_pace()
	var mine := options.your_deck
	var deck: DeckList = null
	if mine == "":
		var playable: Array[String] = []
		for path in opponent_paths:
			if GauntletState.your_deck_problem(path,
					DeckList.load_file(path, true)) == "":
				playable.append(path)
		if playable.is_empty():
			_refuse_your_deck(GauntletState.YOUR_DECK_ILLEGAL)
			return false
		mine = playable[_rng.randi() % playable.size()]
	deck = DeckList.load_file(mine, true)
	var problem := GauntletState.your_deck_problem(mine, deck)
	if problem != "":
		_refuse_your_deck(problem % GauntletOptions.deck_title(mine))
		return false
	config.decks[0] = deck.cards
	config.sideboards[0] = deck.sideboard
	config.player_names[0] = "You"
	config.panel_colors[0] = DuelConfig.dominant_color(deck.cards)
	return true


## Your deck cannot be played: say which and why, then put the options
## window back up so a new one can be chosen. Headless, the warning is
## the whole of it — there is nobody to choose again.
func _refuse_your_deck(message: String) -> void:
	last_refusal = message
	push_warning(message)
	if DisplayServer.get_name() == "headless":
		return
	_close_window()
	var dialog := OriginalDialog.create(GauntletState.TITLE,
		Vector2(430, 150), "panel_dark_stone")
	dialog.z_index = WINDOW_Z
	_window = dialog
	dialog.body().add_child(_centred(message, 14))
	GauntletOptions.fit(dialog.add_button("OK")).pressed.connect(
		func() -> void:
			_close_window()
			_show_options())
	add_child(dialog)


# ------------------------------------------------------------ the rounds --

## ONE ROUND: check the opponent's deck, ANNOUNCE who it is, then play the
## match. The announcement is a window, so the last two are separate calls
## — [method _show_announcement] raises it and its OK runs
## [method _play_match]. Headless skips straight to the match, exactly as
## it skips the round window, and adds no wait a headless run did not have.
##
## The deck is checked BEFORE the announcement and not after: announcing an
## opponent and then refusing to meet them would be two windows to say one
## thing, and `@GAUNTLETERRORS` is a message box that ends the run.
func _start_match() -> void:
	var round_config := _config_for_this_round()
	if round_config == null:
		return                        # the deck refused; the run is over
	if DisplayServer.get_name() == "headless":
		_play_match(round_config)
		return
	_show_announcement(round_config)


## The match itself: a whole [MatchScreen] against the round's opponent.
func _play_match(round_config: DuelConfig) -> void:
	_match = load("res://game/match_screen.tscn").instantiate()
	_match.config = round_config
	# Both before it enters the tree: the match must know its last word is
	# not its own before it can possibly reach it.
	_match.reports_to_owner = true
	_match.match_finished.connect(_on_match_finished)
	add_child(_match)


## THE NEXT-OPPONENT WINDOW — `@DIALOG_STARTEXP1MATCH_GAUNTLET`
## (`Program/UIStrings.txt:149-153` = `s30/assets/text/Uistrings.txt:149-153`),
## the three lines that introduce a round's opponent, over the opponent's
## own name. [method GauntletState.announcement] picks which of the three.
##
## THIS IS A WINDOW THE ORIGINAL HAD AND WE DID NOT, and it is worth
## saying why it is a window of ours rather than a screen of theirs. The
## 1997 announcement sat on the pre-match VERSUS screen —
## `@DIALOG_STARTEXP1MATCH` (`:144-147`) is that screen's own two strings,
## `vs.` and `playing with %s`, and the 240x170 `Face_*` portrait set is
## its art (`Provenance.md`). We have no versus screen and building one is
## not slice 4; what slice 4 owes is the three SENTENCES. So they get the
## smallest honest home — the announcement over the name, on the same
## stone the round window wears — and `vs.` / `playing with %s` are left
## for whoever builds the screen they belong to.
##
## It follows the round window rather than replacing that window's
## `Your next duel is against %s.`: those are two different moments in the
## original (one closes a round, one opens the next) and the round window
## must keep its line, because the LAST round's window has no announcement
## after it at all.
func _show_announcement(round_config: DuelConfig) -> void:
	_close_window()
	# Measured, not guessed: two lines and a foot. The round window is 250
	# for five lines and this is the same stone at the same rhythm — the
	# screenshot pass caught 190 leaving a hand's width of bare rock
	# between the name and the button.
	var dialog := OriginalDialog.create(GauntletState.TITLE,
		Vector2(430, 150), "panel_dark_stone")
	dialog.z_index = WINDOW_Z
	_window = dialog
	dialog.body().add_child(_centred(state.announcement(), 14))
	dialog.body().add_child(_centred(state.opponent_name(), 18, true))
	GauntletOptions.fit(dialog.add_button("OK")).pressed.connect(
		func() -> void:
			_close_window()
			_play_match(round_config))
	add_child(dialog)


## The round's own config: the run's, with the opponent's deck loaded into
## seat 1 and a seed of its own drawn from the run's stream.
##
## THE OPPONENT'S DECK IS VALIDATED EVERY ROUND, in the original's own
## words. `@GAUNTLETERRORS` (`Program/UIStrings.txt:1365-1378` =
## `s30/assets/text/Uistrings.txt:1325-1338`) ships four messages for the
## opponent's deck alone and three of them are reachable here — the run
## cannot continue into a duel with an empty library, and a deck deleted
## or shortened between the shuffle and the round is exactly the case the
## original guards. [method GauntletState.opponent_deck_problem] chooses
## between them and its doc comment carries the fourth's obituary.
func _config_for_this_round() -> DuelConfig:
	var path := state.opponent()
	var deck := DeckList.load_file(path, true) if path != "" else DeckList.new()
	var problem := GauntletState.opponent_deck_problem(path, deck)
	if problem != "":
		_end_run_on_error(problem % state.opponent_name())
		return null
	var out := DuelConfig.new()
	out.decks = [(config.decks[0] as Array).duplicate(), deck.cards]
	out.sideboards = [(config.sideboards[0] as Array).duplicate(),
		deck.sideboard]
	out.player_names = [config.player_names[0], state.opponent_name()]
	out.deck_names = [config.deck_names[0], state.opponent_name()]
	out.portraits = config.portraits.duplicate()
	out.lives = config.lives.duplicate()
	out.pilots = config.pilots.duplicate()
	out.panel_colors = [config.panel_colors[0],
		DuelConfig.dominant_color(deck.cards)]
	out.pace = config.pace
	out.ante = config.ante
	out.best_of = config.best_of
	out.sideboard_between_duels = config.sideboard_between_duels
	out.deck_format = config.deck_format
	out.rng_seed = _rng.randi() | 1
	return out


## A match has ended. Fold its duels into the session record, compose the
## message BEFORE the round counter moves (`That was round %d` names the
## round just played), then advance or stop.
func _on_match_finished(winner_id: int) -> void:
	var human: int = _match.state.human_seat
	var won := winner_id == human
	# THE RECORD IS THE SESSION'S, NOT THE MATCH'S — three counters the
	# match's own pair is zeroed against and these are not (`DUEL.EXE`
	# 0x5f76c0 / 0x5f6494 / 0x5f67fc against 0x5f6c58 / 0x5f67e8). The
	# match kept its duels; the run adds them and keeps them.
	var tally: MatchState = _match.state
	for _i in tally.wins[human]:
		state.record_duel(GauntletState.Outcome.WON)
	for _i in tally.wins[1 - human]:
		state.record_duel(GauntletState.Outcome.LOST)
	for _i in tally.draws:
		state.record_duel(GauntletState.Outcome.TIED)
	var lines := state.end_of_duel_lines(
		GauntletState.outcome_for(tally.last_winner, human), true, won)
	state.record_match(won)
	if DisplayServer.get_name() == "headless":
		# Tests/CI: no window to dismiss, so the run plays straight on —
		# and adds no wait a headless run did not have.
		_advance()
		return
	_show_round_window(lines)


## `&Next round`, or what the headless path does instead of offering it.
func _advance() -> void:
	if state.over:
		return
	_drop_match()
	_start_match()


func _drop_match() -> void:
	if is_instance_valid(_match):
		_match.queue_free()
	_match = null


# ------------------------------------------------------- the round window --

## THE ROUND WINDOW — `@DIALOG_GAUNTLETENDDUEL`, the between-matches
## window, and the mode's whole voice.
##
## Two rules from the decompiled dialog (resource `0xf6`) that are easy to
## get wrong, and both have a test:
##
##  1. **The record is the session's, not the match's** — see
##     [method _on_match_finished].
##  2. **When the run is over the two buttons are not disabled, they are
##     ABSENT.** The original hides both and shows the lone OK it had
##     hidden to make room for them:
##
##         if (gauntlet_flag == 0) { hide(0x493); SetDlgItemText(0x494, OK); }
##         else { SetDlgItemText(0x493, "&Next Round");
##                SetDlgItemText(0x494, "&Quit Gauntlet"); }
##
##     and *"if the run is over at all, both buttons are hidden"*. §6.1's
##     "grey what you cannot offer" is about MENU entries — a dead-end
##     dialog offering a greyed `Next round` would be offering a round
##     that does not exist.
func _show_round_window(lines: Array[String]) -> void:
	if _window != null:
		_window.queue_free()
	# The run's last word wears the End of Duel ground, whose bevel is the
	# only INSET one in the set — the same treatment the duel's own
	# verdict gets.
	var dialog := OriginalDialog.create(GauntletState.TITLE,
		Vector2(430, 250),
		"panel_end_duel" if state.over else "panel_dark_stone")
	dialog.z_index = WINDOW_Z
	_window = dialog
	for i in lines.size():
		# The result line is the message's own headline; the rest is body.
		dialog.body().add_child(_centred(lines[i], 16 if i == 0 else 14,
			i == 0))
	if state.over:
		GauntletOptions.fit(dialog.add_button("OK")).pressed.connect(_leave)
	else:
		GauntletOptions.fit(dialog.add_button(
			GauntletState.NEXT_ROUND)).pressed.connect(_next_round)
		GauntletOptions.fit(dialog.add_button(
			GauntletState.QUIT)).pressed.connect(_quit_run)
	add_child(dialog)


## A dialog line, centred — the same treatment [MatchScreen] gives its
## own window's lines, so the two read as one piece of furniture.
static func _centred(text: String, size := 14, bold := false) -> Label:
	var line := OriginalDialog.label(text, size, bold)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return line


func _next_round() -> void:
	_close_window()
	_advance()


## `&Quit Gauntlet` — the original's dialog returns 0 and its driver falls
## back to the startup screen. Ours goes back to the title, which is where
## every other screen in this project ends.
func _quit_run() -> void:
	state.quit()
	_close_window()
	_leave()


func _close_window() -> void:
	if _window != null:
		_window.queue_free()
		_window = null


## A deck the run cannot use. `@GAUNTLETERRORS`' own words, then out —
## the original shows a message box and returns to its startup screen.
func _end_run_on_error(message: String) -> void:
	state.quit()
	push_warning(message)
	if DisplayServer.get_name() == "headless":
		return
	_show_round_window([message] as Array[String])


func _leave() -> void:
	get_tree().change_scene_to_file("res://game/main.tscn")

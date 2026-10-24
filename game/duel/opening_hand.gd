class_name OpeningHand
extends Control
## THE OPENING HAND — play or draw, then the mulligans (docs/duel-todo.md
## §1.5, §6.2). Runs between the coin toss and turn 1.
##
## THE ORDER OF EVENTS is the owner's, from the playtest of 2026-09-08:
## *"There is a coin toss, and then winning player decides play or draw
## first! But!! Then, the winning player must see his hand (so first hand
## stack should be seen besides starting window!) and only then can he
## decide (ai or human) to mulligan or not! And then second player should
## also be able to take a mulligan again by seeing his hand. After each
## mulligan you draw one card less."* So:
##
##   1. the toss winner chooses the order (`Play first` / `Draw first`;
##      an AI winner takes the play, as both references do);
##   2. the toss winner looks at their hand and keeps it or throws it back,
##      as often as they like — each redraw is one card fewer (the PARIS
##      mulligan, `MtgGame.take_mulligan`), and the question is asked
##      again of the smaller hand until they keep;
##   3. the other seat does the same;
##   4. the duel begins.
##
## THE RULE IS NO LONGER 1997'S. `Duel.hlp`, topic **Mulligan**, allowed one
## redraw of seven for seven, and only of a hand with no land or nothing
## but land; the engine's own history of that rule is in `MtgGame`, above
## `take_mulligan`, and docs/ROADMAP.md carries the owner's ruling and the
## Deck Lab's measure of it. `[QoL]`. The `mulligan to %d` strings in the
## top-level string table (`UIStrings.txt:551-556`) are Manalink 3's, and
## still not ported: every line here is the 1997 table's, with the new
## hand's size added by [constant MULLIGAN_COUNT].
##
## THE HAND IS IN VIEW while the question is asked — INSIDE THE WINDOW,
## as the seat's own hand window standing between the two figures of the
## ground ([method OpeningWindow.show_hand]), shown again after every
## redraw and turned round with the window in a hotseat. The owner,
## 2026-09-08: *"card stack for mulligan decision would be centered on
## the right besides ante cards between the standing ladies"*. What the
## seat that is deciding sees is its own hand, the antes, and the two
## buttons — which is the 1997 screenshot, with the hand in it. The duel
## screen's own hand windows are out of sight for the duration
## (`DuelScreen._run_opening_hand`): the window is centred over them and
## one hand shown twice is one too many.
##
## BEFORE IT, the toss winner CHOOSES. `Duel.hlp`, **Play or Draw Rule**:
## *"In every duel, one player plays first and the other draws first. Who
## does which is decided by the player who wins a coin toss… The player who
## gets First Play does not draw a card during her first turn."*
##
## EVERY LINE THIS SHOWS is `@DIALOG_PLAYORDRAW` (Program/UIStrings.txt:487)
## or `@DIALOG_MULLIGAN` (:499), quoted exactly — see [constant PLAY_OR_DRAW]
## and [constant MULLIGAN].
##
## IT ALL HAPPENS IN ONE WINDOW ([OpeningWindow]), AND THAT IS OUR OWN
## COMPOSITION — `[QoL]`, not `[1997]`. **1997 had two windows.**
## `@DIALOG_PLAYORDRAW` is `Magic.exe`'s DIALOG resource 244 — four
## controls, `Play first` and `Draw first` and NO OK button — on
## `Winbk_Startduel2.pic` (284x394); `@DIALOG_MULLIGAN` is resource 227 —
## the first-turn line, both ante slots, `Mulligan`, and `Start the duel`
## at control id 1 (IDOK) — on `Winbk_Startduel.pic` (659x394). Two
## loaders in Manalink's `src/functions/windows.c:1338-1369` bind each
## ground to its dialog. The full citation is docs/duel-todo.md §6.2,
## "THE COMPOSITION CLAIM ABOVE IS WRONG". Our one window asks each
## question in its own button row — the order, then `Take mulligan` /
## `Start the duel` for as long as the seat keeps redrawing — with both
## antes up from the first frame.
##
## THE LAST LOOK. The window closes on the player's own press. When the
## opponent throws a hand back AFTER that press, the head band says so
## ("Cromer has no land and chose to take a mulligan", the 1997
## screenshot) and the window holds for one more `Start the duel` so the
## player actually reads it — [member OpeningWindow.status_serial] against
## `run`'s `pressed_serial` is the whole of that rule. An opponent who
## merely KEEPS after the press changes nothing the player needs to see,
## so it costs no click (the 2026-09-06 playtest's "one decision, one
## click").
##
## The engine half is MtgGame.stake_ante / deal_opening_hands / may_mulligan
## / take_mulligan / decline_mulligan / start_duel; this only asks.
##
## AN ADVENTURE DUEL'S OPENING (part B, W2, 2026-10-23) asks three things
## of this, each opt-in from its [DuelConfig] through
## [method DuelOpening.configure] and the game's own `mulligan_rule`:
## a FORCED START ([member forced_first]: no order question, only the lead
## line), 1997'S COMPUTER CHOOSING PLAY OR DRAW AT RANDOM
## ([member ai_random_order]), and 1997'S ADVENTURE MULLIGAN in 1997's own
## order ([method _run_1997_mulligans]). Without them the sequence above is
## untouched.

## `@DIALOG_PLAYORDRAW`, Program/UIStrings.txt:487 — 9 entries, verbatim.
const PLAY_OR_DRAW := {
	"won": "%s won the toss",
	"will_play": "and will play first.",
	"chose_draw": "and has chosen to draw first.",
	"you_won": "You won the coin toss.",
	"ask": "Would you like to:",
	"play_first": "Play first",
	"draw_first": "Draw first",
	"they_play": "%s will play first.",
	"they_draw": "%s has chosen to draw first.",
}

## `@DIALOG_MULLIGAN`, Program/UIStrings.txt:499 — 12 entries, verbatim
## but for the Windows accelerator ampersands in the two buttons.
const MULLIGAN := {
	"starts": "%s will start first",
	"you_start": "You will take the first turn",
	# Entries 3-4 — the ANTE captions, word for word the same pair
	# `@DIALOG_VIEWANTES` (:588) gives the graveyard menu's `View both
	# antes`. The window shows the stake before the first card is played.
	"their_ante": "%s ante:",
	"your_ante": "Your ante:",
	"no_land": "%s has no land and chose to take a mulligan",
	"all_land": "%s has all land and will take a mulligan",
	"chose": "%s has chosen to take a mulligan",
	"declined": "%s did not take a mulligan",
	"also": "%s will also take a mulligan",
	"also_declined": "%s decided not to take a mulligan",
	"take": "Take mulligan",
	"start": "Start the duel",
}

## `[QoL]` — the size of the hand a redraw deals, said after the 1997
## line: "Cromer has no land and chose to take a mulligan, drawing 6". The
## 1997 table has no count because the 1997 redraw was always seven.
const MULLIGAN_COUNT := ", drawing %d"

## The whole sequence is over; [param first_player] plays first.
signal finished(first_player: int)
## One announcement to put in the Situation Bar as the sequence runs.
signal announced(line: String)

var _game: MtgGame = null
var _is_human := Callable()
var _window: OpeningWindow = null
## The seat the window is oriented on — the one it says `Your` to.
var _viewer := -1
## Each seat's deck colour, for the hand window's chrome (see `run`).
var _colors: Array = []
var _private_hotseat := false

# --- part B (W2): the adventure's opening ---
## THE FIRST PLAYER WAS DECIDED BEFORE THE OPENING (`DuelConfig.first_player`:
## a creature's First Strike, the adventurer's first-move gift): the seat
## [method run] is given STARTS — nobody won a toss, so nobody is asked play
## or draw, and the window says only who starts, `@DIALOG_MULLIGAN`'s first
## two lines. 1997 skipped its play-or-draw dialog the same way
## (`run_duel_coin_flip_dialogs`: no dialog 0xf4 unless the start was random).
var forced_first := false
## 1997'S COMPUTER CHOOSES AT RANDOM (`DuelConfig.ai_random_play_or_draw`):
## a toss winner that is not a human seat plays or draws on a coin of its
## own, [method ai_chooses_play]. False keeps ours: it takes the play.
var ai_random_order := false


## 1997's toss winner at the computer's seat (`dlgproc_duel_coin_flip`,
## `duel_engine_coin_flip.c`): `internal_rand(2)`, 1 to play, 0 to draw —
## here on the duel's own rng, so a seeded duel replays it.
static func ai_chooses_play(game: MtgGame) -> bool:
	return game.rng.randi_range(0, 1) == 1
# --- end part B (W2) ---


func _init() -> void:
	name = "OpeningHand"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Which `@DIALOG_MULLIGAN` line describes what [param pid] just decided.
## [param courtesy] is true when the OTHER seat has already thrown a hand
## back — the pair of strings the table keeps apart from the first four
## ("will also take", "decided not to"). [param drawing], when not negative,
## is the size of the hand the redraw deals and is said after the line
## ([constant MULLIGAN_COUNT]); build the line BEFORE `take_mulligan`, which
## replaces the hand the line names.
static func announcement(game: MtgGame, pid: int, took: bool,
		courtesy: bool, drawing := -1) -> String:
	var who: String = game.players[pid].player_name
	var line: String
	if courtesy:
		line = (MULLIGAN["also"] if took else MULLIGAN["also_declined"]) % who
	elif not took:
		line = MULLIGAN["declined"] % who
	else:
		var lands := 0
		for inst in game.players[pid].hand:
			if inst.is_land():
				lands += 1
		# The table has a line for each of the two mulligan hands by name.
		if lands == 0:
			line = MULLIGAN["no_land"] % who
		elif lands == game.players[pid].hand.size():
			line = MULLIGAN["all_land"] % who
		else:
			line = MULLIGAN["chose"] % who
	if took and drawing >= 0:
		line += MULLIGAN_COUNT % drawing
	return line


## Which line reports the toss winner's decision to the other seat.
static func play_or_draw_line(game: MtgGame, winner: int, plays: bool, private := false) -> String:
	var key: String = "they_play" if plays else "they_draw"
	return PLAY_OR_DRAW[key] % (DuelConfig.seat_label(winner) if private else game.players[winner].player_name)


## Run the whole sequence. [param is_human] answers "does this seat need a
## window"; a seat that is not human answers through its DecisionAgent and
## nothing is drawn, which is what makes the sequence testable headless.
##
## With a human at the table this opens ONE [OpeningWindow] and keeps it up
## until the player has had the last word — their own `Start the duel`, or
## one more when the opponent redrew after it — which is the reason both
## antes are on screen for the whole opening. [param colors] is each
## seat's deck colour (`DuelConfig.panel_colors`), worn by the hand window
## in the opening window as the duel's own wears it; empty for the plain
## frame.
func run(game: MtgGame, winner: int, is_human: Callable,
		colors: Array = [], private := false) -> void:
	_game = game
	_is_human = is_human
	_colors = colors
	_private_hotseat = private
	# The seat sitting at this screen: the one the window says `Your` to.
	# In a hotseat both seats are human and the window re-orients onto
	# whichever one it is asking.
	_viewer = -1
	for pid in 2:
		if _human(pid):
			_viewer = pid
			break
	if _private_hotseat and _human(winner):
		_viewer = winner
	if _viewer >= 0 and is_inside_tree():
		_window = OpeningWindow.new()
		add_child(_window)
		_window.show_antes(game, _viewer, _private_hotseat)
		_show_hand()

	# THE PLAYER PRESSED LAST: -1 until they have, so a duel in which the
	# player is never asked anything still ends on their own `Start the
	# duel` — which is exactly what the original's window is for.
	var pressed_serial := -1

	# 1. THE ORDER. The AI takes the play, which is what both references do
	# and what the 1997 opponent does: the tempo is worth more than the
	# extra card.
	var plays_first := true
	if forced_first:
		pass   # part B (W2): nobody won a toss, so nobody chooses
	elif _human(winner):
		plays_first = await _ask_order(winner)
		if _left():
			return
		if _window != null:
			pressed_serial = _window.status_serial
	elif ai_random_order:
		plays_first = ai_chooses_play(game)   # part B (W2): 1997's coin
	var first_player := winner if plays_first else game.opponent_of(winner)
	if forced_first:
		# `@DIALOG_MULLIGAN` entry 1, in the third person for the bar.
		announced.emit(lead_line(game, first_player, -1, _private_hotseat))
	else:
		announced.emit(play_or_draw_line(game, winner, plays_first, _private_hotseat))
	if _window != null:
		_window.set_lead(lead_line(game, first_player, _viewer, _private_hotseat))

	# 2-3. THE HANDS, the toss winner's first. Each seat looks at its own
	# hand and keeps or redraws until it keeps; a redraw deals one fewer
	# and asks again (the owner: "after each mulligan you draw one card
	# less"), down to the empty hand that nobody is asked about. Under
	# 1997's adventure rule, its own order instead (part B, W2).
	if game.mulligan_rule == MtgGame.MULLIGAN_1997:
		pressed_serial = await _run_1997_mulligans(game, pressed_serial)
		if pressed_serial == -2:
			return
	else:
		for step in 2:
			var pid := winner if step == 0 else game.opponent_of(winner)
			while game.may_mulligan(pid):
				var courtesy := game.has_mulliganed(game.opponent_of(pid))
				var took := false
				if _human(pid):
					if _window != null and pid != _viewer:
						_viewer = pid          # hotseat: turn the window round
						_window.show_antes(game, _viewer, _private_hotseat)
						_window.set_lead(lead_line(game, first_player, _viewer, _private_hotseat))
						_show_hand()
					took = await _ask_mulligan(pid)
					if _left():
						return
				else:
					took = game.agents[pid].choose_mulligan(game, pid)
				# NAME THE HAND BEFORE IT IS GONE. `%s has no land…` describes
				# the hand that was thrown away, and take_mulligan has already
				# replaced it by the time the line would otherwise be built.
				var line := announcement(game, pid, took, courtesy,
					game.players[pid].hand.size() - 1)
				if took:
					game.take_mulligan(pid)
					if pid == _viewer:
						_show_hand()      # the stack is a picture of the hand
				else:
					game.decline_mulligan(pid)
				announced.emit(line)
				if _window != null:
					if pid == _viewer:
						pressed_serial = _window.status_serial
					elif took:
						# The head band's right half — "Cromer has no land and
						# chose to take a mulligan", as the 1997 screenshot has
						# it. A keep is not news and does not land there.
						_window.set_status(line)
	# 4. The last word is always the player's: if anything happened after
	# their last press (or they were never asked anything), the window
	# waits on one more `Start the duel` so they actually see it.
	if _window != null and _window.status_serial != pressed_serial:
		await _window.ask([{"answer": OpeningWindow.Answer.START,
			"label": MULLIGAN["start"]}])
		if _left():
			return
	if _window != null and _private_hotseat:
		_window.conceal_hand()
	game.start_duel(first_player)
	if _window != null:
		# AWAITED: the duel screen frees this node the moment run() returns,
		# and a fade whose owner is already gone never plays.
		await _window.close()
		_window = null
	finished.emit(first_player)


## `@DIALOG_MULLIGAN` entries 1-2 — who takes the first turn, in the second
## person for the seat at this screen and by name for the other.
static func lead_line(game: MtgGame, first_player: int, viewer: int, private := false) -> String:
	if private:
		return MULLIGAN["starts"] % DuelConfig.seat_label(first_player)
	if first_player == viewer:
		return MULLIGAN["you_start"]
	return MULLIGAN["starts"] % game.players[first_player].player_name


## THE SCREEN WENT WHILE THE WINDOW ASKED (hunt of 2026-10-21): Pause →
## `Exit duel` or `Return to main menu` takes the duel screen, and this
## with it, out of the tree at once. [method OpeningWindow.ask] then comes
## back with no button pressed, which read as `Play first` and a keep at
## every question — and the abandoned duel was started under a screen on
## its way out. A run whose window has gone stops where it is.
func _left() -> bool:
	return _window != null and not is_inside_tree()


func _human(pid: int) -> bool:
	return _is_human.is_valid() and bool(_is_human.call(pid))


## The viewer's hand into the window, in the viewer's deck colour.
func _show_hand() -> void:
	if _window == null or _viewer < 0:
		return
	var color := ""
	if _viewer < _colors.size():
		color = str(_colors[_viewer])
	_window.show_hand(_game, _viewer, color, _private_hotseat)


## `@DIALOG_PLAYORDRAW` entries 4-7, asked in the opening window's own
## button row rather than in a popup of its own: `Draw first` / `Play
## first`, and nothing else in the row. The hand is not part of this
## question — the owner's order of 2026-09-08 has the winner choose the
## order FIRST and look at their hand second — so the row of 2026-09-03
## (`Take mulligan` beside the order) is gone with the rule it served.
## Returns true for the play.
func _ask_order(pid: int) -> bool:
	if _window == null:
		return true
	var verdict := "%s won the coin toss." % DuelConfig.seat_label(pid) \
		if _private_hotseat else str(PLAY_OR_DRAW["you_won"])
	_window.set_lead("%s\n%s" % [verdict, PLAY_OR_DRAW["ask"]])
	var answer := await _window.ask([
		{"answer": OpeningWindow.Answer.DRAW_FIRST,
			"label": PLAY_OR_DRAW["draw_first"]},
		{"answer": OpeningWindow.Answer.PLAY_FIRST,
			"label": PLAY_OR_DRAW["play_first"]},
	])
	return answer != OpeningWindow.Answer.DRAW_FIRST


## `Take mulligan` / `Start the duel` — the window's own two buttons
## (`@DIALOG_MULLIGAN` entries 11-12), put up once per look at the hand:
## a redraw brings the row straight back over the smaller hand, and
## `Start the duel` is the keep.
##
## THE COURTESY OFFER NEEDS NO EXTRA LINE. When the opponent redrew, the
## head band is already saying so — `%s has no land and chose to take a
## mulligan`, which is precisely the state the owner's 1997 screenshot
## froze. Entries 9-10 (`%s will also take a mulligan` / `%s decided not to
## take a mulligan`) REPORT the second player's decision afterwards; they
## are not a prompt.
func _ask_mulligan(_pid: int) -> bool:
	if _window == null:
		return false
	var answer := await _window.ask([
		{"answer": OpeningWindow.Answer.TAKE_MULLIGAN,
			"label": MULLIGAN["take"]},
		{"answer": OpeningWindow.Answer.START, "label": MULLIGAN["start"]},
	])
	return answer == OpeningWindow.Answer.TAKE_MULLIGAN


## THE 1997 ADVENTURE MULLIGAN ([constant MtgGame.MULLIGAN_1997]), in 1997's
## own order (`play_duel`, `duel.c:2399-2470`; `dlgproc_duel_redraw_ante`):
##   1. the creature's hand of no land or nothing but land goes back at
##      once, and the window says so before the adventurer is asked — the
##      1997 dialog opened on that line;
##   2. the adventurer is offered ONE free redraw of seven, and only for a
##      hand of no land or all land; any other hand is not offered one and
##      the window has `Start the duel` alone;
##   3. when the adventurer redrew, the creature redraws too if its hand
##      holds fewer than two lands or more than five ("%s will also take a
##      mulligan"), and otherwise says it will not ("%s decided not to take
##      a mulligan").
## The creature's rule is automatic whoever sits there; the adventurer's
## offer is the player's to answer, or the seat's agent's. The lines carry
## no count — 1997's redraw was always seven. Returns the window's serial
## at the player's last press ([param pressed_serial] when they were not
## asked), or -2 when the screen went while asking ([method _left]).
func _run_1997_mulligans(game: MtgGame, pressed_serial: int) -> int:
	var hero := MtgGame.MULLIGAN_1997_HERO
	var creature := game.opponent_of(hero)
	# 1. The creature's own no-land / all-land redraw.
	if game.may_mulligan(creature):
		_redraw_1997(game, creature, true, false)
	# 2. The adventurer's offer.
	if game.may_mulligan(hero):
		var took := false
		if _human(hero):
			if _window != null and hero != _viewer:
				_viewer = hero
				_window.show_antes(game, _viewer, _private_hotseat)
				_show_hand()
			took = await _ask_mulligan(hero)
			if _left():
				return -2
		else:
			took = game.agents[hero].choose_mulligan(game, hero)
		_redraw_1997(game, hero, took, false)
		if _window != null and hero == _viewer:
			pressed_serial = _window.status_serial
	# 3. The creature's answer to the adventurer's redraw.
	if game.has_mulliganed(hero) and not game.has_mulliganed(creature):
		_redraw_1997(game, creature, game.may_mulligan(creature), true)
	return pressed_serial


## One 1997 decision for [param pid]: the redraw ([param took]) or the keep,
## announced in the table's words — [param courtesy] for the creature's
## answer to the adventurer's redraw — and, when it is news to the player
## at this screen, put in the window's head band.
func _redraw_1997(game: MtgGame, pid: int, took: bool, courtesy: bool) -> void:
	var line := announcement(game, pid, took, courtesy)
	if took:
		game.take_mulligan(pid)
		if pid == _viewer:
			_show_hand()
	else:
		game.decline_mulligan(pid)
	announced.emit(line)
	if _window != null and pid != _viewer and (took or courtesy):
		_window.set_status(line)


## The window this run is asking through — null when no seat is human
## (headless tests, an AI-vs-AI demo), which is what keeps the whole
## sequence runnable with nothing drawn.
func window() -> OpeningWindow:
	return _window

class_name OpeningHand
extends Control
## THE OPENING HAND — play or draw, then the mulligans (docs/duel-todo.md
## §1.5, §6.2). Runs between the coin toss and turn 1.
##
## THE RULE IS SHANDALAR'S, and it is neither Paris nor London. `Duel.hlp`,
## topic **Mulligan**, verbatim: *"If either player draws no land in this
## seven cards or draws all land, then that player has the option to
## declare a mulligan… that player must shuffle her hand back into her
## library and draw seven new cards… The other player has the option to do
## so as well… Each player has only one chance to redraw, and once that's
## used or waived, the duel begins."* Seven for seven, no bottoming, no
## descending count. The `mulligan to %d` strings in the top-level string
## table are Manalink 3's and are not ported; s30's London mulligan
## (`duel.go:3918-4074`) is [s30] and is not ported either.
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
## THE TOSS WINNER IS ASKED ONCE. When the player wins, the window's row
## is `Take mulligan` / `Draw first` / `Play first` together, because the
## redraw and the order are one decision about the same seven cards; when
## the AI wins it takes the play and the player's row is `Take mulligan` /
## `Start the duel` (see [method _ask_lead_and_mulligan], and the owner's
## correction it records).
##
## IT ALL HAPPENS IN ONE WINDOW ([OpeningWindow], §6.19). The original does
## not pop a dialog per question: it opens the start-of-duel window on the
## classical line-art ground, shows BOTH ANTES as full cards, and asks each
## question in that window's own button row — which is why `@DIALOG_MULLIGAN`
## carries `%s ante:` and `Your ante:` among its twelve entries. The window
## closes on your `Start the duel`, and the duel begins.
##
## The engine half is MtgGame.stake_ante / deal_opening_hands / may_mulligan
## / take_mulligan / decline_mulligan / start_duel; this only asks.

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

## The whole sequence is over; [param first_player] plays first.
signal finished(first_player: int)
## One announcement to put in the Situation Bar as the sequence runs.
signal announced(line: String)

var _game: MtgGame = null
var _is_human := Callable()
var _window: OpeningWindow = null
## The seat the window is oriented on — the one it says `Your` to.
var _viewer := -1


func _init() -> void:
	name = "OpeningHand"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Which `@DIALOG_MULLIGAN` line describes what [param pid] just decided.
## [param courtesy] is true for the second offer — the one that exists only
## because the opponent redrew, which is the pair of strings the table
## keeps apart from the first four.
static func announcement(game: MtgGame, pid: int, took: bool,
		courtesy: bool) -> String:
	var who: String = game.players[pid].player_name
	if courtesy:
		return (MULLIGAN["also"] if took else MULLIGAN["also_declined"]) % who
	if not took:
		return MULLIGAN["declined"] % who
	var lands := 0
	for inst in game.players[pid].hand:
		if inst.is_land():
			lands += 1
	# The table has a line for each of the two mulligan hands by name.
	if lands == 0:
		return MULLIGAN["no_land"] % who
	if lands == game.players[pid].hand.size():
		return MULLIGAN["all_land"] % who
	return MULLIGAN["chose"] % who


## Which line reports the toss winner's decision to the other seat.
static func play_or_draw_line(game: MtgGame, winner: int, plays: bool) -> String:
	var key: String = "they_play" if plays else "they_draw"
	return PLAY_OR_DRAW[key] % game.players[winner].player_name


## Run the whole sequence. [param is_human] answers "does this seat need a
## window"; a seat that is not human answers through its DecisionAgent and
## nothing is drawn, which is what makes the sequence testable headless.
##
## With a human at the table this opens ONE [OpeningWindow] and keeps it up
## until the player presses `Start the duel` — the original's shape, and
## the reason both antes are on screen for the whole opening.
func run(game: MtgGame, winner: int, is_human: Callable) -> void:
	_game = game
	_is_human = is_human
	# The seat sitting at this screen: the one the window says `Your` to.
	# In a hotseat both seats are human and the window re-orients onto
	# whichever one it is asking.
	_viewer = -1
	for pid in 2:
		if _human(pid):
			_viewer = pid
			break
	if _viewer >= 0 and is_inside_tree():
		_window = OpeningWindow.new()
		add_child(_window)
		_window.show_antes(game, _viewer)

	var plays_first := true
	if _human(winner):
		plays_first = await _ask_lead_and_mulligan(winner)
	# The AI takes the play, which is what both references do and what the
	# 1997 opponent does: the tempo is worth more than the extra card.
	var first_player := winner if plays_first else game.opponent_of(winner)
	announced.emit(play_or_draw_line(game, winner, plays_first))
	if _window != null:
		_window.set_lead(lead_line(game, first_player, _viewer))

	# THE PLAYER PRESSED LAST: -1 until they have, so a duel in which nobody
	# is ever offered a mulligan still ends on their own `Start the duel`
	# — which is exactly what the original's window is for.
	var pressed_serial := -1

	# The offers, first player first — and then round two, which exists
	# because "the other player has the option to do so as well".
	for round_index in 2:
		for step in 2:
			var pid := first_player if step == 0 else game.opponent_of(first_player)
			if not game.may_mulligan(pid):
				continue
			var courtesy := not game.hand_is_a_mulligan_hand(pid)
			var took := false
			if _human(pid):
				if _window != null and pid != _viewer:
					_viewer = pid          # hotseat: turn the window round
					_window.show_antes(game, _viewer)
					_window.set_lead(lead_line(game, first_player, _viewer))
				took = await _ask_mulligan(pid)
			else:
				took = game.agents[pid].choose_mulligan(game, pid, not courtesy)
			# NAME THE HAND BEFORE IT IS GONE. `%s has no land…` describes
			# the hand that was thrown away, and take_mulligan has already
			# replaced it by the time the line would otherwise be built.
			var line := announcement(game, pid, took, courtesy)
			if took:
				game.take_mulligan(pid)
			else:
				game.decline_mulligan(pid)
			announced.emit(line)
			if _window != null:
				if pid == _viewer:
					pressed_serial = _window.status_serial
				else:
					# The head band's right half — "Cromer has no land and
					# chose to take a mulligan", as the 1997 screenshot has it.
					_window.set_status(line)
	# The last word is always the player's: if anything happened after their
	# last press (or they were never asked anything), the window waits on one
	# more `Start the duel` so they actually see it.
	if _window != null and _window.status_serial != pressed_serial:
		await _window.ask([{"answer": OpeningWindow.Answer.START,
			"label": MULLIGAN["start"]}])
	game.start_duel(first_player)
	if _window != null:
		# AWAITED: the duel screen frees this node the moment run() returns,
		# and a fade whose owner is already gone never plays.
		await _window.close()
		_window = null
	finished.emit(first_player)


## `@DIALOG_MULLIGAN` entries 1-2 — who takes the first turn, in the second
## person for the seat at this screen and by name for the other.
static func lead_line(game: MtgGame, first_player: int, viewer: int) -> String:
	if first_player == viewer:
		return MULLIGAN["you_start"]
	return MULLIGAN["starts"] % game.players[first_player].player_name


func _human(pid: int) -> bool:
	return _is_human.is_valid() and bool(_is_human.call(pid))


## `@DIALOG_PLAYORDRAW` entries 4-7, asked in the opening window's own
## button row rather than in a popup of its own.
## ONE ROW, NOT TWO. The toss winner is asked their order and their
## mulligan TOGETHER — `Take mulligan`, `Draw first`, `Play first` — and
## the row shows the mulligan only while the rule allows one (`Duel.hlp`,
## **Mulligan**: a no-land or all-land hand, or the courtesy after the
## opponent redrew).
##
## The owner's correction, 2026-09-03: asking the order first and the
## mulligan second put the player through two button rows where the 1997
## window has one, and made a redraw feel like a different question from
## the choice it belongs to. Taking the mulligan re-asks — the order has
## not been chosen yet — and choosing the order is also the decline, which
## is why this returns having already spent the seat's one chance.
func _ask_lead_and_mulligan(pid: int) -> bool:
	if _window == null:
		return true
	_window.set_lead("%s\n%s" % [PLAY_OR_DRAW["you_won"], PLAY_OR_DRAW["ask"]])
	while true:
		var options: Array = []
		if _game.may_mulligan(pid):
			options.append({"answer": OpeningWindow.Answer.TAKE_MULLIGAN,
				"label": MULLIGAN["take"]})
		options.append({"answer": OpeningWindow.Answer.DRAW_FIRST,
			"label": PLAY_OR_DRAW["draw_first"]})
		options.append({"answer": OpeningWindow.Answer.PLAY_FIRST,
			"label": PLAY_OR_DRAW["play_first"]})
		var answer := await _window.ask(options)
		if answer == OpeningWindow.Answer.TAKE_MULLIGAN:
			# NAME THE HAND BEFORE IT IS GONE — take_mulligan replaces it.
			var line := announcement(_game, pid, true,
				not _game.hand_is_a_mulligan_hand(pid))
			_game.take_mulligan(pid)
			announced.emit(line)
			continue          # the order is still unanswered
		# Choosing the order waives the redraw, and the table has a line
		# for that too.
		if _game.may_mulligan(pid):
			var declined := announcement(_game, pid, false,
				not _game.hand_is_a_mulligan_hand(pid))
			_game.decline_mulligan(pid)
			announced.emit(declined)
		return answer != OpeningWindow.Answer.DRAW_FIRST
	return true


## `Take mulligan` / `Start the duel` — the window's own two buttons
## (`@DIALOG_MULLIGAN` entries 11-12).
##
## THE COURTESY OFFER NEEDS NO EXTRA LINE. It exists only because the
## opponent redrew, and the head band is already saying so — `%s has no
## land and chose to take a mulligan`, which is precisely the state the
## owner's 1997 screenshot froze. Entries 9-10 (`%s will also take a
## mulligan` / `%s decided not to take a mulligan`) REPORT the second
## player's decision afterwards; they are not a prompt.
func _ask_mulligan(_pid: int) -> bool:
	if _window == null:
		return false
	var answer := await _window.ask([
		{"answer": OpeningWindow.Answer.TAKE_MULLIGAN,
			"label": MULLIGAN["take"]},
		{"answer": OpeningWindow.Answer.START, "label": MULLIGAN["start"]},
	])
	return answer == OpeningWindow.Answer.TAKE_MULLIGAN


## The window this run is asking through — null when no seat is human
## (headless tests, an AI-vs-AI demo), which is what keeps the whole
## sequence runnable with nothing drawn.
func window() -> OpeningWindow:
	return _window

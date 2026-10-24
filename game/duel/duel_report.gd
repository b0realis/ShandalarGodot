class_name DuelReport
extends RefCounted
## WHAT A FINISHED DUEL LEAVES BEHIND, for whatever held it — the adventure
## reads one after [signal DuelScreen.duel_finished] to settle the spoils
## (part B, W2, 2026-10-23). Plain data, taken from the game the moment it
## is asked for ([method of]); nothing in it moves a card.
##
## THE RESULT IS 1997'S, from seat 0's side — `RunDuelEngine`'s return
## (`duel.c:2876-2884`, `visitLocation.c:2135`): 1 the adventurer won (alive,
## under ten poison, the creature dead or poisoned), 0 it lost, -1 anything
## else, a draw. Each caller reads it its own way (b4 §1.3); the PLAN's
## ruling is that a draw changes no cards anywhere.
##
## THE ANTE IS REPORTED BY OWNER, AND NOTHING SETTLES IT. The engine keeps a
## card in the ante array of the player who OWNS it, and ownership, not the
## pile, decides who keeps what (docs/duel-todo.md §7) — a Bronze Tablet, a
## Tempest Efreet or a Darkpact changes an owner for good mid-duel, and
## [member owner_changes] lists every such change. The adventure moves its
## own cards: on a win the creature's stake ([member ante] [1]) joins the
## collection, on a loss the adventurer's own ([member ante] [0]) leaves it.

## [member result]'s three values.
const WIN := 1
const LOSS := 0
const DRAW := -1

## Did the duel reach its end? False for a duel abandoned or still running;
## every other field then describes the table as it stood.
var finished := false
## The engine's winner: 0, 1, or -1 for a draw (`MtgGame.winner`).
var winner := -1
## 1 win, 0 loss, -1 draw — from seat 0's side (see the class doc). -1 too
## while the duel is unfinished; read [member finished] first.
var result := DRAW
## Each seat's life at the start (`DuelConfig.lives`) and at the end — the
## adventurer's carried-lives reward is the difference (1997 bit 0x1:
## "If end life ≠ start life: carry delta = end − start").
var lives_start: Array[int] = [0, 0]
var lives_end: Array[int] = [0, 0]
## Seat 0's life at the end: [member lives_end] [0], named for the reader.
var hero_life := 0
## Each seat's poison counters at the end.
var poison: Array[int] = [0, 0]
## The cards in the ante zone at the end, by OWNER: `[[names], [names]]` —
## seat 0's own cards, then seat 1's (printed names: the physical cards).
var ante: Array = [[], []]
## Every permanent change of owner during the duel, in order
## (`MtgGame.owner_changes`): `{"id", "card", "from", "to"}`.
var owner_changes: Array[Dictionary] = []
## How many turns were begun.
var turns := 0


## The report of [param game] as it stands, with [param config]'s starting
## lives. Safe on any game, finished or not.
static func of(game: MtgGame, config: DuelConfig = null) -> DuelReport:
	var out := DuelReport.new()
	if game == null or game.players.size() != 2:
		return out
	out.finished = game.game_over
	out.winner = game.winner if game.game_over else -1
	out.result = result_for(out.winner) if game.game_over else DRAW
	for pid in 2:
		var p: MtgPlayer = game.players[pid]
		out.lives_start[pid] = config.lives[pid] if config != null else p.life
		out.lives_end[pid] = p.life
		out.poison[pid] = p.poison
		var names: Array[String] = []
		for inst in p.ante:
			names.append(inst.printed_data.card_name)
		out.ante[pid] = names
	out.hero_life = out.lives_end[0]
	out.owner_changes.assign(game.owner_changes.duplicate(true))
	out.turns = game.turn_number
	return out


## 1997's result from seat 0's side for the engine's [param winner_id].
static func result_for(winner_id: int) -> int:
	match winner_id:
		0: return WIN
		1: return LOSS
	return DRAW


func hero_won() -> bool:
	return finished and result == WIN


func hero_lost() -> bool:
	return finished and result == LOSS


func is_draw() -> bool:
	return finished and result == DRAW


## One line for a log or a failing test's message.
func describe() -> String:
	var verdict := "unfinished"
	if finished:
		verdict = {WIN: "won", LOSS: "lost", DRAW: "drawn"}[result]
	return "duel %s after %d turns; lives %d-%d (from %d-%d); ante %s / %s; %d owner change(s)" % [
		verdict, turns, lives_end[0], lives_end[1], lives_start[0], lives_start[1],
		", ".join(PackedStringArray(ante[0])), ", ".join(PackedStringArray(ante[1])),
		owner_changes.size()]

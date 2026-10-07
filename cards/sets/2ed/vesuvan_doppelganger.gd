extends CardScript
## Vesuvan Doppelganger — {3}{U}{U} — Creature — Shapeshifter — 0/0 — (2ed, rare)
## Oracle: You may have this creature enter as a copy of any creature on the
##         battlefield, except it doesn't copy that creature's color and it
##         has "At the beginning of your upkeep, you may have this creature
##         become a copy of target creature, except it doesn't copy that
##         creature's color and it has this ability."
##
## Implementation: Clone's enters-as-a-copy replacement plus two riders.
## "Doesn't copy that creature's color" keeps the Doppelganger blue
## (become_copy's keep_own_colors writes the old colours as an indefinite
## colour override). "And it has this ability" is handled by adopting a
## SHALLOW COPY of the target's definition with the upkeep trigger appended
## — so every shape the Doppelganger takes can shift again next upkeep.
##
## The choice on resolution is the acting seat's own, asked through their
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The value the card
## computes is only the HINT, and the candidates are pre-sorted for it.
##
## What it copies is the target's COPIABLE VALUES (MtgGame.copiable_data):
## a face-down creature is a nameless colourless 2/2 with no abilities (CR
## 707.2 / 708.2), so the Doppelganger never learns — or announces — the
## card underneath (bug pass 2026-10-03).
##
## The hint on the upkeep trigger is "shift only when the new shape is
## bigger"; the hint on arrival is the biggest creature on the board. The
## upkeep trigger asks BOTH of its questions — whether to shift, and into
## what — through that funnel; until 2026-09-17 it picked the biggest body
## itself and never offered a smaller shape at all.
##
## The upkeep shape is a TARGET (campaign 2026-10, w1-9): chosen as the
## trigger goes on the stack (CR 603.3d), so protection from blue (Blue
## Ward) keeps a creature out of the list, the opponent sees what is
## aimed at and may respond, and a target gone or turned illegal by
## resolution makes the trigger do nothing (CR 608.2b). "You may" is asked
## on resolution. The Doppelganger itself is no candidate: becoming a copy
## of itself changes nothing (and would stack a second copy of this
## ability onto the copied definition).


static func _any_creature(inst: CardInstance) -> bool:
	return inst.is_creature()


## The upkeep ability, rebuilt fresh each time so the copied definition
## carries its own instance of it.
static func _shift_ability() -> TriggeredAbility:
	return TriggeredAbility.new(
		Mtg.EventType.UPKEEP_START, _shift,
		"At the beginning of your upkeep, you may have this creature become a copy of target creature, except it doesn't copy that creature's color and it has this ability.",
		_your_upkeep) \
		.targeting(TargetSpec.creature("target creature").with_source_filter(_not_itself),
			_biggest_first, "Select a creature for Vesuvan Doppelganger to copy.")


static func _not_itself(_game: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return source == null or inst != source


## Biggest body first (power + toughness), then the oldest — the heuristic
## seat's pick and the human seat's default highlight.
static func _biggest_first(game: MtgGame, _source: CardInstance,
		a: TargetRef, b: TargetRef) -> bool:
	var ia := game.find_instance(a.instance_id)
	var ib := game.find_instance(b.instance_id)
	var va := ia.cur_power + ia.cur_toughness
	var vb := ib.cur_power + ib.cur_toughness
	if va != vb:
		return va > vb
	return ia.id < ib.id


## "…and it has this ability": adopt the target's definition PLUS the
## upkeep trigger.
static func _keep_the_ability(source_data: CardData) -> CardData:
	return source_data.with_extra_trigger(_shift_ability())


func build() -> CardData:
	return CardData.new("Vesuvan Doppelganger", "{3}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_subtypes(["shapeshifter"]) \
		.with_enters_as_copy(_any_creature, "any creature on the battlefield",
			0, true, _keep_the_ability) \
		.triggered(_shift_ability()) \
		.oracle("You may have this creature enter as a copy of any creature on the battlefield, except it doesn't copy that creature's color and it has \"At the beginning of your upkeep, you may have this creature become a copy of target creature, except it doesn't copy that creature's color and it has this ability.\"")


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _shift(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	# Phased out in response: it can't become a copy (CR 702.26b/e) —
	# become_copy itself does not ask.
	if not game.is_present(source):
		return
	# "…become a copy of TARGET creature" — chosen as the trigger went on
	# the stack; the engine hands over only a target still legal (CR 608.2b).
	var refs: Array = game.current_targets()
	if refs.is_empty():
		return
	var shape := game.find_instance(refs[0].instance_id)
	if shape == null or shape == source or not game.is_present(shape) or not shape.is_creature():
		return
	var pid := source.controller_id
	# "YOU MAY": the hint is the old heuristic — shift only when the shape
	# is an upgrade — but the answer is the seat's, so a smaller body that
	# flies, taps for mana or dodges a sweeper is a line the controller may
	# take (it was unreachable until 2026-09-17). The prompt names the shape
	# as the stack line does (a face-down one stays nameless, CR 708.2).
	var worth_it: bool = shape.cur_power + shape.cur_toughness \
		> source.cur_power + source.cur_toughness
	if not game.agents[pid].choose_yes_no(game, pid,
			"Have Vesuvan Doppelganger become a copy of %s?" % game.target_label(refs[0]),
			worth_it):
		return
	# Copiable values (CR 707.2): a face-down shape is a nameless 2/2, never
	# the card underneath (CR 708.2; bug pass 2026-10-03).
	game.become_copy(source, _keep_the_ability(game.copiable_data(shape)), 0, true)

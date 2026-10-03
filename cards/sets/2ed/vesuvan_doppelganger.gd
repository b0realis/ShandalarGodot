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


static func _any_creature(inst: CardInstance) -> bool:
	return inst.is_creature()


## The upkeep ability, rebuilt fresh each time so the copied definition
## carries its own instance of it.
static func _shift_ability() -> TriggeredAbility:
	return TriggeredAbility.new(
		Mtg.EventType.UPKEEP_START, _shift,
		"At the beginning of your upkeep, you may have this creature become a copy of target creature, except it doesn't copy that creature's color and it has this ability.",
		_your_upkeep)


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
	var pid := source.controller_id
	# "…become a copy of TARGET creature" — every other creature on the
	# table is a candidate, ranked biggest first so the head of the list is
	# the heuristic's pick and the human seat's default highlight.
	var shapes: Array[CardInstance] = []
	for inst in game.all_battlefield():
		if inst != source and inst.is_creature():
			shapes.append(inst)
	if shapes.is_empty():
		return
	shapes.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var va := a.cur_power + a.cur_toughness
		var vb := b.cur_power + b.cur_toughness
		if va != vb:
			return va > vb
		return a.id < b.id)
	# "YOU MAY": the hint is the old heuristic — shift only when the best
	# shape available is an upgrade — but the answer is the seat's, so a
	# smaller body that flies, taps for mana or dodges a sweeper is a line
	# the controller may take (it was unreachable until 2026-09-17).
	var worth_it: bool = shapes[0].cur_power + shapes[0].cur_toughness \
		> source.cur_power + source.cur_toughness
	if not game.agents[pid].choose_yes_no(game, pid,
			"Have Vesuvan Doppelganger become a copy of another creature?",
			worth_it):
		return
	# WHICH creature is the seat's own choice too, not the engine's.
	var shape := game.agents[pid].choose_card(game, pid, shapes,
		"Become a copy of which creature?", false, false, true)
	if shape == null or not shapes.has(shape):
		shape = shapes[0]
	# Copiable values (CR 707.2): a face-down shape is a nameless 2/2, never
	# the card underneath (CR 708.2; bug pass 2026-10-03).
	game.become_copy(source, _keep_the_ability(game.copiable_data(shape)), 0, true)

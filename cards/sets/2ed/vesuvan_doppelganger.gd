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
## The hint on the upkeep trigger is "shift only when the new shape is
## bigger"; the hint on arrival is the biggest creature on the board.


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
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var best: CardInstance = null
	for inst in game.all_battlefield():
		if inst == source or not inst.is_creature():
			continue
		if best == null or inst.cur_power + inst.cur_toughness \
				> best.cur_power + best.cur_toughness:
			best = inst
	if best == null:
		return
	# "You may": only shift when the new shape is actually bigger.
	if best.cur_power + best.cur_toughness <= source.cur_power + source.cur_toughness:
		return
	if not game.agents[source.controller_id].choose_yes_no(game, source.controller_id,
			"Become a copy of %s?" % best.data.card_name, true):
		return
	game.become_copy(source, _keep_the_ability(best.data), 0, true)

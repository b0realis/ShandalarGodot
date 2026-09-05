extends CardScript
## Lord of the Pit — {4}{B}{B}{B} — Creature — Demon — 7/7 — (2ed, rare)
## Oracle: Flying, trample
##         At the beginning of your upkeep, sacrifice a creature other
##         than this creature. If you can't, this creature deals 7 damage
##         to you.
##
## Implementation: the upkeep tribute — resolving asks the controller's
## DecisionAgent to pick a creature (candidates pre-sorted cheapest
## first; the sacrifice is NOT optional, so a null/invalid pick takes the
## cheapest). With nothing to feed it, 7 black damage to its controller.
## The trigger is independent of the Lord once it is on the stack
## (CR 603.6): removing the Lord in response does not cancel the tribute.


func build() -> CardData:
	return CardData.new("Lord of the Pit", "{4}{B}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(7, 7) \
		.with_subtypes(["demon"]) \
		.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.TRAMPLE]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _tribute,
			"At the beginning of your upkeep, sacrifice a creature other than this creature. If you can't, this creature deals 7 damage to you.",
			_own_upkeep)) \
		.oracle("Flying, trample\nAt the beginning of your upkeep, sacrifice a creature other than this creature. If you can't, this creature deals 7 damage to you.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


static func _cheapest_first(a: CardInstance, b: CardInstance) -> bool:
	return a.data.cost.mana_value() < b.data.cost.mana_value()


## NO "is it still on the battlefield?" guard: a triggered ability exists
## independently of its source once it is on the stack and resolves even if
## the source has left (CR 603.6), so answering the Lord in response to its
## own upkeep trigger still costs you a creature. The "other than this
## creature" clause needs no guard either — a departed Lord is not on the
## battlefield to be a candidate. The player comes off the EVENT rather
## than off the (possibly reset) source.
static func _tribute(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var candidates: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_creature() and inst != source:
			candidates.append(inst)
	if candidates.is_empty():
		game.deal_damage(source, TargetRef.player(pid), 7)
		return
	candidates.sort_custom(_cheapest_first)
	var chosen := game.agents[pid].choose_card(game, pid, candidates,
		"Sacrifice a creature to %s" % source.data.card_name)
	if chosen == null or not candidates.has(chosen):
		chosen = candidates[0]   # the tribute is mandatory
	game.sacrifice_permanent(chosen)

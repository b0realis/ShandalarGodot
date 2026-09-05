extends CardScript
## Serendib Djinn — {2}{U}{U} — Creature — Djinn — 5/6 — (arn, rare)
## Oracle: Flying
##         At the beginning of your upkeep, sacrifice a land. If you
##         sacrifice an Island this way, this creature deals 3 damage to
##         you.
##         When you control no lands, sacrifice this creature.
##
## Implementation: the biggest flier of its cost, rented against your own
## mana base. The upkeep sacrifice is MANDATORY (unlike Elder Spawn's
## "unless you sacrifice an Island"), so the DecisionAgent only picks WHICH
## land — candidates are offered non-Islands first, since an Island costs
## an extra three life. The last line is Dandân's state trigger with an
## arbitrary predicate (CardData.sacrifices_when), which fires the moment
## the Djinn eats your final land.


func build() -> CardData:
	return CardData.new("Serendib Djinn", "{2}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(5, 6) \
		.with_subtypes(["djinn"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.sacrifices_when(_no_lands) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _tithe,
			"At the beginning of your upkeep, sacrifice a land. If you sacrifice an Island this way, this creature deals 3 damage to you.",
			_own_upkeep)) \
		.oracle("Flying\n"
			+ "At the beginning of your upkeep, sacrifice a land. If you sacrifice an Island this way, this creature deals 3 damage to you.\n"
			+ "When you control no lands, sacrifice this creature.")


static func _no_lands(game: MtgGame, source: CardInstance) -> bool:
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_land():
			return false
	return true


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


## Non-Islands first: giving up an Island also costs 3 life, so a seat that
## does not answer for itself should not volunteer one while it has a
## choice.
static func _islands_last(a: CardInstance, b: CardInstance) -> bool:
	return int(a.has_subtype("island")) < int(b.has_subtype("island"))


## The trigger resolves whatever became of the Djinn (CR 603.6): bouncing
## it in response still costs the land, and the damage — dealt by its last
## known existence (CR 608.2h) — still arrives.
static func _tithe(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var lands: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_land():
			lands.append(inst)
	if lands.is_empty():
		return   # nothing to sacrifice; the state trigger buries the Djinn
	lands.sort_custom(_islands_last)
	var chosen := game.agents[pid].choose_card(game, pid, lands,
		"Sacrifice a land to %s" % source.data.card_name)
	if chosen == null or not lands.has(chosen):
		chosen = lands[0]   # the sacrifice is mandatory
	var was_island := chosen.has_subtype("island")
	game.sacrifice_permanent(chosen)
	if was_island:
		game.deal_damage(source, TargetRef.player(pid), 3)

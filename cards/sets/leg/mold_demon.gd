extends CardScript
## Mold Demon — {5}{B}{B} — Creature — Fungus Demon — 6/6 — (leg, rare)
## Oracle: When this creature enters, sacrifice it unless you sacrifice
##         two Swamps.
##
## Implementation: an ETB trigger that OFFERS two Swamps through the
## controller's DecisionAgent (the sacrifice is an optional cost, and the
## player picks which Swamps) and otherwise eats the Demon. A 6/6 for
## seven that also costs two lands — Legends' pricing on a large body.


func build() -> CardData:
	return CardData.new("Mold Demon", "{5}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(6, 6) \
		.with_subtypes(["fungus", "demon"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _toll,
			"When Mold Demon enters, sacrifice it unless you sacrifice two Swamps.",
			_is_self)) \
		.oracle("When this creature enters, sacrifice it unless you sacrifice two Swamps.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _toll(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var swamps: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_land() and inst.has_subtype("swamp"):
			swamps.append(inst)
	if swamps.size() < 2 or not game.agents[pid].choose_yes_no(game, pid,
			"Sacrifice two Swamps to keep %s?" % source.data.card_name, true):
		game.sacrifice_permanent(source)
		return
	for _i in 2:
		var pick := game.agents[pid].choose_card(game, pid, swamps, "Sacrifice a Swamp")
		if pick == null or not swamps.has(pick):
			pick = swamps[0]
		swamps.erase(pick)
		game.sacrifice_permanent(pick)

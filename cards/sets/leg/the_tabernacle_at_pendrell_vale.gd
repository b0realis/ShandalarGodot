extends CardScript
## The Tabernacle at Pendrell Vale — Legendary Land — (leg, rare)
## Oracle: All creatures have "At the beginning of your upkeep, destroy
##         this creature unless you pay {1}."
##
## Implementation: rather than granting a trigger to every creature, the
## Tabernacle carries ONE upkeep trigger that walks the ACTIVE player's
## creatures and charges {1} for each — the granted ability's "your
## upkeep" means the creature's controller, so only the active player
## pays on any given turn, and over a turn cycle both players do.
## Observationally identical in a duel. Symmetric and land-cheap: the
## most feared prison land of the era.


func build() -> CardData:
	return CardData.new("The Tabernacle at Pendrell Vale", "", Mtg.CardType.LAND) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _rent,
			"At the beginning of each player's upkeep, that player destroys each "
			+ "creature they control unless they pay {1} for it.")) \
		.oracle("All creatures have \"At the beginning of your upkeep, destroy this "
			+ "creature unless you pay {1}.\"")


static func _rent(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var creatures: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_creature():
			creatures.append(inst)
	for inst in creatures:
		if inst.zone != Mtg.Zone.BATTLEFIELD:
			continue
		var cost := ManaCost.parse("{1}")
		if game.can_afford_cost(pid, cost) \
				and game.agents[pid].choose_yes_no(game, pid,
					"Pay {1} to keep %s?" % inst.data.card_name, true) \
				and game.try_pay(pid, cost):
			continue
		game.destroy(inst)

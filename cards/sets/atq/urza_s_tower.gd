extends CardScript
## Urza's Tower — Land — Urza's Tower — (atq, common)
## Oracle: {T}: Add {C}. If you control an Urza's Mine and an Urza's
##         Power-Plant, add {C}{C}{C} instead.
##
## Implementation: the Urzatron's payoff piece — three colourless once the
## set is complete, one otherwise. Same dynamic ManaAbility shape as its
## two siblings.


func build() -> CardData:
	return CardData.new("Urza's Tower", "", Mtg.CardType.LAND) \
		.with_subtypes(["urza's", "tower"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.C).with_dynamic_amount(_amount)) \
		.oracle("{T}: Add {C}. If you control an Urza's Mine and an Urza's "
			+ "Power-Plant, add {C}{C}{C} instead.")


static func _controls(game: MtgGame, pid: int, card_name: String) -> bool:
	for inst in game.players[pid].battlefield:
		if inst.data.card_name == card_name:
			return true
	return false


static func _amount(game: MtgGame, source: CardInstance) -> int:
	var pid := source.controller_id
	if _controls(game, pid, "Urza's Mine") and _controls(game, pid, "Urza's Power Plant"):
		return 3
	return 1

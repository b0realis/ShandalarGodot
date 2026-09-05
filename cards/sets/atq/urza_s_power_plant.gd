extends CardScript
## Urza's Power Plant — Land — Urza's Power-Plant — (atq, common)
## Oracle: {T}: Add {C}. If you control an Urza's Mine and an Urza's
##         Tower, add {C}{C} instead.
##
## Implementation: the Urzatron's middle piece — the same dynamic
## ManaAbility as Urza's Mine, looking for the other two by name.


func build() -> CardData:
	return CardData.new("Urza's Power Plant", "", Mtg.CardType.LAND) \
		.with_subtypes(["urza's", "power-plant"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.C).with_dynamic_amount(_amount)) \
		.oracle("{T}: Add {C}. If you control an Urza's Mine and an Urza's Tower, "
			+ "add {C}{C} instead.")


static func _controls(game: MtgGame, pid: int, card_name: String) -> bool:
	for inst in game.players[pid].battlefield:
		if inst.data.card_name == card_name:
			return true
	return false


static func _amount(game: MtgGame, source: CardInstance) -> int:
	var pid := source.controller_id
	if _controls(game, pid, "Urza's Mine") and _controls(game, pid, "Urza's Tower"):
		return 2
	return 1

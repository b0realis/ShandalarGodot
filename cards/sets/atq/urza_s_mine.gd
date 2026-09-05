extends CardScript
## Urza's Mine — Land — Urza's Mine — (atq, uncommon)
## Oracle: {T}: Add {C}. If you control an Urza's Power-Plant and an
##         Urza's Tower, add {C}{C} instead.
##
## Implementation: a ManaAbility with a DYNAMIC amount — the callable
## checks the CONTROLLER's battlefield for the two siblings by name and
## returns 2 when the Tron is assembled, 1 otherwise. The three lands
## together produce seven colourless a turn, which is the whole point.


func build() -> CardData:
	return CardData.new("Urza's Mine", "", Mtg.CardType.LAND) \
		.with_subtypes(["urza's", "mine"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.C).with_dynamic_amount(_amount)) \
		.oracle("{T}: Add {C}. If you control an Urza's Power-Plant and an Urza's "
			+ "Tower, add {C}{C} instead.")


static func _controls(game: MtgGame, pid: int, card_name: String) -> bool:
	for inst in game.players[pid].battlefield:
		if inst.data.card_name == card_name:
			return true
	return false


static func _amount(game: MtgGame, source: CardInstance) -> int:
	var pid := source.controller_id
	if _controls(game, pid, "Urza's Power Plant") and _controls(game, pid, "Urza's Tower"):
		return 2
	return 1

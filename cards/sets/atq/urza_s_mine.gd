extends CardScript
## Urza's Mine — Land — Urza's Mine — (atq, uncommon)
## Oracle: {T}: Add {C}. If you control an Urza's Power-Plant and an
##         Urza's Tower, add {C}{C} instead.
##
## Implementation: a ManaAbility with a DYNAMIC amount — the callable
## checks the CONTROLLER's battlefield for the two siblings by land type and
## returns 2 when the Tron is assembled, 1 otherwise. The three lands
## together produce seven colourless a turn, which is the whole point.


func build() -> CardData:
	return CardData.new("Urza's Mine", "", Mtg.CardType.LAND) \
		.with_subtypes(["urza's", "mine"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.C).with_dynamic_amount(_amount, true)) \
		.oracle("{T}: Add {C}. If you control an Urza's Power-Plant and an Urza's "
			+ "Tower, add {C}{C} instead.")


## "An Urza's Power-Plant" names a LAND TYPE pair (Urza's + Power-Plant),
## not a card: read the live subtypes (CONTRIBUTING.md rule 5), so an Evil
## Presence on the Tower breaks the set and nothing else completes it by
## name alone. Until 2026-10-03 this matched card names.
static func _controls(game: MtgGame, pid: int, piece: String) -> bool:
	for inst in game.players[pid].battlefield:
		if inst.is_land() and inst.has_subtype("urza's") and inst.has_subtype(piece):
			return true
	return false


static func _amount(game: MtgGame, _source: CardInstance, pid: int) -> int:
	if _controls(game, pid, "power-plant") and _controls(game, pid, "tower"):
		return 2
	return 1

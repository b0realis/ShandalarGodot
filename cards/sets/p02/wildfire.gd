extends CardScript
## Wildfire — {4}{R}{R} — Sorcery (Portal Second Age, 1998).
## Oracle: Each player sacrifices four lands of their choice. Wildfire deals 4 damage to each creature.

func build() -> CardData:
	var c := CardData.new("Wildfire", "{4}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Each player sacrifices four lands of their choice. Wildfire deals 4 damage to each creature.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)

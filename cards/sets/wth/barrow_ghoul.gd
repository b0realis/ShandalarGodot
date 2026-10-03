extends CardScript
## Barrow Ghoul — {1}{B} — Creature — Zombie (common, wth).
## Oracle: At the beginning of your upkeep, sacrifice this creature unless you exile the top creature card of your graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Barrow Ghoul", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["zombie"])
	c.oracle("At the beginning of your upkeep, sacrifice this creature unless you exile the top creature card of your graveyard.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

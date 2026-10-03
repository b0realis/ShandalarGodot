extends CardScript
## Peacekeeper — {2}{W} — Creature — Human (rare, wth).
## Oracle: At the beginning of your upkeep, sacrifice this creature unless you pay {1}{W}.
##         Creatures can't attack.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Peacekeeper", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human"])
	c.oracle("At the beginning of your upkeep, sacrifice this creature unless you pay {1}{W}.\nCreatures can't attack.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

extends CardScript
## Multani's Acolyte — {G}{G} — Creature — Elf (common, ulg).
## Oracle: Echo {G}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Multani's Acolyte", "{G}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["elf"])
	c.oracle("Echo {G}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, draw a card.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

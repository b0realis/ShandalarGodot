extends CardScript
## Yavimaya Granger — {2}{G} — Creature — Elf (common, ulg).
## Oracle: Echo {2}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, you may search your library for a basic land card, put that card onto the battlefield tapped, then shuffle.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Yavimaya Granger", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["elf"])
	c.oracle("Echo {2}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, you may search your library for a basic land card, put that card onto the battlefield tapped, then shuffle.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

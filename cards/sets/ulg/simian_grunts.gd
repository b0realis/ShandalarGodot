extends CardScript
## Simian Grunts — {2}{G} — Creature — Ape (common, ulg).
## Oracle: Flash
##         Echo {2}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Simian Grunts", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["ape"])
	c.with_keywords([Mtg.Keyword.FLASH])
	c.oracle("Flash\nEcho {2}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

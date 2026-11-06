extends CardScript
## Shivan Raptor — {2}{R} — Creature — Dinosaur (uncommon, usg).
## Oracle: First strike, haste
##         Echo {2}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shivan Raptor", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 1)
	c.with_subtypes(["dinosaur"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.HASTE])
	c.oracle("First strike, haste\nEcho {2}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)

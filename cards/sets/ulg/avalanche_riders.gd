extends CardScript
## Avalanche Riders — {3}{R} — Creature — Human Nomad (uncommon, ulg).
## Oracle: Haste
##         Echo {3}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, destroy target land.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Avalanche Riders", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","nomad"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste\nEcho {3}{R} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, destroy target land.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

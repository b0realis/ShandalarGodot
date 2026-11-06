extends CardScript
## Thran War Machine — {4} — Artifact Creature — Construct (uncommon, ulg).
## Oracle: Echo {4} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         This creature attacks each combat if able.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thran War Machine", "{4}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(4, 5)
	c.with_subtypes(["construct"])
	c.oracle("Echo {4} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nThis creature attacks each combat if able.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

extends CardScript
## Ring of Gix — {3} — Artifact (rare, ulg).
## Oracle: Echo {3} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         {1}, {T}: Tap target artifact, creature, or land.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ring of Gix", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("Echo {3} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\n{1}, {T}: Tap target artifact, creature, or land.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

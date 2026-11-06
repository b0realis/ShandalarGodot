extends CardScript
## Extruder — {4} — Artifact Creature — Juggernaut (uncommon, uds).
## Oracle: Echo {4} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         Sacrifice an artifact: Put a +1/+1 counter on target creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Extruder", "{4}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(4, 3)
	c.with_subtypes(["juggernaut"])
	c.oracle("Echo {4} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nSacrifice an artifact: Put a +1/+1 counter on target creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

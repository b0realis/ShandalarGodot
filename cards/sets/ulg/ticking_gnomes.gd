extends CardScript
## Ticking Gnomes — {3} — Artifact Creature — Gnome (uncommon, ulg).
## Oracle: Echo {3} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         Sacrifice this creature: It deals 1 damage to any target.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ticking Gnomes", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(3, 3)
	c.with_subtypes(["gnome"])
	c.oracle("Echo {3} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nSacrifice this creature: It deals 1 damage to any target.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

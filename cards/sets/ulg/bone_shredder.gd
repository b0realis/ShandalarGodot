extends CardScript
## Bone Shredder — {2}{B} — Creature — Phyrexian Minion (uncommon, ulg).
## Oracle: Flying
##         Echo {2}{B} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, destroy target nonartifact, nonblack creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bone Shredder", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["phyrexian","minion"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nEcho {2}{B} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, destroy target nonartifact, nonblack creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

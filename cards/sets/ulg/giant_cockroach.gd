extends CardScript
## Giant Cockroach — {3}{B} — Creature — Insect (common, ulg).
## Oracle: (No rules text.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Giant Cockroach", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(4, 2)
	c.with_subtypes(["insect"])
	c.oracle("")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

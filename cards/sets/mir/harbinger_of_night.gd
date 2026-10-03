extends CardScript
## Harbinger of Night — {2}{B}{B} — Creature — Spirit (rare, mir).
## Oracle: At the beginning of your upkeep, put a -1/-1 counter on each creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Harbinger of Night", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["spirit"])
	c.oracle("At the beginning of your upkeep, put a -1/-1 counter on each creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

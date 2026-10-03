extends CardScript
## Lichenthrope — {3}{G}{G} — Creature — Plant Fungus (rare, vis).
## Oracle: If damage would be dealt to this creature, put that many -1/-1 counters on it instead.
##         At the beginning of your upkeep, remove a -1/-1 counter from this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lichenthrope", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["plant","fungus"])
	c.oracle("If damage would be dealt to this creature, put that many -1/-1 counters on it instead.\nAt the beginning of your upkeep, remove a -1/-1 counter from this creature.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

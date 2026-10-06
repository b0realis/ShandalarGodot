extends CardScript
## Dirtcowl Wurm — {4}{G} — Creature — Wurm (rare, tmp).
## Oracle: Whenever an opponent plays a land, put a +1/+1 counter on this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dirtcowl Wurm", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["wurm"])
	c.oracle("Whenever an opponent plays a land, put a +1/+1 counter on this creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

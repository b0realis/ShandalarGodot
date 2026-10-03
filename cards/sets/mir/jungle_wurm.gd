extends CardScript
## Jungle Wurm — {3}{G}{G} — Creature — Wurm (common, mir).
## Oracle: Whenever this creature becomes blocked, it gets -1/-1 until end of turn for each creature blocking it beyond the first.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jungle Wurm", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["wurm"])
	c.oracle("Whenever this creature becomes blocked, it gets -1/-1 until end of turn for each creature blocking it beyond the first.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

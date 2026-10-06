extends CardScript
## Segmented Wurm — {3}{R}{G} — Creature — Wurm (uncommon, tmp).
## Oracle: Whenever this creature becomes the target of a spell or ability, put a -1/-1 counter on it.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Segmented Wurm", "{3}{R}{G}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["wurm"])
	c.oracle("Whenever this creature becomes the target of a spell or ability, put a -1/-1 counter on it.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

extends CardScript
## Wild Elephant — {3}{G} — Creature — Elephant (common, mir).
## Oracle: Trample
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wild Elephant", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["elephant"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

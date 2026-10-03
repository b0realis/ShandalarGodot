extends CardScript
## Uktabi Faerie — {1}{G} — Creature — Faerie (common, mir).
## Oracle: Flying
##         {3}{G}, Sacrifice this creature: Destroy target artifact.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Uktabi Faerie", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["faerie"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{3}{G}, Sacrifice this creature: Destroy target artifact.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

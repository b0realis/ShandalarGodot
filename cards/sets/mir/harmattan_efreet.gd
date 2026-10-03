extends CardScript
## Harmattan Efreet — {2}{U}{U} — Creature — Efreet (uncommon, mir).
## Oracle: Flying
##         {1}{U}{U}: Target creature gains flying until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Harmattan Efreet", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["efreet"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{1}{U}{U}: Target creature gains flying until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

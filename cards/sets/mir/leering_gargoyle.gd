extends CardScript
## Leering Gargoyle — {1}{W}{U} — Creature — Gargoyle (rare, mir).
## Oracle: Flying
##         {T}: This creature gets -2/+2 and loses flying until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Leering Gargoyle", "{1}{W}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["gargoyle"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{T}: This creature gets -2/+2 and loses flying until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

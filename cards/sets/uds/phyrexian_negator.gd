extends CardScript
## Phyrexian Negator — {2}{B} — Creature — Phyrexian Horror (rare, uds).
## Oracle: Trample
##         Whenever this creature is dealt damage, sacrifice that many permanents.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Negator", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(5, 5)
	c.with_subtypes(["phyrexian","horror"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nWhenever this creature is dealt damage, sacrifice that many permanents.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)

extends CardScript
## Spirit en-Kor — {3}{W} — Creature — Kor Spirit (common, sth).
## Oracle: Flying
##         {0}: The next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spirit en-Kor", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["kor","spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{0}: The next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

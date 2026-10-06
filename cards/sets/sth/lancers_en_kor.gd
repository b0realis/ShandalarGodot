extends CardScript
## Lancers en-Kor — {3}{W}{W} — Creature — Kor Soldier (uncommon, sth).
## Oracle: Trample
##         {0}: The next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lancers en-Kor", "{3}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["kor","soldier"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\n{0}: The next 1 damage that would be dealt to this creature this turn is dealt to target creature you control instead.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

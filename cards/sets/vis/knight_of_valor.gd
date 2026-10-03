extends CardScript
## Knight of Valor — {2}{W} — Creature — Human Knight (common, vis).
## Oracle: Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
##         {1}{W}: Each creature without flanking blocking this creature gets -1/-1 until end of turn. Activate only once each turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Knight of Valor", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.oracle("Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)\n{1}{W}: Each creature without flanking blocking this creature gets -1/-1 until end of turn. Activate only once each turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

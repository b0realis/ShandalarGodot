extends CardScript
## Knight of the Mists — {2}{U} — Creature — Human Knight (common, vis).
## Oracle: Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
##         When this creature enters, you may pay {U}. If you don't, destroy target Knight and it can't be regenerated.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Knight of the Mists", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.oracle("Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)\nWhen this creature enters, you may pay {U}. If you don't, destroy target Knight and it can't be regenerated.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

extends CardScript
## Suq'Ata Lancer — {2}{R} — Creature — Human Knight (common, vis).
## Oracle: Haste
##         Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Suq'Ata Lancer", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste\nFlanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

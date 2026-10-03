extends CardScript
## Shadow Rider — {2}{B}{B} — Creature — Knight (common, wth).
## Oracle: Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shadow Rider", "{2}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["knight"])
	c.oracle("Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

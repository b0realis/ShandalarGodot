extends CardScript
## Cadaverous Knight — {2}{B} — Creature — Zombie Knight (common, mir).
## Oracle: Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
##         {1}{B}{B}: Regenerate this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cadaverous Knight", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["zombie","knight"])
	c.oracle("Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)\n{1}{B}{B}: Regenerate this creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

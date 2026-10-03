extends CardScript
## Searing Spear Askari — {2}{R} — Creature — Human Knight (common, mir).
## Oracle: Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
##         {1}{R}: This creature gains menace until end of turn. (It can't be blocked except by two or more creatures.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Searing Spear Askari", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.oracle("Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)\n{1}{R}: This creature gains menace until end of turn. (It can't be blocked except by two or more creatures.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

extends CardScript
## Burning Shield Askari — {2}{R} — Creature — Human Knight (common, mir).
## Oracle: Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
##         {R}{R}: This creature gains first strike until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Burning Shield Askari", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.oracle("Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)\n{R}{R}: This creature gains first strike until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

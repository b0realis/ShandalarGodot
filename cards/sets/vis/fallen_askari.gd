extends CardScript
## Fallen Askari — {1}{B} — Creature — Human Knight (common, vis).
## Oracle: Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
##         This creature can't block.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fallen Askari", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.oracle("Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)\nThis creature can't block.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

extends CardScript
## Zhalfirin Commander — {2}{W} — Creature — Human Knight (uncommon, mir).
## Oracle: Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
##         {1}{W}{W}: Target Knight creature gets +1/+1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Zhalfirin Commander", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.oracle("Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)\n{1}{W}{W}: Target Knight creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

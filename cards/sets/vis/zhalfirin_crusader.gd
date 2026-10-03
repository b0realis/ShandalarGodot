extends CardScript
## Zhalfirin Crusader — {1}{W}{W} — Creature — Human Knight (rare, vis).
## Oracle: Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
##         {1}{W}: The next 1 damage that would be dealt to this creature this turn is dealt to any target instead.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Zhalfirin Crusader", "{1}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.oracle("Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)\n{1}{W}: The next 1 damage that would be dealt to this creature this turn is dealt to any target instead.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

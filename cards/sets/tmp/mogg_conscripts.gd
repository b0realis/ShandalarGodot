extends CardScript
## Mogg Conscripts — {R} — Creature — Goblin (common, tmp).
## Oracle: This creature can't attack unless you've cast a creature spell this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mogg Conscripts", "{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["goblin"])
	c.oracle("This creature can't attack unless you've cast a creature spell this turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

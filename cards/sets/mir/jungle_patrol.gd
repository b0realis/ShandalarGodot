extends CardScript
## Jungle Patrol — {3}{G} — Creature — Human Soldier (rare, mir).
## Oracle: {1}{G}, {T}: Create a 0/1 green Wall creature token with defender named Wood.
##         Sacrifice a token named Wood: Add {R}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jungle Patrol", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["human","soldier"])
	c.oracle("{1}{G}, {T}: Create a 0/1 green Wall creature token with defender named Wood.\nSacrifice a token named Wood: Add {R}.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

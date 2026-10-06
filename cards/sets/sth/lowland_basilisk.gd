extends CardScript
## Lowland Basilisk — {2}{G} — Creature — Basilisk (common, sth).
## Oracle: Whenever this creature deals damage to a creature, destroy that creature at end of combat.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lowland Basilisk", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["basilisk"])
	c.oracle("Whenever this creature deals damage to a creature, destroy that creature at end of combat.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)

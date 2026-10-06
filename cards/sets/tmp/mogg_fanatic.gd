extends CardScript
## Mogg Fanatic — {R} — Creature — Goblin (common, tmp).
## Oracle: Sacrifice this creature: It deals 1 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mogg Fanatic", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin"])
	c.oracle("Sacrifice this creature: It deals 1 damage to any target.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)

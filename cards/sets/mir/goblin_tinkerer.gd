extends CardScript
## Goblin Tinkerer — {1}{R} — Creature — Goblin Artificer (common, mir).
## Oracle: {R}, {T}: Destroy target artifact. That artifact deals damage equal to its mana value to this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Tinkerer", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["goblin","artificer"])
	c.oracle("{R}, {T}: Destroy target artifact. That artifact deals damage equal to its mana value to this creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

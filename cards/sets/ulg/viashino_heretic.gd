extends CardScript
## Viashino Heretic — {2}{R} — Creature — Lizard (uncommon, ulg).
## Oracle: {1}{R}, {T}: Destroy target artifact. This creature deals damage to that artifact's controller equal to the artifact's mana value.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Viashino Heretic", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["lizard"])
	c.oracle("{1}{R}, {T}: Destroy target artifact. This creature deals damage to that artifact's controller equal to the artifact's mana value.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)

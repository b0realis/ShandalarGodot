extends CardScript
## Jungle Troll — {1}{R}{G} — Creature — Troll (uncommon, mir).
## Oracle: {R}: Regenerate this creature.
##         {G}: Regenerate this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jungle Troll", "{1}{R}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["troll"])
	c.oracle("{R}: Regenerate this creature.\n{G}: Regenerate this creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

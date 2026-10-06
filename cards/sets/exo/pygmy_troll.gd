extends CardScript
## Pygmy Troll — {1}{G} — Creature — Troll (common, exo).
## Oracle: Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn.
##         {G}: Regenerate this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pygmy Troll", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["troll"])
	c.oracle("Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn.\n{G}: Regenerate this creature.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

extends CardScript
## Locust Swarm — {3}{G} — Creature — Insect (uncommon, mir).
## Oracle: Flying
##         {G}: Regenerate this creature.
##         {G}: Untap this creature. Activate only once each turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Locust Swarm", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{G}: Regenerate this creature.\n{G}: Untap this creature. Activate only once each turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)

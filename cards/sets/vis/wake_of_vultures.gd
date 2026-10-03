extends CardScript
## Wake of Vultures — {3}{B} — Creature — Bird (common, vis).
## Oracle: Flying
##         {1}{B}, Sacrifice a creature: Regenerate this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wake of Vultures", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 1)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{1}{B}, Sacrifice a creature: Regenerate this creature.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

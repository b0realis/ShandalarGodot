extends CardScript
## Rootwater Alligator — {3}{G} — Creature — Crocodile (common, exo).
## Oracle: Sacrifice a Forest: Regenerate this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rootwater Alligator", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["crocodile"])
	c.oracle("Sacrifice a Forest: Regenerate this creature.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)

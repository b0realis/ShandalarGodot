extends CardScript
## Straw Golem — {1} — Artifact Creature — Golem (uncommon, wth).
## Oracle: When an opponent casts a creature spell, sacrifice this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Straw Golem", "{1}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 3)
	c.with_subtypes(["golem"])
	c.oracle("When an opponent casts a creature spell, sacrifice this creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)

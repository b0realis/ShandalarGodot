extends CardScript
## Giant Caterpillar — {3}{G} — Creature — Insect (common, vis).
## Oracle: {G}, Sacrifice this creature: Create a 1/1 green Insect creature token with flying named Butterfly at the beginning of the next end step.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Giant Caterpillar", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["insect"])
	c.oracle("{G}, Sacrifice this creature: Create a 1/1 green Insect creature token with flying named Butterfly at the beginning of the next end step.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)

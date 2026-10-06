extends CardScript
## Escaped Shapeshifter — {3}{U}{U} — Creature — Shapeshifter (rare, tmp).
## Oracle: As long as an opponent controls a creature with flying not named Escaped Shapeshifter, this creature has flying. The same is true for first strike, trample, and protection from any color.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Escaped Shapeshifter", "{3}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["shapeshifter"])
	c.oracle("As long as an opponent controls a creature with flying not named Escaped Shapeshifter, this creature has flying. The same is true for first strike, trample, and protection from any color.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
